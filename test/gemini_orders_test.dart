import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/orders_screen.dart';

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

  for (final w in [390.0, 320.0]) {
    testWidgets('orders renders without overflow at ${w}px', (t) async {
      t.view.physicalSize = Size(w, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const GOrders(
              orders: [
                GOrder(
                  'TF-8942',
                  'Subscription Meal',
                  'Out for Delivery',
                  'Batata Bhaji + Matki Usal',
                  'Today, 1:00 PM - 1:30 PM',
                  '₹80',
                  live: true,
                ),
                GOrder(
                  'TF-8810',
                  'One-Time Order',
                  'Delivered',
                  'Aloo Bhaji + Baingan Bhaji',
                  'Yesterday, 8:15 PM',
                  '₹100',
                ),
              ],
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await t.pump();
      final b = t.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await t.runAsync(() async {
        final im = await b.toImage(pixelRatio: 2);
        final d = await im.toByteData(format: ui.ImageByteFormat.png);
        Directory('/tmp/gshots').createSync(recursive: true);
        await File('/tmp/gshots/orders_${w.toInt()}.png')
            .writeAsBytes(d!.buffer.asUint8List());
      });
      expect(find.text('Order history'), findsOneWidget);
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Track Details'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(find.textContaining('emo'), findsNothing);
    });
  }
}
