import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../update/update_download.dart';

/// In-app update for Tiffe Staff. It reads the public update feed, shows the
/// current and latest version with release notes, downloads the APK inside the
/// app with a progress bar, and hands the file to the Android package
/// installer. No browser or external page is ever opened. Version and
/// download-folder facts come from the native "app/update" channel.

const kStaffAppName = 'Tiffe Staff';
const kStaffFeedUrl =
    'https://raw.githubusercontent.com/frances09f-lgtm/child-safety-updates/main/version.json';
const kStaffFeedKey = 'tiffe_staff';
// Second feed, written by the release CI (APK mirror workflow) on the
// apk-mirror branch. The newest version across both feeds wins.
const kStaffMirrorFeedUrl =
    'https://raw.githubusercontent.com/frances09f-lgtm/tiffe/apk-mirror/version.json';
const kStaffFeedUrls = [kStaffFeedUrl, kStaffMirrorFeedUrl];
const kStaffAutoCheckInterval = Duration(hours: 6);

class StaffUpdateInfo {
  final String version;
  final String notes;
  final String apkUrl;

  /// Every address this APK can be downloaded from (mirror, GitHub).
  final List<String> apkUrls;

  /// Exact APK size in bytes when the feed states it.
  final int? size;
  const StaffUpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    this.apkUrls = const [],
    this.size,
  });

  /// Download addresses in the order the updater tries them: mirror first,
  /// GitHub's release file host last.
  List<Uri> get downloadUrls => orderDownloadUrls([apkUrl, ...apkUrls]);
}

/// Newest entry across feeds; addresses of every feed listing that same
/// version are combined.
StaffUpdateInfo? pickNewestStaff(Iterable<StaffUpdateInfo?> entries) {
  final list = entries.whereType<StaffUpdateInfo>().toList();
  if (list.isEmpty) return null;
  var best = list.first;
  for (final e in list.skip(1)) {
    if (compareStaffVersions(e.version, best.version) > 0) best = e;
  }
  final same = list
      .where((e) => compareStaffVersions(e.version, best.version) == 0)
      .toList();
  final urls = orderDownloadUrls([
    for (final e in same) ...[e.apkUrl, ...e.apkUrls],
  ]).map((u) => u.toString()).toList();
  return StaffUpdateInfo(
    version: best.version,
    notes: same
        .map((e) => e.notes)
        .firstWhere((n) => n.isNotEmpty, orElse: () => best.notes),
    apkUrl: urls.first,
    apkUrls: urls,
    size: same.map((e) => e.size).whereType<int>().firstOrNull,
  );
}

class StaffUpdateResult {
  /// Newer release, or null when the app is current or the check failed.
  final StaffUpdateInfo? info;
  final bool failed;
  final String current;
  const StaffUpdateResult({
    required this.info,
    required this.failed,
    required this.current,
  });
}

class StaffUpdateCancel {
  bool cancelled = false;
}

/// Numeric compare: above 0 when a is newer than b. Ignores a leading v and
/// any +build suffix; missing segments count as 0.
int compareStaffVersions(String a, String b) {
  List<int> parts(String v) => v
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Reads this app's entry from the feed JSON. Returns null when the entry is
/// missing, incomplete, or the APK address is not https.
StaffUpdateInfo? parseStaffFeed(String body) {
  final Object? j;
  try {
    j = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final e = j[kStaffFeedKey];
  if (e is! Map) return null;
  final v = (e['version'] is String ? e['version'] as String : '').trim();
  final apk = (e['apk'] is String ? e['apk'] as String : '').trim();
  if (v.isEmpty || apk.isEmpty) return null;
  final uri = Uri.tryParse(apk);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  final notes = (e['notes'] is String ? e['notes'] as String : '').trim();
  final mirrors = <String>[
    for (final m in (e['mirrors'] is List ? e['mirrors'] as List : const []))
      if (m is String && m.trim().isNotEmpty) m.trim(),
  ];
  final size = e['size'] is int ? e['size'] as int : null;
  return StaffUpdateInfo(
    version: v,
    notes: notes,
    apkUrl: apk,
    apkUrls: [apk, ...mirrors],
    size: size != null && size > 0 ? size : null,
  );
}

class StaffUpdateChecker {
  StaffUpdateChecker({
    Future<String> Function(Uri uri)? fetchText,
    Future<String> Function()? currentVersion,
    Future<void> Function(String apkPath)? installer,
    Future<bool> Function()? canInstall,
    Future<void> Function()? openInstallSettings,
    Future<Directory> Function()? cacheDir,
    DateTime Function()? clock,
    http.Client Function()? clientFactory,
    Future<File> Function(
      StaffUpdateInfo info, {
      void Function(int received, int? total)? onProgress,
      StaffUpdateCancel? cancel,
    })?
    downloader,
  }) : _fetchText = fetchText ?? _httpText,
       _currentVersion = currentVersion ?? _nativeVersion,
       _installer = installer ?? _nativeInstall,
       _canInstall = canInstall ?? _nativeCanInstall,
       _openInstallSettings = openInstallSettings ?? _nativeOpenSettings,
       _cacheDir = cacheDir ?? _nativeCacheDir,
       _downloader = downloader,
       _clientFactory = clientFactory ?? http.Client.new,
       _closeClients = true,
       _clock = clock ?? DateTime.now;

  static const _channel = MethodChannel('app/update');
  final Future<String> Function(Uri uri) _fetchText;
  final http.Client Function() _clientFactory;
  final bool _closeClients;
  final Future<String> Function() _currentVersion;
  final Future<void> Function(String) _installer;
  final Future<bool> Function() _canInstall;
  final Future<void> Function() _openInstallSettings;
  final Future<Directory> Function() _cacheDir;
  final Future<File> Function(
    StaffUpdateInfo info, {
    void Function(int received, int? total)? onProgress,
    StaffUpdateCancel? cancel,
  })?
  _downloader;
  final DateTime Function() _clock;

  static Future<String> _httpText(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Tiffe-Staff-app');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw StateError('feed returned HTTP ${res.statusCode}');
      }
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _nativeVersion() async {
    try {
      return await _channel.invokeMethod<String>('appVersion') ?? '0.0.0';
    } catch (_) {
      return '0.0.0';
    }
  }

  static Future<Directory> _nativeCacheDir() async {
    final p = await _channel.invokeMethod<String>('cacheDir');
    if (p == null || p.isEmpty) {
      throw StateError('no cache folder from the phone');
    }
    return Directory(p);
  }

  static Future<bool> _nativeCanInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _nativeOpenSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } catch (_) {}
  }

  static Future<void> _nativeInstall(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }

  /// Checks the feed. A failed check is reported as failed, never as
  /// "up to date".
  Future<StaffUpdateResult> check() async {
    String current = '0.0.0';
    try {
      current = await _currentVersion();
      // Both feeds at once; either one alone is enough.
      final entries = await Future.wait(
        kStaffFeedUrls.map((url) async {
          try {
            return parseStaffFeed(await _fetchText(Uri.parse(url)));
          } catch (_) {
            return null;
          }
        }),
      );
      final info = pickNewestStaff(entries);
      if (info == null) {
        return StaffUpdateResult(info: null, failed: true, current: current);
      }
      final newer = compareStaffVersions(info.version, current) > 0;
      return StaffUpdateResult(
        info: newer ? info : null,
        failed: false,
        current: current,
      );
    } catch (_) {
      return StaffUpdateResult(info: null, failed: true, current: current);
    }
  }

  /// Start-up check, at most once per [kStaffAutoCheckInterval].
  Future<StaffUpdateInfo?> autoCheck(
    Future<int> Function() readLast,
    Future<void> Function(int ms) writeLast,
  ) async {
    final last = await readLast();
    if (_clock().millisecondsSinceEpoch - last <
        kStaffAutoCheckInterval.inMilliseconds) {
      return null;
    }
    final result = await check();
    await writeLast(_clock().millisecondsSinceEpoch);
    return result.info;
  }

  Future<File> download(
    StaffUpdateInfo info, {
    void Function(int received, int? total)? onProgress,
    void Function(int source, Uri url)? onSourceChange,
    StaffUpdateCancel? cancel,
  }) async {
    final dl = _downloader;
    if (dl != null) {
      return dl(info, onProgress: onProgress, cancel: cancel);
    }
    final dir = Directory(
      '${(await _cacheDir()).path}${Platform.pathSeparator}updates',
    );
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}Tiffe-Staff-${info.version}.apk',
    );
    // StaffUpdateCancel is a flag; turn it into the cancel signal.
    final cancelTicks = cancel == null
        ? null
        : Stream<void>.periodic(
            const Duration(milliseconds: 200),
          ).where((_) => cancel.cancelled);
    return downloadApkWithFallback(
      urls: info.downloadUrls,
      target: file,
      clientFactory: _clientFactory,
      closeClients: _closeClients,
      userAgent: 'Tiffe-Staff-app',
      expectedSize: info.size,
      onProgress: (r, t, _) => onProgress?.call(r, t),
      onSourceChange: onSourceChange,
      cancelToken: cancelTicks,
    );
  }

  Future<void> install(File apk) => _installer(apk.path);
  Future<bool> canInstall() => _canInstall();
  Future<void> openInstallSettings() => _openInstallSettings();
}

/// Called once after the first frame of the staff screens. Does nothing in
/// tests. Shows the update dialog only when a newer version is in the feed.
Future<void> maybePromptStaffUpdate(
  BuildContext context, {
  StaffUpdateChecker? checker,
}) async {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;
  final c = checker ?? StaffUpdateChecker();
  final info = await c.autoCheck(_readLast, _saveLast);
  if (info != null && context.mounted) {
    await showStaffUpdateDialog(context, info, checker: c);
  }
}

// The last-check stamp lives in a small file in the app cache folder, so the
// update code needs no extra packages.
Future<File> _stampFile() async {
  final dir = await StaffUpdateChecker._nativeCacheDir();
  return File('${dir.path}${Platform.pathSeparator}staff_update_check.txt');
}

Future<int> _readLast() async {
  try {
    final f = await _stampFile();
    if (!await f.exists()) return 0;
    return int.tryParse((await f.readAsString()).trim()) ?? 0;
  } catch (_) {
    return 0;
  }
}

Future<void> _saveLast(int ms) async {
  try {
    final f = await _stampFile();
    await f.writeAsString('$ms');
  } catch (_) {}
}

/// The Update button: always checks, and says plainly when the check failed.
Future<void> checkStaffUpdateManually(
  BuildContext context, {
  StaffUpdateChecker? checker,
}) async {
  final c = checker ?? StaffUpdateChecker();
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    const SnackBar(content: Text('Checking for updates...')),
  );
  final r = await c.check();
  messenger?.hideCurrentSnackBar();
  if (!context.mounted) return;
  if (r.failed) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Could not check for updates. Try again in a minute.'),
      ),
    );
    return;
  }
  if (r.info == null) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text('You have the latest version (${r.current}).'),
      ),
    );
    return;
  }
  await showStaffUpdateDialog(context, r.info!, checker: c, current: r.current);
}

enum _Phase { available, downloading, needsPermission, installing, error }

Future<void> showStaffUpdateDialog(
  BuildContext context,
  StaffUpdateInfo info, {
  StaffUpdateChecker? checker,
  String? current,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffUpdateDialog(
      info: info,
      checker: checker ?? StaffUpdateChecker(),
      current: current,
    ),
  );
}

class _StaffUpdateDialog extends StatefulWidget {
  final StaffUpdateInfo info;
  final StaffUpdateChecker checker;
  final String? current;
  const _StaffUpdateDialog({
    required this.info,
    required this.checker,
    this.current,
  });
  @override
  State<_StaffUpdateDialog> createState() => _StaffUpdateDialogState();
}

class _StaffUpdateDialogState extends State<_StaffUpdateDialog> {
  _Phase phase = _Phase.available;
  int received = 0;
  int? total;
  String? error;
  String? source;
  final cancel = StaffUpdateCancel();

  @override
  void dispose() {
    cancel.cancelled = true;
    super.dispose();
  }

  Future<void> _start() async {
    if (!await widget.checker.canInstall()) {
      if (mounted) setState(() => phase = _Phase.needsPermission);
      return;
    }
    await _download();
  }

  Future<void> _download() async {
    setState(() {
      phase = _Phase.downloading;
      received = 0;
      total = null;
      error = null;
      source = null;
    });
    try {
      final apk = await widget.checker.download(
        widget.info,
        onProgress: (r, t) {
          if (mounted) {
            setState(() {
              received = r;
              total = t;
            });
          }
        },
        onSourceChange: (i, url) {
          if (mounted) {
            setState(() {
              received = 0;
              source = 'Trying the ${downloadSourceName(url)}...';
            });
          }
        },
        cancel: cancel,
      );
      if (!mounted) return;
      setState(() => phase = _Phase.installing);
      await widget.checker.install(apk);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        phase = _Phase.error;
        error = e is UpdateDownloadException
            ? e.message
            : "Couldn't update: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dim = scheme.onSurfaceVariant;
    final v = widget.info.version;
    final cur = widget.current;
    final progress = total != null && total! > 0
        ? (received / total!).clamp(0.0, 1.0)
        : null;
    return AlertDialog(
      title: const Text('Software Update', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              switch (phase) {
                _Phase.available => '$kStaffAppName $v is available',
                _Phase.downloading => 'Downloading $kStaffAppName $v...',
                _Phase.needsPermission => 'One permission needed',
                _Phase.installing => 'Opening installer...',
                _Phase.error => 'Update failed',
              },
              style: TextStyle(color: dim, fontSize: 13),
            ),
          ),
          if (cur != null && phase == _Phase.available)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  'Installed: $cur  Latest: $v',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
              ),
            ),
          if (phase == _Phase.downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              total != null
                  ? '${(received / 1e6).toStringAsFixed(1)} / ${(total! / 1e6).toStringAsFixed(1)} MB'
                  : '${(received / 1e6).toStringAsFixed(1)} MB',
              style: TextStyle(color: dim, fontSize: 11),
            ),
            if (source != null)
              Text(source!, style: TextStyle(color: dim, fontSize: 11)),
          ],
          if (phase == _Phase.needsPermission)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Android asks once: allow this app to install updates. '
                'On the next screen, turn on "Allow from this source", '
                'then come back and tap Update again.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          if (phase == _Phase.error)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error ?? 'Something went wrong.',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
          if (widget.info.notes.isNotEmpty &&
              phase != _Phase.needsPermission) ...[
            const SizedBox(height: 12),
            const Text(
              "What's new",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.notes,
                  style: TextStyle(fontSize: 12, color: dim),
                ),
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (phase == _Phase.available) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(onPressed: _start, child: const Text('Update')),
        ],
        if (phase == _Phase.downloading)
          TextButton(
            onPressed: () {
              cancel.cancelled = true;
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        if (phase == _Phase.needsPermission) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => widget.checker.openInstallSettings(),
            child: const Text('Open settings'),
          ),
        ],
        if (phase == _Phase.error) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(onPressed: _download, child: const Text('Retry')),
        ],
      ],
    );
  }
}
