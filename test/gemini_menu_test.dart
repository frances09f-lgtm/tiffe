import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  for (final w in [390.0, 320.0]) {
    for (final v in [
      (0, [0], false),
      (0, [0, 3], false),
      (1, [0, 4], false),
      (0, [0], true),
      (0, [0, 3], true),
      (1, [0, 4], true),
    ]) {
      testWidgets(
        'menu renders without overflow at ${w}px variant ${v.$3}${v.$1}${v.$2.length}',
        (t) async {
          t.view.physicalSize = Size(w, 1080);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            RepaintBoundary(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: GMenu(
                  initialSelected: v.$2,
                  categories: const [
                    'Lunch (12 PM - 2 PM)',
                    'Dinner (7 PM - 9 PM)',
                  ],
                  initialCategory: v.$1,
                  grid: v.$3,
                  items: const [
                    [
                      GMenuItem(
                        'Batata Bhaji',
                        'Home-style potato bhaji with curry leaves and mustard.',
                        '₹10',
                        'Most Ordered',
                        'assets/food/batata.jpg',
                      ),
                      GMenuItem(
                        'Aloo Bhaji',
                        'Dry potato bhaji, lightly spiced and made daily.',
                        '₹10',
                        'Mild',
                        'assets/food/aloo.jpg',
                      ),
                      GMenuItem(
                        'Baingan Bhaji',
                        'Brinjal bhaji cooked in a simple masala.',
                        '₹10',
                        'Spicy',
                        'assets/food/baingan.jpg',
                        special: true,
                      ),
                      GMenuItem(
                        'Matki Usal',
                        'Sprouted moth bean bhaji, a Maharashtrian favourite.',
                        '₹10',
                        'Seasonal',
                        'assets/food/matki.jpg',
                      ),
                      GMenuItem(
                        'Vatana Usal',
                        'Green peas bhaji, simple and homely.',
                        '₹10',
                        'Mild',
                        'assets/food/vatana.jpg',
                      ),
                      GMenuItem(
                        'Cabbage Bhaji',
                        'Shredded cabbage bhaji with mustard and curry leaves.',
                        '₹10',
                        'Light',
                        'assets/food/cabbage.jpg',
                      ),
                    ],
                    [
                      GMenuItem(
                        'Batata Bhaji',
                        'Home-style potato bhaji with curry leaves and mustard.',
                        '₹10',
                        'Most Ordered',
                        'assets/food/batata.jpg',
                      ),
                      GMenuItem(
                        'Aloo Bhaji',
                        'Dry potato bhaji, lightly spiced and made daily.',
                        '₹10',
                        'Mild',
                        'assets/food/aloo.jpg',
                      ),
                      GMenuItem(
                        'Baingan Bhaji',
                        'Brinjal bhaji cooked in a simple masala.',
                        '₹10',
                        'Spicy',
                        'assets/food/baingan.jpg',
                        special: true,
                      ),
                      GMenuItem(
                        'Matki Usal',
                        'Sprouted moth bean bhaji, a Maharashtrian favourite.',
                        '₹10',
                        'Seasonal',
                        'assets/food/matki.jpg',
                      ),
                      GMenuItem(
                        'Mix Veg Bhaji',
                        'Seasonal vegetables cooked together in a light masala.',
                        '₹10',
                        'New',
                        'assets/food/mix.jpg',
                        special: true,
                      ),
                      GMenuItem(
                        'Mirchi Bhaji',
                        'Green chilli bhaji, for those who like it hot.',
                        '₹10',
                        'New',
                        'assets/food/mirchi.jpg',
                        special: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
          await t.pump(const Duration(milliseconds: 300));
          await t.runAsync(
            () => Future.delayed(const Duration(milliseconds: 400)),
          );
          await t.pump();
          final b = t.firstRenderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await t.runAsync(() async {
            final im = await b.toImage(pixelRatio: 2);
            final d = await im.toByteData(format: ui.ImageByteFormat.png);
            Directory('/tmp/gshots').createSync(recursive: true);
            await File(
              '/tmp/gshots/menu_${w.toInt()}_${v.$3 ? 'grid' : 'list'}${v.$1}${v.$2.length}.png',
            ).writeAsBytes(d!.buffer.asUint8List());
          });
          expect(t.takeException(), isNull);
          expect(find.textContaining('emo'), findsNothing);
        },
      );
    }
  }
}
