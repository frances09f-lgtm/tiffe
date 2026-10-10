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

  test('error logs carry only a type name, never the message', () {
    expect(
      errorKind(const FormatException('token=abc secret@x.com')),
      'FormatException',
    );
    expect(errorKind(_Custom('https://x/?k=1')), 'Other');
  });

  testWidgets('full queue says so and keeps old reports', (t) async {
    SharedPreferences.setMockInitialValues({
      BugReports.queueKey: [
        for (var i = 0; i < 20; i++)
          '{"t":${DateTime.now().millisecondsSinceEpoch},"r":{"n":$i}}',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final r = await t.runAsync(
      () => BugReports.send(ContentBackend().client, prefs, {'n': 99}),
    );
    expect(r, ReportResult.full);
    expect(prefs.getStringList(BugReports.queueKey), hasLength(20));
    expect(prefs.getStringList(BugReports.queueKey)!.first, contains('"n":0'));
  });

  test('expired queued reports are dropped', () async {
    SharedPreferences.setMockInitialValues({
      BugReports.queueKey: ['{"t":1,"r":{"n":1}}'],
    });
    final prefs = await SharedPreferences.getInstance();
    await BugReports.flush(ContentBackend().client, prefs);
    expect(prefs.getStringList(BugReports.queueKey), isEmpty);
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
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Help & Support'));
    await t.pumpAndSettle();
    await t.tap(find.text('Report a problem'));
    await t.pumpAndSettle();
    expect(find.text('What went wrong? (optional)'), findsOneWidget);
    await t.tap(find.text('Send report'));
    await t.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await t.pumpAndSettle();
    expect(store.prefs.getStringList(BugReports.queueKey), hasLength(1));
    expect(
      store.prefs.getStringList(BugReports.queueKey)!.first,
      contains('"r"'),
    );
    expect(
      find.text('Saved on this phone. It will be sent later.'),
      findsOneWidget,
    );
  });
}

class _Custom {
  final String m;
  _Custom(this.m);
}
