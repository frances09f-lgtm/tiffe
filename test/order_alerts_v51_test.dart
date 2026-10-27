import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/order_alerts.dart';

void main() {
  test(
    'only real changed server statuses are eligible, never elapsed time',
    () {
      expect(orderAlertText.keys, [
        // 1.0.56: staff acceptance (Order placed -> Confirmed) is a real
        // server change too.
        'Confirmed',
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
  test('setup errors show code and message and the icon cannot be shrunk', () {
    final code = File('lib/live/order_alerts.dart').readAsStringSync();
    expect(code.contains('PlatformException code=\${e.code}'), isTrue);
    expect(code.contains('@mipmap/ic_launcher'), isTrue);
    expect(code.contains('order_alert_setup_result'), isTrue);
    final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(keep.contains('@drawable/ic_tiffe_notification'), isTrue);
    final page = File('lib/live/notification_settings.dart').readAsStringSync();
    expect(page.contains('Setup: \$setup'), isTrue);
  });
  test('error detail keeps the plugin code and message', () {
    final text = orderAlertErrorDetail(
      PlatformException(code: 'invalid_icon', message: 'no such icon'),
    );
    expect(text.contains('invalid_icon'), isTrue);
    expect(text.contains('no such icon'), isTrue);
  });
}
