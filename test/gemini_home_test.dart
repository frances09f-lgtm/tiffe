import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/home_screen.dart';

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
    testWidgets('home renders without overflow at ${w}px', (t) async {
      t.view.physicalSize = Size(w, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const GHome(
              address: 'Flat 402, Sterling Heights, Baner',
              name: 'Aarav',
              subtitle: 'Homemade bhaji, made daily.',
              planTitle: 'Monthly Bhaji Plan',
              planSubtitle: '18 Days Remaining • Renews 28th Oct 2026',
              todayMeal: 'Batata Bhaji',
              todayStatus: 'On the way',
              thaliTitle: 'Batata Bhaji',
              thaliBlurb:
                  'Home-style potato bhaji, a favourite with our customers.',
              thaliPrice: '₹10',
              thaliTag: 'Most Ordered',
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
        await File('/tmp/gshots/home_${w.toInt()}.png')
            .writeAsBytes(d!.buffer.asUint8List());
      });
      expect(t.takeException(), isNull);
      expect(find.textContaining('emo'), findsNothing);
    });
  }
}
