import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'admin_controls_test.dart' show OwnerBackend;

typedef Rows = List<Map<String, dynamic>>;
Map<String, dynamic> order(String id, {bool paid = false}) => {
  'id': id,
  'customer_id': 'synthetic',
  'delivery_date': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 5, minutes: 30))
      .toIso8601String()
      .substring(0, 10),
  'quantity': 1,
  'status': 'Confirmed',
  'payment_status': paid ? 'verified' : 'unpaid',
  'assigned_to': null,
  'total_paise': 10000,
  'meal': 'lunch',
};
Rows bhaji(String name) => [
  {'order_id': 'order-0001', 'item_name': name, 'tiffin': 1},
];
const loadError = 'Bhaji counts could not be loaded. Refresh to retry.';

class PendingBackend extends OwnerBackend {
  final Rows rows;
  PendingBackend({Rows? orders}) : rows = orders ?? [order('order-0001')];
  final calls = <String>[];
  final pending = <Completer<void>>[];
  Future<void> hold(String call) {
    calls.add(call);
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }

  @override
  Stream<Rows> orders({bool customer = false}) => Stream.value(rows);
  @override
  Future<Rows> orderItems(List<String> ids) async => [];
  @override
  Future<void> advance(String id, String status, {DateTime? eta}) =>
      hold('advance:$id:$status');
  @override
  Future<void> verifyPayment(String id) => hold('payment:$id');
  @override
  Future<void> assignRider(String id, String rider) =>
      hold('assign:$id:$rider');
}

class RaceBackend extends OwnerBackend {
  final events = StreamController<Rows>.broadcast();
  final reads = <Completer<Rows>>[];
  Completer<Map<String, dynamic>?>? nextProfile;
  @override
  Stream<Rows> orders({bool customer = false}) => events.stream;
  @override
  Future<Rows> orderItems(List<String> ids) {
    if (ids.isEmpty) return Future.value([]);
    final c = Completer<Rows>();
    reads.add(c);
    return c.future;
  }

  @override
  Future<Map<String, dynamic>?> profile() {
    final p = nextProfile;
    nextProfile = null;
    return p?.future ?? Future.value(null);
  }
}

Future<void> open(
  WidgetTester t,
  OwnerBackend b, {
  String role = 'owner',
}) async {
  t.view.physicalSize = const Size(1440, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: PartnerHub(backend: b, role: role),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> allOrders(WidgetTester t) async {
  await t.tap(find.text('All Orders'));
  await t.pumpAndSettle();
}

Finder button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);
void enabled(WidgetTester t, String label, bool value) {
  expect(
    t.widget<ButtonStyleButton>(button(label)).onPressed != null,
    value,
    reason: '$label enabled=$value',
  );
}

Future<void> confirm(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pumpAndSettle();
  await t.tap(find.text('Confirm'));
  await t.pumpAndSettle();
}

Future<void> emit(WidgetTester t, RaceBackend b, {int quantity = 1}) async {
  b.events.add([
    {...order('order-0001'), 'quantity': quantity},
  ]);
  await t.pumpAndSettle();
}

Future<void> endRace(WidgetTester t, RaceBackend b) async {
  await t.pumpWidget(const SizedBox());
  await b.events.close();
}

void main() {
  testWidgets('retained callbacks cannot bypass lock before the next rebuild', (
    t,
  ) async {
    final b = PendingBackend(orders: [order('order-0001', paid: true)]);
    await open(t, b);
    await allOrders(t);
    final start = t
        .widget<ButtonStyleButton>(button('Mark Preparing'))
        .onPressed!;
    final assign = t
        .widget<PopupMenuButton<String>>(
          find.ancestor(
            of: find.text('Assign rider'),
            matching: find.byType(PopupMenuButton<String>),
          ),
        )
        .onSelected!;
    start();
    start();
    assign('rider-0000-1111');
    await t.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    expect(b.calls, isEmpty);
    await t.tap(find.text('Confirm'));
    await t.pumpAndSettle();
    expect(b.calls.length, 1);
    assign('rider-0000-1111');
    start();
    await t.pumpAndSettle();
    expect(b.calls.length, 1);
    b.pending.single.complete();
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'kitchen uses shared lock before confirmation and across navigation',
    (t) async {
      final b = PendingBackend();
      await open(t, b);
      await t.tap(find.text('Accept Order'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      enabled(t, 'Reject', false);
      await t.tap(find.text('Confirm'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await allOrders(t);
      enabled(t, 'Mark Preparing', false);
      enabled(t, 'Verify payment', false);
      b.pending.single.completeError(StateError('synthetic failure'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      enabled(t, 'Mark Preparing', true);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'disposal while confirmation open never submits an order update',
    (t) async {
      final b = PendingBackend();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      t.view.physicalSize = const Size(1440, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, _) =>
                show ? PartnerHub(backend: b, role: 'owner') : const SizedBox(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await allOrders(t);
      await t.tap(find.text('Mark Preparing'));
      await t.pumpAndSettle();
      visible.value = false;
      await t.pumpAndSettle();
      await t.tap(find.text('Confirm'));
      await t.pumpAndSettle();
      expect(b.calls, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'same-order transition cannot repeat while pending; success releases controls',
    (t) async {
      final b = PendingBackend();
      await open(t, b);
      await allOrders(t);
      await confirm(t, 'Mark Preparing');
      expect(b.calls.length, 1);
      await t.tap(find.text('Mark Preparing'));
      await t.pumpAndSettle();
      // If the defect is present, actually confirm the second dialog before asserting.
      if (find.text('Confirm').evaluate().isNotEmpty) {
        await t.tap(find.text('Confirm'));
        await t.pumpAndSettle();
      }
      expect(b.calls.length, 1);
      enabled(t, 'Mark Preparing', false);
      enabled(t, 'Verify payment', false);
      b.pending.single.complete();
      await t.pumpAndSettle();
      enabled(t, 'Mark Preparing', true);
      enabled(t, 'Verify payment', true);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('lock starts before confirmation and Cancel releases it', (
    t,
  ) async {
    final b = PendingBackend();
    await open(t, b);
    await allOrders(t);
    await t.tap(find.text('Mark Preparing'));
    await t.pumpAndSettle();
    enabled(t, 'Verify payment', false);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(b.calls, isEmpty);
    enabled(t, 'Mark Preparing', true);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'payment shares lock and failure releases without automatic retry',
    (t) async {
      final b = PendingBackend();
      await open(t, b);
      await allOrders(t);
      await confirm(t, 'Verify payment');
      enabled(t, 'Mark Preparing', false);
      b.pending.single.completeError(StateError('synthetic refusal'));
      await t.pumpAndSettle();
      expect(b.calls.length, 1);
      enabled(t, 'Verify payment', true);
      enabled(t, 'Mark Preparing', true);
      expect(
        find.text('Update refused. Refresh before trying again.'),
        findsOneWidget,
      );
      await confirm(t, 'Verify payment');
      expect(b.calls.length, 2);
      b.pending.last.complete();
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('assignment shares order lock, catches failure and recovers', (
    t,
  ) async {
    final b = PendingBackend(orders: [order('order-0001', paid: true)]);
    await open(t, b);
    await allOrders(t);
    await t.tap(find.text('Assign rider'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rider').last);
    await t.pumpAndSettle();
    expect(b.calls.single, startsWith('assign:'));
    enabled(t, 'Mark Preparing', false);
    expect(
      t
          .widget<PopupMenuButton<String>>(
            find.ancestor(
              of: find.text('Assign rider'),
              matching: find.byType(PopupMenuButton<String>),
            ),
          )
          .enabled,
      false,
    );
    b.pending.single.completeError(StateError('synthetic refusal'));
    await t.pumpAndSettle();
    enabled(t, 'Mark Preparing', true);
    expect(
      t
          .widget<PopupMenuButton<String>>(
            find.ancestor(
              of: find.text('Assign rider'),
              matching: find.byType(PopupMenuButton<String>),
            ),
          )
          .enabled,
      true,
    );
    expect(
      find.text('Update refused. Refresh before trying again.'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('pending transition disables assignment too', (t) async {
    final b = PendingBackend(orders: [order('order-0001', paid: true)]);
    await open(t, b);
    await allOrders(t);
    await confirm(t, 'Mark Preparing');
    expect(
      t
          .widget<PopupMenuButton<String>>(
            find.ancestor(
              of: find.text('Assign rider'),
              matching: find.byType(PopupMenuButton<String>),
            ),
          )
          .enabled,
      false,
    );
    b.pending.single.complete();
    await t.pumpAndSettle();
    expect(
      t
          .widget<PopupMenuButton<String>>(
            find.ancestor(
              of: find.text('Assign rider'),
              matching: find.byType(PopupMenuButton<String>),
            ),
          )
          .enabled,
      true,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('different orders remain independent', (t) async {
    final b = PendingBackend(
      orders: [order('order-0001'), order('order-0002')],
    );
    await open(t, b);
    await allOrders(t);
    await t.tap(find.text('Mark Preparing').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Confirm'));
    await t.pumpAndSettle();
    final controls = t
        .widgetList<FilledButton>(find.byType(FilledButton))
        .where(
          (w) => w.child is Text && (w.child as Text).data == 'Mark Preparing',
        )
        .toList();
    expect(controls.where((w) => w.onPressed == null).length, 1);
    expect(controls.where((w) => w.onPressed != null).length, 1);
    b.pending.single.complete();
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('lock survives navigation to kitchen and back', (t) async {
    final b = PendingBackend();
    await open(t, b);
    await allOrders(t);
    await confirm(t, 'Mark Preparing');
    await t.tap(find.text('Live Kitchen (KDS)'));
    await t.pumpAndSettle();
    enabled(t, 'Accept Order', false);
    await allOrders(t);
    enabled(t, 'Mark Preparing', false);
    b.pending.single.complete();
    await t.pumpAndSettle();
    enabled(t, 'Mark Preparing', true);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'disposing hub while action pending has no setState-after-dispose',
    (t) async {
      final b = PendingBackend();
      await open(t, b);
      await allOrders(t);
      await confirm(t, 'Mark Preparing');
      await t.pumpWidget(const SizedBox());
      b.pending.single.completeError(StateError('synthetic failure'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('older stream success cannot replace newer kitchen data', (
    t,
  ) async {
    final b = RaceBackend();
    await open(t, b, role: 'kitchen');
    await emit(t, b);
    await emit(t, b, quantity: 2);
    expect(b.reads.length, 2);
    b.reads[1].complete(bhaji('newest-bhaji'));
    await t.pumpAndSettle();
    b.reads[0].complete(bhaji('stale-bhaji'));
    await t.pumpAndSettle();
    expect(find.text('newest-bhaji'), findsWidgets);
    expect(find.text('stale-bhaji'), findsNothing);
    await endRace(t, b);
  });
  testWidgets('older stream failure cannot replace newer success', (t) async {
    final b = RaceBackend();
    await open(t, b, role: 'kitchen');
    await emit(t, b);
    await emit(t, b, quantity: 2);
    b.reads[1].complete(bhaji('newest-bhaji'));
    await t.pumpAndSettle();
    b.reads[0].completeError(StateError('stale failure'));
    await t.pumpAndSettle();
    expect(find.text(loadError), findsNothing);
    expect(find.text('newest-bhaji'), findsWidgets);
    await endRace(t, b);
  });
  testWidgets(
    'older success cannot clear latest error; latest success clears it',
    (t) async {
      final b = RaceBackend();
      await open(t, b, role: 'kitchen');
      await emit(t, b);
      await emit(t, b, quantity: 2);
      b.reads[1].completeError(StateError('new failure'));
      await t.pumpAndSettle();
      expect(find.text(loadError), findsOneWidget);
      b.reads[0].complete(bhaji('stale-bhaji'));
      await t.pumpAndSettle();
      expect(find.text(loadError), findsOneWidget);
      expect(find.text('stale-bhaji'), findsNothing);
      await emit(t, b, quantity: 3);
      b.reads[2].complete(bhaji('recovered-bhaji'));
      await t.pumpAndSettle();
      expect(find.text(loadError), findsNothing);
      expect(find.text('recovered-bhaji'), findsWidgets);
      await endRace(t, b);
    },
  );
  testWidgets('refresh supersedes earlier stream fetch', (t) async {
    final b = RaceBackend();
    await open(t, b, role: 'kitchen');
    await emit(t, b);
    final refresh = t.widget<KitchenHub>(find.byType(KitchenHub)).onSync();
    await t.pumpAndSettle();
    expect(b.reads.length, 2);
    b.reads[1].complete(bhaji('refresh-newest'));
    await refresh;
    await t.pumpAndSettle();
    b.reads[0].complete(bhaji('stream-stale'));
    await t.pumpAndSettle();
    expect(find.text('refresh-newest'), findsWidgets);
    expect(find.text('stream-stale'), findsNothing);
    await endRace(t, b);
  });
  testWidgets(
    'stream supersedes refresh even when refresh profile completes late',
    (t) async {
      final b = RaceBackend();
      await open(t, b, role: 'kitchen');
      await emit(t, b);
      b.reads[0].complete(bhaji('initial'));
      await t.pumpAndSettle();
      final profile = Completer<Map<String, dynamic>?>();
      b.nextProfile = profile;
      final refresh = t.widget<KitchenHub>(find.byType(KitchenHub)).onSync();
      await t.pumpAndSettle();
      await emit(t, b, quantity: 2);
      // Fixed implementation starts refresh item read before unrelated profile awaits.
      expect(b.reads.length, 3);
      b.reads[2].complete(bhaji('stream-newest'));
      await t.pumpAndSettle();
      profile.complete(null);
      b.reads[1].complete(bhaji('refresh-stale'));
      await refresh;
      await t.pumpAndSettle();
      expect(find.text('stream-newest'), findsWidgets);
      expect(find.text('refresh-stale'), findsNothing);
      await endRace(t, b);
    },
  );
  testWidgets('refresh latest failure is visible, and retry clears it', (
    t,
  ) async {
    final b = RaceBackend();
    await open(t, b, role: 'kitchen');
    await emit(t, b);
    b.reads[0].complete(bhaji('initial'));
    await t.pumpAndSettle();
    var refresh = t.widget<KitchenHub>(find.byType(KitchenHub)).onSync();
    await t.pumpAndSettle();
    b.reads[1].completeError(StateError('refresh failure'));
    await refresh;
    await t.pumpAndSettle();
    expect(find.text(loadError), findsOneWidget);
    refresh = t.widget<KitchenHub>(find.byType(KitchenHub)).onSync();
    await t.pumpAndSettle();
    b.reads[2].complete(bhaji('retry-bhaji'));
    await refresh;
    await t.pumpAndSettle();
    expect(find.text(loadError), findsNothing);
    expect(find.text('retry-bhaji'), findsWidgets);
    await endRace(t, b);
  });
  testWidgets('late item success and error after disposal are ignored', (
    t,
  ) async {
    final b = RaceBackend();
    await open(t, b, role: 'kitchen');
    await emit(t, b);
    await emit(t, b, quantity: 2);
    await t.pumpWidget(const SizedBox());
    b.reads[0].complete(bhaji('late'));
    b.reads[1].completeError(StateError('late failure'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await b.events.close();
  });
}
