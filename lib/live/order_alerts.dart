import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
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

/// Short, private error label that is safe to show on the diagnostics page.
String orderAlertErrorKind(Object e) {
  if (e is PostgrestException) return 'Server ${e.code ?? 'error'}';
  return e.runtimeType.toString();
}

/// Runs in a background isolate about every 15 minutes, also when the app
/// is closed. Android decides the exact time.
@pragma('vm:entry-point')
void orderAlertsDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, inputData) async {
    try {
      await OrderAlerts.backgroundCheck();
      return true;
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'order_alert_last_result',
          'Retry: ${orderAlertErrorKind(e)}',
        );
      } catch (_) {}
      return false; // Android retries transient failures with backoff.
    }
  });
}

/// Order status alerts for the customer app. There is no push server, so a
/// background check reads the customer's orders and shows a local
/// notification when the server status changed since the last look. Only
/// statuses written by staff are read; nothing here advances an order.
class OrderAlerts {
  OrderAlerts._();

  static const _channelId = 'tiffe_order_status';
  static const _statusKey = 'order_alert_status_';
  static const _beatKey = 'order_alert_fg_ms';
  static const _tokenKey = 'order_alert_rt';
  static const _tokenByKey = 'order_alert_rt_by';
  static const _resultKey = 'order_alert_last_result';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Order updates',
      channelDescription: 'Status changes for your Tiffe orders',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_tiffe_notification',
    ),
  );

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_tiffe_notification'),
      ),
    );
    _ready = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// True when Android will really show an order notification.
  static Future<bool> canNotify() async {
    await _init();
    final android = _android;
    if (android == null) return false;
    if (await android.areNotificationsEnabled() != true) return false;
    final channels = await android.getNotificationChannels();
    if (channels != null) {
      for (final channel in channels) {
        if (channel.id == _channelId && channel.importance == Importance.none) {
          return false;
        }
      }
    }
    return true;
  }

  /// Schedules the background check, creates the channel and asks for the
  /// notification permission (Android 13+). Scheduling never waits for the
  /// permission dialog. The permission is asked once on its own and again
  /// only when the customer taps the repair button.
  static Future<void> start({bool requestPermission = false}) async {
    if (!onAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      await Workmanager().initialize(orderAlertsDispatcher);
      await Workmanager().registerPeriodicTask(
        'tiffe-order-alerts',
        'tiffe.order.alerts',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      await prefs.setInt(
        'order_alert_scheduled_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.remove('order_alert_schedule_error');
    } catch (e) {
      await prefs.setString(
        'order_alert_schedule_error',
        orderAlertErrorKind(e),
      );
    }
    try {
      await _init();
      final android = _android;
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Order updates',
          description: 'Status changes for your Tiffe orders',
          importance: Importance.high,
        ),
      );
      if (requestPermission || prefs.getBool('order_alert_permission_asked') != true) {
        await prefs.setBool('order_alert_permission_asked', true);
        await android?.requestNotificationsPermission();
      }
    } catch (e) {
      await prefs.setString(
        _resultKey,
        'Notification setup: ${orderAlertErrorKind(e)}',
      );
    }
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
  /// first look only stores a baseline. A change that Android would not
  /// show (permission or channel off) is kept unseen so it can still be
  /// delivered after the customer fixes the setting.
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
      final next = Map<String, String>.from(now);
      if (notify && !first) {
        final pending = <String, String>{};
        for (final e in now.entries) {
          final was = before[e.key];
          final text = orderAlertText[e.value];
          if (was == null || was == e.value || text == null) continue;
          pending[e.key] = text;
        }
        if (pending.isNotEmpty) {
          if (!await canNotify()) {
            for (final key in pending.keys) {
              next[key] = before[key] ?? now[key]!;
            }
            await prefs.setString(
              _resultKey,
              'Notifications blocked: open Profile > Notifications',
            );
          } else {
            var shown = 0;
            for (final e in pending.entries) {
              final id = e.key;
              final short = (id.length > 6 ? id.substring(0, 6) : id)
                  .toUpperCase();
              try {
                await _plugin.show(
                  id: id.hashCode & 0x7fffffff,
                  title: 'Tiffe order #$short',
                  body: e.value,
                  notificationDetails: _details,
                );
                shown++;
              } catch (_) {
                next[id] = before[id] ?? now[id]!;
              }
            }
            await prefs.setString(_resultKey, 'Showed $shown alert(s)');
          }
        }
      }
      await prefs.setString('$_statusKey$uid', jsonEncode(next));
    } catch (e) {
      try {
        await prefs.setString(
          _resultKey,
          'Alert error: ${orderAlertErrorKind(e)}',
        );
      } catch (_) {}
    }
  }

  /// The saved customer id. Supabase starts without waiting for an expired
  /// session to refresh, so this waits for it (and refreshes it) before
  /// giving up. Only the notification reader does this.
  static Future<String?> _customerId(SupabaseClient client) async {
    for (var i = 0; i < 10 && client.auth.currentSession == null; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    var session = client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      final fresh = await client.auth.refreshSession().timeout(
        const Duration(seconds: 20),
      );
      session = fresh.session ?? client.auth.currentSession;
    }
    return session?.user.id;
  }

  /// One background run: read the orders and notify about changes.
  static Future<void> backgroundCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setInt(
      'order_alert_last_run',
      DateTime.now().millisecondsSinceEpoch,
    );
    final beat = prefs.getInt(_beatKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - beat < 90000) {
      await prefs.setString(_resultKey, 'Skipped while the app is open');
      return;
    }
    final client = await BackendConfig.initialize();
    if (client == null) throw StateError('Backend unavailable');
    final uid = await _customerId(client);
    if (uid == null) {
      await prefs.setString(_resultKey, 'No saved customer login');
      return;
    }
    final rows = await client
        .from('orders')
        .select('id,status')
        .eq('customer_id', uid)
        .timeout(const Duration(seconds: 20));
    final list = List<Map<String, dynamic>>.from(rows);
    await prefs.setString(_resultKey, 'Checked ${list.length} order(s)');
    await record(prefs, uid, list, notify: true);
    final token = client.auth.currentSession?.refreshToken;
    if (token != null && token != prefs.getString(_tokenKey)) {
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_tokenByKey, 'bg');
    }
  }
}
