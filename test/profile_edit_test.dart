import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/data/store.dart';

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
  for (final dark in [false, true]) {
    testWidgets(
      'profile edit saves and cancel preserves ${dark ? "dark" : "light"}',
      (t) async {
        final s = await helpers.store();
        s.darkMode = dark;
        await helpers.open(t, s, width: 360, height: 800);
        await t.tap(find.text('Profile').last);
        await t.pumpAndSettle();
        expect(find.byTooltip('Edit profile'), findsOneWidget);
        await helpers.capture(
          t,
          'profile-edit-icon-${dark ? "dark" : "light"}',
        );
        await t.tap(find.byTooltip('Edit profile'));
        await t.pumpAndSettle();
        await helpers.capture(
          t,
          'profile-edit-form-${dark ? "dark" : "light"}',
        );
        await t.enterText(find.byType(TextFormField).at(0), 'Abhijeet Ambi');
        await t.enterText(find.byType(TextFormField).at(1), '9123456789');
        await t.enterText(
          find.byType(TextFormField).at(2),
          'Flat 7, Prabhat Road',
        );
        await t.tap(find.text('Save profile'));
        await t.pumpAndSettle();
        expect(find.text('Abhijeet Ambi'), findsOneWidget);
        expect(find.text('Profile updated successfully'), findsOneWidget);
        final snack = t.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.behavior, SnackBarBehavior.floating);
        expect(snack.duration, const Duration(seconds: 2));
        expect(
          snack.backgroundColor,
          dark ? const Color(0xFF303030) : Colors.white,
        );
        final feedback = t.widget<Text>(
          find.text('Profile updated successfully'),
        );
        expect(
          feedback.style?.color,
          dark ? Colors.white : const Color(0xFF303030),
        );
        final shape = snack.shape! as RoundedRectangleBorder;
        expect(
          shape.side,
          dark
              ? BorderSide.none
              : const BorderSide(color: Colors.black, width: 1),
        );
        expect(find.byIcon(Icons.check_circle), findsWidgets);
        await helpers.capture(
          t,
          'profile-save-styled-${dark ? "dark" : "light"}',
        );
        expect(s.phone, '9123456789');
        final restored = TiffeStore(s.prefs);
        expect(restored.name, 'Abhijeet Ambi');
        expect(restored.address, 'Flat 7, Prabhat Road');
        await t.tap(find.byTooltip('Edit profile'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextFormField).first, 'Unsaved');
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        expect(s.name, 'Abhijeet Ambi');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
