import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'admin_controls_test.dart' show OwnerBackend;
import 'staff_kitchen_v9_test.dart' show dataWith, istToday, istTomorrow, order;

class _ShotBackend extends OwnerBackend {
  @override
  Future<Map<String, dynamic>?> currentSettings() async =>
      {'kitchen_auto_accept': true};
}

void main() {
  testWidgets('staff v9 kitchen hub render: summary, auto-confirm, handover',
      (t) async {
    final loader = FontLoader('TiffeSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'TiffeSans',
          colorSchemeSeed: const Color(0xff285A3F),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: const Key('shot'),
              child: KitchenHub(
                d: dataWith([
                  // Ready for pickup, verified payment, no rider: assignment.
                  order('ord-0001', istToday, 'Packed'),
                  // Ready with a rider: handover confirmation.
                  order('ord-0002', istToday, 'Packed', rider: 'rider-1'),
                  order('ord-0003', istToday, 'Preparing'),
                  // Upcoming stays visible below today's summary.
                  order('ord-0004', istTomorrow, 'Confirmed'),
                ]),
                b: _ShotBackend(),
                role: 'owner',
                items: const [
                  {'order_id': 'ord-0001', 'item_name': 'Batata Bhaji'},
                  {'order_id': 'ord-0003', 'item_name': 'Aloo Gobi'},
                ],
                onSync: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // The v9 surfaces must actually be on screen before the pixels count.
    expect(find.text('Assign delivery partner'), findsOneWidget);
    expect(find.text('Confirm Handover'), findsOneWidget);
    expect(find.text('Auto-confirm new orders'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    await t.runAsync(() async {
      final boundary =
          t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/staff-v9-kitchen.png')
          .writeAsBytes(data!.buffer.asUint8List());
    });
  });
}
