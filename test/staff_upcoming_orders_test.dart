import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'partner_hub_test.dart' as hub;

String day(int add) => DateTime.now()
    .toUtc()
    .add(Duration(hours: 5, minutes: 30, days: add))
    .toIso8601String()
    .substring(0, 10);

Map<String, dynamic> order(
  String id,
  String date,
  String status,
  String created,
) => {
  'id': id,
  'customer_id': 'c1',
  'delivery_date': date,
  'meal': 'lunch',
  'status': status,
  'payment_status': 'unpaid',
  'assigned_to': null,
  'total_paise': 10000,
  'quantity': 2,
  'created_at': created,
  'eta_at': null,
};

class RowsBackend extends hub.WebBackend {
  final List<Map<String, dynamic>> rows;
  RowsBackend(this.rows);
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value(rows);
}

Future<void> open(WidgetTester t, RowsBackend b, String role) async {
  t.view.physicalSize = const Size(430, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: PartnerHub(backend: b, role: role)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'kitchen sees tomorrow orders under Upcoming without inflating today',
    (t) async {
      final b = RowsBackend([
        order('aaaaaa01', day(1), 'Confirmed', '2026-10-24T05:00:00Z'),
        order('bbbbbb02', day(0), 'Confirmed', '2026-10-24T04:00:00Z'),
        order('cccccc03', day(1), 'Delivered', '2026-10-24T03:00:00Z'),
      ]);
      await open(t, b, 'kitchen');
      expect(find.text('UPCOMING ORDERS (1)'), findsOneWidget);
      expect(find.text('NEW ORDERS (1)'), findsOneWidget);
      expect(find.textContaining('#AAAAAA'), findsOneWidget);
      expect(find.textContaining('#BBBBBB'), findsOneWidget);
      expect(find.textContaining('#CCCCCC'), findsNothing);
      expect(find.textContaining('Delivery ${day(1)}'), findsOneWidget);
      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.text('6 Pcs'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('kitchen with no later orders shows an empty Upcoming list', (
    t,
  ) async {
    final b = RowsBackend([
      order('bbbbbb02', day(0), 'Confirmed', '2026-10-24T04:00:00Z'),
    ]);
    await open(t, b, 'kitchen');
    expect(find.text('UPCOMING ORDERS (0)'), findsOneWidget);
    expect(find.text('No upcoming orders.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('All Orders lists the newest order first', (t) async {
    final b = RowsBackend([
      order('aaaaaa01', day(0), 'Confirmed', '2026-10-20T05:00:00Z'),
      order('bbbbbb02', day(1), 'Confirmed', '2026-10-24T05:00:00Z'),
      order('cccccc03', day(0), 'Preparing', '2026-10-22T05:00:00Z'),
    ]);
    await open(t, b, 'owner');
    await t.tap(find.text('All Orders'));
    await t.pumpAndSettle();
    double top(String id) => t.getTopLeft(find.textContaining(id)).dy;
    expect(top('#BBBBBB'), lessThan(top('#CCCCCC')));
    expect(top('#CCCCCC'), lessThan(top('#AAAAAA')));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
