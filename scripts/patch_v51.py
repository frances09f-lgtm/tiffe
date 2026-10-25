from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '.')
def patch(path, old, new):
 p=root/path; s=p.read_text()
 assert s.count(old)==1, f'{path}: expected one patch target: {old[:60]!r}'
 p.write_text(s.replace(old,new))
if '1.0.51+51' in (root/'pubspec.yaml').read_text():
 print('v51 patch already applied'); sys.exit(0)
patch('pubspec.yaml','version: 1.0.50+50','version: 1.0.51+51')
patch('lib/live/bug_report.dart',"const appVersion = '1.0.50+50';","const appVersion = '1.0.51+51';")
patch('lib/live/live_app.dart',"import 'order_alerts.dart';","import 'order_alerts.dart';\nimport 'notification_settings.dart';")
patch('lib/live/live_app.dart',"        unawaited(_refreshMenuRows());\n        unawaited(_alertsForeground(true));","        unawaited(_refreshMenuRows());\n        unawaited(_alertsForeground(true));\n        unawaited(OrderAlerts.start());")
patch('lib/live/live_app.dart',"          showNotifications: false,","          showNotifications: true,\n          onNotifications: () => Navigator.of(routeContext).push(\n            MaterialPageRoute<void>(builder: (_) => const NotificationSettingsPage()),\n          ),")
patch('android/app/src/main/kotlin/com/tiffe/tiffe/MainActivity.kt',"        registerUpdateChannel(flutterEngine)\n","        registerUpdateChannel(flutterEngine)\n        OrderNotificationSettings.register(this, flutterEngine)\n")
print('Applied customer-only v51 patches')
