import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';

import 'shots_test.dart' show ContentBackend;

class BuyBackend extends ContentBackend {
  final subs = StreamController<List<Map<String, dynamic>>>.broadcast();
  String? bought;
  bool fail = false;
  @override
  Stream<List<Map<String, dynamic>>> subscriptions() => subs.stream;
  @override
  Future<String> buySubscription(String plan) async {
    if (fail) throw Exception('You already have a plan.');
    bought = plan;
    return 'sub-1';
  }
}

Future<void> openPlans(WidgetTester t, BuyBackend b) async {
  SharedPreferences.setMockInitialValues({});
  final s = TiffeStore(await SharedPreferences.getInstance());
  t.view.physicalSize = const Size(390, 1900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    TiffeApp(
      store: s,
      startScreen: LiveWorkspace(backend: b, store: s),
    ),
  );
  await t.pumpAndSettle();
  b.subs.add([]);
  await t.pumpAndSettle();
  await t.tap(find.text('Plans').last);
  await t.pumpAndSettle();
}

Future<void> payFlow(WidgetTester t) async {
  await t.tap(find.text('Select This Plan').first);
  await t.pumpAndSettle();
  await t.tap(find.textContaining('Proceed to Payment'));
  await t.pumpAndSettle();
  await t.tap(find.textContaining('Continue ·'));
  await t.pump(const Duration(seconds: 4));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('buying a plan saves it and is active right away', (t) async {
    final b = BuyBackend();
    await openPlans(t, b);
    await payFlow(t);
    expect(b.bought, 'double');
    expect(find.text('Plan request sent'), findsOneWidget);
    expect(find.textContaining('waiting'), findsNothing);
    b.subs.add([
      {
        'id': 'sub-1',
        'customer_id': 'fixture-customer',
        'plan': 'double',
        'starts_on': '2020-01-01',
        'ends_on': '2099-01-01',
        'verified': true,
      },
    ]);
    await t.tap(find.text('Go to Home Dashboard'));
    await t.pumpAndSettle();
    expect(find.text('Waiting for payment confirmation'), findsNothing);
    await t.tap(find.text('Plans').last);
    await t.pumpAndSettle();
    expect(find.text('Active Plan'), findsOneWidget);
  });

  testWidgets('a plan the owner added unverified shows as awaiting', (t) async {
    final b = BuyBackend();
    await openPlans(t, b);
    b.subs.add([
      {
        'id': 'sub-2',
        'customer_id': 'fixture-customer',
        'plan': 'daily',
        'starts_on': '2020-01-01',
        'ends_on': '2099-01-01',
        'verified': false,
      },
    ]);
    await t.pumpAndSettle();
    await t.tap(find.text('Plans').last);
    await t.pumpAndSettle();
    expect(find.text('Awaiting Confirmation'), findsOneWidget);
    expect(find.text('Active Plan'), findsNothing);
  });

  testWidgets('a failed purchase never looks booked', (t) async {
    final b = BuyBackend()..fail = true;
    await openPlans(t, b);
    await payFlow(t);
    expect(find.text('Plan request sent'), findsNothing);
    expect(find.textContaining('You already have a plan'), findsWidgets);
    expect(find.text('Select This Plan'), findsWidgets);
  });
}
