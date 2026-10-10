import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/bug_report.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';

import 'live_content_test.dart';

void main() {
  test('app version matches pubspec', () {
    final v = RegExp(
      r'^version: (.+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!.trim();
    expect(appVersion, v);
  });

  test('scrub removes emails and phone numbers', () {
    expect(
      scrub('mail a.b@x.com or +91 98765 43210 now'),
      'mail [email] or [number] now',
    );
  });

  test('report id is a uuid and log is capped', () {
    expect(
      newReportId(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    BugLog.clear();
    for (var i = 0; i < 80; i++) {
      BugLog.add('line $i a@b.com');
    }
    expect(BugLog.lines.length, 50);
    expect(BugLog.lines.join(), isNot(contains('a@b.com')));
  });

  testWidgets('one tap report is queued on the phone when offline', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    await t.pumpWidget(
      TiffeApp(
        store: store,
        startScreen: LiveWorkspace(backend: ContentBackend(), store: store),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Report a problem'));
    await t.pumpAndSettle();
    expect(find.text('What went wrong? (optional)'), findsOneWidget);
    await t.tap(find.text('Send report'));
    await t.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await t.pumpAndSettle();
    expect(store.prefs.getStringList(BugReports.queueKey), hasLength(1));
    expect(
      find.text('Saved on this phone. It will be sent later.'),
      findsOneWidget,
    );
  });
}
