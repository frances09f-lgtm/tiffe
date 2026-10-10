import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/ui/gemini/auth_screens.dart';

import 'admin_controls_test.dart' show OwnerBackend;

class _StaffBackend extends OwnerBackend {
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
  @override
  Future<String?> role() async => 'owner';
}

void main() {
  testWidgets('customer dark mode never darkens the staff area', (t) async {
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final s = TiffeStore(await SharedPreferences.getInstance())
      ..darkMode = true;

    // Customer side: dark.
    await t.pumpWidget(
      TiffeApp(
        store: s,
        startScreen: const Scaffold(body: SizedBox()),
      ),
    );
    await t.pumpAndSettle();
    expect(GColors.dark, isTrue);
    expect(
      Theme.of(t.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    // Same phone, staff account: light, whatever the customer chose.
    await t.pumpWidget(
      TiffeApp(
        store: s,
        startScreen: LiveGate(backend: _StaffBackend(), store: s, admin: true),
      ),
    );
    await t.pumpAndSettle();
    final ctx = t.element(find.byType(LiveWorkspace));
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(
      Theme.of(ctx).scaffoldBackgroundColor,
      tiffeLightTheme().scaffoldBackgroundColor,
    );
    expect(GColors.dark, isFalse);
    expect(GColors.cream, const Color(0xFFFBF9F5));
    // The saved customer choice is untouched.
    expect(s.darkMode, isTrue);

    // Back to the customer side: dark again.
    await t.pumpWidget(
      TiffeApp(
        store: s,
        startScreen: const Scaffold(body: SizedBox()),
      ),
    );
    await t.pumpAndSettle();
    expect(GColors.dark, isTrue);
    expect(
      Theme.of(t.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });
}
