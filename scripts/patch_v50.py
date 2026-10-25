#!/usr/bin/env python3
# Customer v50 source patch: unavailable bhajis are blocked at selection,
# and order status alerts reach the phone when the app is closed.
# Exact-string edits: every edit asserts it matched once.
import pathlib, sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')


def rd(p):
    return (ROOT / p).read_text(encoding='utf-8')


def wr(p, t):
    f = ROOT / p
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(t, encoding='utf-8')


def rep(t, old, new, n=1):
    c = t.count(old)
    assert c == n, 'expected %d match(es), found %d for: %s' % (n, c, old[:90])
    return t.replace(old, new)


# ---------------------------------------------------------------- menu_screen
p = 'lib/ui/gemini/menu_screen.dart'
t = rd(p)
t = rep(t, """  final bool special;
  const GMenuItem(
    this.title,
    this.blurb,
    this.price,
    this.tag,
    this.image, {
    this.special = false,
  });""", """  final bool special;

  /// Switched off by the kitchen: shown greyed out and cannot be picked.
  final bool unavailable;
  const GMenuItem(
    this.title,
    this.blurb,
    this.price,
    this.tag,
    this.image, {
    this.special = false,
    this.unavailable = false,
  });""")
t = rep(t, """  late final Map<int, Set<int>> _picks = {
    widget.initialCategory: {...widget.initialSelected},
  };""", """  late final Map<int, Set<int>> _picks = {
    widget.initialCategory: {
      for (final i in widget.initialSelected)
        if (i >= 0 &&
            i < widget.items[widget.initialCategory].length &&
            !widget.items[widget.initialCategory][i].unavailable)
          i,
    },
  };""")
t = rep(t, """  void _toggle(int i) => setState(() {
    if (_sel.contains(i)) {""", """  void _toggle(int i) => setState(() {
    if (_items[i].unavailable) return;
    if (_sel.contains(i)) {""")
t = rep(t, """  Widget _card(int idx, GMenuItem it) => Container(
    padding: const EdgeInsets.all(16),""", """  Widget _card(int idx, GMenuItem it) => it.unavailable
      ? Opacity(opacity: 0.5, child: _cardBody(idx, it))
      : _cardBody(idx, it);

  Widget _cardBody(int idx, GMenuItem it) => Container(
    padding: const EdgeInsets.all(16),""")
t = rep(t, """  Widget _gridCard(int idx, GMenuItem it) {
    final on = _sel.contains(idx);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (!on && _sel.length >= _max) ? null : () => _toggle(idx),""", """  Widget _gridCard(int idx, GMenuItem it) => it.unavailable
      ? Opacity(opacity: 0.5, child: _gridCardBody(idx, it))
      : _gridCardBody(idx, it);

  Widget _gridCardBody(int idx, GMenuItem it) {
    final on = _sel.contains(idx);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (it.unavailable || (!on && _sel.length >= _max))
          ? null
          : () => _toggle(idx),""")
t = rep(t, """    final on = _sel.contains(idx);
    final locked = !on && _sel.length >= _max;
    return GestureDetector(
      onTap: locked ? null : () => _toggle(idx),""", """    final on = _sel.contains(idx);
    final off = _items[idx].unavailable;
    final locked = off || (!on && _sel.length >= _max);
    return GestureDetector(
      onTap: locked ? null : () => _toggle(idx),""")
t = rep(t, "              on ? Icons.check : Icons.add,", "              off ? Icons.block : (on ? Icons.check : Icons.add),")
t = rep(t, "                  on ? 'Selected' : 'Select',", "                  off ? 'Unavailable' : (on ? 'Selected' : 'Select'),")
wr(p, t)

# ------------------------------------------------------------------- backend
p = 'lib/live/backend.dart'
t = rd(p)
t = rep(t, """  Stream<List<Map<String, dynamic>>> menu() =>
      client.from('menu_items').stream(primaryKey: ['id']).order('sort_order');
""", """  Stream<List<Map<String, dynamic>>> menu() =>
      client.from('menu_items').stream(primaryKey: ['id']).order('sort_order');

  /// One fresh read of the menu. The live stream can lag on a sleeping phone.
  Future<List<Map<String, dynamic>>> menuNow() async {
    final rows = await client
        .from('menu_items')
        .select()
        .order('sort_order')
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(rows);
  }
""")
wr(p, t)

# ------------------------------------------------------------------ live_app
p = 'lib/live/live_app.dart'
t = rd(p)
t = rep(t, "import 'bug_report.dart';\n", "import 'bug_report.dart';\nimport 'order_alerts.dart';\n")

# lifecycle + helpers (customer only)
t = rep(t, """  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) retryReports();
  }
""", """  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      retryReports();
      if (widget.role == null) {
        unawaited(_refreshMenuRows());
        unawaited(_alertsForeground(true));
      }
    } else if (widget.role == null &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      unawaited(_alertsForeground(false));
    }
  }

  Timer? _alertsBeat;

  /// Tells the background order check whether the app is on screen, so the
  /// two never refresh the saved login at the same time.
  Future<void> _alertsForeground(bool on) async {
    if (!onAndroid) return;
    _alertsBeat?.cancel();
    _alertsBeat = null;
    final prefs = widget.store.prefs;
    if (on) {
      await OrderAlerts.adoptSession(widget.backend.client, prefs);
      await OrderAlerts.heartbeat(prefs, true);
      _alertsBeat = Timer.periodic(
        const Duration(seconds: 30),
        (_) => OrderAlerts.heartbeat(prefs, true),
      );
    } else {
      await OrderAlerts.heartbeat(prefs, false);
      await OrderAlerts.saveSession(widget.backend.client, prefs);
    }
  }

  /// Customer only: re-reads the menu so availability is never stale.
  Future<void> _refreshMenuRows() async {
    if (widget.role != null || !onAndroid) return;
    try {
      final rows = await widget.backend.menuNow();
      if (mounted && rows.isNotEmpty) setState(() => menuRows = rows);
    } catch (_) {}
  }
""")
t = rep(t, """    if (widget.role == null) {
      for (final id
          in widget.store.prefs.getStringList('demo_orders') ??""", """    if (widget.role == null) {
      unawaited(OrderAlerts.start());
      unawaited(_alertsForeground(true));
      for (final id
          in widget.store.prefs.getStringList('demo_orders') ??""")
t = rep(t, """      if (mounted) setState(() => orderRows = rows);
      if (widget.role == null && mounted) loadItems();""", """      if (widget.role == null) {
        final life = WidgetsBinding.instance.lifecycleState;
        unawaited(
          OrderAlerts.record(
            widget.store.prefs,
            widget.backend.userId,
            rows,
            notify: life != null && life != AppLifecycleState.resumed,
          ),
        );
      }
      if (mounted) setState(() => orderRows = rows);
      if (widget.role == null && mounted) loadItems();""")
t = rep(t, "    flushTimer?.cancel();\n    menuListener?.cancel();", "    flushTimer?.cancel();\n    _alertsBeat?.cancel();\n    menuListener?.cancel();")
t = rep(t, "    void go(int i) => setState(() => tab = i);", """    void go(int i) {
      setState(() => tab = i);
      if (i == 1) unawaited(_refreshMenuRows());
    }""")
t = rep(t, """  Future<void> _orderBhajis(List<String> names) async {
    if (cfg == null) return;
""", """  Future<void> _orderBhajis(List<String> names) async {
    if (cfg == null) return;
    if (onAndroid) {
      await _refreshMenuRows();
      if (!mounted) return;
    }
""")
t = rep(t, """          items: [
            [
              for (final m in avail)
                GMenuItem(
                  m['name'] as String,
                  (m['description'] as String?) ?? '',
                  '',
                  '',
                  foodImage(m['name'] as String),
                ),
            ],""", """          items: [
            [
              for (final m in menuForPicker(menuRows))
                GMenuItem(
                  m['name'] as String,
                  (m['description'] as String?) ?? '',
                  '',
                  '',
                  foodImage(m['name'] as String),
                  unavailable: m['available'] != true,
                ),
            ],""")
t = rep(t, "class OrderSheet extends StatefulWidget {", """/// Menu rows for the picker: available first, unavailable last (greyed out).
List<Map<String, dynamic>> menuForPicker(List<Map<String, dynamic>> rows) => [
  ...rows.where((m) => m['available'] == true),
  ...rows.where((m) => m['available'] != true),
];

class OrderSheet extends StatefulWidget {""")

# OrderSheet state
t = rep(t, "  late final String idempotencyKey = newOrderKey();\n", """  late final String idempotencyKey = newOrderKey();
  late List<Map<String, dynamic>> _menu = widget.menuRows;

  /// Fresh read of the menu, so a bhaji switched off a moment ago is caught
  /// before checkout and not by the server at payment.
  Future<void> _refreshMenu() async {
    if (!onAndroid) return;
    try {
      final rows = await widget.backend.menuNow();
      if (rows.isNotEmpty) _menu = rows;
    } catch (_) {}
  }

  /// Removes bhajis the menu now shows as unavailable. Returns their names.
  List<String> _dropUnavailable() {
    final byId = {for (final m in _menu) m['id']: m};
    final gone = <String>[];
    for (final t in tiffins) {
      for (final id in t.toList()) {
        final m = byId[id];
        if (m != null && m['available'] != true) {
          t.remove(id);
          final n = (m['name'] as String?) ?? 'A bhaji';
          if (!gone.contains(n)) gone.add(n);
        }
      }
    }
    return gone;
  }

  String _goneMessage(List<String> gone) => gone.isEmpty
      ? 'A bhaji is unavailable now. Please pick again.'
      : '${gone.join(', ')} ${gone.length == 1 ? 'is' : 'are'} unavailable now. Please pick again.';

  /// Last check before the order is sent. False means the selection changed.
  Future<bool> _freshOk() async {
    await _refreshMenu();
    if (!mounted) return false;
    final gone = _dropUnavailable();
    if (gone.isEmpty) return true;
    setState(() {
      busy = false;
      error = _goneMessage(gone);
    });
    gToast(context, _goneMessage(gone));
    if (_firstIncomplete >= 0) unawaited(_pick(_firstIncomplete));
    return false;
  }

  /// The server still refuses an unavailable bhaji: refresh and ask again.
  Future<void> _afterFail(String e) async {
    if (!e.contains('Bhaji unavailable')) return;
    await _refreshMenu();
    if (!mounted) return;
    final gone = _dropUnavailable();
    setState(() => error = _goneMessage(gone));
    gToast(context, _goneMessage(gone));
    if (_firstIncomplete >= 0) unawaited(_pick(_firstIncomplete));
  }
""")
t = rep(t, """    super.initState();
    // No complete selection yet: send the customer straight to the Menu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tiffins[0].length < 2) _pick(0);
    });""", """    super.initState();
    final gone = _dropUnavailable();
    if (gone.isNotEmpty) error = _goneMessage(gone);
    // No complete selection yet: send the customer straight to the Menu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (gone.isNotEmpty) gToast(context, _goneMessage(gone));
      if (tiffins[0].length < 2) _pick(0);
    });""")
t = rep(t, """  Future<bool> _pick(int i) async {
    final avail = widget.menuRows.where((m) => m['available'] == true).toList();
""", """  Future<bool> _pick(int i) async {
    if (onAndroid) {
      await _refreshMenu();
      if (!mounted) return false;
      final gone = _dropUnavailable();
      if (gone.isNotEmpty) gToast(context, _goneMessage(gone));
    }
    final avail = menuForPicker(_menu);
""")
t = rep(t, """                  food.menu.any((f) => f.name == m['name'])
                      ? food.menu.firstWhere((f) => f.name == m['name']).image
                      : 'assets/food/hero.jpg',
                ),""", """                  food.menu.any((f) => f.name == m['name'])
                      ? food.menu.firstWhere((f) => f.name == m['name']).image
                      : 'assets/food/hero.jpg',
                  unavailable: m['available'] != true,
                ),""")
t = rep(t, """  Future<void> place() async {
    if (!_valid()) return;
""", """  Future<void> place() async {
    if (!_valid()) return;
    if (onAndroid && !await _freshOk()) return;
""")
t = rep(t, """        setState(() {
          busy = false;
          error = _clean(e);
        });
      }
    }""", """        setState(() {
          busy = false;
          error = _clean(e);
        });
        unawaited(_afterFail(_clean(e)));
      }
    }""")
t = rep(t, """  void payAndPlace(String total) {
    if (!_valid()) return;
    setState(() => error = null);""", """  Future<void> payAndPlace(String total) async {
    if (!_valid()) return;
    if (onAndroid && !await _freshOk()) return;
    if (!mounted) return;
    setState(() => error = null);""")
t = rep(t, """                onError: (e) {
                  nav.pop();
                  if (mounted) setState(() => error = e);
                },""", """                onError: (e) {
                  nav.pop();
                  if (mounted) {
                    setState(() => error = e);
                    unawaited(_afterFail(e));
                  }
                },""")
t = rep(t, """  String _names(Set<String> ids) => [
    for (final m in widget.menuRows)""", """  String _names(Set<String> ids) => [
    for (final m in _menu)""")
wr(p, t)

# ------------------------------------------------------- version, deps, gradle
p = 'pubspec.yaml'
t = rd(p)
t = rep(t, "version: 1.0.49+49", "version: 1.0.50+50")
t = rep(t, "  latlong2: ^0.10.1\n", "  latlong2: ^0.10.1\n  workmanager: ^0.10.10\n  flutter_local_notifications: ^22.3.3\n")
wr(p, t)
p = 'lib/live/bug_report.dart'
t = rd(p)
t = rep(t, "const appVersion = '1.0.49+49';", "const appVersion = '1.0.50+50';")
wr(p, t)
p = 'android/app/build.gradle.kts'
t = rd(p)
t = rep(t, """        targetCompatibility = JavaVersion.VERSION_17
    }""", """        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }""")
t = rep(t, """flutter {
    source = "../.."
}""", """flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}""")
wr(p, t)

# ------------------------------------------------------------- new files
wr('lib/live/order_alerts.dart', r'''import 'dart:convert';
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
          final short = (id.length > 6 ? id.substring(0, 6) : id)
              .toUpperCase();
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
''')

wr('test/bhaji_unavailable_test.dart', r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/menu_screen.dart';

void main() {
  testWidgets('an unavailable bhaji is greyed out and cannot be picked', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: GMenu(
          categories: const ['Today’s Menu'],
          items: const [
            [
              GMenuItem('Vatana', 'Peas', '', '', 'assets/food/batata.jpg'),
              GMenuItem(
                'Cabbage Bhaji',
                'Cabbage',
                '',
                '',
                'assets/food/aloo.jpg',
                unavailable: true,
              ),
              GMenuItem('Aloo Bhaji', 'Potato', '', '', 'assets/food/aloo.jpg'),
            ],
          ],
          showWeekly: false,
          maxPick: 8,
          initialSelected: const [1],
        ),
      ),
    );
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
    await t.tap(find.text('Unavailable'));
    await t.pump();
    expect(find.text('0 selected'), findsOneWidget);
    await t.tap(find.text('Select').first);
    await t.pump();
    expect(find.text('1 selected'), findsOneWidget);
  });
}
''')
print('patched')
