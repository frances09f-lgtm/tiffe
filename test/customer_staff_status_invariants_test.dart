import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/orders_screen.dart';
import 'package:tiffe/domain/delivery_schedule.dart';
import 'package:tiffe/update/app_update.dart';
import 'package:tiffe/live/update_check.dart';

void main() {
  test('customer update is feed-driven with no Firebase action', () {
    expect(kFeedKey, 'tiffe');
    expect(
      kUpdateFeedUrl,
      'https://raw.githubusercontent.com/frances09f-lgtm/child-safety-updates/main/version.json',
    );
    expect(updatePage, 'tiffe://in-app-update');
    final code = File('lib/live/update_check.dart').readAsStringSync();
    expect(code.contains('appdistribution.firebase.google.com'), isFalse);
    expect(code.contains('await installLatest()'), isTrue);
  });
  test('native scheduled notifications cannot run or fire after upgrade', () {
    final receiver = File(
      'android/app/src/main/kotlin/com/tiffe/tiffe/DeliveryNotificationReceiver.kt',
    ).readAsStringSync();
    expect(receiver.contains('manager.notify('), isFalse);
    final native = File(
      'android/app/src/main/kotlin/com/tiffe/tiffe/MainActivity.kt',
    ).readAsStringSync();
    expect(native.contains('setRepeating('), isFalse);
    expect(native.contains('Timer-based notifications disabled'), isTrue);
    final live = File('lib/live/live_app.dart').readAsStringSync();
    expect(live.contains('_simTimer'), isFalse);
    expect(live.contains('secs ~/ 150'), isFalse);
    expect(live.contains("invokeMethod<bool>('scheduleOrder'"), isFalse);
    expect(live.contains('before != status'), isTrue);
  });
  test('elapsed time does not mark a delivery finished', () {
    for (final hour in [0, 9, 20, 23]) {
      expect(
        DeliverySchedule.status(DateTime.utc(2026, 10, 25, hour)),
        'Waiting for staff update',
      );
    }
    const order = GOrder(
      '#A',
      'One-time',
      'Confirmed',
      'Meal',
      'Today',
      '₹100',
      demoStatus: 'Delivered',
    );
    expect(order.shown, 'Confirmed');
    expect(isHistoryOrder(order), isFalse);
  });
  testWidgets(
    'staff status is displayed and a legacy simulated value is ignored',
    (t) async {
      const confirmed = GOrder(
        '#A',
        'One-time',
        'Confirmed',
        'Meal',
        'Today',
        '₹100',
        demoStatus: 'Delivered',
      );
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: GOrderCard(confirmed))),
      );
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
      await t.pump(const Duration(minutes: 30));
      expect(find.text('Confirmed'), findsOneWidget);
      const cooking = GOrder(
        '#A',
        'One-time',
        'Preparing',
        'Meal',
        'Today',
        '₹100',
      );
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: GOrderCard(cooking))),
      );
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Confirmed'), findsNothing);
    },
  );
}
