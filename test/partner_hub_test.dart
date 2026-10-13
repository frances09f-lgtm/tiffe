import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/backend.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'admin_controls_test.dart' show OwnerBackend;

// Match the production admin's Pune day instead of expiring at midnight.
final today = DateTime.now()
    .toUtc()
    .add(const Duration(hours: 5, minutes: 30))
    .toIso8601String()
    .substring(0, 10);

class WebBackend extends OwnerBackend {
  @override
  Future<List<Map<String, dynamic>>> orderItems(List<String> ids) async => [];
  String? verifiedSub;
  @override
  Future<void> verifySubscription(String id) async => verifiedSub = id;

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
      'id': 's3',
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

class FutureOrdersBackend extends WebBackend {
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) {
    final n = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    String day(int add) =>
        n.add(Duration(days: add)).toIso8601String().substring(0, 10);
    Map<String, dynamic> o(String id, String c, String d, String st) => {
      'id': id,
      'customer_id': c,
      'delivery_date': d,
      'meal': 'lunch',
      'status': st,
      'payment_status': 'unpaid',
      'assigned_to': null,
      'total_paise': 10000,
      'eta_at': null,
    };
    return Stream.value([
      o('aaaaaa11', 'c1', day(0), 'Delivered'),
      o('bbbbbb22', 'c2', day(1), 'Confirmed'),
      o('cccccc33', 'c3', day(-2), 'Delivered'),
    ]);
  }
}

Future<void> open(
  WidgetTester t,
  double w, {
  double scale = 1,
  TiffeBackend? backend,
}) async {
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
        child: PartnerHub(backend: backend ?? WebBackend(), role: 'owner'),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('owner mobile hub has usable navigation', (t) async {
    await open(t, 390);
    expect(find.text('Tiffie Central Kitchen'), findsOneWidget);
    expect(find.text('Live Kitchen (KDS)'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-240, 0),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Menu & Item Status'));
    await t.pumpAndSettle();
    expect(find.text('Menu & Daily Item Stock Status'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('kitchen cannot reject, handover or edit automatic setting', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        home: PartnerHub(backend: WebBackend(), role: 'kitchen'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Fleet'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
