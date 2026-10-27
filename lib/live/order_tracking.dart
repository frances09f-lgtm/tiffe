import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';
import 'order_alerts.dart';
import 'order_status.dart';

/// Live order tracking while the app is closed.
///
/// There is no push server, so while the customer has an order that is not
/// finished yet, Tiffe keeps a small Android foreground service running
/// ("Tracking your order"). It listens to the customer's own orders over
/// Supabase Realtime (their own login, so the database's row rules apply)
/// and shows a notification for every status change. If Realtime is not
/// available it re-reads the orders every minute instead. The service stops
/// by itself when no unfinished order is left. The 15-minute background
/// check in [OrderAlerts] stays as a fallback.

/// Statuses after which nothing else happens to an order.
const kFinishedStatuses = {'Delivered', 'Cancelled', 'Failed', 'Refunded'};

/// True while an order can still change (placed, confirmed, preparing,
/// packed, out for delivery ...).
bool orderActive(Map o) {
  final status = o['status']?.toString() ?? '';
  return status.isNotEmpty && !kFinishedStatuses.contains(status);
}

List<Map<String, dynamic>> activeOrders(List<Map<String, dynamic>> rows) => [
  for (final o in rows)
    if (orderActive(o)) o,
];

/// Short order code as the customer sees it (#ABC123).
String orderShortCode(Object? id) {
  final s = id?.toString() ?? '';
  return (s.length > 6 ? s.substring(0, 6) : s).toUpperCase();
}

/// Whether the tracking service should run.
bool shouldTrack({
  required bool loggedIn,
  required bool notificationsAllowed,
  required List<Map<String, dynamic>> rows,
}) => loggedIn && notificationsAllowed && activeOrders(rows).isNotEmpty;

/// What the service should do with the tracker after a fresh look.
enum TrackerAction { start, keep, stop, none }

TrackerAction trackerAction({required bool running, required bool wanted}) {
  if (wanted) return running ? TrackerAction.keep : TrackerAction.start;
  return running ? TrackerAction.stop : TrackerAction.none;
}

/// Title and text of the quiet "Tracking your order" notification.
({String title, String text}) trackingNotice(List<Map<String, dynamic>> rows) {
  final active = activeOrders(rows);
  if (active.isEmpty) {
    return (title: 'Tiffe', text: 'Checking your orders');
  }
  if (active.length == 1) {
    final o = active.first;
    return (
      title: 'Tracking your order #${orderShortCode(o['id'])}',
      text: '${o['status']} · you will get a notification at every step',
    );
  }
  return (
    title: 'Tracking ${active.length} orders',
    text: 'You will get a notification at every step',
  );
}

/// How often the service re-reads the orders itself. With a working
/// Realtime connection this is only a safety net.
Duration trackerPollEvery({required bool realtimeOk}) =>
    realtimeOk ? const Duration(minutes: 5) : const Duration(minutes: 1);

bool trackerPollDue({
  required DateTime? lastPoll,
  required DateTime now,
  required bool realtimeOk,
}) =>
    lastPoll == null ||
    now.difference(lastPoll) >= trackerPollEvery(realtimeOk: realtimeOk);

/// True while the app is on screen (it writes a heartbeat every few
/// seconds). Then the app itself shows live status and owns the login.
bool appOnScreen(int beatMs, int nowMs) => nowMs - beatMs < 90000;

/// True when the service should refresh its login now (the app is not on
/// screen and the access token runs out within two minutes).
bool loginNeedsRefresh({required int? expiresAtSec, required int nowMs}) =>
    expiresAtSec == null || expiresAtSec * 1000 - nowMs < 120000;

/// One-time battery prompt: asked once, only while tracking is wanted and
/// Android still restricts Tiffe in the background.
bool shouldAskBattery({
  required bool exempt,
  required bool alreadyAsked,
  required bool tracking,
}) => tracking && !exempt && !alreadyAsked;

const kTrackerBeatKey = 'order_track_beat_ms';

/// Text of the one-time battery prompt.
const kBatteryPromptText =
    'Many phones (Xiaomi, Vivo, Oppo, Realme and others) close apps in the '
    'background to save battery. That can stop Tiffe from telling you when '
    'your order is accepted, out for delivery or delivered.\n\n'
    'Allow Tiffe to keep running in the background? It only stays active '
    'while you have an open order.';
const kSessionKey = 'order_alert_session';
const kBatteryAskedKey = 'order_track_battery_asked';
const kTrackerResultKey = 'order_track_last_result';

/// True when the tracking service wrote its heartbeat within 90 seconds;
/// the 15-minute check then leaves the work to it.
bool trackerAlive(int beatMs, int nowMs) => nowMs - beatMs < 90000;

@pragma('vm:entry-point')
void orderTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(OrderTrackingHandler());
}

/// App side: start, stop and talk to the service.
class OrderTracking {
  OrderTracking._();

  static bool _initialized = false;
  static bool _listening = false;
  static StreamSubscription<AuthState>? _authSub;

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tiffe_order_tracking',
        channelName: 'Order tracking',
        channelDescription:
            'Quiet notification while Tiffe tracks an unfinished order',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  /// Saves the app's login for the service (and the 15-minute check).
  static Future<void> shareSession(Session? session) async {
    if (!onAndroid || session == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kSessionKey, jsonEncode(session.toJson()));
      if (session.refreshToken != null) {
        await prefs.setString('order_alert_rt', session.refreshToken!);
        await prefs.setString('order_alert_rt_by', 'fg');
      }
    } catch (_) {}
  }

  /// Wires the app to the service: the app shares every new login with
  /// it, and takes over a login the service refreshed while the app was
  /// in the background, without refreshing again.
  static void listen(SupabaseClient client) {
    if (!onAndroid || _listening) return;
    _listening = true;
    try {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback((data) async {
        if (data is Map && data['session'] is String) {
          try {
            await client.auth.recoverSession(data['session'] as String);
          } catch (_) {}
        }
      });
      _authSub = client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.signedIn) {
          unawaited(shareSession(state.session));
        }
        if (state.event == AuthChangeEvent.signedOut) unawaited(stop());
      });
    } catch (_) {}
  }

  static Future<void> dispose() async {
    await _authSub?.cancel();
    _authSub = null;
    _listening = false;
  }

  /// Starts or stops the service for these orders. Only call it while the
  /// app is on screen: Android does not let a closed app start one.
  static Future<void> sync(
    SupabaseClient client,
    List<Map<String, dynamic>> rows,
  ) async {
    if (!onAndroid) return;
    try {
      _init();
      final session = client.auth.currentSession;
      final wanted = shouldTrack(
        loggedIn: session != null,
        notificationsAllowed: await OrderAlerts.canNotify(),
        rows: rows,
      );
      final running = await FlutterForegroundTask.isRunningService;
      final prefs = await SharedPreferences.getInstance();
      switch (trackerAction(running: running, wanted: wanted)) {
        case TrackerAction.start:
          await shareSession(session);
          final notice = trackingNotice(rows);
          final result = await FlutterForegroundTask.startService(
            serviceId: 4401,
            serviceTypes: const [ForegroundServiceTypes.remoteMessaging],
            notificationTitle: notice.title,
            notificationText: notice.text,
            notificationIcon: const NotificationIcon(
              metaDataName: 'com.ambi.tiffe.TRACKING_ICON',
            ),
            callback: orderTrackingCallback,
          );
          await prefs.setString(
            kTrackerResultKey,
            result is ServiceRequestFailure
                ? 'Start failed: ${orderAlertErrorDetail(result.error)}'
                : 'Tracking started',
          );
        case TrackerAction.keep:
          final notice = trackingNotice(rows);
          await FlutterForegroundTask.updateService(
            notificationTitle: notice.title,
            notificationText: notice.text,
          );
        case TrackerAction.stop:
          await FlutterForegroundTask.stopService();
          await prefs.setString(kTrackerResultKey, 'No open order: stopped');
        case TrackerAction.none:
          break;
      }
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          kTrackerResultKey,
          'Tracking error: ${orderAlertErrorDetail(e)}',
        );
      } catch (_) {}
    }
  }

  static Future<void> stop() async {
    if (!onAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  static Future<bool> isRunning() async {
    if (!onAndroid) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> batteryExempt() async {
    if (!onAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return true;
    }
  }

  /// Android's own "Allow Tiffe to run in the background?" dialog.
  static Future<bool> requestBatteryExemption() async {
    if (!onAndroid) return true;
    try {
      return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {
      try {
        return await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
      } catch (_) {
        return false;
      }
    }
  }

  /// Watchdog for the 15-minute check: restarts tracking when an order is
  /// still open but the service is gone (killed by the phone). Android
  /// allows this from the background only when Tiffe is exempt from
  /// battery optimization; otherwise it fails quietly and the 15-minute
  /// check carries on alone.
  static Future<void> watchdog(List<Map<String, dynamic>> rows) async {
    if (!onAndroid || activeOrders(rows).isEmpty) return;
    try {
      _init();
      if (await FlutterForegroundTask.isRunningService) return;
      if (!await OrderAlerts.canNotify()) return;
      final notice = trackingNotice(rows);
      await FlutterForegroundTask.startService(
        serviceId: 4401,
        serviceTypes: const [ForegroundServiceTypes.remoteMessaging],
        notificationTitle: notice.title,
        notificationText: notice.text,
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.ambi.tiffe.TRACKING_ICON',
        ),
        callback: orderTrackingCallback,
      );
    } catch (_) {}
  }
}

/// Runs inside the foreground service, also when the app is closed.
class OrderTrackingHandler extends TaskHandler {
  SupabaseClient? _client;
  RealtimeChannel? _channel;
  String? _uid;
  bool _realtimeOk = false;
  DateTime? _lastPoll;
  bool _busy = false;
  bool _stopping = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    await _tick(force: true);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_tick());
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _unsubscribe();
  }

  Future<void> _note(SharedPreferences prefs, String text) async {
    try {
      await prefs.setString(kTrackerResultKey, text);
    } catch (_) {}
  }

  Future<void> _tick({bool force = false}) async {
    if (_busy || _stopping) return;
    _busy = true;
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(kTrackerBeatKey, nowMs);
      if (appOnScreen(prefs.getInt('order_alert_fg_ms') ?? 0, nowMs)) {
        // The app shows live status itself and owns the login now.
        await _unsubscribe();
        await _note(prefs, 'Paused while the app is open');
        return;
      }
      final client = _client ??= await BackendConfig.initialize(
        autoRefresh: false,
      );
      if (client == null) {
        await _note(prefs, 'Backend unavailable');
        return;
      }
      final uid = await _login(client, prefs, nowMs);
      if (uid == null) {
        await _note(prefs, 'No saved customer login');
        await _stop(prefs);
        return;
      }
      if (_uid != uid) {
        await _unsubscribe();
        _uid = uid;
      }
      if (_channel == null) _subscribe(client, uid, prefs);
      if (force ||
          trackerPollDue(
            lastPoll: _lastPoll,
            now: DateTime.now(),
            realtimeOk: _realtimeOk,
          )) {
        await _check(client, uid, prefs);
      }
    } catch (e) {
      await _note(prefs, 'Tracker error: ${orderAlertErrorDetail(e)}');
    } finally {
      _busy = false;
    }
  }

  /// The customer's id with a valid login. Takes over a newer login the
  /// app saved, and refreshes the login itself only while the app is not
  /// on screen, so only one side ever refreshes it.
  Future<String?> _login(
    SupabaseClient client,
    SharedPreferences prefs,
    int nowMs,
  ) async {
    final auth = client.auth;
    final saved = prefs.getString(kSessionKey);
    final savedToken = prefs.getString('order_alert_rt');
    final by = prefs.getString('order_alert_rt_by');
    if (saved != null &&
        by == 'fg' &&
        savedToken != null &&
        savedToken != auth.currentSession?.refreshToken) {
      try {
        await auth.recoverSession(saved);
      } catch (_) {}
    }
    var session = auth.currentSession;
    if (session == null && savedToken != null) {
      final res = await auth.setSession(savedToken);
      session = res.session;
      await _shareRefreshed(prefs, session);
    } else if (session != null &&
        loginNeedsRefresh(expiresAtSec: session.expiresAt, nowMs: nowMs)) {
      final res = await auth.refreshSession().timeout(
        const Duration(seconds: 20),
      );
      session = res.session ?? auth.currentSession;
      await _shareRefreshed(prefs, session);
    }
    if (session != null) {
      try {
        await client.realtime.setAuth(session.accessToken);
      } catch (_) {}
    }
    return session?.user.id;
  }

  Future<void> _shareRefreshed(SharedPreferences prefs, Session? s) async {
    if (s == null) return;
    final json = jsonEncode(s.toJson());
    await prefs.setString(kSessionKey, json);
    if (s.refreshToken != null) {
      await prefs.setString('order_alert_rt', s.refreshToken!);
      await prefs.setString('order_alert_rt_by', 'bg');
    }
    // If the app is still alive in the background it takes this login over
    // without refreshing it again.
    FlutterForegroundTask.sendDataToMain({'session': json});
  }

  void _subscribe(SupabaseClient client, String uid, SharedPreferences prefs) {
    _realtimeOk = false;
    _channel = client
        .channel('tiffe-order-tracking-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: uid,
          ),
          callback: (_) {
            final c = _client;
            final id = _uid;
            if (c != null && id != null) unawaited(_check(c, id, prefs));
          },
        )
        .subscribe((status, [error]) {
          final ok = status == RealtimeSubscribeStatus.subscribed;
          if (ok && !_realtimeOk) {
            // Catch anything that changed while the connection was down.
            final c = _client;
            final id = _uid;
            if (c != null && id != null) unawaited(_check(c, id, prefs));
          }
          _realtimeOk = ok;
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            // Re-subscribed on the next tick; polling covers the gap.
            final dead = _channel;
            _channel = null;
            if (dead != null) unawaited(client.removeChannel(dead));
          }
        });
  }

  Future<void> _unsubscribe() async {
    final c = _client;
    final ch = _channel;
    _channel = null;
    _realtimeOk = false;
    if (c != null && ch != null) {
      try {
        await c.removeChannel(ch);
      } catch (_) {}
    }
  }

  bool _checking = false;

  /// Reads the orders, notifies about every change, updates the quiet
  /// notification and stops when no order is open any more.
  Future<void> _check(
    SupabaseClient client,
    String uid,
    SharedPreferences prefs,
  ) async {
    if (_checking || _stopping) return;
    _checking = true;
    try {
      _lastPoll = DateTime.now();
      final raw = await client
          .from('orders')
          .select()
          .eq('customer_id', uid)
          .timeout(const Duration(seconds: 20));
      final rows = [
        for (final o in List<Map<String, dynamic>>.from(raw))
          customerOrderView(o),
      ];
      await OrderAlerts.record(prefs, uid, rows, notify: true);
      if (activeOrders(rows).isEmpty) {
        await _note(prefs, 'All orders finished: stopped');
        await _stop(prefs);
        return;
      }
      final notice = trackingNotice(rows);
      await FlutterForegroundTask.updateService(
        notificationTitle: notice.title,
        notificationText: notice.text,
      );
      await _note(
        prefs,
        'Tracking ${activeOrders(rows).length} order(s), '
        '${_realtimeOk ? 'live' : 'checking every minute'}',
      );
    } catch (e) {
      await _note(prefs, 'Check failed: ${orderAlertErrorDetail(e)}');
    } finally {
      _checking = false;
    }
  }

  Future<void> _stop(SharedPreferences prefs) async {
    if (_stopping) return;
    _stopping = true;
    await _unsubscribe();
    try {
      await prefs.setInt(kTrackerBeatKey, 0);
    } catch (_) {}
    await FlutterForegroundTask.stopService();
  }
}
