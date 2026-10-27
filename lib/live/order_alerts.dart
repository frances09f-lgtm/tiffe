import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'backend.dart';
import 'order_status.dart';

/// True on a real Android phone. False in tests and everywhere else.
bool get onAndroid {
  try {
    return Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

const orderAlertText = {
  'Confirmed': 'The kitchen accepted your order',
  'Preparing': 'Your meal is being prepared in the kitchen',
  'Packed': 'Your order is packed and ready for dispatch',
  'Out for Delivery': 'Your order is out for delivery',
  'Delivered': 'Your order was delivered',
};

/// Full error text for the diagnostics page: type, code and message.
String orderAlertErrorDetail(Object e) {
  String text;
  if (e is PlatformException) {
    text =
        'PlatformException code=${e.code} message=${e.message} details=${e.details}';
  } else if (e is PostgrestException) {
    text = 'PostgrestException code=${e.code} message=${e.message}';
  } else {
    text = '${e.runtimeType}: $e';
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 500 ? '${text.substring(0, 500)}...' : text;
}

/// Short, private error label that is safe to show on the diagnostics page.
String orderAlertErrorKind(Object e) {
  if (e is PostgrestException) return 'Server ${e.code ?? 'error'}';
  return e.runtimeType.toString();
}

/// What to do about the notification permission on this start.
enum PermissionStep { none, ask, openSettings }

/// Saved permission outcome. Replaces the old one-way
/// "order_alert_permission_asked" flag, which was set before (or without)
/// the Android dialog ever showing and then blocked the prompt for good.
const kPermissionStateKey = 'order_alert_permission_state';
const kOldPermissionFlag = 'order_alert_permission_asked';

/// Pure decision, so it can be tested without a phone:
/// - allowed: nothing to do.
/// - automatic start: ask once unless the customer already said no.
/// - repair button: ask again; after a recorded "no" Android may not show
///   the dialog any more, so open the app's notification settings instead.
PermissionStep permissionStep({
  required bool allowed,
  required String? state,
  required bool manual,
}) {
  if (allowed) return PermissionStep.none;
  if (state == 'denied') {
    return manual ? PermissionStep.openSettings : PermissionStep.none;
  }
  return PermissionStep.ask;
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
          'Retry: ${orderAlertErrorDetail(e)}',
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
  static const _settings = MethodChannel('tiffe/order_notification_settings');
  static const _statusKey = 'order_alert_status_';
  static const _beatKey = 'order_alert_fg_ms';
  static const _tokenKey = 'order_alert_rt';
  static const _tokenByKey = 'order_alert_rt_by';
  static const _resultKey = 'order_alert_last_result';
  static const _setupKey = 'order_alert_setup_result';
  static Future<void>? _starting;
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

  /// The first small icon Android accepts wins: the Tiffe icon, then the
  /// launcher icon that v50 used. A missing icon used to stop the setup.
  static const _icons = ['ic_tiffe_notification', '@mipmap/ic_launcher'];

  static Future<void> _init() async {
    if (_ready) return;
    Object? firstError;
    for (final icon in _icons) {
      try {
        await _plugin.initialize(
          settings: InitializationSettings(
            android: AndroidInitializationSettings(icon),
          ),
        );
        _ready = true;
        return;
      } catch (e) {
        firstError ??= e;
      }
    }
    throw firstError ?? StateError('Notification init failed');
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
  /// only when the customer taps the repair button. Calls run one at a
  /// time, and each step reports its own full error on the diagnostics page.
  static Future<void> start({bool requestPermission = false}) async {
    if (!onAndroid) return;
    while (_starting != null) {
      try {
        await _starting;
      } catch (_) {}
    }
    final run = _start(requestPermission);
    _starting = run;
    try {
      await run;
    } finally {
      if (identical(_starting, run)) _starting = null;
    }
  }

  static Future<void> _start(bool requestPermission) async {
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
        orderAlertErrorDetail(e),
      );
    }
    final problems = <String>[];
    try {
      await _init();
    } catch (e) {
      problems.add('init: ${orderAlertErrorDetail(e)}');
    }
    if (_ready) {
      final android = _android;
      try {
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Order updates',
            description: 'Status changes for your Tiffe orders',
            importance: Importance.high,
          ),
        );
      } catch (e) {
        problems.add('channel: ${orderAlertErrorDetail(e)}');
      }
      try {
        // The old flag could hide the prompt forever; it is not read any more.
        await prefs.remove(kOldPermissionFlag);
        final allowed = await android?.areNotificationsEnabled() == true;
        if (allowed) await prefs.setString(kPermissionStateKey, 'granted');
        final step = permissionStep(
          allowed: allowed,
          state: prefs.getString(kPermissionStateKey),
          manual: requestPermission,
        );
        if (step == PermissionStep.ask) {
          final granted = await android?.requestNotificationsPermission();
          final now = granted == true ||
              await android?.areNotificationsEnabled() == true;
          // Respect a "no": the app does not ask again by itself.
          await prefs.setString(kPermissionStateKey, now ? 'granted' : 'denied');
        } else if (step == PermissionStep.openSettings) {
          await _settings.invokeMethod<void>('notifications');
        }
      } catch (e) {
        problems.add('permission: ${orderAlertErrorDetail(e)}');
      }
    }
    try {
      final old = prefs.getString(_resultKey) ?? '';
      if (old.startsWith('Notification setup:')) await prefs.remove(_resultKey);
      if (problems.isEmpty) {
        await prefs.setString(_setupKey, 'OK');
      } else {
        await prefs.setString(_setupKey, problems.join(' | '));
      }
    } catch (_) {}
  }

  /// When the app leaves the screen, ask Android for one extra check in
  /// about 5 minutes on top of the 15-minute periodic one, so a status
  /// change soon after leaving is not left for the next periodic slot.
  /// Android may still delay it (battery saver); this is not instant push.
  static Future<void> checkSoon() async {
    if (!onAndroid) return;
    try {
      await Workmanager().registerOneOffTask(
        'tiffe-order-alerts-soon',
        'tiffe.order.alerts.soon',
        initialDelay: const Duration(minutes: 5),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
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
            String? showError;
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
              } catch (e) {
                showError ??= orderAlertErrorDetail(e);
                next[id] = before[id] ?? now[id]!;
              }
            }
            await prefs.setString(
              _resultKey,
              showError == null
                  ? 'Showed $shown alert(s)'
                  : 'Showed $shown alert(s). Show failed: $showError',
            );
          }
        }
      }
      await prefs.setString('$_statusKey$uid', jsonEncode(next));
    } catch (e) {
      try {
        await prefs.setString(
          _resultKey,
          'Alert error: ${orderAlertErrorDetail(e)}',
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
    // All columns: works before and after the tiffe-v56 database update
    // (awaiting_acceptance), so "Order placed" -> "Confirmed" is noticed.
    final rows = await client
        .from('orders')
        .select()
        .eq('customer_id', uid)
        .timeout(const Duration(seconds: 20));
    final list = [
      for (final o in List<Map<String, dynamic>>.from(rows))
        customerOrderView(o),
    ];
    await prefs.setString(_resultKey, 'Checked ${list.length} order(s)');
    await record(prefs, uid, list, notify: true);
    final token = client.auth.currentSession?.refreshToken;
    if (token != null && token != prefs.getString(_tokenKey)) {
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_tokenByKey, 'bg');
    }
  }
}
