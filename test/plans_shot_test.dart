import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/plan_flow.dart';
import 'package:tiffe/ui/gemini/plans_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
    final l = FontLoader('PlusJakartaSans');
    for (final f in ['Jakarta-400', 'Jakarta-600', 'Jakarta-700']) {
      l.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await l.load();
  });
  for (final w in [360.0, 320.0]) {
    testWidgets('plans page ${w.toInt()}', (t) async {
      t.view.physicalSize = Size(w, 940);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      GPlan? picked;
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(w, 940),
                textScaler: TextScaler.linear(w == 320 ? 1.3 : 1),
              ),
              child: GPlans(
                subtitle: 'Save up to 20% with monthly plans. Pause or skip any meal anytime.',
                plans: tiffinPlans(
                  doublePaise: 300000,
                  dailyPaise: 150000,
                  deliveryPaise: 20000,
                ),
                onSelect: (p) => picked = p,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Select This Plan'), findsNWidgets(2));
      await t.tap(find.text('Select This Plan').first);
      expect(picked?.price, '₹3,000');
      final b = t.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await t.runAsync(() async {
        final im = await b.toImage(pixelRatio: 2);
        final d = await im.toByteData(format: ui.ImageByteFormat.png);
        Directory('/tmp/lshots').createSync(recursive: true);
        await File('/tmp/lshots/plans_${w.toInt()}.png')
            .writeAsBytes(d!.buffer.asUint8List());
      });
      expect(t.takeException(), isNull);
    });
  }
  final flow = <String, Widget>{
    'flow_checkout': const GPlanCheckout(
      planName: 'Monthly Homestyle Thali (Lunch & Dinner)',
      planPrice: '₹3,000',
      deliveryPrice: '₹200',
      total: '₹3,200',
      addressTitle: 'Sample Customer',
      addressLines: 'Sample address, Kothrud, Pune',
    ),
    'flow_order': const GPlanCheckout(
      title: 'Order Checkout',
      cardTitle: 'Your Order',
      planName: 'Tiffin x 1: Batata Bhaji, Matki Usal',
      planPrice: '₹80',
      priceLabel: 'Tiffin',
      note: 'Delivered on the day you pick. Order before the daily cutoff.',
      deliveryPrice: '₹20',
      total: '₹100',
      buttonLabel: 'Pay ₹100 & Place Order',
      addressTitle: 'Sample Customer',
      addressLines: 'Sample address, Kothrud, Pune',
    ),
    'flow_pay': const GPlanPay(total: '₹3,200'),
    'flow_received': const GPlanConfirmed(),
  };
  for (final e in flow.entries) {
    testWidgets(e.key, (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(debugShowCheckedModeBanner: false, home: e.value),
        ),
      );
      await t.pumpAndSettle();
      final b = t.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await t.runAsync(() async {
        final im = await b.toImage(pixelRatio: 2);
        final d = await im.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/lshots/${e.key}.png')
            .writeAsBytes(d!.buffer.asUint8List());
      });
      expect(t.takeException(), isNull);
    });
  }
}
