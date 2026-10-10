import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/live/bug_report.dart';
import 'package:tiffe/live/update_check.dart';

Future<BuildContext> host(WidgetTester t) async {
  late BuildContext ctx;
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold();
        },
      ),
    ),
  );
  return ctx;
}

void main() {
  test('build number comes from appVersion', () {
    expect(currentBuild, int.parse(appVersion.split('+').last));
  });

  testWidgets('newer release shows popup; Update opens Firebase page', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Uri? opened;
    UpdateCheck.opener = (u) async => opened = u;
    final ctx = await host(t);
    final f = UpdateCheck.run(ctx, prefs, fetch: () async => currentBuild + 1);
    await t.pumpAndSettle();
    expect(find.text('New version available'), findsOneWidget);
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    await f;
    expect(opened.toString(), updatePage);
  });

  testWidgets('Later snoozes; up to date or offline shows nothing', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctx = await host(t);
    final f = UpdateCheck.run(ctx, prefs, fetch: () async => currentBuild + 1);
    await t.pumpAndSettle();
    await t.tap(find.text('Later'));
    await t.pumpAndSettle();
    await f;
    expect(prefs.getInt(UpdateCheck.snoozeKey), isNotNull);
    // within the 6h window nothing is fetched again
    var calls = 0;
    await UpdateCheck.run(
      ctx,
      prefs,
      fetch: () async {
        calls++;
        return currentBuild + 5;
      },
    );
    expect(calls, 0);
    for (final r in [currentBuild, null]) {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await UpdateCheck.run(ctx, p, fetch: () async => r);
      await t.pumpAndSettle();
      expect(find.text('New version available'), findsNothing);
    }
  });
}
