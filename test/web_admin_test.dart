import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/web_admin/admin_site.dart';

import 'admin_controls_test.dart' show OwnerBackend;

const today = '2026-10-11';

class WebBackend extends OwnerBackend {
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value([
        for (final r in [
          [
            'a1b2c3d4',
            'c1',
            'lunch',
            'Out for Delivery',
            'verified',
            'r1',
            150000,
          ],
          ['b2c3d4e5', 'c2', 'lunch', 'Packed', 'verified', null, 150000],
          ['c3d4e5f6', 'c3', 'lunch', 'Preparing', 'verified', null, 150000],
          ['d4e5f6a7', 'c4', 'dinner', 'Confirmed', 'unpaid', null, 10000],
          ['e5f6a7b8', 'c5', 'lunch', 'Delivered', 'verified', 'r2', 300000],
        ])
          {
            'id': r[0],
            'customer_id': r[1],
            'delivery_date': today,
            'meal': r[2],
            'status': r[3],
            'payment_status': r[4],
            'assigned_to': r[5],
            'total_paise': r[6],
            'eta_at': null,
          },
      ]);
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value([
    {
      'id': 'm1',
      'name': 'Batata Bhaji',
      'description': 'Dry potato bhaji',
      'available': true,
    },
    {
      'id': 'm2',
      'name': 'Matki Usal',
      'description': 'Sprouted moth beans',
      'available': true,
    },
    {
      'id': 'm3',
      'name': 'Baingan Masala',
      'description': 'Brinjal masala',
      'available': false,
    },
  ]);
  @override
  Future<List<Map<String, dynamic>>> deliveryStaff() async => [
    {'user_id': 'r1', 'name': 'Ramesh'},
    {'user_id': 'r2', 'name': 'Suresh'},
  ];
  @override
  Future<List<Map<String, dynamic>>> customers() async => [
    {
      'id': 'c1',
      'name': 'Aarav Sharma',
      'phone': '98765 43210',
      'area': 'Baner',
      'created_at': '2026-10-10T08:00:00Z',
    },
    {
      'id': 'c2',
      'name': 'Priya Patel',
      'phone': '98111 22334',
      'area': 'Aundh',
      'created_at': '2026-10-09T08:00:00Z',
    },
    {
      'id': 'c3',
      'name': 'Vikram Malhotra',
      'phone': '97222 33445',
      'area': 'Wakad',
      'created_at': '2026-10-08T08:00:00Z',
    },
    {
      'id': 'c4',
      'name': 'Anita Desai',
      'phone': '99333 44556',
      'area': 'Baner',
      'created_at': '2026-10-07T08:00:00Z',
    },
    {
      'id': 'c5',
      'name': 'Neha Gupta',
      'phone': '99000 11223',
      'area': 'Kothrud',
      'created_at': '2026-10-05T08:00:00Z',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> allSubscriptions() async => [
    {
      'customer_id': 'c1',
      'plan': 'daily',
      'starts_on': '2026-10-01',
      'ends_on': '2026-10-31',
      'verified': true,
    },
    {
      'customer_id': 'c2',
      'plan': 'double',
      'starts_on': '2026-10-03',
      'ends_on': '2026-11-02',
      'verified': true,
    },
    {
      'customer_id': 'c3',
      'plan': 'daily',
      'starts_on': '2026-10-08',
      'ends_on': '2026-11-07',
      'verified': false,
    },
    {
      'customer_id': 'c5',
      'plan': 'daily',
      'starts_on': '2026-09-01',
      'ends_on': '2026-09-30',
      'verified': true,
    },
  ];
}

Future<void> open(WidgetTester t, double w, {double scale = 1}) async {
  t.view.physicalSize = Size(w, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(w, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: AdminSite(backend: WebBackend()),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('desktop shows real counts and customers search', (t) async {
    await open(t, 1440);
    expect(find.text('Kitchen overview'), findsOneWidget);
    expect(find.text('Orders today'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsWidgets);
    await t.tap(find.text('Customers').first);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('5 customers'), findsOneWidget);
    expect(find.textContaining('Joined 10 Oct'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'baner');
    await t.pump();
    expect(find.text('2 customers'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pump();
    expect(find.text('No customers match that search.'), findsOneWidget);
  });

  testWidgets('every screen fits 320px at 1.3x text', (t) async {
    await open(t, 320, scale: 1.3);
    for (var i = 0; i < 5; i++) {
      await t.tap(find.byType(NavigationDestination).at(i));
      await t.pump(const Duration(milliseconds: 200));
      final ex = t.takeException();
      expect(ex, isNull, reason: 'screen $i');
    }
  });
}
