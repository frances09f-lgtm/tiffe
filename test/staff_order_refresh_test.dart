import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'partner_hub_test.dart' as hub;

class EmptyOrdersBackend extends hub.WebBackend {
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value([]);
}

class BrokenOrdersBackend extends EmptyOrdersBackend {
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.error(StateError('isolated stream failure'));
}

Map<String, dynamic> newOrder() => {
  'id': '7228c400-test',
  'customer_id': 'c4',
  'delivery_date': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 29, minutes: 30))
      .toIso8601String()
      .substring(0, 10),
  'status': 'Confirmed',
  'payment_status': 'unpaid',
  'quantity': 1,
  'total_paise': 10000,
};

Future<void> open(
  WidgetTester t,
  Future<List<Map<String, dynamic>>> Function() read, {
  hub.WebBackend? backend,
}) async {
  t.view.physicalSize = const Size(430, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: PartnerHub(
        backend: backend ?? EmptyOrdersBackend(),
        role: 'owner',
        readOrders: read,
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('All Orders'));
  await t.pumpAndSettle();
  await t.tap(find.text('All'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('polling recovers a new future unpaid order after 15 seconds', (
    t,
  ) async {
    var reads = 0;
    final backend = EmptyOrdersBackend();
    await open(t, () async {
      reads++;
      return [newOrder()];
    }, backend: backend);
    expect(reads, 0);
    expect(find.textContaining('#7228C4'), findsNothing);
    await t.pump(const Duration(seconds: 15));
    await t.pumpAndSettle();
    expect(reads, 1);
    expect(find.textContaining('#7228C4'), findsOneWidget);
    expect(find.textContaining('Payment pending'), findsOneWidget);
    expect(backend.verifiedOrder, isNull);
    expect(backend.advancedTo, isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 30));
    expect(reads, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Refresh keeps old rows on failure and clears the banner on retry',
    (t) async {
      var fail = false;
      await open(t, () async {
        if (fail) throw StateError('isolated read failure');
        return [newOrder()];
      });
      await t.tap(find.text('Refresh'));
      await t.pumpAndSettle();
      expect(find.textContaining('#7228C4'), findsOneWidget);
      fail = true;
      await t.tap(find.text('Refresh'));
      await t.pumpAndSettle();
      expect(find.textContaining('Orders could not load.'), findsOneWidget);
      expect(find.textContaining('#7228C4'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Refresh'));
      await t.pumpAndSettle();
      expect(find.textContaining('Orders could not load.'), findsNothing);
      expect(find.textContaining('#7228C4'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('pull-to-refresh works even with an empty short list', (t) async {
    var reads = 0;
    await open(t, () async {
      reads++;
      return [newOrder()];
    });
    final scroll = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(SingleChildScrollView),
    );
    await t.drag(scroll, const Offset(0, 500));
    await t.pumpAndSettle();
    expect(reads, 1);
    expect(find.textContaining('#7228C4'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a stream failure is visible and manual read recovers', (
    t,
  ) async {
    await open(t, () async => [newOrder()], backend: BrokenOrdersBackend());
    expect(find.textContaining('Orders could not load.'), findsOneWidget);
    await t.tap(find.text('Refresh'));
    await t.pumpAndSettle();
    expect(find.textContaining('Orders could not load.'), findsNothing);
    expect(find.textContaining('#7228C4'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('one read at a time and timeout shows a retry banner', (t) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    var reads = 0;
    await open(t, () {
      reads++;
      return pending.future;
    });
    await t.tap(find.text('Refresh'));
    await t.pump();
    expect(reads, 1);
    expect(find.text('Refreshing...'), findsOneWidget);
    await t.pump(const Duration(seconds: 11));
    await t.pumpAndSettle();
    expect(find.textContaining('Orders could not load.'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    pending.complete([newOrder()]);
    await t.pumpAndSettle();
    expect(find.textContaining('#7228C4'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
