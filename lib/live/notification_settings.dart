import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/gemini/auth_screens.dart';
import 'order_alerts.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}
class _NotificationSettingsPageState extends State<NotificationSettingsPage> with WidgetsBindingObserver {
  static const channel = MethodChannel('tiffe/order_notification_settings');
  Map<dynamic, dynamic> device = {};
  String result = 'Checking…', scheduled = 'Unknown', lastRun = 'Not run yet';
  bool busy = false;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); refresh(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) refresh(); }
  String when(int? ms) => ms == null ? 'Not recorded yet' : DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toString().split('.').first;
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    Map<dynamic, dynamic> info = {};
    try { info = await channel.invokeMethod<Map<dynamic, dynamic>>('status') ?? {}; } catch (_) {}
    if (!mounted) return;
    setState(() {
      device = info;
      result = prefs.getString('order_alert_last_result') ?? 'No background result yet';
      scheduled = prefs.getString('order_alert_schedule_error') ?? when(prefs.getInt('order_alert_scheduled_at'));
      lastRun = when(prefs.getInt('order_alert_last_run'));
    });
  }
  Future<void> action(String method) async { try { await channel.invokeMethod<void>(method); } catch (_) {} await refresh(); }
  Future<void> enable() async {
    setState(() => busy = true);
    try { await OrderAlerts.start(requestPermission: true); await refresh(); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    appBar: AppBar(title: const Text('Notifications'), backgroundColor: GColors.card, foregroundColor: GColors.ink),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Text('Order updates', style: gText(22, w: FontWeight.w700, c: GColors.ink)),
      const SizedBox(height: 12),
      Text('Alerts use real status changes from the kitchen. This app never advances an order by time. Android background checks run at least 15 minutes apart and may be delayed by battery saving.', style: gText(14, c: GColors.charcoal, height: 1.4)),
      const SizedBox(height: 16),
      Text('Android API: ${device['sdk'] ?? 'Unknown'}\nPhone: ${device['manufacturer'] ?? 'Unknown'}\nApp notifications: ${device['enabled'] == true ? 'Allowed' : 'Blocked or unknown'}\nOrder channel: ${device['channelEnabled'] == true ? 'Allowed' : 'Blocked or not created'}\nBattery: ${device['batteryExempt'] == true ? 'Unrestricted' : 'Optimized or unknown'}\nBackground scheduled: $scheduled\nLast background run: $lastRun\nResult: $result', style: gText(14, c: GColors.ink, height: 1.6)),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : enable, child: Text(busy ? 'Please wait…' : 'Allow notifications and repair scheduling')),
      TextButton(onPressed: () => action('notifications'), child: const Text('Open app notification settings')),
      TextButton(onPressed: () => action('channel'), child: const Text('Open Order updates channel')),
      TextButton(onPressed: () => action('battery'), child: const Text('Open battery settings')),
      TextButton(onPressed: refresh, child: const Text('Refresh diagnostics')),
      const SizedBox(height: 12),
      Text('If Android or your phone stops Tiffe after swiping it away, set its battery use to Unrestricted and allow background activity or auto-start in phone settings. Force stop prevents background work until you reopen Tiffe. An app cannot override a denied notification permission or a blocked channel. No test or timer-based order messages are sent.', style: gText(13, c: GColors.grey, height: 1.4)),
    ]),
  );
}
