import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/live_app.dart';

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
    final n = FontLoader('Inter');
    for (final f in ['Inter-400', 'Inter-600', 'Inter-700']) {
      n.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await n.load();
  });
  for (final dbl in [true, false]) {
    testWidgets('plan review dbl=$dbl', (t) async {
      t.view.physicalSize = const Size(360, 1250);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: PlanReview(
              isDouble: dbl,
              cfg: const {
                'daily_price_paise': 150000,
                'double_price_paise': 300000,
                'monthly_delivery_paise': 20000,
                'extra_bhaji_paise': 1000,
              },
              name: 'Sample Customer',
              phone: '9999999999',
              area: 'Kothrud',
              address: 'Sample address, Pune',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final b = t.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await t.runAsync(() async {
        final im = await b.toImage(pixelRatio: 2);
        final d = await im.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/lshots/planreview_${dbl ? 'double' : 'daily'}.png')
            .writeAsBytes(d!.buffer.asUint8List());
      });
    });
  }
}
