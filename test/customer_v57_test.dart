import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/order_alerts.dart';
import 'package:tiffe/live/order_status.dart';
import 'package:tiffe/live/order_tracking.dart';

Map<String, dynamic> o(String id, String status, {bool? awaiting}) => {
  'id': id,
  'status': status,
  'awaiting_acceptance': ?awaiting,
};

void main() {
  group('status -> notification for every step', () {
    test('each staff step after placing has its own alert', () {
      final steps = [
        kOrderPlaced,
        'Confirmed',
        'Preparing',
        'Packed',
        'Out for Delivery',
        'Delivered',
      ];
      for (var i = 1; i < steps.length; i++) {
        final text = orderAlertChange(steps[i - 1], steps[i]);
        expect(text, isNotNull, reason: '${steps[i - 1]} -> ${steps[i]}');
        expect(text, orderAlertText[steps[i]]);
      }
    });

    test('accepted by staff (awaiting true -> false) reads Confirmed', () {
      final before = customerOrderView(o('a1', 'Confirmed', awaiting: true));
      final after = customerOrderView(o('a1', 'Confirmed', awaiting: false));
      expect(before['status'], kOrderPlaced);
      expect(after['status'], 'Confirmed');
      expect(
        orderAlertChange(before['status'], after['status']),
        'The kitchen accepted your order',
      );
    });

    test('cancelled, failed and refunded orders notify too', () {
      expect(orderAlertChange('Preparing', 'Cancelled'), contains('cancelled'));
      expect(orderAlertChange(kOrderPlaced, 'Cancelled'), isNotNull);
      expect(orderAlertChange('Out for Delivery', 'Failed'), isNotNull);
      expect(orderAlertChange('Cancelled', 'Refunded'), contains('refunded'));
    });

    test('no alert without a real change', () {
      expect(orderAlertChange('Preparing', 'Preparing'), isNull);
      expect(orderAlertChange('Preparing', 'Some new status'), isNull);
    });

    test('a brand-new order alerts only while it waits for the kitchen', () {
      expect(orderAlertChange(null, kOrderPlaced), kNewOrderAlertText);
      expect(orderAlertChange(null, 'Delivered'), isNull);
      expect(orderAlertChange(null, 'Preparing'), isNull);
    });
  });

  group('which orders keep tracking alive', () {
    test('open statuses are active, finished ones are not', () {
      for (final s in [
        kOrderPlaced,
        'Confirmed',
        'Preparing',
        'Packed',
        'Out for Delivery',
      ]) {
        expect(orderActive(o('x', s)), isTrue, reason: s);
      }
      for (final s in ['Delivered', 'Cancelled', 'Failed', 'Refunded', '']) {
        expect(orderActive(o('x', s)), isFalse, reason: s);
      }
    });

    test(
      'tracking runs only with a login, notifications and an open order',
      () {
        final open = [o('1', 'Delivered'), o('2', 'Preparing')];
        final done = [o('1', 'Delivered'), o('2', 'Cancelled')];
        expect(
          shouldTrack(loggedIn: true, notificationsAllowed: true, rows: open),
          isTrue,
        );
        expect(
          shouldTrack(loggedIn: true, notificationsAllowed: true, rows: done),
          isFalse,
        );
        expect(
          shouldTrack(loggedIn: false, notificationsAllowed: true, rows: open),
          isFalse,
        );
        expect(
          shouldTrack(loggedIn: true, notificationsAllowed: false, rows: open),
          isFalse,
        );
        expect(
          shouldTrack(
            loggedIn: true,
            notificationsAllowed: true,
            rows: const [],
          ),
          isFalse,
        );
      },
    );
  });

  group('service lifecycle', () {
    test('start, keep, stop, nothing', () {
      expect(trackerAction(running: false, wanted: true), TrackerAction.start);
      expect(trackerAction(running: true, wanted: true), TrackerAction.keep);
      expect(trackerAction(running: true, wanted: false), TrackerAction.stop);
      expect(trackerAction(running: false, wanted: false), TrackerAction.none);
    });

    test('polls every minute without Realtime, every 5 minutes with it', () {
      final t0 = DateTime(2026, 10, 27, 12);
      expect(trackerPollDue(lastPoll: null, now: t0, realtimeOk: true), isTrue);
      final t1 = t0.add(const Duration(seconds: 61));
      expect(trackerPollDue(lastPoll: t0, now: t1, realtimeOk: false), isTrue);
      expect(trackerPollDue(lastPoll: t0, now: t1, realtimeOk: true), isFalse);
      final t5 = t0.add(const Duration(minutes: 5));
      expect(trackerPollDue(lastPoll: t0, now: t5, realtimeOk: true), isTrue);
    });

    test('the service stays quiet while the app is on screen', () {
      const now = 1000000000;
      expect(appOnScreen(now - 30000, now), isTrue);
      expect(appOnScreen(now - 91000, now), isFalse);
      expect(appOnScreen(0, now), isFalse);
    });

    test('login refresh only near expiry', () {
      const now = 1800000000000;
      expect(
        loginNeedsRefresh(expiresAtSec: now ~/ 1000 + 3600, nowMs: now),
        isFalse,
      );
      expect(
        loginNeedsRefresh(expiresAtSec: now ~/ 1000 + 60, nowMs: now),
        isTrue,
      );
      expect(loginNeedsRefresh(expiresAtSec: null, nowMs: now), isTrue);
    });

    test('the 15-minute check steps aside while the tracker is alive', () {
      const now = 1000000000;
      expect(trackerAlive(now - 30000, now), isTrue);
      expect(trackerAlive(now - 120000, now), isFalse);
    });

    test('battery prompt is asked once, only while tracking', () {
      expect(
        shouldAskBattery(exempt: false, alreadyAsked: false, tracking: true),
        isTrue,
      );
      expect(
        shouldAskBattery(exempt: false, alreadyAsked: true, tracking: true),
        isFalse,
      );
      expect(
        shouldAskBattery(exempt: true, alreadyAsked: false, tracking: true),
        isFalse,
      );
      expect(
        shouldAskBattery(exempt: false, alreadyAsked: false, tracking: false),
        isFalse,
      );
      expect(kBatteryPromptText, contains('Xiaomi'));
    });
  });

  group('quiet tracking notification', () {
    test('one open order names it and its status', () {
      final n = trackingNotice([
        o('abcdef123', 'Preparing'),
        o('zz', 'Delivered'),
      ]);
      expect(n.title, 'Tracking your order #ABCDEF');
      expect(n.text, startsWith('Preparing'));
    });
    test('several open orders', () {
      final n = trackingNotice([o('a', 'Preparing'), o('b', kOrderPlaced)]);
      expect(n.title, 'Tracking 2 orders');
    });
    test('no open orders', () {
      expect(trackingNotice(const []).text, 'Checking your orders');
    });
  });

  group('Android wiring', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    test(
      'foreground service declared with an Android 14 type and permissions',
      () {
        expect(
          manifest,
          contains(
            'com.pravera.flutter_foreground_task.service.ForegroundService',
          ),
        );
        expect(
          manifest,
          contains('android:foregroundServiceType="remoteMessaging"'),
        );
        expect(
          manifest,
          contains('android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING'),
        );
        expect(manifest, contains('android.permission.FOREGROUND_SERVICE"'));
        expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
        expect(
          manifest,
          contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
        );
        expect(manifest, contains('com.ambi.tiffe.TRACKING_ICON'));
      },
    );
    test(
      'service start uses the same type, restarts on boot and after swipe',
      () {
        final src = File('lib/live/order_tracking.dart').readAsStringSync();
        expect(src, contains('ForegroundServiceTypes.remoteMessaging'));
        expect(src, contains('autoRunOnBoot: true'));
        expect(src, contains('allowAutoRestart: true'));
        expect(src, contains('stopWithTask: false'));
        expect(src, contains("table: 'orders'"));
        expect(src, contains("column: 'customer_id'"));
      },
    );
    test('app starts tracking from the order stream and on resume', () {
      final app = File('lib/live/live_app.dart').readAsStringSync();
      expect('_syncTracking('.allMatches(app).length, greaterThanOrEqualTo(3));
      expect(app, contains('OrderTracking.listen('));
      final alerts = File('lib/live/order_alerts.dart').readAsStringSync();
      expect(alerts, contains('OrderTracking.watchdog('));
    });
  });
}
