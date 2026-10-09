import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/domain/tiffin.dart';

import 'ui_test.dart' as helpers;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('TiffeSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('logout cancels safely and preserves saved local data', (
    t,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('tiffe/delivery_notifications'),
          (_) async => true,
        );
    final s = await helpers.store();
    s.darkMode = true;
    final date = DateTime.now();
    await s.saveSelection(date, 0, ['baingan', 'cabbage']);
    await helpers.open(t, s, width: 360, height: 800);
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Log out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.drag(find.byType(ListView).first, const Offset(0, -150));
    await t.pumpAndSettle();
    await helpers.capture(t, 'profile-logout-dark');
    await t.tap(find.text('Log out'));
    await t.pumpAndSettle();
    await helpers.capture(t, 'logout-confirm-dark');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(s.onboarded, true);
    await t.tap(find.text('Log out'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Log out'));
    await t.pumpAndSettle();
    expect(s.onboarded, false);
    expect(find.text('Your daily dabba,\nsorted.'), findsOneWidget);
    expect(s.name, 'Aditi');
    expect(s.plan, Plan.daily);
    expect(TiffeStore(s.prefs).selected(date, 0), ['baingan', 'cabbage']);
    expect(TiffeStore(s.prefs).onboarded, false);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
