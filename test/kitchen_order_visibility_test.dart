import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'admin_controls_test.dart' show OwnerBackend;
import 'order_safety_regression_test.dart' show order;

class VisibilityBackend extends OwnerBackend {
  final events = StreamController<List<Map<String, dynamic>>>.broadcast();
  int refreshes = 0;
  @override
  void refreshOrders() => refreshes++;
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      events.stream;
  @override
  Future<List<Map<String, dynamic>>> orderItems(List<String> ids) async => [];
}

Future<void> open(WidgetTester t, VisibilityBackend b) async {
  t.view.physicalSize = const Size(1440, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: PartnerHub(backend: b, role: 'kitchen'),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Sync explicitly requests a fresh order read, not only old items',
    (t) async {
      final b = VisibilityBackend();
      await open(t, b);
      final before = b.refreshes;
      await t.widget<KitchenHub>(find.byType(KitchenHub)).onSync();
      await t.pump();
      expect(b.refreshes, before + 1);
      await t.pumpWidget(const SizedBox());
      await b.events.close();
    },
  );
  testWidgets('returning to foreground requests fresh orders', (t) async {
    final b = VisibilityBackend();
    await open(t, b);
    final before = b.refreshes;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(b.refreshes, before + 1);
    await t.pumpWidget(const SizedBox());
    await b.events.close();
  });
  testWidgets(
    'tomorrow orders are visible separately without inflating today prep',
    (t) async {
      final b = VisibilityBackend();
      await open(t, b);
      final next = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 29, minutes: 30))
          .toIso8601String()
          .substring(0, 10);
      b.events.add([
        {...order('future-001'), 'delivery_date': next, 'quantity': 7},
      ]);
      await t.pumpAndSettle();
      expect(find.text('UPCOMING ORDERS (1)'), findsOneWidget);
      expect(find.textContaining('Delivery $next'), findsOneWidget);
      expect(find.text('NEW ORDERS (0)'), findsOneWidget);
      expect(find.text('0 Pcs'), findsOneWidget);
      expect(find.text('Start Preparing'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await b.events.close();
    },
  );
  testWidgets('sync failure is visible and a later snapshot clears it', (
    t,
  ) async {
    final b = VisibilityBackend();
    await open(t, b);
    b.events.addError(StateError('connection unavailable'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('Orders could not sync'), findsOneWidget);
    b.events.add([]);
    await t.pumpAndSettle();
    expect(find.textContaining('Orders could not sync'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await b.events.close();
  });
}
