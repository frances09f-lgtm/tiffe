import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';

import 'live_content_test.dart';

const batata = '7ebaba2e-f7d1-413d-a0c6-708c3f7dc48d';
const matki = 'fb32420b-f2a1-465d-b5e3-4acfeeeacf20';
const baingan = '271e8b53-4e69-4969-a3af-d1b908d0b0bd';

class PlanBackend extends ContentBackend {
  List<Map<String, dynamic>> items = [];
  String? changedOrder;
  List<String>? changedTo;
  Object? failWith;
  @override
  Future<List<Map<String, dynamic>>> orderItems(List<String> ids) async =>
      items;
  @override
  Future<void> setOrderBhajis(String orderId, List<String> ids) async {
    if (failWith != null) throw failWith!;
    changedOrder = orderId;
    changedTo = ids;
  }
}

Map<String, dynamic> order(
  String id,
  String date,
  String meal,
  String status, {
  bool sub = true,
}) => {
  'id': id,
  'delivery_date': date,
  'quantity': 1,
  'status': status,
  'total_paise': 0,
  'payment_status': 'verified',
  'eta_at': null,
  'created_at': '2026-10-09T18:30:00Z',
  'subscription_id': sub ? 'sub-1' : null,
  'meal': meal,
};

List<Map<String, dynamic>> pair(String id, List<String> names) => [
  for (var k = 0; k < names.length; k++)
    {
      'order_id': id,
      'tiffin': 1,
      'menu_item_id': 'x$k',
      'item_name': names[k],
      'extra_price_paise': 0,
    },
];

void main() {
  tearDown(() {
    LiveClock.now = () =>
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  });

  Future<PlanBackend> open(
    WidgetTester t, {
    required List<Map<String, dynamic>> rows,
    DateTime? now,
  }) async {
    LiveClock.now = () => now ?? DateTime(2026, 10, 10, 8, 20);
    t.view.physicalSize = const Size(390, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    final b = PlanBackend()
      ..orderRows = rows
      ..items = [
        for (final r in rows)
          ...pair(r['id'] as String, ['Batata Bhaji', 'Matki Usal']),
      ];
    await t.pumpWidget(
      TiffeApp(
        store: store,
        startScreen: LiveWorkspace(backend: b, store: store),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Orders').last);
    await t.pumpAndSettle();
    return b;
  }

  testWidgets(
    'double plan shows today and tomorrow lunch and dinner, delivered is in Completed',
    (t) async {
      await open(
        t,
        rows: [
          order('l1', '2026-10-10', 'lunch', 'Confirmed'),
          order('d1', '2026-10-10', 'dinner', 'Confirmed'),
          order('l2', '2026-10-11', 'lunch', 'Confirmed'),
          order('d2', '2026-10-11', 'dinner', 'Confirmed'),
          order('old', '2026-10-09', 'dinner', 'Delivered'),
        ],
      );
      expect(find.text('Today, Sat 10 Oct'), findsOneWidget);
      expect(find.text('Tomorrow, Sun 11 Oct'), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(4));
      expect(find.text('Change bhajis'), findsNWidgets(4));
      expect(find.text('Change until 12:00 PM today'), findsOneWidget);
      expect(find.text('Change until 8:00 PM today'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
      expect(find.text('Completed'), findsOneWidget);
      await t.tap(find.text('Completed'));
      await t.pumpAndSettle();
      expect(find.text('Delivered'), findsWidgets);
    },
  );

  testWidgets('lunch-only plan has one card per day', (t) async {
    await open(
      t,
      rows: [
        order('l1', '2026-10-10', 'lunch', 'Confirmed'),
        order('l2', '2026-10-11', 'lunch', 'Confirmed'),
      ],
    );
    expect(find.text('Pending'), findsNWidgets(2));
    expect(find.textContaining('Dinner'), findsNothing);
  });

  testWidgets('changing bhajis sends exactly two ids and shows Your pick', (
    t,
  ) async {
    final b = await open(
      t,
      rows: [order('l1', '2026-10-10', 'lunch', 'Confirmed')],
    );
    expect(find.text('Default bhajis'), findsOneWidget);
    await t.tap(find.text('Change bhajis'));
    await t.pumpAndSettle();
    // Save is disabled until exactly two are picked.
    await t.tap(find.text('Matki Usal').last);
    await t.pump();
    expect(find.text('Pick 1 more'), findsOneWidget);
    await t.tap(find.text('Baingan Masala'));
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(b.changedOrder, 'l1');
    expect(b.changedTo, [batata, baingan]);
    expect(find.textContaining('bhajis updated'), findsOneWidget);
  });

  testWidgets('after the cutoff the card locks, the other meal stays open', (
    t,
  ) async {
    await open(
      t,
      rows: [
        order('l1', '2026-10-10', 'lunch', 'Packed'),
        order('d1', '2026-10-10', 'dinner', 'Confirmed'),
      ],
      now: DateTime(2026, 10, 10, 12, 30),
    );
    expect(find.text('Locked, kitchen is preparing'), findsOneWidget);
    expect(find.text('Change bhajis'), findsOneWidget);
    expect(find.text('Pending'), findsNWidgets(2));
  });

  testWidgets(
    'undelivered order from an earlier day stays Pending and locked',
    (t) async {
      await open(t, rows: [order('l0', '2026-10-09', 'dinner', 'Preparing')]);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Locked, kitchen is preparing'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
    },
  );

  testWidgets(
    'out for delivery plan order is On the way, one-time orders show on top',
    (t) async {
      await open(
        t,
        rows: [
          order('l1', '2026-10-10', 'lunch', 'Out for Delivery'),
          order('ot', '2026-10-10', '', 'Confirmed', sub: false)
            ..remove('meal'),
          order('d1', '2026-10-10', 'dinner', 'Confirmed'),
        ],
      );
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsOneWidget);
      expect(find.text('One-time'), findsNothing);
      expect(find.textContaining('One-time'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    },
  );

  testWidgets('server refusal is shown, nothing changes', (t) async {
    final b = await open(
      t,
      rows: [order('l1', '2026-10-10', 'lunch', 'Confirmed')],
    );
    b.failWith = Exception('Bhajis can no longer change (cutoff passed)');
    await t.tap(find.text('Change bhajis'));
    await t.pumpAndSettle();
    await t.tap(find.text('Matki Usal').last);
    await t.tap(find.text('Baingan Masala'));
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.textContaining('already being prepared'), findsOneWidget);
    expect(b.changedOrder, isNull);
  });

  testWidgets(
    'non-plan user: no daily cards, empty message when nothing at all',
    (t) async {
      await open(t, rows: []);
      expect(find.textContaining('No orders yet'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
    },
  );

  testWidgets('home counts both meals of the day', (t) async {
    await open(
      t,
      rows: [
        order('l1', '2026-10-10', 'lunch', 'Confirmed'),
        order('d1', '2026-10-10', 'dinner', 'Confirmed'),
      ],
    );
    await t.tap(find.text('Home').last);
    await t.pumpAndSettle();
    expect(find.textContaining('2 Tiffins'), findsOneWidget);
  });
}
