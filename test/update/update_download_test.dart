import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiffe/update/app_update.dart';
import 'package:tiffe/update/update_download.dart';

final _apk = [0x50, 0x4B, 3, 4, ...List.filled(5000, 7)];

/// Local server: /ok serves the APK, /stall sends headers then nothing,
/// /slow trickles a few bytes, /html serves a block page, /404 fails.
Future<HttpServer> _server() async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    final r = req.response;
    switch (req.uri.path) {
      case '/ok':
        r.contentLength = _apk.length;
        r.add(_apk);
        await r.close();
      case '/stall':
        // Headers and the first bytes arrive, then nothing (the GitHub
        // release host on the blocked network).
        r.contentLength = _apk.length;
        r.add([0x50, 0x4B]);
        await r.flush();
      case '/hang':
        // Never answers at all.
        await Future<void>.delayed(const Duration(seconds: 30));
      case '/slow':
        r.contentLength = _apk.length;
        for (var i = 0; i < 40; i++) {
          r.add([0x50]);
          await r.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      case '/html':
        final b = '<html>blocked</html>'.codeUnits;
        r.contentLength = b.length;
        r.add(b);
        await r.close();
      default:
        r.statusCode = 404;
        await r.close();
    }
  });
  return s;
}

void main() {
  late HttpServer server;
  late Directory tmp;
  Uri u(String p) => Uri.parse('http://127.0.0.1:${server.port}$p');

  setUp(() async {
    server = await _server();
    tmp = await Directory.systemTemp.createTemp('upd');
  });
  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  Future<File> run(
    List<Uri> urls, {
    int? size,
    List<int>? sources,
    Stream<void>? cancel,
  }) => downloadApkWithFallback(
    urls: urls,
    target: File('${tmp.path}/a.apk'),
    clientFactory: http.Client.new,
    expectedSize: size,
    onSourceChange: (i, _) => sources?.add(i),
    cancelToken: cancel,
    connectTimeout: const Duration(seconds: 2),
    stallTimeout: const Duration(milliseconds: 600),
    minBytesPerWindow: 1024,
  );

  test('orders mirror first and GitHub release last, drops bad urls', () {
    final o = orderDownloadUrls([
      'https://github.com/o/r/releases/download/v1/T.apk',
      'http://insecure.example/T.apk',
      'https://o.github.io/r/T.apk',
      'https://raw.githubusercontent.com/o/r/apk-mirror/T.apk',
      'https://raw.githubusercontent.com/o/r/apk-mirror/T.apk',
      'not a url',
    ]).map((e) => e.host).toList();
    expect(o, ['raw.githubusercontent.com', 'o.github.io', 'github.com']);
  });

  test('stalled source (headers, no data) moves on to the next', () async {
    final sources = <int>[];
    final sw = Stopwatch()..start();
    final f = await run([u('/stall'), u('/ok')], sources: sources);
    expect(await f.readAsBytes(), _apk);
    expect(sources, [1]);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('a trickle below the minimum rate counts as stalled', () async {
    final f = await run([u('/slow'), u('/ok')]);
    expect(await f.length(), _apk.length);
  });

  test('block page and HTTP errors fall through to a working source', () async {
    final f = await run([u('/html'), u('/404'), u('/ok')]);
    expect(await f.length(), _apk.length);
  });

  test('all sources failing gives a readable message, not a hang', () async {
    final e = await run([
      u('/stall'),
      u('/hang'),
      u('/404'),
      u('/html'),
    ]).then<Object>((_) => 'no error', onError: (Object e) => e);
    expect(e, isA<UpdateDownloadException>());
    final m = (e as UpdateDownloadException).message;
    expect(m, contains('any of its 4 download addresses'));
    expect(m, anyOf(contains('stalled at 0.0 MB'), contains('no data for')));
    expect(m, contains('no answer in 2 s'));
    expect(m, contains('HTTP 404'));
    expect(m, contains('web page'));
    expect(m, contains('Retry'));
    expect(File('${tmp.path}/a.apk').existsSync(), isFalse);
  });

  test('wrong size from the feed is rejected', () async {
    final e = await run([u('/ok')], size: 99).then<Object>(
      (_) => 'no error',
      onError: (Object e) => e,
    );
    expect((e as UpdateDownloadException).message, contains('wrong file size'));
  });

  test('cancel stops the download', () async {
    final c = StreamController<void>.broadcast();
    final fut = run([u('/stall'), u('/ok')], cancel: c.stream);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    c.add(null);
    final e = await fut.then<Object>((_) => 'no error', onError: (Object e) => e);
    expect((e as UpdateDownloadException).cancelled, isTrue);
    await c.close();
  });

  test('feed entry with mirrors and newest across feeds', () {
    final a = parseFeedEntry({
      'version': '1.0.58',
      'notes': 'n',
      'apk': 'https://github.com/o/r/releases/download/v58/T.apk',
    });
    final b = parseFeedEntry({
      'version': '1.0.58',
      'notes': '',
      'apk': 'https://raw.githubusercontent.com/o/r/apk-mirror/T.apk',
      'mirrors': ['https://o.github.io/r/T.apk'],
      'size': 123,
    });
    final old = parseFeedEntry({
      'version': '1.0.57',
      'apk': 'https://raw.githubusercontent.com/o/r/apk-mirror/old.apk',
    });
    final n = pickNewest([old, null, a, b])!;
    expect(n.version, '1.0.58');
    expect(n.notes, 'n');
    expect(n.size, 123);
    expect(n.downloadUrls.map((e) => e.host).toList(), [
      'raw.githubusercontent.com',
      'o.github.io',
      'github.com',
    ]);
    expect(pickNewest([null, null]), isNull);
    expect(parseFeedEntry({'version': '1'}), isNull);
  });

  test('checker reads both feeds and survives one failing', () async {
    final c = UpdateChecker(
      client: MockClient((req) async {
        if (req.url.toString() == kMirrorFeedUrl) {
          return http.Response(
            '{"tiffe":{"version":"1.0.59","notes":"m",'
            '"apk":"https://raw.githubusercontent.com/o/r/apk-mirror/T.apk"}}',
            200,
          );
        }
        return http.Response('nope', 404);
      }),
      currentVersion: () async => '1.0.57',
    );
    final info = await c.fetchLatest();
    expect(info!.version, '1.0.59');
    expect(info.apkUrl, startsWith('https://raw.githubusercontent.com/'));
  });
}
