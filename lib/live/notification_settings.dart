import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/gemini/auth_screens.dart';
import 'order_alerts.dart';
import 'order_tracking.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('tiffe/order_notification_settings');
  Map<dynamic, dynamic> device = {};
  String result = 'Checking…', scheduled = 'Unknown', lastRun = 'Not run yet';
  String tracking = 'Not started yet';
  String setup = 'Not run yet', statusError = '';
  String? permission;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  String when(int? ms) => ms == null
      ? 'Not recorded yet'
      : DateTime.fromMillisecondsSinceEpoch(ms)
            .toLocal()
            .toString()
            .split('.')
            .first;
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    Map<dynamic, dynamic> info = {};
    String readError = '';
    try {
      info = await channel.invokeMethod<Map<dynamic, dynamic>>('status') ?? {};
    } catch (e) {
      readError = orderAlertErrorDetail(e);
    }
    if (!mounted) return;
    setState(() {
      device = info;
      statusError = readError;
      setup = prefs.getString('order_alert_setup_result') ?? 'Not run yet';
      result =
          prefs.getString('order_alert_last_result') ??
          'No background result yet';
      scheduled =
          prefs.getString('order_alert_schedule_error') ??
          when(prefs.getInt('order_alert_scheduled_at'));
      lastRun = when(prefs.getInt('order_alert_last_run'));
      permission = prefs.getString(kPermissionStateKey);
      tracking = prefs.getString(kTrackerResultKey) ?? 'Not started yet';
    });
  }

  Future<void> action(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } catch (e) {
      if (mounted) setState(() => statusError = orderAlertErrorDetail(e));
      return;
    }
    await refresh();
  }

  Future<void> enable() async {
    setState(() => busy = true);
    try {
      await OrderAlerts.start(requestPermission: true);
      await refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    appBar: AppBar(
      title: const Text('Notifications'),
      backgroundColor: GColors.card,
      foregroundColor: GColors.ink,
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Order updates',
          style: gText(22, w: FontWeight.w700, c: GColors.ink),
        ),
        const SizedBox(height: 12),
        Text(
          'Alerts use real status changes from the kitchen. This app never advances an order by time. While you have an open order, Tiffe shows a quiet "Tracking your order" notification and gets every status change live, also when the app is closed, so you hear about each step right away. It stops by itself once the order is delivered. If your phone stops it, Tiffe still checks about every 15 minutes.',
          style: gText(14, c: GColors.charcoal, height: 1.4),
        ),
        const SizedBox(height: 16),
        SelectableText(
          'Android API: ${device['sdk'] ?? 'Unknown'}\nPhone: ${device['manufacturer'] ?? 'Unknown'}\nApp notifications: ${device['enabled'] == true ? 'Allowed' : 'Blocked or unknown'}\nOrder channel: ${device['channelEnabled'] == true ? 'Allowed' : 'Blocked or not created'}\nBattery: ${device['batteryExempt'] == true ? 'Unrestricted' : 'Optimized or unknown'}\nBackground scheduled: $scheduled\nLast background run: $lastRun\nSetup: $setup\nResult: $result\nLive tracking: $tracking${statusError.isEmpty ? '' : '\nSettings read: $statusError'}',
          style: gText(14, c: GColors.ink, height: 1.6),
        ),
        if (device['enabled'] != true && permission == 'denied') ...[
          const SizedBox(height: 12),
          Text(
            'You said no to notifications, so Tiffe will not ask again by itself. Tap the button below to turn them on in Android settings.',
            style: gText(14, w: FontWeight.w600, c: GColors.ink, height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : enable,
          child: Text(
            busy ? 'Please wait…' : 'Allow notifications and repair scheduling',
          ),
        ),
        TextButton(
          onPressed: () => action('notifications'),
          child: const Text('Open app notification settings'),
        ),
        TextButton(
          onPressed: () => action('channel'),
          child: const Text('Open Order updates channel'),
        ),
        TextButton(
          onPressed: () async {
            await OrderTracking.requestBatteryExemption();
            await refresh();
          },
          child: const Text('Let Tiffe run in the background'),
        ),
        TextButton(
          onPressed: refresh,
          child: const Text('Refresh diagnostics'),
        ),
        const SizedBox(height: 12),
        Text(
          'If Android or your phone stops Tiffe after swiping it away, set its battery use to Unrestricted and allow background activity or auto-start in phone settings. Force stop prevents background work until you reopen Tiffe. An app cannot override a denied notification permission or a blocked channel. No test or timer-based order messages are sent.',
          style: gText(13, c: GColors.grey, height: 1.4),
        ),
      ],
    ),
  );
}
