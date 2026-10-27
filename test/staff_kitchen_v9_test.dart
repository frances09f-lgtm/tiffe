import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'admin_controls_test.dart' show OwnerBackend;

final istToday = DateTime.now()
    .toUtc()
    .add(const Duration(hours: 5, minutes: 30))
    .toIso8601String()
    .substring(0, 10);

final istTomorrow = DateTime.now()
    .toUtc()
    .add(const Duration(hours: 5, minutes: 30) + const Duration(days: 1))
    .toIso8601String()
    .substring(0, 10);

Map<String, dynamic> order(String id, String date, String status,
        {int qty = 1, String payment = 'verified', String? rider}) =>
    {
      'id': id,
      'customer_id': 'cust-1',
      'delivery_date': date,
      'meal': 'lunch',
      'quantity': qty,
      'status': status,
      'payment_status': payment,
      'assigned_to': rider,
      'total_paise': 10000,
      'eta_at': null,
      'created_at': '2026-10-27T03:00:00Z',
    };

AdminData dataWith(List<Map<String, dynamic>> orders) => AdminData(
      orders: orders,
      subs: const [],
      customers: const [
        {'id': 'cust-1', 'name': 'Asha'},
      ],
      menu: const [],
      riders: const [
        {'user_id': 'rider-1', 'name': 'Vijay'},
      ],
      today: istToday,
    );

void main() {
  test('KitchenCounts counts today deliveries only, not upcoming', () {
    final d = dataWith([
      order('ord-0001', istToday, 'Confirmed', qty: 2),
      order('ord-0002', istToday, 'Preparing'),
      order('ord-0003', istTomorrow, 'Confirmed', qty: 5),
      order('ord-0004', istToday, 'Delivered', qty: 7),
    ]);
    final items = [
      {'order_id': 'ord-0001', 'item_name': 'Batata Bhaji'},
      {'order_id': 'ord-0001', 'item_name': 'Batata Bhaji'},
      {'order_id': 'ord-0003', 'item_name': 'Aloo Gobi'},
    ];
    final c = KitchenCounts.from(d, items);
    // Today + active statuses only: ord-0001 (2) + ord-0002 (1) = 3 tiffins;
    // tomorrow's 5 and today's delivered 7 excluded.
    expect(c.tiffins, 3);
    expect(c.bhajis, {'Batata Bhaji': 2});
  });

  testWidgets('Ready card with verified payment and no rider offers assignment',
      (t) async {
    final b = OwnerBackend();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenHub(
              d: dataWith([order('ord-0001', istToday, 'Packed')]),
              b: b,
              role: 'owner',
              items: const [],
              onSync: () async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Assign delivery partner'), findsOneWidget);
    await t.ensureVisible(find.text('Assign delivery partner'));
    await t.pumpAndSettle();
    await t.tap(find.text('Assign delivery partner'));
    await t.pumpAndSettle();
    expect(find.text('Vijay'), findsWidgets);
    await t.tap(find.text('Vijay').last);
    await t.pumpAndSettle();
    expect(b.assignedOrder, 'ord-0001');
    expect(b.assignedRider, 'rider-1');
  });

  testWidgets('Ready card hides assignment when payment is unverified',
      (t) async {
    final b = OwnerBackend();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenHub(
              d: dataWith([order('ord-0001', istToday, 'Packed', payment: 'unpaid')]),
              b: b,
              role: 'owner',
              items: const [],
              onSync: () async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Assign delivery partner'), findsNothing);
  });

  testWidgets('Auto-confirm switch reflects server setting for owner',
      (t) async {
    final b = _SettingsBackend(true);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenHub(
              d: dataWith(const []),
              b: b,
              role: 'owner',
              items: const [],
              onSync: () async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final sw = t.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue);
  });

  testWidgets('Kitchen staff role does not see the auto-confirm switch',
      (t) async {
    final b = _SettingsBackend(true);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenHub(
              d: dataWith(const []),
              b: b,
              role: 'kitchen',
              items: const [],
              onSync: () async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
  });
}

class _SettingsBackend extends OwnerBackend {
  _SettingsBackend(this.on);
  final bool on;
  @override
  Future<Map<String, dynamic>?> currentSettings() async =>
      {'kitchen_auto_accept': on};
}
