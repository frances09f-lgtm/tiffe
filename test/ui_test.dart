import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/domain/tiffin.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/ui/subscriber_orders.dart';

Future<TiffeStore> store({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final s = TiffeStore(await SharedPreferences.getInstance());
  s
    ..onboarded = onboarded
    ..name = 'Aditi'
    ..phone = '9876543210'
    ..address = 'Flat 12, Prabhat Road'
    ..area = 'Kothrud'
    ..plan = Plan.daily;
  return s;
}

Future<void> capture(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final ctx = t.element(find.byType(MaterialApp));
    for (final n in [
      'hero',
      'batata',
      'matki',
      'baingan',
      'cabbage',
      'vatana',
      'mix',
      'mirchi',
      'aloo',
    ]) {
      await precacheImage(AssetImage('assets/food/$n.jpg'), ctx);
    }
  });
  await t.pumpAndSettle();
  final boundary = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('screenshots').create(recursive: true);
    await File('screenshots/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> open(
  WidgetTester t,
  TiffeStore s, {
  double width = 430,
  double height = 932,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(RepaintBoundary(child: TiffeApp(store: s)));
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 1200));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('TiffeSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('subscriber cutoff locks at 9 AM on delivery date', () {
    final day = DateTime(2026, 10, 10);
    expect(canChangeBhaji(day, DateTime(2026, 10, 10, 8, 59)), isTrue);
    expect(canChangeBhaji(day, DateTime(2026, 10, 10, 9)), isFalse);
    expect(canChangeBhaji(day, DateTime(2026, 10, 11)), isFalse);
  });
  testWidgets('subscriber daily double and Sunday orders previews', (t) async {
    final s = await store();
    await open(t, s);
    final theme = Theme.of(t.element(find.byType(Shell)));
    for (final plan in [Plan.daily, Plan.double]) {
      s.plan = plan;
      await s.saveSelection(DateTime(2026, 10, 9), 0, ['aloo', 'matki']);
      await s.saveSelection(DateTime(2026, 10, 10), 0, ['baingan', 'mix']);
      if (plan == Plan.double) {
        await s.saveSelection(DateTime(2026, 10, 9), 1, ['batata', 'cabbage']);
        await s.saveSelection(DateTime(2026, 10, 10), 1, ['vatana', 'mix']);
      }
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SafeArea(
                child: SubscriberOrders(
                  key: UniqueKey(),
                  store: s,
                  clock: DateTime(2026, 10, 9, 10),
                ),
              ),
            ),
          ),
        ),
      );
      await capture(t, 'subscriber-${plan.name}');
      expect(find.text('My Tiffe Plan'), findsOneWidget);
      expect(find.textContaining('₹80'), findsNothing);
      await t.drag(find.byType(ListView), const Offset(0, -480));
      await t.pumpAndSettle();
      await capture(t, 'subscriber-${plan.name}-tomorrow');
      expect(t.takeException(), isNull);
    }
    s.plan = Plan.daily;
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: SubscriberOrders(
                key: UniqueKey(),
                store: s,
                clock: DateTime(2026, 10, 11, 10),
              ),
            ),
          ),
        ),
      ),
    );
    await t.drag(find.byType(ListView), const Offset(0, 2000));
    await t.pumpAndSettle();
    await capture(t, 'subscriber-sunday');
    expect(find.textContaining('Sunday Sweet Included'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('preview confirmation reaches success without payment', (
    t,
  ) async {
    final s = await store();
    await open(t, s);
    final shellContext = t.element(find.byType(Shell));
    Navigator.of(shellContext).push(
      MaterialPageRoute(
        builder: (_) => Checkout(
          store: s,
          plan: Plan.daily,
          date: DateTime(2026, 10, 9),
          selections: const [],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Complete demo payment'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(Checkout),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(find.text('Complete demo payment'));
    await t.pumpAndSettle();
    expect(find.text('Confirm your Tiffe'), findsOneWidget);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('Payment successful'), findsOneWidget);
    await t.tap(find.text('Back to Tiffe'));
    await t.pumpAndSettle();
    expect(find.byType(Shell), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('payment and tracking are separate screens', (t) async {
    final s = await store();
    await open(t, s);
    final theme = Theme.of(t.element(find.byType(Shell)));
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: PaymentSuccessPreview(
            plan: Plan.daily,
            date: DateTime(2026, 10, 9),
          ),
        ),
      ),
    );
    await capture(t, 'payment-success-preview');
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('Will deliver in a few minutes'), findsNothing);
    expect(find.text('Track my Tiffe'), findsOneWidget);
    await t.tap(find.text('Track my Tiffe'));
    await t.pumpAndSettle();
    expect(find.text('Payment successful'), findsNothing);
    expect(find.byType(DeliveryTrackingPreview), findsOneWidget);
    await capture(t, 'tracking-preview');
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('Tiffin left'), findsWidgets);
    await capture(t, 'delivery-left-preview');
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.text('Tiffin is coming'), findsWidgets);
    await capture(t, 'delivery-coming-preview');
    await t.pump(const Duration(seconds: 24));
    await t.pumpAndSettle();
    expect(find.text('Tiffin arrived'), findsWidgets);
    await capture(t, 'delivery-arrived-preview');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('checkout prices monthly and one-time delivery', (t) async {
    final s = await store();
    await open(t, s);
    final checkoutTheme = Theme.of(t.element(find.byType(Shell)));
    t.view.physicalSize = const Size(430, 932);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: checkoutTheme,
          home: Checkout(
            store: s,
            plan: Plan.none,
            date: DateTime(2026, 10, 9),
            selections: const [
              ['batata', 'matki', 'baingan'],
            ],
          ),
        ),
      ),
    );
    await capture(t, 'checkout-one-time');
    expect(find.text('₹20'), findsOneWidget);
    expect(find.text('₹110'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: checkoutTheme,
          home: Checkout(
            key: const ValueKey('monthly'),
            store: s,
            plan: Plan.daily,
            date: DateTime(2026, 10, 9),
            selections: const [],
          ),
        ),
      ),
    );
    await capture(t, 'checkout-monthly');
    expect(find.text('₹199'), findsOneWidget);
    expect(find.text('₹1699'), findsOneWidget);
    expect(find.text('Delivery / month'), findsOneWidget);
    expect(find.text('Total / month'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('helpline contact and responsive screenshot', (t) async {
    final s = await store();
    await open(t, s);
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Help & support'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await capture(t, 'help-support');
    expect(find.text('Sourabh - CEO'), findsOneWidget);
    expect(find.text('+91 72491 19955'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(
      t.getSize(find.widgetWithText(FilledButton, 'Call')),
      t.getSize(find.widgetWithText(FilledButton, 'WhatsApp')),
    );
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('home selection pricing and plans screenshots', (t) async {
    final s = await store();
    await open(t, s);
    await capture(t, 'home');
    expect(t.takeException(), isNull);
    await t.tap(find.text('Menu').last);
    await t.pumpAndSettle();
    await capture(t, 'menu');
    expect(t.takeException(), isNull);
    await t.tap(find.text('Home').last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Choose your bhaji'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Choose your bhaji'));
    await t.pumpAndSettle();
    await t.tap(find.text('Batata Bhaji'));
    await t.tap(find.text('Matki Usal'));
    await t.tap(find.text('Baingan Masala'));
    await t.pumpAndSettle();
    expect(find.text('Extra bhaji +₹10'), findsOneWidget);
    await capture(t, 'selection-extra');
    expect(t.takeException(), isNull);
    await t.tap(find.text('Save choices'));
    await t.pumpAndSettle();
    expect(find.text('Your choices are saved'), findsOneWidget);
    expect(s.selected(DateTime.now(), 0).length, 3);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.text('Plan').last);
    await t.pumpAndSettle();
    await capture(t, 'plans');
    expect(t.takeException(), isNull);
  });
  testWidgets('onboarding screenshot and validations', (t) async {
    final s = await store(onboarded: false);
    await open(t, s);
    await capture(t, 'login');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number'),
      findsOneWidget,
    );
    await t.enterText(find.byType(TextFormField), '9876543210');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await capture(t, 'otp');
    await t.enterText(find.byType(TextFormField), '123456');
    await t.tap(find.text('Verify code'));
    await t.pumpAndSettle();
    await capture(t, 'address');
    expect(t.takeException(), isNull);
  });
  testWidgets('compact phone and double separate selection', (t) async {
    final s = await store();
    s.plan = Plan.double;
    await open(t, s, width: 360, height: 800);
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(
      find.text('Choose your bhaji'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Choose your bhaji'));
    await t.pumpAndSettle();
    await t.tap(find.text('Batata Bhaji'));
    await t.tap(find.text('Matki Usal'));
    await t.tap(find.text('Tiffin 2'));
    await t.pumpAndSettle();
    expect(find.text('0 / 2 selected'), findsOneWidget);
    await capture(t, 'double-compact');
    expect(t.takeException(), isNull);
  });
  testWidgets('store survives recreation and separates dates', (t) async {
    final s = await store();
    final d = DateTime(2026, 10, 9);
    await s.saveSelection(d, 0, ['batata', 'matki', 'not-real']);
    await s.saveSelection(d.add(const Duration(days: 1)), 0, ['aloo', 'mix']);
    final restored = TiffeStore(s.prefs);
    expect(restored.selected(d, 0), ['batata', 'matki']);
    expect(restored.selected(d, 1), isEmpty);
    expect(restored.selected(d.add(const Duration(days: 1)), 0), [
      'aloo',
      'mix',
    ]);
  });
}
