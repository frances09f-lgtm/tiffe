import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'backend.dart';

/// True on a real Android phone. False in tests and everywhere else.
bool get onAndroid {
  try {
    return Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

const orderAlertText = {
  'Preparing': 'Your meal is being prepared in the kitchen',
  'Packed': 'Your order is packed and ready for dispatch',
  'Out for Delivery': 'Your order is out for delivery',
  'Delivered': 'Your order was delivered',
};

/// Runs in a background isolate about every 15 minutes, also when the app
/// is closed.
@pragma('vm:entry-point')
void orderAlertsDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await OrderAlerts.backgroundCheck();
    } catch (_) {}
    return true;
  });
}

/// Order status alerts for the customer app. There is no push server, so a
/// background check reads the customer's orders and shows a local
/// notification when a status changed since the last look.
class OrderAlerts {
  OrderAlerts._();

  static const _channelId = 'tiffe_order_status';
  static const _statusKey = 'order_alert_status_';
  static const _beatKey = 'order_alert_fg_ms';
  static const _tokenKey = 'order_alert_rt';
  static const _tokenByKey = 'order_alert_rt_by';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Order updates',
      channelDescription: 'Status changes for your Tiffe orders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Asks for the notification permission (Android 13+), creates the
  /// channel and schedules the background check.
  static Future<void> start() async {
    if (!onAndroid) return;
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Order updates',
          description: 'Status changes for your Tiffe orders',
          importance: Importance.high,
        ),
      );
    } catch (_) {}
    try {
      await Workmanager().initialize(orderAlertsDispatcher);
      await Workmanager().registerPeriodicTask(
        'tiffe-order-alerts',
        'tiffe.order.alerts',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}
  }

  /// The app writes this while it is on screen. The background check skips
  /// its run then, so only one side refreshes the saved login.
  static Future<void> heartbeat(SharedPreferences prefs, bool on) async {
    if (!onAndroid) return;
    try {
      await prefs.setInt(
        _beatKey,
        on ? DateTime.now().millisecondsSinceEpoch : 0,
      );
    } catch (_) {}
  }

  /// When the background check refreshed the login, the open app takes
  /// over the newer session instead of using its old one.
  static Future<void> adoptSession(
    SupabaseClient client,
    SharedPreferences prefs,
  ) async {
    if (!onAndroid) return;
    try {
      await prefs.reload();
      final saved = prefs.getString(_tokenKey);
      if (prefs.getString(_tokenByKey) != 'bg' || saved == null) return;
      await prefs.setString(_tokenByKey, 'fg');
      if (saved != client.auth.currentSession?.refreshToken) {
        await client.auth.setSession(saved);
      }
    } catch (_) {}
  }

  /// Remembers the app's own login when it goes to the background.
  static Future<void> saveSession(
    SupabaseClient client,
    SharedPreferences prefs,
  ) async {
    if (!onAndroid) return;
    try {
      final token = client.auth.currentSession?.refreshToken;
      if (token == null) return;
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_tokenByKey, 'fg');
    } catch (_) {}
  }

  static Map<String, String> _load(SharedPreferences prefs, String uid) {
    final raw = prefs.getString('$_statusKey$uid');
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in m.entries) e.key: e.value.toString()};
    } catch (_) {
      return {};
    }
  }

  /// Stores the statuses seen now. With [notify] it also shows a
  /// notification for every status that changed since the last look. The
  /// first look only stores a baseline.
  static Future<void> record(
    SharedPreferences prefs,
    String? uid,
    List<Map<String, dynamic>> rows, {
    required bool notify,
  }) async {
    if (!onAndroid || uid == null) return;
    try {
      await prefs.reload();
      final first = prefs.getString('$_statusKey$uid') == null;
      final before = _load(prefs, uid);
      final now = {
        for (final o in rows) o['id'].toString(): o['status'].toString(),
      };
      if (notify && !first) {
        await _init();
        for (final e in now.entries) {
          final was = before[e.key];
          final text = orderAlertText[e.value];
          if (was == null || was == e.value || text == null) continue;
          final id = e.key;
          final short = (id.length > 6 ? id.substring(0, 6) : id).toUpperCase();
          await _plugin.show(
            id: id.hashCode & 0x7fffffff,
            title: 'Tiffe order #$short',
            body: text,
            notificationDetails: _details,
          );
        }
      }
      await prefs.setString('$_statusKey$uid', jsonEncode(now));
    } catch (_) {}
  }

  /// One background run: read the orders and notify about changes.
  static Future<void> backgroundCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final beat = prefs.getInt(_beatKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - beat < 90000) return;
    final client = await BackendConfig.initialize();
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;
    final rows = await client
        .from('orders')
        .select('id,status')
        .eq('customer_id', uid)
        .timeout(const Duration(seconds: 20));
    await record(
      prefs,
      uid,
      List<Map<String, dynamic>>.from(rows),
      notify: true,
    );
    final token = client.auth.currentSession?.refreshToken;
    if (token != null && token != prefs.getString(_tokenKey)) {
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_tokenByKey, 'bg');
    }
  }
}
