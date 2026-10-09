import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/app.dart';

void main() {
  testWidgets('circular brand logo is shared by all app placements', (t) async {
    await (FontLoader('TiffeSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await t.binding.setSurfaceSize(const Size(412, 820));
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'TiffeSans'),
          home: Scaffold(
            backgroundColor: cream,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Logo(size: 180),
                  const SizedBox(height: 24),
                  Text(
                    'Tiffe',
                    style: TextStyle(
                      color: green,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rozcha dabba. Tumchya choice cha.',
                    style: TextStyle(color: muted, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Logo(size: 48),
                      SizedBox(width: 20),
                      Logo(size: 72),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand/tiffe-logo.png'),
        key.currentContext!,
      );
    });
    await t.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Tiffe circular tiffin logo'),
      findsNWidgets(3),
    );
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/tiffe-v12-logo-preview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
  test('launcher legacy and adaptive icons use new brand', () {
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File('android/app/src/main/res/mipmap-$density/ic_launcher.png')
            .lengthSync(),
        greaterThan(100),
      );
    }
    expect(
      File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
          .readAsStringSync(),
      contains('@drawable/tiffe_foreground'),
    );
  });
}
