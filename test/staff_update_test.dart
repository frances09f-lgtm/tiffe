import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/staff_update.dart';

const _feed =
    '{"parent":{"version":"1.4.17","notes":"p","apk":"https://example.com/p.apk"},'
    '"tiffe_staff":{"version":"1.0.7","notes":"Adds an Update button.",'
    '"apk":"https://github.com/frances09f-lgtm/tiffe/releases/download/staff-v7/Tiffe-Staff.apk"}}';

void main() {
  test('compareStaffVersions orders versions numerically', () {
    expect(compareStaffVersions('1.0.7', '1.0.6'), greaterThan(0));
    expect(compareStaffVersions('1.0.6', '1.0.7'), lessThan(0));
    expect(compareStaffVersions('1.0.10', '1.0.9'), greaterThan(0));
    expect(compareStaffVersions('v1.0.7', '1.0.7+7'), 0);
    expect(compareStaffVersions('1.1', '1.0.9'), greaterThan(0));
    expect(compareStaffVersions('1.0', '1.0.0'), 0);
  });

  test('parseStaffFeed reads the tiffe_staff entry only', () {
    final info = parseStaffFeed(_feed)!;
    expect(info.version, '1.0.7');
    expect(info.notes, 'Adds an Update button.');
    expect(
      info.apkUrl,
      'https://github.com/frances09f-lgtm/tiffe/releases/download/staff-v7/Tiffe-Staff.apk',
    );
    expect(parseStaffFeed('{"parent":{"version":"1","apk":"https://x.y/a"}}'),
        isNull);
    expect(parseStaffFeed('not json'), isNull);
    expect(parseStaffFeed('[]'), isNull);
    expect(
      parseStaffFeed(
        '{"tiffe_staff":{"version":"1.0.7","apk":"http://x.y/a.apk"}}',
      ),
      isNull,
    );
    expect(
      parseStaffFeed('{"tiffe_staff":{"version":"","apk":"https://x.y/a"}}'),
      isNull,
    );
    expect(
      parseStaffFeed('{"tiffe_staff":{"version":"1.0.7","apk":""}}'),
      isNull,
    );
  });

  test('check reports newer, current and failed separately', () async {
    Future<StaffUpdateResult> run(String current, String Function() body) =>
        StaffUpdateChecker(
          fetchText: (_) async => body(),
          currentVersion: () async => current,
        ).check();

    final newer = await run('1.0.6', () => _feed);
    expect(newer.failed, isFalse);
    expect(newer.info!.version, '1.0.7');
    expect(newer.current, '1.0.6');

    final same = await run('1.0.7', () => _feed);
    expect(same.failed, isFalse);
    expect(same.info, isNull);

    final broken = await run('1.0.6', () => throw const SocketException('x'));
    expect(broken.failed, isTrue);
    expect(broken.info, isNull);

    final empty = await run('1.0.6', () => '{}');
    expect(empty.failed, isTrue);
  });

  test('check reads only the update feed address', () async {
    Uri? seen;
    await StaffUpdateChecker(
      fetchText: (u) async {
        seen = u;
        return _feed;
      },
      currentVersion: () async => '1.0.6',
    ).check();
    expect(seen.toString(), kStaffFeedUrl);
    expect(kStaffFeedUrl, contains('child-safety-updates'));
    expect(kStaffFeedKey, 'tiffe_staff');
  });

  test('update code never opens a browser or a distribution page', () {
    final src = File('lib/staff/staff_update.dart').readAsStringSync();
    final lower = src.toLowerCase();
    for (final banned in [
      'url_launcher',
      'launchurl',
      'firebase',
      'appdistribution',
      'update_check.dart',
      'canlaunch',
    ]) {
      expect(lower.contains(banned), isFalse, reason: 'found $banned');
    }
    expect(src, contains("MethodChannel('app/update')"));
  });

  test('Staff screens have the update button wired', () {
    final hub = File('lib/staff/partner_hub.dart').readAsStringSync();
    final home = File('lib/staff/staff_app.dart').readAsStringSync();
    expect(hub, contains('checkStaffUpdateManually'));
    expect(hub, contains('Check for updates'));
    expect(hub, contains("'Updates'"));
    expect(hub, contains('Icons.system_update'));
    expect(home, contains('checkStaffUpdateManually'));
    expect(home, contains('Check for updates'));
  });

  test('native update pieces exist for the staff package', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains(r'${applicationId}.updateprovider'));
    expect(manifest, contains('REQUEST_INSTALL_PACKAGES'));
    final kt = File(
      'android/app/src/main/kotlin/com/tiffe/tiffe/MainActivity.kt',
    ).readAsStringSync();
    expect(kt, contains('"app/update"'));
    expect(kt, contains(r'"$packageName.updateprovider"'));
    expect(
      File(
        'android/app/src/main/res/xml/file_paths.xml',
      ).readAsStringSync(),
      contains('updates/'),
    );
  });

  Future<void> openDialog(
    WidgetTester t,
    StaffUpdateChecker checker,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showStaffUpdateDialog(
                c,
                const StaffUpdateInfo(
                  version: '1.0.7',
                  notes: 'Adds an Update button.',
                  apkUrl: 'https://example.com/Tiffe-Staff.apk',
                ),
                checker: checker,
                current: '1.0.6',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets('Update downloads in the app and starts the installer', (
    t,
  ) async {
    String? installed;
    var progressSeen = false;
    final checker = StaffUpdateChecker(
      canInstall: () async => true,
      installer: (path) async => installed = path,
      downloader: (info, {onProgress, cancel}) async {
        onProgress?.call(5, 10);
        progressSeen = true;
        return File('/cache/updates/Tiffe-Staff-${info.version}.apk');
      },
    );
    await openDialog(t, checker);
    expect(find.text('Software Update'), findsOneWidget);
    expect(find.text('Tiffe Staff 1.0.7 is available'), findsOneWidget);
    expect(find.text('Installed: 1.0.6  Latest: 1.0.7'), findsOneWidget);
    expect(find.text('Adds an Update button.'), findsOneWidget);
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    expect(progressSeen, isTrue);
    expect(installed, '/cache/updates/Tiffe-Staff-1.0.7.apk');
    expect(find.text('Software Update'), findsNothing);
  });

  testWidgets('Missing install permission opens the system settings', (
    t,
  ) async {
    var settingsOpened = 0;
    var downloaded = false;
    final checker = StaffUpdateChecker(
      canInstall: () async => false,
      openInstallSettings: () async => settingsOpened++,
      downloader: (info, {onProgress, cancel}) async {
        downloaded = true;
        return File('/cache/x.apk');
      },
    );
    await openDialog(t, checker);
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    expect(find.text('One permission needed'), findsOneWidget);
    expect(downloaded, isFalse);
    await t.tap(find.text('Open settings'));
    await t.pump();
    expect(settingsOpened, 1);
  });

  testWidgets('A failed download shows an error and Retry', (t) async {
    var calls = 0;
    final checker = StaffUpdateChecker(
      canInstall: () async => true,
      installer: (_) async {},
      downloader: (info, {onProgress, cancel}) async {
        calls++;
        if (calls == 1) throw StateError('download failed (HTTP 404)');
        return File('/cache/ok.apk');
      },
    );
    await openDialog(t, checker);
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    expect(find.text('Update failed'), findsOneWidget);
    expect(find.textContaining('HTTP 404'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Software Update'), findsNothing);
  });

  test('Staff auto-confirm is an owner switch, never a silent force-off', () {
    final hub = File('lib/staff/partner_hub.dart').readAsStringSync();
    // v9: the owner controls order auto-confirmation with a visible switch
    // that persists the chosen value; the old silent owner-only force-off
    // must not come back.
    expect(hub.contains('Auto-confirm new orders'), isTrue);
    expect(hub.contains('set_kitchen_auto_accept'), isTrue);
    expect(hub.contains("'p_enabled': false"), isFalse);
    expect(hub.contains('Auto-Accept'), isFalse);
    expect(hub.contains('onAuto'), isFalse);
  });
}
