from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '.')
def patch(path, old, new):
 p=root/path; s=p.read_text()
 assert s.count(old)==1, f'{path}: expected one patch target'
 p.write_text(s.replace(old,new))
if '1.0.51+51' in (root/'pubspec.yaml').read_text():
 print('v51 patch already applied'); sys.exit(0)
patch('pubspec.yaml','version: 1.0.50+50','version: 1.0.51+51')
patch('lib/live/bug_report.dart',"const appVersion = '1.0.50+50';","const appVersion = '1.0.51+51';")
patch('lib/live/order_alerts.dart',"import 'dart:convert';", "import 'dart:convert';\nimport 'dart:ui' show DartPluginRegistrant;\nimport 'package:flutter/widgets.dart';\nimport 'bug_report.dart';")
patch('lib/live/order_alerts.dart',"  Workmanager().executeTask((task, inputData) async {\n    try {\n      await OrderAlerts.backgroundCheck();\n    } catch (_) {}\n    return true;\n  });", "  WidgetsFlutterBinding.ensureInitialized();\n  DartPluginRegistrant.ensureInitialized();\n  Workmanager().executeTask((task, inputData) async {\n    try {\n      await OrderAlerts.backgroundCheck();\n      return true;\n    } catch (e) {\n      final prefs = await SharedPreferences.getInstance();\n      await prefs.setString('order_alert_last_result', 'Retry: ${errorKind(e)}');\n      BugLog.add('Order alerts retry: ${errorKind(e)}');\n      return false; // Android retries transient failures with backoff.\n    }\n  });")
patch('lib/live/order_alerts.dart',"android: AndroidInitializationSettings('@mipmap/ic_launcher'),","android: AndroidInitializationSettings('ic_tiffe_notification'),")
patch('lib/live/order_alerts.dart',"        priority: Priority.high,", "        priority: Priority.high,\n        icon: 'ic_tiffe_notification',")
start="  static Future<void> start() async {"
a=(root/'lib/live/order_alerts.dart').read_text(); i=a.index(start); j=a.index('  /// The app writes this',i)
a=a[:i]+'''  static Future<void> start({bool requestPermission = false}) async {
    if (!onAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    // Scheduling must not depend on a permission dialog completing.
    try {
      await Workmanager().initialize(orderAlertsDispatcher);
      await Workmanager().registerPeriodicTask(
        'tiffe-order-alerts', 'tiffe.order.alerts',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      await prefs.setInt('order_alert_scheduled_at', DateTime.now().millisecondsSinceEpoch);
      await prefs.remove('order_alert_schedule_error');
    } catch (e) {
      await prefs.setString('order_alert_schedule_error', errorKind(e));
      BugLog.add('Order alerts schedule: ${errorKind(e)}');
    }
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId, 'Order updates',
        description: 'Status changes for your Tiffe orders', importance: Importance.high,
      ));
      // Ask once automatically, or on the customer's explicit button tap.
      if (requestPermission || prefs.getBool('order_alert_permission_asked') != true) {
        await prefs.setBool('order_alert_permission_asked', true);
        await android?.requestNotificationsPermission();
      }
    } catch (e) {
      await prefs.setString('order_alert_last_result', 'Notification setup: ${errorKind(e)}');
      BugLog.add('Order alerts notification setup: ${errorKind(e)}');
    }
  }

  static Future<bool> canNotify() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (await android?.areNotificationsEnabled() != true) return false;
    final channels = await android?.getNotificationChannels();
    if (channels != null) {
      for (final channel in channels) {
        if (channel.id == _channelId && channel.importance == Importance.none) return false;
      }
    }
    return true;
  }

'''+a[j:]; (root/'lib/live/order_alerts.dart').write_text(a)
patch('lib/live/order_alerts.dart',"    } catch (_) {}\n  }\n\n  /// One background run", "    } catch (e) {\n      await prefs.setString('order_alert_last_result', 'Notification retry: ${errorKind(e)}');\n      rethrow;\n    }\n  }\n\n  /// One background run")
patch('lib/live/order_alerts.dart',"        await _init();\n        for (final e in now.entries)","        // Android can silently discard show() when app/channel permission is off.\n        // Preserve unseen changes instead of acknowledging a dropped notification.\n        if (!await canNotify()) {\n          await prefs.setString('order_alert_last_result', 'Notifications blocked: open Profile > Notifications');\n          return;\n        }\n        for (final e in now.entries)")
patch('lib/live/order_alerts.dart',"            if (was == null || was == e.value || text == null) continue;", "            if (was == null || was == e.value || text == null) continue;") if False else None
patch('lib/live/order_alerts.dart',"      final prefs = await SharedPreferences.getInstance();\n      final beat = prefs.getInt(_beatKey) ?? 0;", "      final prefs = await SharedPreferences.getInstance();\n      await prefs.reload();\n      await prefs.setInt('order_alert_last_run', DateTime.now().millisecondsSinceEpoch);\n      final beat = prefs.getInt(_beatKey) ?? 0;") if False else None
patch('lib/live/order_alerts.dart',"    final prefs = await SharedPreferences.getInstance();\n    final beat = prefs.getInt(_beatKey) ?? 0;", "    final prefs = await SharedPreferences.getInstance();\n    await prefs.reload();\n    await prefs.setInt('order_alert_last_run', DateTime.now().millisecondsSinceEpoch);\n    final beat = prefs.getInt(_beatKey) ?? 0;")
patch('lib/live/order_alerts.dart',"    if (DateTime.now().millisecondsSinceEpoch - beat < 90000) return;", "    if (DateTime.now().millisecondsSinceEpoch - beat < 90000) {\n      await prefs.setString('order_alert_last_result', 'Skipped while app is on screen');\n      return;\n    }")
patch('lib/live/order_alerts.dart',"    final uid = client?.auth.currentUser?.id;\n    if (client == null || uid == null) return;", "    if (client == null) throw StateError('Backend unavailable');\n    // Supabase v2 initialization does not wait for an expired session to refresh.\n    // Only the notification reader waits; sign-in/role/payment code is unchanged.\n    final session = await client.auth.getSession().timeout(const Duration(seconds: 20));\n    final uid = session?.user.id;\n    if (uid == null) {\n      await prefs.setString('order_alert_last_result', 'No saved customer session');\n      return;\n    }")
patch('lib/live/order_alerts.dart',"    await record(\n      prefs,", "    await prefs.setString('order_alert_last_result', 'Read server statuses');\n    await record(\n      prefs,")
patch('lib/live/live_app.dart',"import 'order_alerts.dart';", "import 'order_alerts.dart';\nimport 'notification_settings.dart';")
patch('lib/live/live_app.dart',"      unawaited(OrderAlerts.start());", "      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (mounted) unawaited(OrderAlerts.start());\n      });")
patch('lib/live/live_app.dart',"        unawaited(_alertsForeground(true));", "        unawaited(_alertsForeground(true));\n        unawaited(OrderAlerts.start());")
patch('lib/live/live_app.dart',"          showNotifications: false,", "          showNotifications: true,\n          onNotifications: () => Navigator.of(routeContext).push(\n            MaterialPageRoute<void>(builder: (_) => const NotificationSettingsPage()),\n          ),")
# Native customer channel is added without altering the legacy timer-disabled or update methods.
patch('android/app/src/main/kotlin/com/tiffe/tiffe/MainActivity.kt',"        registerUpdateChannel(flutterEngine)", "        registerUpdateChannel(flutterEngine)\n        OrderNotificationSettings.register(this, flutterEngine)")
print('Applied customer-only v51 patches')
