import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/staff_app.dart';

import 'admin_controls_test.dart';

void main() {
  testWidgets('owner mobile order review pixels', (t) async {
    final loader = FontLoader('TiffeSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'TiffeSans',
          colorSchemeSeed: const Color(0xff285A3F),
        ),
        home: RepaintBoundary(
          key: const Key('preview'),
          child: StaffHome(backend: OwnerBackend(), role: 'owner'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Tiffe Staff'), findsOneWidget);
    expect(find.text('Assign delivery person'), findsOneWidget);
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('preview')),
      );
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/tiffe-staff-owner.png')
          .writeAsBytes(data!.buffer.asUint8List());
    });
  });
}
