import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Resilient APK download for the in-app updater.
///
/// Why this exists: on some networks (seen on Indian ISPs) GitHub's release
/// file host (release-assets.githubusercontent.com) answers with headers and
/// then sends no data, so the old updater sat at "0.0 / 39.7 MB" forever.
/// Now the updater tries each address in turn (mirror first, GitHub release
/// last), treats a download that moves less than [minBytesPerWindow] in
/// [stallTimeout] as stalled and moves on, and when every address fails it
/// throws an [UpdateDownloadException] with a message a person can read.

/// Orders download addresses: the raw.githubusercontent.com mirror (the same
/// host the update feed loads from) first, then GitHub Pages, then anything
/// else, and GitHub's release file host last. Drops duplicates and non-https.
List<Uri> orderDownloadUrls(Iterable<String> urls) {
  int rank(Uri u) {
    final h = u.host.toLowerCase();
    if (h == 'raw.githubusercontent.com') return 0;
    if (h.endsWith('.github.io')) return 1;
    if (h == 'github.com' || h.endsWith('githubusercontent.com')) return 3;
    return 2;
  }

  final seen = <String>{};
  final out = <Uri>[];
  for (final s in urls) {
    final t = s.trim();
    final u = Uri.tryParse(t);
    if (u == null || u.scheme != 'https' || u.host.isEmpty) continue;
    if (seen.add(u.toString())) out.add(u);
  }
  final indexed = out.asMap().entries.toList()
    ..sort((a, b) {
      final r = rank(a.value).compareTo(rank(b.value));
      return r != 0 ? r : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// Short, human name for a download address, used in messages.
String downloadSourceName(Uri u) {
  final h = u.host.toLowerCase();
  if (h == 'raw.githubusercontent.com') return 'update mirror';
  if (h.endsWith('.github.io')) return 'backup mirror';
  if (h == 'github.com' || h.endsWith('githubusercontent.com')) {
    return 'GitHub';
  }
  return h;
}

class DownloadAttempt {
  final Uri url;
  final String problem;
  const DownloadAttempt(this.url, this.problem);
  @override
  String toString() => '${downloadSourceName(url)}: $problem';
}

class UpdateDownloadException implements Exception {
  final List<DownloadAttempt> attempts;
  final bool cancelled;
  const UpdateDownloadException(this.attempts, {this.cancelled = false});

  /// What the update dialog shows.
  String get message {
    if (cancelled) return 'Download cancelled.';
    if (attempts.isEmpty) return 'No download address for this update.';
    final n = attempts.length;
    final lines = attempts.map((a) => '- $a').join('\n');
    return "Couldn't download the update from "
        '${n == 1 ? 'its download address' : 'any of its $n download addresses'}:\n'
        '$lines\n'
        'Check your internet connection and tap Retry. If it keeps failing, '
        'your network may be blocking the download.';
  }

  @override
  String toString() => message;
}

class _AttemptFailed implements Exception {
  final String problem;
  _AttemptFailed(this.problem);
}

class _Cancelled implements Exception {}

/// Downloads the first address that works into [target].
///
/// [onProgress] gets bytes received for the current address, the expected
/// total when known, and the 0-based index of the address being tried.
/// [onSourceChange] fires before each attempt after the first.
Future<File> downloadApkWithFallback({
  required List<Uri> urls,
  required File target,
  required http.Client Function() clientFactory,
  bool closeClients = true,
  String userAgent = 'Tiffe-app',
  int? expectedSize,
  void Function(int received, int? total, int source)? onProgress,
  void Function(int source, Uri url)? onSourceChange,
  Stream<void>? cancelToken,
  Duration connectTimeout = const Duration(seconds: 20),
  Duration stallTimeout = const Duration(seconds: 15),
  int minBytesPerWindow = 16 * 1024,
}) async {
  final attempts = <DownloadAttempt>[];
  var cancelled = false;
  final cancelCompleter = Completer<void>();
  final cancelSub = cancelToken?.listen((_) {
    cancelled = true;
    if (!cancelCompleter.isCompleted) cancelCompleter.complete();
  });
  try {
    for (var i = 0; i < urls.length; i++) {
      if (cancelled) break;
      if (i > 0) onSourceChange?.call(i, urls[i]);
      try {
        await _attempt(
          url: urls[i],
          source: i,
          target: target,
          clientFactory: clientFactory,
          closeClient: closeClients,
          userAgent: userAgent,
          expectedSize: expectedSize,
          onProgress: onProgress,
          cancelled: () => cancelled,
          cancelSignal: cancelCompleter.future,
          connectTimeout: connectTimeout,
          stallTimeout: stallTimeout,
          minBytesPerWindow: minBytesPerWindow,
        );
        return target;
      } on _Cancelled {
        cancelled = true;
      } on _AttemptFailed catch (e) {
        attempts.add(DownloadAttempt(urls[i], e.problem));
      } catch (e) {
        attempts.add(DownloadAttempt(urls[i], _describe(e)));
      }
      if (await target.exists()) {
        try {
          await target.delete();
        } catch (_) {}
      }
    }
  } finally {
    await cancelSub?.cancel();
  }
  throw UpdateDownloadException(attempts, cancelled: cancelled);
}

String _describe(Object e) {
  if (e is TimeoutException) return 'timed out';
  if (e is SocketException) return 'could not connect';
  if (e is HandshakeException) return 'secure connection failed';
  if (e is http.ClientException) return 'connection failed';
  if (e is FileSystemException) return 'could not save the file';
  return 'failed';
}

Future<void> _attempt({
  required Uri url,
  required int source,
  required File target,
  required http.Client Function() clientFactory,
  required bool closeClient,
  required String userAgent,
  required int? expectedSize,
  required void Function(int, int?, int)? onProgress,
  required bool Function() cancelled,
  required Future<void> cancelSignal,
  required Duration connectTimeout,
  required Duration stallTimeout,
  required int minBytesPerWindow,
}) async {
  final client = clientFactory();
  IOSink? sink;
  StreamSubscription<List<int>>? sub;
  Timer? watchdog;
  try {
    final req = http.Request('GET', url)..headers['User-Agent'] = userAgent;
    onProgress?.call(0, expectedSize, source);
    final http.StreamedResponse res;
    try {
      res = await Future.any([
        client.send(req),
        cancelSignal.then<http.StreamedResponse>((_) => throw _Cancelled()),
      ]).timeout(connectTimeout);
    } on TimeoutException {
      throw _AttemptFailed(
        'no answer in ${connectTimeout.inSeconds} s',
      );
    }
    if (res.statusCode != 200) {
      throw _AttemptFailed('HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? expectedSize;
    if (expectedSize != null &&
        res.contentLength != null &&
        res.contentLength != expectedSize) {
      throw _AttemptFailed('wrong file size');
    }
    await target.parent.create(recursive: true);
    sink = target.openWrite();
    var received = 0;
    var windowStart = DateTime.now();
    var windowBytes = 0;
    var head = <int>[];
    final done = Completer<void>();
    void fail(Object e) {
      if (!done.isCompleted) done.completeError(e);
    }

    sub = res.stream.listen(
      (chunk) {
        if (cancelled()) return fail(_Cancelled());
        if (head.length < 2) head = [...head, ...chunk.take(2 - head.length)];
        sink!.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total, source);
      },
      onError: (Object e) => fail(e),
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    final tick = Duration(
      milliseconds: (stallTimeout.inMilliseconds ~/ 5).clamp(20, 1000),
    );
    watchdog = Timer.periodic(tick, (_) {
      if (cancelled()) return fail(_Cancelled());
      final now = DateTime.now();
      if (now.difference(windowStart) >= stallTimeout) {
        if (received - windowBytes < minBytesPerWindow) {
          fail(
            _AttemptFailed(
              received == 0
                  ? 'no data for ${stallTimeout.inSeconds} s'
                  : 'stalled at ${(received / 1e6).toStringAsFixed(1)} MB',
            ),
          );
        } else {
          windowStart = now;
          windowBytes = received;
        }
      }
    });
    cancelSignal.then((_) => fail(_Cancelled()));
    await done.future;
    if (cancelled()) throw _Cancelled();
    if (received == 0) throw _AttemptFailed('empty file');
    if (total != null && received != total) {
      throw _AttemptFailed('download cut off');
    }
    if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
      // An APK is a zip ("PK"); anything else is a block or error page.
      throw _AttemptFailed('got a web page instead of the app file');
    }
  } finally {
    watchdog?.cancel();
    await sub?.cancel();
    await sink?.close();
    if (closeClient) client.close();
  }
}
