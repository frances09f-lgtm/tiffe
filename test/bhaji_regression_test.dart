import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/domain/tiffin.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/ui/subscriber_orders.dart';

import 'ui_test.dart' as helpers;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('TiffeSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets(
    'after cutoff clearly chooses tomorrow and leaves today untouched',
    (t) async {
      final s = await helpers.store();
      s.darkMode = true;
      final today = DateTime(2026, 10, 9);
      await s.saveSelection(today, 0, ['matki', 'vatana']);
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        RepaintBoundary(
          child: TiffeApp(
            store: s,
            startScreen: SelectionPage(
              store: s,
              date: today,
              clock: DateTime(2026, 10, 9, 9, 30),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text("Today's menu is locked - you're picking for tomorrow"),
        findsOneWidget,
      );
      await t.tap(find.text('Baingan Masala'));
      await t.tap(find.text('Cabbage Bhaji'));
      await t.pumpAndSettle();
      await helpers.capture(t, 'bhaji-cutoff-tomorrow');
      await t.tap(find.text('Save choices'));
      await t.pumpAndSettle();
      expect(s.selected(today, 0), ['matki', 'vatana']);
      expect(s.selected(DateTime(2026, 10, 10), 0), ['baingan', 'cabbage']);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('before cutoff today and two independent tiffins persist', (
    t,
  ) async {
    final s = await helpers.store();
    s.plan = Plan.double;
    final today = DateTime(2026, 10, 9);
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      RepaintBoundary(
        child: TiffeApp(
          store: s,
          startScreen: SelectionPage(
            store: s,
            date: today,
            clock: DateTime(2026, 10, 9, 8),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Baingan Masala'));
    await t.tap(find.text('Cabbage Bhaji'));
    await t.tap(find.text('Tiffin 2'));
    await t.pumpAndSettle();
    await t.tap(find.text('Batata Bhaji'));
    await t.tap(find.text('Matki Usal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save choices'));
    await t.pumpAndSettle();
    expect(s.selected(today, 0), ['baingan', 'cabbage']);
    expect(s.selected(today, 1), ['batata', 'matki']);
    expect(TiffeStore(s.prefs).selected(today, 0), ['baingan', 'cabbage']);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('narrow selected cards stay readable at larger text', (t) async {
    final s = await helpers.store();
    s.darkMode = true;
    final date = DateTime.now().add(const Duration(days: 1));
    await s.saveSelection(date, 0, ['batata', 'matki']);
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tiffeDarkTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: SelectionPage(store: s, date: date),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await helpers.capture(t, 'bhaji-large-text');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('new plan checkout does not discard chosen bhajis', (t) async {
    final s = await helpers.store();
    s.plan = Plan.none;
    final date = DateTime.now();
    await t.pumpWidget(
      TiffeApp(
        store: s,
        startScreen: Checkout(
          store: s,
          plan: Plan.daily,
          date: date,
          selections: const [
            ['baingan', 'cabbage'],
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Complete demo payment'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    await t.tap(find.text('Complete demo payment'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(s.plan, Plan.daily);
    expect(s.selected(date, 0), ['baingan', 'cabbage']);
    await t.pumpWidget(const SizedBox());
  });
  for (final dark in [false, true]) {
    testWidgets(
      'custom choices survive save reopen restart and details ${dark ? "dark" : "light"}',
      (t) async {
        final s = await helpers.store();
        s.darkMode = dark;
        final date = DateTime.now();
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          RepaintBoundary(
            child: TiffeApp(
              store: s,
              startScreen: SelectionPage(
                store: s,
                date: date,
                clock: DateTime(date.year, date.month, date.day, 8),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Baingan Masala'));
        await t.tap(find.text('Cabbage Bhaji'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await helpers.capture(t, 'bhaji-fixed-${dark ? "dark" : "light"}');
        await t.tap(find.text('Save choices'));
        await t.pumpAndSettle();
        expect(find.text('Your choices are saved'), findsOneWidget);
        expect(s.selected(date, 0), ['baingan', 'cabbage']);
        await t.tap(find.text('Done'));
        await t.pumpAndSettle();
        await t.pumpWidget(const SizedBox());
        final restored = TiffeStore(s.prefs);
        expect(restored.selected(date, 0), ['baingan', 'cabbage']);
        await t.pumpWidget(
          RepaintBoundary(
            child: TiffeApp(
              store: restored,
              startScreen: SelectionPage(
                store: restored,
                date: date,
                clock: DateTime(date.year, date.month, date.day, 8),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('2 / 2 selected'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          RepaintBoundary(
            child: TiffeApp(
              store: restored,
              startScreen: Scaffold(
                body: SubscriberOrders(
                  store: restored,
                  clock: DateTime(date.year, date.month, date.day, 12),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('View Details'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.text('View Details'));
        await t.pumpAndSettle();
        expect(find.text('Baingan Masala + Cabbage Bhaji'), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Batata Bhaji + Matki Usal'),
          ),
          findsNothing,
        );
        await helpers.capture(t, 'bhaji-details-${dark ? "dark" : "light"}');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
