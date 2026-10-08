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
    await t.tap(find.text('Save choices · preview'));
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
    await t.tap(find.text('Verify preview code'));
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
