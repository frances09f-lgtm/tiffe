import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/order_alerts.dart';
import 'package:tiffe/live/order_status.dart';

/// Customer 1.0.56: notification permission, background checks, "Order
/// placed" until the kitchen accepts, removed bhajis leave the menu.
void main() {
  group('notification permission', () {
    test('allowed: nothing to ask', () {
      for (final manual in [false, true]) {
        expect(
          permissionStep(allowed: true, state: null, manual: manual),
          PermissionStep.none,
        );
      }
    });

    test('never answered: the prompt is shown, also for old installs', () {
      // The old one-way flag is not part of the decision any more.
      expect(
        permissionStep(allowed: false, state: null, manual: false),
        PermissionStep.ask,
      );
      expect(
        permissionStep(allowed: false, state: 'granted', manual: false),
        PermissionStep.ask,
        reason: 'turned off later in settings: ask once more',
      );
    });

    test('a "no" is respected; the repair button opens settings', () {
      expect(
        permissionStep(allowed: false, state: 'denied', manual: false),
        PermissionStep.none,
      );
      expect(
        permissionStep(allowed: false, state: 'denied', manual: true),
        PermissionStep.openSettings,
      );
    });

    test('the old permission flag no longer gates the prompt', () {
      final code = File('lib/live/order_alerts.dart').readAsStringSync();
      expect(code, isNot(contains("getBool('order_alert_permission_asked')")));
      expect(code, contains('prefs.remove(kOldPermissionFlag)'));
      expect(code, contains("now ? 'granted' : 'denied'"));
    });

    test('settings page keeps the manual repair and settings buttons', () {
      final page = File(
        'lib/live/notification_settings.dart',
      ).readAsStringSync();
      expect(page, contains('Allow notifications and repair scheduling'));
      expect(page, contains('Open app notification settings'));
      expect(page, contains('You said no to notifications'));
      // Honest about timing: polling, not push.
      expect(page, contains('While you have an open order'));
    });
  });

  group('background checks outside the foreground', () {
    final code = File('lib/live/order_alerts.dart').readAsStringSync();
    test('periodic 15-minute check plus one check soon after leaving', () {
      expect(code, contains('frequency: const Duration(minutes: 15)'));
      expect(code, contains('registerOneOffTask('));
      expect(code, contains('initialDelay: const Duration(minutes: 5)'));
      final app = File('lib/live/live_app.dart').readAsStringSync();
      expect(app, contains('OrderAlerts.checkSoon()'));
    });

    test('background read works before and after the database update', () {
      // select() of every column: no hard dependency on new columns.
      expect(code, isNot(contains(".select('id,status')")));
      expect(code, contains('customerOrderView(o)'));
    });

    test('kitchen acceptance is a notified change', () {
      expect(orderAlertText['Confirmed'], 'The kitchen accepted your order');
      expect(orderAlertText[kOrderPlaced], isNull, reason: 'no alert on own order');
    });
  });

  group('Order placed until the kitchen accepts', () {
    test('legacy rows keep their status (no awaiting_acceptance column)', () {
      final o = {'id': 'a', 'status': 'Confirmed'};
      expect(customerOrderView(o)['status'], 'Confirmed');
      expect(
        customerOrderView({...o, 'awaiting_acceptance': null})['status'],
        'Confirmed',
      );
      expect(
        customerOrderView({...o, 'awaiting_acceptance': false})['status'],
        'Confirmed',
      );
    });

    test('new orders read "Order placed" until accepted', () {
      final o = {'id': 'a', 'status': 'Confirmed', 'awaiting_acceptance': true};
      final v = customerOrderView(o);
      expect(v['status'], kOrderPlaced);
      expect(o['status'], 'Confirmed', reason: 'source row is not modified');
      expect(customerOrderView({'id': 'b', 'status': 'Placed'})['status'], kOrderPlaced);
    });

    test('later statuses ignore the flag', () {
      for (final s in ['Preparing', 'Packed', 'Out for Delivery', 'Delivered', 'Cancelled']) {
        expect(
          customerOrderView({'status': s, 'awaiting_acceptance': true})['status'],
          s,
        );
      }
    });

    test('tracker and order list know the new first step', () {
      final app = File('lib/live/live_app.dart').readAsStringSync();
      expect(app, contains("kOrderPlaced => 'Order placed'"));
      expect(app, contains("'Confirmed': 'The kitchen accepted your order'"));
    });
  });

  group('removed bhajis', () {
    test('archived rows leave the menu, others stay', () {
      final rows = [
        {'id': '1', 'name': 'Batata', 'available': true},
        {'id': '2', 'name': 'Old', 'available': false, 'archived_at': '2026-10-20T00:00:00Z'},
        {'id': '3', 'name': 'Bhindi', 'available': false, 'archived_at': null},
      ];
      expect(activeMenu(rows).map((m) => m['id']), ['1', '3']);
    });

    test('both menu reads filter removed bhajis', () {
      final b = File('lib/live/backend.dart').readAsStringSync();
      expect(b, contains('.map(activeMenu)'));
      expect(b, contains('return activeMenu('));
    });
  });
}
