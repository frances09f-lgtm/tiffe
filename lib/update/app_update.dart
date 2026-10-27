import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/gemini/auth_screens.dart' show GColors;
import 'update_download.dart';

/// In-app self-update: checks for a newer release, shows a
/// "Software Update" dialog with release notes, downloads the APK in-app
/// with a progress bar, and hands it to the Android package installer.
/// No browser is ever opened. All version/download-dir facts come from the
/// native "app/update" MethodChannel, so this file adds no pub dependencies.

// ---- per-app configuration (the only lines that change between apps) ----
const kAppName = 'Tiffe';
// GitHub mode: slug of the public repo whose latest release carries the APK.
const kUpdateRepo = 'frances09f-lgtm/tiffe';
// Feed mode (for apps whose source repo is private): public JSON file with
// {"<kFeedKey>": {"version": "...", "notes": "...", "apk": "..."}}.
const kUpdateFeedUrl =
    'https://raw.githubusercontent.com/frances09f-lgtm/child-safety-updates/main/version.json';
const kFeedKey = 'tiffe';
// Second feed, written by the release CI (APK mirror workflow) on the
// apk-mirror branch of this repo. The newest version across both feeds wins.
const kMirrorFeedUrl =
    'https://raw.githubusercontent.com/frances09f-lgtm/tiffe/apk-mirror/version.json';
const kUpdateFeedUrls = [kUpdateFeedUrl, kMirrorFeedUrl];
// -------------------------------------------------------------------------

const kAutoCheckInterval = Duration(hours: 6);
const _kLastCheckKey = 'app_update_last_check_ms';

class UpdateInfo {
  final String version;
  final String notes;
  final String apkUrl;

  /// Every address this APK can be downloaded from, best first. Always
  /// contains [apkUrl].
  final List<String> apkUrls;

  /// Exact APK size in bytes when the feed states it.
  final int? size;
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    List<String>? apkUrls,
    this.size,
  }) : apkUrls = apkUrls ?? const [];

  /// Download addresses in the order the updater tries them.
  List<Uri> get downloadUrls => orderDownloadUrls([apkUrl, ...apkUrls]);
}

/// One feed entry ({"version", "notes", "apk", "mirrors", "size"}) or null.
UpdateInfo? parseFeedEntry(Object? e) {
  if (e is! Map) return null;
  final v = (e['version'] is String ? e['version'] as String : '').trim();
  final apk = (e['apk'] is String ? e['apk'] as String : '').trim();
  if (v.isEmpty || apk.isEmpty) return null;
  final mirrors = <String>[
    for (final m in (e['mirrors'] is List ? e['mirrors'] as List : const []))
      if (m is String && m.trim().isNotEmpty) m.trim(),
  ];
  final size = e['size'] is int ? e['size'] as int : null;
  return UpdateInfo(
    version: v,
    notes: (e['notes'] is String ? e['notes'] as String : '').trim(),
    apkUrl: apk,
    apkUrls: [apk, ...mirrors],
    size: size != null && size > 0 ? size : null,
  );
}

/// Newest entry across feeds; download addresses of every feed that lists
/// that same version are combined (mirror and GitHub alike).
UpdateInfo? pickNewest(Iterable<UpdateInfo?> entries) {
  final list = entries.whereType<UpdateInfo>().toList();
  if (list.isEmpty) return null;
  var best = list.first;
  for (final e in list.skip(1)) {
    if (compareVersions(e.version, best.version) > 0) best = e;
  }
  final same = list.where((e) => compareVersions(e.version, best.version) == 0);
  final urls = orderDownloadUrls([
    for (final e in same) ...[e.apkUrl, ...e.apkUrls],
  ]).map((u) => u.toString()).toList();
  final notes = same
      .map((e) => e.notes)
      .firstWhere((n) => n.isNotEmpty, orElse: () => best.notes);
  final size = same.map((e) => e.size).whereType<int>().firstOrNull;
  return UpdateInfo(
    version: best.version,
    notes: notes,
    apkUrl: urls.first,
    apkUrls: urls,
    size: size,
  );
}

/// Numeric semver-ish compare: >0 when a > b. Ignores a leading v and any
/// +build suffix; missing segments count as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

class UpdateChecker {
  UpdateChecker({
    http.Client? client,
    Future<String> Function()? currentVersion,
    Future<void> Function(String apkPath)? installer,
    Future<bool> Function()? canInstall,
    Future<void> Function()? openInstallSettings,
    Future<Directory> Function()? cacheDir,
    DateTime Function()? clock,
    this._downloader,
  }) : _client = client ?? http.Client(),
       _injectedClient = client,
       _currentVersion = currentVersion ?? _nativeVersion,
       _installer = installer ?? _nativeInstall,
       _canInstall = canInstall ?? _nativeCanInstall,
       _openInstallSettings = openInstallSettings ?? _nativeOpenSettings,
       _cacheDir = cacheDir ?? _nativeCacheDir,
       _clock = clock ?? DateTime.now;

  static const _channel = MethodChannel('app/update');
  final http.Client _client;
  final http.Client? _injectedClient;
  final Future<String> Function() _currentVersion;
  final Future<void> Function(String) _installer;
  final Future<bool> Function() _canInstall;
  final Future<void> Function() _openInstallSettings;
  final Future<Directory> Function() _cacheDir;
  final Future<File> Function(
    UpdateInfo info, {
    void Function(int received, int? total)? onProgress,
    Stream<void>? cancelToken,
  })?
  _downloader;
  final DateTime Function() _clock;

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
      throw StateError('no cache dir from platform');
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

  /// Latest release info, or null when there is nothing newer or the check
  /// fails (offline, rate limit): callers treat null as "no update".
  Future<UpdateInfo?> fetchLatest() async {
    try {
      final info = kUpdateFeedUrl.isNotEmpty
          ? await _fetchFromFeed()
          : await _fetchFromGithub();
      if (info == null) return null;
      final current = await _currentVersion();
      return compareVersions(info.version, current) > 0 ? info : null;
    } catch (_) {
      return null;
    }
  }

  Future<UpdateInfo?> _fetchFromGithub() async {
    final res = await _client
        .get(
          Uri.parse(
            'https://api.github.com/repos/$kUpdateRepo/releases/latest',
          ),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': '$kAppName-app',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) return null;
    String? apk;
    for (final a in (j['assets'] as List? ?? const [])) {
      final name = (a as Map)['name'] as String? ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apk = a['browser_download_url'] as String?;
        break;
      }
    }
    if (apk == null) return null;
    return UpdateInfo(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      notes: (j['body'] as String? ?? '').trim(),
      apkUrl: apk,
    );
  }

  Future<UpdateInfo?> _fetchFromFeed() async {
    // Both feeds at once; a feed that fails (blocked, offline, missing) is
    // skipped, so either one alone is enough.
    final entries = await Future.wait(
      kUpdateFeedUrls.map((url) async {
        try {
          final res = await _client
              .get(Uri.parse(url), headers: {'User-Agent': '$kAppName-app'})
              .timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) return null;
          final j = jsonDecode(res.body);
          return j is Map ? parseFeedEntry(j[kFeedKey]) : null;
        } catch (_) {
          return null;
        }
      }),
    );
    return pickNewest(entries);
  }

  /// Auto check on app start: at most once per [kAutoCheckInterval].
  Future<UpdateInfo?> autoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastCheckKey) ?? 0;
    if (_clock().millisecondsSinceEpoch - last <
        kAutoCheckInterval.inMilliseconds) {
      return null;
    }
    final info = await fetchLatest();
    // Stamp even failures so an offline stretch does not poll every launch.
    await prefs.setInt(_kLastCheckKey, _clock().millisecondsSinceEpoch);
    return info;
  }

  /// Download the APK to the cache dir with byte progress.
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int? total)? onProgress,
    void Function(int source, Uri url)? onSourceChange,
    Stream<void>? cancelToken,
  }) async {
    final dl = _downloader;
    if (dl != null) {
      return dl(info, onProgress: onProgress, cancelToken: cancelToken);
    }
    final dir = Directory(
      '${(await _cacheDir()).path}${Platform.pathSeparator}updates',
    );
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}$kAppName-${info.version}.apk',
    );
    final injected = _injectedClient;
    return downloadApkWithFallback(
      urls: info.downloadUrls,
      target: file,
      clientFactory: injected != null ? () => injected : http.Client.new,
      closeClients: injected == null,
      userAgent: '$kAppName-app',
      expectedSize: info.size,
      onProgress: (r, t, _) => onProgress?.call(r, t),
      onSourceChange: onSourceChange,
      cancelToken: cancelToken,
    );
  }

  Future<void> install(File apk) => _installer(apk.path);
  Future<bool> canInstall() => _canInstall();
  Future<void> openInstallSettings() => _openInstallSettings();
}

/// Root navigator key for apps that set MaterialApp.navigatorKey: lets the
/// update dialog survive splash->home navigation.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Launch-time check for apps using [appNavigatorKey]. Fire-and-forget.
Future<void> checkForUpdateOnLaunch({UpdateChecker? checker}) async {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;
  final c = checker ?? UpdateChecker();
  final info = await c.autoCheck();
  final ctx = appNavigatorKey.currentContext;
  if (info != null && ctx != null && ctx.mounted) {
    await showUpdateDialog(ctx, info, checker: c);
  }
}

/// Auto-prompt entry point called once after the first frame.
Future<void> maybePromptUpdate(
  BuildContext context, {
  UpdateChecker? checker,
}) async {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;
  final c = checker ?? UpdateChecker();
  final info = await c.autoCheck();
  if (info != null && context.mounted) {
    await showUpdateDialog(context, info, checker: c);
  }
}

/// Manual "Check for updates": always fetches, reports when up to date.
Future<void> checkUpdateManually(
  BuildContext context, {
  UpdateChecker? checker,
}) async {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;
  final c = checker ?? UpdateChecker();
  final info = await c.fetchLatest();
  if (!context.mounted) return;
  if (info == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('No update available')));
    return;
  }
  await showUpdateDialog(context, info, checker: c);
}

enum _Phase { available, downloading, needsPermission, installing, error }

Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  UpdateChecker? checker,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _UpdateDialog(info: info, checker: checker ?? UpdateChecker()),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final UpdateChecker checker;
  const _UpdateDialog({required this.info, required this.checker});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase phase = _Phase.available;
  int received = 0;
  int? total;
  String? error;
  String? source;
  final _cancel = StreamController<void>.broadcast();

  @override
  void dispose() {
    _cancel.close();
    super.dispose();
  }

  Future<void> _start() async {
    // The one Android requirement we cannot skip: "install unknown apps"
    // for this app. Ask once, explain inside the dialog, then continue.
    final allowed = await widget.checker.canInstall();
    if (!mounted) return;
    if (!allowed) {
      setState(() => phase = _Phase.needsPermission);
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
        cancelToken: _cancel.stream,
      );
      if (!mounted) return;
      setState(() => phase = _Phase.installing);
      // Android always shows its own package-installer confirm screen; that
      // tap is the system's, not ours.
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
    final dim = GColors.grey;
    final v = widget.info.version;
    final progress = total != null && total! > 0
        ? (received / total!).clamp(0.0, 1.0)
        : null;
    return AlertDialog(
      backgroundColor: GColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Software Update', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(switch (phase) {
              _Phase.available => '$kAppName $v is available',
              _Phase.downloading => 'Downloading $kAppName $v...',
              _Phase.needsPermission => 'One permission needed',
              _Phase.installing => 'Opening installer...',
              _Phase.error => 'Update failed',
            }, style: TextStyle(color: dim, fontSize: 13)),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
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
              _cancel.add(null);
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
            onPressed: () async {
              await widget.checker.openInstallSettings();
            },
            child: const Text('Open settings'),
          ),
          FilledButton(onPressed: _start, child: const Text('Update')),
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
