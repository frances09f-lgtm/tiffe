import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/order_alerts.dart';

void main() {
  test(
    'only real changed server statuses are eligible, never elapsed time',
    () {
      expect(orderAlertText.keys, [
        'Preparing',
        'Packed',
        'Out for Delivery',
        'Delivered',
      ]);
      final code = File('lib/live/order_alerts.dart').readAsStringSync();
      expect(
        code.contains('was == null || was == e.value || text == null'),
        isTrue,
      );
      expect(code.contains(".from('orders')"), isTrue);
      expect(code.contains('.update('), isFalse);
      expect(code.contains('.rpc('), isFalse);
      expect(code.contains('Timer.periodic'), isFalse);
    },
  );
  test(
    'worker retries errors and preserves notifications blocked by Android',
    () {
      final code = File('lib/live/order_alerts.dart').readAsStringSync();
      expect(code.contains('return false; // Android retries'), isTrue);
      expect(code.contains('if (!await canNotify())'), isTrue);
      expect(code.contains('ExistingPeriodicWorkPolicy.update'), isTrue);
      expect(code.contains('NetworkType.connected'), isTrue);
      expect(code.contains('DartPluginRegistrant.ensureInitialized()'), isTrue);
      expect(code.contains('auth.refreshSession()'), isTrue);
      expect(code.contains('ic_tiffe_notification'), isTrue);
    },
  );
  test('native diagnostics offer settings without scheduled fake messages', () {
    final code = File(
      'android/app/src/main/kotlin/com/tiffe/tiffe/OrderNotificationSettings.kt',
    ).readAsStringSync();
    expect(code.contains('areNotificationsEnabled'), isTrue);
    expect(code.contains('isIgnoringBatteryOptimizations'), isTrue);
    expect(code.contains('ACTION_CHANNEL_NOTIFICATION_SETTINGS'), isTrue);
    expect(code.contains('.notify('), isFalse);
  });
}
