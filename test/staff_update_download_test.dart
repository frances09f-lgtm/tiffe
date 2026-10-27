import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tiffe/staff/staff_update.dart';
import 'package:tiffe/update/update_download.dart';

final _apk = [0x50, 0x4B, 3, 4, ...List.filled(3000, 1)];

void main() {
  test('reads mirrors and size, newest across both feeds wins', () async {
    final c = StaffUpdateChecker(
      currentVersion: () async => '1.0.10',
      fetchText: (uri) async {
        if (uri.toString() == kStaffMirrorFeedUrl) {
          return '{"tiffe_staff":{"version":"1.0.11","notes":"m",'
              '"apk":"https://raw.githubusercontent.com/o/r/apk-mirror/S.apk",'
              '"mirrors":["https://github.com/o/r/releases/download/staff-v11/S.apk"],'
              '"size":3004}}';
        }
        return '{"tiffe_staff":{"version":"1.0.10","notes":"old",'
            '"apk":"https://github.com/o/r/releases/download/staff-v10/S.apk"}}';
      },
    );
    final r = await c.check();
    expect(r.failed, isFalse);
    expect(r.info!.version, '1.0.11');
    expect(r.info!.size, 3004);
    expect(r.info!.downloadUrls.map((u) => u.host).toList(), [
      'raw.githubusercontent.com',
      'github.com',
    ]);
  });

  test('one feed failing is not a failed check', () async {
    final c = StaffUpdateChecker(
      currentVersion: () async => '1.0.10',
      fetchText: (uri) async {
        if (uri.toString() == kStaffFeedUrl) throw StateError('blocked');
        return '{"tiffe_staff":{"version":"1.0.10",'
            '"apk":"https://raw.githubusercontent.com/o/r/apk-mirror/S.apk"}}';
      },
    );
    final r = await c.check();
    expect(r.failed, isFalse);
    expect(r.info, isNull);
  });

  test('download skips a stalled source and saves the APK', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final r = req.response;
      r.contentLength = _apk.length;
      if (req.uri.path == '/stall') {
        r.add([0x50]);
        await r.flush();
        return;
      }
      r.add(_apk);
      await r.close();
    });
    final tmp = await Directory.systemTemp.createTemp('staffupd');
    addTearDown(() async {
      await server.close(force: true);
      await tmp.delete(recursive: true);
    });
    final base = 'http://127.0.0.1:${server.port}';
    final f = await downloadApkWithFallback(
      urls: [Uri.parse('$base/stall'), Uri.parse('$base/ok')],
      target: File('${tmp.path}/s.apk'),
      clientFactory: http.Client.new,
      stallTimeout: const Duration(milliseconds: 500),
      minBytesPerWindow: 512,
    );
    expect(await f.readAsBytes(), _apk);
  });

  test('every source failing gives a readable error', () async {
    final e = UpdateDownloadException([
      DownloadAttempt(
        Uri.parse('https://raw.githubusercontent.com/o/r/a.apk'),
        'no data for 15 s',
      ),
      DownloadAttempt(
        Uri.parse('https://github.com/o/r/releases/download/x/a.apk'),
        'HTTP 403',
      ),
    ]);
    expect(e.message, contains('update mirror: no data for 15 s'));
    expect(e.message, contains('GitHub: HTTP 403'));
    expect(e.message, contains('Retry'));
  });
}
