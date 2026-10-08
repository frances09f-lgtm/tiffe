import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/admin.dart';

Future<void> screenshot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final context = t.element(find.byType(MaterialApp));
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
      await precacheImage(AssetImage('assets/food/$n.jpg'), context);
    }
  });
  await t.pumpAndSettle();
  final boundary = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await t.runAsync(() async {
    final im = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    await Directory('screenshots').create(recursive: true);
    await File('screenshots/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('TiffeSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('demand sums each independent tiffin and extras', () {
    final os = demoOrders();
    final counts = demand(os);
    expect(os.fold(0, (n, o) => n + o.tiffins.length), 8);
    expect(os.fold(0, (n, o) => n + o.extras), 3);
    expect(counts.values.fold(0, (n, v) => n + v), 19);
    expect(counts['batata'], 4);
    expect(counts['matki'], 4);
  });
  testWidgets('admin overview orders and delivery previews', (t) async {
    t.view.physicalSize = const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const RepaintBoundary(child: KitchenApp()));
    await t.pumpAndSettle();
    await screenshot(t, 'admin-login');
    await t.tap(find.text('Enter demo'));
    await t.pumpAndSettle();
    await screenshot(t, 'admin-overview');
    expect(t.takeException(), isNull);
    await t.tap(find.text('Orders').first);
    await t.pumpAndSettle();
    await screenshot(t, 'admin-orders');
    expect(t.takeException(), isNull);
    await t.tap(find.text('Delivery').first);
    await t.pumpAndSettle();
    await screenshot(t, 'admin-delivery');
    for (final screen in [
      'Subscriptions',
      'Customers',
      'Daily Menu',
      'Sunday Sweet',
      'Payments',
      'Reports',
      'Settings',
      'Notifications',
      'Audit Log',
    ]) {
      await t.tap(find.text(screen).first);
      await t.pumpAndSettle();
      await screenshot(t, 'admin-${screen.toLowerCase().replaceAll(' ', '-')}');
      expect(t.takeException(), isNull);
    }
    await t.tap(find.text('Kitchen').first);
    await t.pumpAndSettle();
    await screenshot(t, 'admin-kitchen');
    await t.tap(find.text('Packing').first);
    await t.pumpAndSettle();
    await screenshot(t, 'admin-packing');
    await t.tap(find.text('Delivery').first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Mark delivered').first);
    await t.pumpAndSettle();
    expect(find.text('Delivered'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  test('cancelled orders excluded from kitchen demand', () {
    final os = demoOrders();
    os.first.status = 'Cancelled';
    expect(demand(os)['batata'], 3);
    expect(demand(os)['matki'], 3);
  });
  testWidgets('kitchen and delivery role navigation', (t) async {
    t.view.physicalSize = const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    for (final role in ['Kitchen', 'Delivery']) {
      await t.pumpWidget(const RepaintBoundary(child: KitchenApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Owner'));
      await t.pumpAndSettle();
      await t.tap(find.text(role).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Enter demo'));
      await t.pumpAndSettle();
      expect(find.text('Payments'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      if (role == 'Delivery') {
        expect(find.textContaining('Sameer Joshi'), findsOneWidget);
        expect(find.textContaining('Rohan Deshmukh'), findsNothing);
      }
      await screenshot(t, 'admin-role-${role.toLowerCase()}');
      expect(t.takeException(), isNull);
      await t.tap(find.text('Logout'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    }
  });
  testWidgets('admin responsive tablet', (t) async {
    t.view.physicalSize = const Size(768, 1100);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const RepaintBoundary(child: KitchenApp()));
    await t.pumpAndSettle();
    await t.tap(find.text('Enter demo'));
    await t.pumpAndSettle();
    await screenshot(t, 'admin-tablet');
    expect(t.takeException(), isNull);
  });
}
