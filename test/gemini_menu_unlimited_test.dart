import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/menu_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/Jakarta-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Jakarta-600.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Jakarta-700.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  const items = [
    [
      GMenuItem('Batata Bhaji', 'Potato', '₹10', '', 'assets/food/batata.jpg'),
      GMenuItem('Aloo Bhaji', 'Potato', '₹10', '', 'assets/food/aloo.jpg'),
      GMenuItem('Baingan Bhaji', 'Brinjal', '₹10', '', 'assets/food/baingan.jpg'),
    ],
  ];

  Widget app({required Widget child}) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: child);
  }

  testWidgets('unlimited portions add and remove without any cap', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      app(
        child: GMenu(
          categories: const ['Lunch'],
          items: items,
          showWeekly: false,
          unlimited: true,
          extraRupees: 10,
          onOrder: (_) {},
        ),
      ),
    );
    await t.pump();
    expect(find.text('0 selected'), findsOneWidget);

    // Select once: stepper appears at x1.
    await t.tap(find.text('Select').first);
    await t.pump();
    expect(find.text('x1'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);

    // Add to 8 portions: no ceiling, extras priced beyond the 2 included.
    for (var k = 0; k < 7; k++) {
      await t.tap(find.byIcon(Icons.add).first);
      await t.pump();
    }
    expect(find.text('x8'), findsOneWidget);
    expect(find.text('8 selected + 6 extra'), findsOneWidget);
    expect(find.text('+₹60 for extras'), findsOneWidget);

    // Remove back down to zero: the Select button returns.
    for (var k = 0; k < 8; k++) {
      await t.tap(find.byIcon(Icons.remove).first);
      await t.pump();
    }
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Select'), findsNWidgets(3));
  });

  testWidgets('unlimited order payload repeats the bhaji once per portion',
      (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    List<GMenuItem>? got;
    await t.pumpWidget(
      app(
        child: GMenu(
          categories: const ['Lunch'],
          items: items,
          showWeekly: false,
          unlimited: true,
          extraRupees: 10,
          onOrder: (sel) => got = sel,
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('Select').first);
    await t.pump();
    for (var k = 0; k < 3; k++) {
      await t.tap(find.byIcon(Icons.add).first);
      await t.pump();
    }
    expect(find.text('x4'), findsOneWidget);
    await t.tap(find.text('Order'));
    await t.pump();
    expect(got, isNotNull);
    expect(got!.length, 4);
    expect(got!.every((g) => g.title == 'Batata Bhaji'), isTrue);
  });

  testWidgets('plan flow without unlimited still requires exactly two',
      (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    List<GMenuItem>? got;
    await t.pumpWidget(
      app(
        child: GMenu(
          categories: const ['Lunch'],
          items: items,
          showWeekly: false,
          onOrder: (sel) => got = sel,
        ),
      ),
    );
    await t.pump();
    expect(find.text('0 of 2 selected'), findsOneWidget);
    await t.tap(find.text('Select').first);
    await t.pump();
    expect(find.text('1 of 2 selected'), findsOneWidget);
    // Plus on the same card cannot push past the required total.
    await t.tap(find.byIcon(Icons.add).first);
    await t.pump();
    expect(find.text('1 of 2 selected'), findsOneWidget);
    await t.tap(find.text('Select').first);
    await t.pump();
    expect(find.text('2 of 2 selected'), findsOneWidget);
    // A third bhaji stays locked once the tiffin is full.
    await t.tap(find.text('Select').first);
    await t.pump();
    expect(find.text('2 of 2 selected'), findsOneWidget);
    await t.tap(find.text('Order'));
    await t.pump();
    expect(got!.length, 2);
    expect(got!.map((g) => g.title).toSet().length, 2);
  });
}
