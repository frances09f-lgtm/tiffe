import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/ui/gemini/auth_screens.dart';
import 'package:tiffe/ui/gemini/home_screen.dart';
import 'live_shell_test.dart' show DataBackend;

void main() {
  testWidgets('default is light, Profile switch turns dark on and it persists',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      // A stale flag from an old build must not turn dark mode on.
      'tiffe.v1': '{"darkMode":true,"onboarded":true}',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = TiffeStore(prefs);
    expect(store.darkMode, isFalse);
    await t.pumpWidget(
      TiffeApp(
        store: store,
        startScreen: LiveWorkspace(backend: DataBackend(), store: store),
      ),
    );
    await t.pumpAndSettle();
    expect(GColors.cream, const Color(0xFFFBF9F5));
    await t.tap(
      find.descendant(
        of: find.byType(GBottomNav),
        matching: find.text('Profile'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Dark mode'), findsOneWidget);
    await t.tap(find.text('Dark mode'));
    await t.pumpAndSettle();
    expect(store.darkMode, isTrue);
    expect(GColors.cream, const Color(0xFF0E1511));
    expect(GColors.card, const Color(0xFF17211B));
    expect(GColors.green, const Color(0xFF1F4631));
    expect(GColors.saffron, const Color(0xFFE86324));
    final again = TiffeStore(await SharedPreferences.getInstance());
    expect(again.darkMode, isTrue);
    await t.tap(find.text('Dark mode'));
    await t.pumpAndSettle();
    expect(store.darkMode, isFalse);
    expect(GColors.cream, const Color(0xFFFBF9F5));
    expect(GColors.green, const Color(0xFF1B3B2B));
  });
}
