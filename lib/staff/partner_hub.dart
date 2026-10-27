// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../live/backend.dart';
import 'staff_update.dart';

/// Staff appearance. Dark by default; the hub header toggle flips this and
/// the choice persists in shared preferences.
final ValueNotifier<bool> staffDark = ValueNotifier<bool>(true);

const _kStaffDarkPref = 'staff_dark_mode';

Future<void> loadStaffTheme() async {
  final p = await SharedPreferences.getInstance();
  staffDark.value = p.getBool(_kStaffDarkPref) ?? true;
}

Future<void> setStaffDark(bool v) async {
  staffDark.value = v;
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kStaffDarkPref, v);
}

Color get _forest =>
    staffDark.value ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);
Color get _cream =>
    staffDark.value ? const Color(0xFF121212) : const Color(0xFFFBF9F4);
Color get _creamMuted =>
    staffDark.value ? const Color(0xFF383838) : const Color(0xFFDDD5C3);
const _saffron = Color(0xFFFC8019);
Color get _muted =>
    staffDark.value ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
Color get _surface =>
    staffDark.value ? _surface : const Color(0xFFFFFFFF);
Color get _headerBg =>
    staffDark.value ? _headerBg : const Color(0xFFFFFFFF);
Color get _okBright =>
    staffDark.value ? _okBright : const Color(0xFF059669);
Color get _dangerBg =>
    staffDark.value ? _dangerBg : const Color(0xFFFEE2E2);
Color get _dangerFg =>
    staffDark.value ? _dangerFg : const Color(0xFFB91C1C);
Color get _liveBg =>
    staffDark.value ? _liveBg : const Color(0xFFD1FAE5);
const _font = 'PlusJakartaSans';

/// Snapshot of everything the admin website shows. Built from the same
/// Supabase tables as the phone app.
class AdminData {
  final List<Map<String, dynamic>> orders, subs, customers, menu, riders;
  final String today;
  const AdminData({
    required this.orders,
    required this.subs,
    required this.customers,
    required this.menu,
    required this.riders,
    required this.today,
  });

  Map<String, String> get names => {
    for (final c in customers) c['id'] as String: (c['name'] as String?) ?? '',
  };
  String nameOf(Map o) {
    final n =
        names[o['customer_id']] ??
        ((o['address_snapshot'] as Map?)?['name'] as String?) ??
        '';
    return n.trim().isEmpty ? 'Customer' : n;
  }

  String riderName(Object? id) {
    if (id == null) return 'Unassigned';
    for (final r in riders) {
      if (r['user_id'] == id) {
        final n = (r['name'] as String?) ?? '';
        return n.trim().isEmpty ? 'Rider' : n;
      }
    }
    return 'Rider';
  }

  List<Map<String, dynamic>> get todayOrders => [
    for (final o in orders)
      if (o['delivery_date'] == today) o,
  ];

  /// Open orders dated after today. The customer app dates orders placed after
  /// the daily cut-off for tomorrow, so the kitchen must see them early.
  List<Map<String, dynamic>> get upcomingOrders =>
      [
        for (final o in orders)
          if ('${o['delivery_date']}'.compareTo(today) > 0 &&
              !const {
                'Delivered',
                'Cancelled',
                'Failed',
                'Refunded',
              }.contains(o['status']))
            o,
      ]..sort((a, b) {
        final day = '${a['delivery_date']}'.compareTo('${b['delivery_date']}');
        if (day != 0) return day;
        return '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}');
      });
  /// IST calendar day (yyyy-MM-dd) an order was placed on.
  static String placedDay(Map o) {
    final t = DateTime.tryParse('${o['created_at'] ?? ''}');
    if (t == null) return '';
    return t
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String()
        .substring(0, 10);
  }

  /// All Orders "Today": delivery is today or the order was placed today.
  List<Map<String, dynamic>> get todayFilterOrders => [
    for (final o in orders)
      if (o['delivery_date'] == today || placedDay(o) == today) o,
  ];

  /// Kitchen queue for one status, whatever the delivery date. Soonest
  /// delivery first, newest placed first within a day.
  List<Map<String, dynamic>> queueFor(String status) =>
      [
        for (final o in orders)
          if (o['status'] == status) o,
      ]..sort((a, b) {
        final day = '${a['delivery_date']}'.compareTo('${b['delivery_date']}');
        if (day != 0) return day;
        return '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}');
      });

  /// Later-dated orders that are not in a kitchen queue.
  List<Map<String, dynamic>> get laterOrders => [
    for (final o in upcomingOrders)
      if (!const {'Confirmed', 'Preparing', 'Packed'}.contains(o['status'])) o,
  ];

  bool isActive(Map s) =>
      s['verified'] == true &&
      (s['starts_on'] as String).compareTo(today) <= 0 &&
      (s['ends_on'] as String).compareTo(today) >= 0;
  int get activeSubscribers =>
      {for (final s in subs.where(isActive)) s['customer_id']}.length;
  int get revenueTodayPaise => todayOrders
      .where((o) => o['payment_status'] == 'verified')
      .fold(0, (a, o) => a + ((o['total_paise'] as num?)?.toInt() ?? 0));
  int get ridersOut => {
    for (final o in orders)
      if (o['status'] == 'Out for Delivery' && o['assigned_to'] != null)
        o['assigned_to'],
  }.length;
}

String rupees(num paise) => '₹${(paise / 100).toStringAsFixed(0)}';

class PartnerHub extends StatefulWidget {
  final TiffeBackend backend;
  final String role;

  /// Optional read seam for isolated tests; production still uses the session's RLS.
  final Future<List<Map<String, dynamic>>> Function()? readOrders;
  const PartnerHub({
    super.key,
    required this.backend,
    required this.role,
    this.readOrders,
  });
  @override
  State<PartnerHub> createState() => _PartnerHubState();
}

class _PartnerHubState extends State<PartnerHub> {
  int screen = 5;
  List<Map<String, dynamic>> orders = [], menu = [];
  List<Map<String, dynamic>> subs = [], customers = [], riders = [];
  StreamSubscription? os, ms;
  String query = '';
  List<Map<String, dynamic>> items = [];
  String manager = 'Staff';
  String? itemsError;
  Timer? ordersPoll;
  Future<void>? ordersRequest;
  String? ordersError;
  bool ordersRefreshing = false;
  int ordersRevision = 0;

  @override
  void initState() {
    super.initState();
    loadStaffTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptStaffUpdate(context);
    });
    os = widget.backend.orders().listen(
      acceptOrders,
      onError: (Object error, StackTrace stack) => orderLoadFailed(),
    );
    // Realtime remains the fast path. A separate SELECT recovers a stalled socket.
    ordersPoll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshOrders(),
    );
    ms = widget.backend.menu().listen((r) => setState(() => menu = r));
    reload();
  }

  void orderLoadFailed() {
    if (!mounted) return;
    setState(
      () => ordersError = 'Orders could not load. The list may be out of date. Tap Refresh to retry.',
    );
  }

  Future<void> acceptOrders(List<Map<String, dynamic>> rows) async {
    if (!mounted) return;
    ordersRevision++;
    setState(() {
      orders = rows;
      ordersError = null;
    });
    try {
      final got = await widget.backend.orderItems(
        rows.map((o) => o['id'] as String).toList(),
      );
      if (mounted)
        setState(() {
          items = got;
          itemsError = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => itemsError =
              'Bhaji counts could not be loaded. Refresh to retry.',
        );
    }
  }

  Future<void> refreshOrders() {
    if (!mounted) return Future.value();
    // Timer, button and pull-to-refresh share one in-flight request.
    return ordersRequest ??= readOrdersOnce().whenComplete(() {
      ordersRequest = null;
    });
  }

  Future<void> readOrdersOnce() async {
    setState(() => ordersRefreshing = true);
    final revision = ordersRevision;
    try {
      final read =
          widget.readOrders ??
          () async {
            final rows = await widget.backend.client
                .from('orders')
                .select()
                .order('created_at', ascending: false);
            return List<Map<String, dynamic>>.from(rows);
          };
      final rows = await read().timeout(const Duration(seconds: 10));
      // Do not overwrite a newer realtime snapshot with an older SELECT result.
      if (mounted && revision == ordersRevision) await acceptOrders(rows);
    } catch (_) {
      orderLoadFailed();
    } finally {
      if (mounted) setState(() => ordersRefreshing = false);
    }
  }

  Future<void> reload() async {
    try {
      final p = await widget.backend.profile();
      if (mounted && p != null)
        setState(
          () => manager = (p['name'] as String?)?.trim().isNotEmpty == true
              ? p['name']
              : 'Staff',
        );
    } catch (_) {}
    try {
      final r = await Future.wait([
        widget.role == 'owner'
            ? widget.backend.allSubscriptions()
            : Future.value(<Map<String, dynamic>>[]),
        widget.role == 'owner'
            ? widget.backend.customers()
            : Future.value(<Map<String, dynamic>>[]),
        widget.role == 'owner'
            ? widget.backend.deliveryStaff()
            : Future.value(<Map<String, dynamic>>[]),
        widget.backend.orderItems(
          orders.map((o) => o['id'] as String).toList(),
        ),
      ]);
      if (mounted) {
        setState(() {
          subs = r[0];
          customers = r[1];
          riders = r[2];
          items = r[3];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    ordersPoll?.cancel();
    os?.cancel();
    ms?.cancel();
    super.dispose();
  }

  AdminData get data {
    final n = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return AdminData(
      orders: orders,
      subs: subs,
      customers: customers,
      menu: menu,
      riders: riders,
      today: n.toIso8601String().substring(0, 10),
    );
  }

  static const nav = [
    (Icons.dashboard_outlined, 'Dashboard & Overview'),
    (Icons.local_shipping_outlined, 'All Orders'),
    (Icons.event_repeat_outlined, 'Subscriptions'),
    (Icons.restaurant_menu_outlined, 'Menu & Item Status'),
    (Icons.people_outline, 'Customers'),
    (Icons.soup_kitchen_outlined, 'Live Kitchen (KDS)'),
    (Icons.delivery_dining, 'Delivery Fleet'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = data;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = switch (widget.role == 'owner' ? screen : 5) {
      0 => _Dashboard(d, onAll: () => setState(() => screen = 1)),
      1 => _LiveOrders(d, widget.backend),
      2 => _Subscriptions(d, widget.backend, reload),
      3 => _MenuManager(d, widget.backend),
      4 => _Customers(d, query, (q) => setState(() => query = q)),
      5 => KitchenHub(
        d: d,
        b: widget.backend,
        role: widget.role,
        items: items,
        error: itemsError,
        onSync: reload,
      ),
      _ => _Fleet(d),
    };
    return ValueListenableBuilder<bool>(
      valueListenable: staffDark,
      builder: (context, dark, _) => Theme(
        data: ThemeData(
          fontFamily: _font,
          scaffoldBackgroundColor: _cream,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _saffron,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _saffron,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          useMaterial3: true,
        ),
        child: Scaffold(
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _PartnerHeader(
                  manager: manager,
                  role: widget.role,
                  screen: screen,
                  onTab: (i) => setState(() => screen = i),
                  onSignOut: widget.backend.signOut,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: ordersRefreshing ? null : refreshOrders,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          ordersRefreshing ? 'Refreshing...' : 'Refresh',
                        ),
                      ),
                    ),
                    if (ordersError != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(ordersError!),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: refreshOrders,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(wide ? 32 : 16),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1180),
                              child: body,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          appBar: null,
          bottomNavigationBar: null,
        ),
      ),
    );
  }
}

double _cw(BuildContext c) {
  final sw = MediaQuery.sizeOf(c).width;
  final wide = sw >= 900;
  final w = (sw - (wide ? 250 + 64 : 32)).clamp(0, 1180).toDouble();
  final cols = w >= 900 ? 3 : (w >= 600 ? 2 : 1);
  return (w - 16 * (cols - 1)) / cols;
}

Widget _title(String t, String sub, [Widget? trailing]) => LayoutBuilder(
  builder: (context, constraints) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth.clamp(0, 700).toDouble(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _forest,
                ),
              ),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(color: _muted, fontSize: 13)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  ),
);

Widget _card({required Widget child, EdgeInsets? pad}) => Container(
  width: double.infinity,
  padding: pad ?? const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _creamMuted),
  ),
  child: Material(color: Colors.transparent, child: child),
);

Widget _chip(String t, Color fg, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
  child: Text(
    t,
    style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
  ),
);

Widget statusChip(String s) => switch (s) {
  'Delivered' => _chip(s, _forest, const Color(0x1A1B3B2B)),
  'Out for Delivery' => _chip(s, _saffron, const Color(0x1AE86324)),
  'Cancelled' ||
  'Failed' ||
  'Refunded' => _chip(s, const Color(0xFFB3261E), const Color(0x1AB3261E)),
  _ => _chip(s, _muted, const Color(0xFFF0EBDD)),
};

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label, value, note;
  const _Metric(this.icon, this.label, this.value, this.note);
  @override
  Widget build(BuildContext context) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _forest.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: _forest),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: _forest,
          ),
        ),
        const SizedBox(height: 4),
        Text(note, style: TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );
}

String _slot(Map o) {
  final m = o['meal'] == 'dinner' ? 'Dinner' : 'Lunch';
  return o['meal'] == null ? 'One-time' : m;
}

class _Dashboard extends StatelessWidget {
  final AdminData d;
  final VoidCallback onAll;
  const _Dashboard(this.d, {required this.onAll});
  @override
  Widget build(BuildContext context) {
    final t = d.todayOrders;
    final feed = t.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Kitchen overview', "Today's tiffin prep and deliveries."),
        LayoutBuilder(
          builder: (c, k) {
            final cols = k.maxWidth >= 900 ? 4 : 2;
            final w = (k.maxWidth - 16 * (cols - 1)) / cols;
            final cards = [
              _Metric(
                Icons.receipt_long_outlined,
                'Orders today',
                '${t.length}',
                '${t.where((o) => o['status'] == 'Delivered').length} delivered',
              ),
              _Metric(
                Icons.people_outline,
                'Active subscribers',
                '${d.activeSubscribers}',
                'With a verified plan today',
              ),
              _Metric(
                Icons.currency_rupee,
                "Today's revenue",
                rupees(d.revenueTodayPaise),
                'Payments you verified',
              ),
              _Metric(
                Icons.two_wheeler_outlined,
                'Delivery partners',
                '${d.ridersOut} out',
                '${d.riders.length} registered',
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [for (final x in cards) SizedBox(width: w, child: x)],
            );
          },
        ),
        const SizedBox(height: 24),
        _card(
          pad: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Live dispatch feed',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _forest,
                        ),
                      ),
                    ),
                    TextButton(onPressed: onAll, child: const Text('View all')),
                  ],
                ),
              ),
              _orderTable(d, feed),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _orderTable(AdminData d, List<Map<String, dynamic>> rows) =>
    LayoutBuilder(
      builder: (c, k) => k.maxWidth >= 640
          ? _orderTableBody(d, rows)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 640, child: _orderTableBody(d, rows)),
            ),
    );

Widget _orderTableBody(AdminData d, List<Map<String, dynamic>> rows) {
  final head = TextStyle(
    color: _muted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );
  Widget row(List<Widget> c, {bool h = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: h ? _cream : null,
      border: Border(top: BorderSide(color: _creamMuted)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < c.length; i++)
          Expanded(flex: const [2, 3, 2, 3, 3][i], child: c[i]),
      ],
    ),
  );
  if (rows.isEmpty) {
    return Padding(
      padding: EdgeInsets.all(28),
      child: Text('No orders for today yet.', style: TextStyle(color: _muted)),
    );
  }
  return Column(
    children: [
      row([
        for (final h in ['ORDER', 'CUSTOMER', 'SLOT', 'STATUS', 'DELIVERY'])
          Text(h, style: head),
      ], h: true),
      for (final o in rows)
        row([
          Text(
            '#${(o['id'] as String).substring(0, 6).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Text(d.nameOf(o), style: const TextStyle(fontSize: 13)),
          Text(_slot(o), style: const TextStyle(fontSize: 13)),
          Align(
            alignment: Alignment.centerLeft,
            child: statusChip('${o['status']}'),
          ),
          Text(
            d.riderName(o['assigned_to']),
            style: TextStyle(fontSize: 13, color: _muted),
          ),
        ]),
    ],
  );
}

class _LiveOrders extends StatefulWidget {
  final AdminData d;
  final TiffeBackend b;
  const _LiveOrders(this.d, this.b);
  @override
  State<_LiveOrders> createState() => _LiveOrdersState();
}

class _LiveOrdersState extends State<_LiveOrders> {
  AdminData get d => widget.d;
  TiffeBackend get b => widget.b;
  String dayLabel(Map o) {
    final day = '${o['delivery_date']}';
    if (day == d.today) return 'Today';
    final t = DateTime.tryParse(day);
    final n = DateTime.tryParse(d.today);
    if (t == null || n == null) return day;
    if (t.difference(n).inDays == 1) return 'Tomorrow';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${m[t.month - 1]}';
  }

  String filter = 'Open';
  static const filters = ['Open', 'Today', 'Delivered', 'All'];
  static const closed = {'Delivered', 'Cancelled', 'Failed', 'Refunded'};
  List<Map<String, dynamic>> pick() {
    final all = d.orders;
    final rows = switch (filter) {
      'Open' => [
        for (final o in all)
          if (!closed.contains(o['status'])) o,
      ],
      'Today' => d.todayFilterOrders,
      'Delivered' => [
        for (final o in all)
          if (o['status'] == 'Delivered') o,
      ],
      _ => all,
    };
    // Newest order first, so a fresh order is the top card.
    return [...rows]..sort((a, b) {
      final newest = '${b['created_at'] ?? ''}'.compareTo(
        '${a['created_at'] ?? ''}',
      );
      if (newest != 0) return newest;
      final c = '${b['delivery_date']}'.compareTo('${a['delivery_date']}');
      if (c != 0) return c;
      return (a['meal'] == 'dinner' ? 1 : 0).compareTo(
        b['meal'] == 'dinner' ? 1 : 0,
      );
    });
  }

  static const flow = [
    'Confirmed',
    'Preparing',
    'Packed',
    'Out for Delivery',
    'Delivered',
  ];
  @override
  Widget build(BuildContext context) {
    final rows = pick();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Live orders & dispatch',
          'Verify payment, move orders through the kitchen, assign a rider.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in filters)
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          _EmptyNote(
            filter == 'Open'
                ? 'No open orders right now.'
                : 'No orders in this view.',
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final o in rows)
              SizedBox(width: _cw(context), child: _orderCard(context, o)),
          ],
        ),
      ],
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> o) {
    final verified = o['payment_status'] == 'verified';
    final i = flow.indexOf('${o['status']}');
    final next = i >= 0 && i < flow.length - 1 ? flow[i + 1] : null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            spacing: 8,
            children: [
              Text(
                '#${(o['id'] as String).substring(0, 6).toUpperCase()} · ${dayLabel(o)} ${_slot(o)}',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              statusChip('${o['status']}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.nameOf(o),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${rupees((o['total_paise'] as num?) ?? 0)} · ${verified ? 'Paid' : 'Payment pending'}',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Rider: ${d.riderName(o['assigned_to'])}',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!verified)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => confirmAdminAction(
                      context,
                      'Verify payment received',
                      () => b.verifyPayment(o['id'] as String),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Verify payment',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              if (verified &&
                  o['assigned_to'] == null &&
                  d.riders.isNotEmpty) ...[
                Expanded(
                  child: PopupMenuButton<String>(
                    onSelected: (r) => b.assignRider(o['id'] as String, r),
                    itemBuilder: (_) => [
                      for (final r in d.riders)
                        PopupMenuItem(
                          value: r['user_id'] as String,
                          child: Text(d.riderName(r['user_id'])),
                        ),
                    ],
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _forest),
                      ),
                      child: Text(
                        'Assign rider',
                        style: TextStyle(
                          color: _forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!verified && next != null) const SizedBox(width: 8),
              if (next != null)
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _saffron,
                      foregroundColor: _cream,
                    ),
                    onPressed:
                        next == 'Out for Delivery' &&
                            (!verified || o['assigned_to'] == null)
                        ? null
                        : () => confirmAdminAction(
                            context,
                            'Mark $next',
                            () => b.advance(o['id'] as String, next),
                          ),
                    child: Text('Mark $next'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Subscriptions extends StatelessWidget {
  final AdminData d;
  final TiffeBackend b;
  final Future<void> Function() onSaved;
  const _Subscriptions(this.d, this.b, this.onSaved);

  Future<void> add(BuildContext context) async {
    String? customer;
    String plan = 'daily';
    bool verified = true;
    final start = TextEditingController(text: d.today);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add subscription'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: [
                    for (final cu in d.customers)
                      DropdownMenuItem(
                        value: cu['id'] as String,
                        child: Text(
                          '${cu['name'] ?? 'Unnamed'} · ${cu['phone'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => set(() => customer = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: plan,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily Tiffe - ₹1500'),
                    ),
                    DropdownMenuItem(
                      value: 'double',
                      child: Text('Double Tiffe - ₹3000'),
                    ),
                  ],
                  onChanged: (v) => set(() => plan = v ?? 'daily'),
                ),
                TextField(
                  controller: start,
                  decoration: const InputDecoration(
                    labelText: 'Starts on (YYYY-MM-DD)',
                    helperText: 'Runs for 30 days',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: verified,
                  onChanged: (v) => set(() => verified = v ?? false),
                  title: const Text('Payment received and verified'),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFB3261E)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final st = DateTime.tryParse(start.text.trim());
                if (customer == null || st == null) {
                  set(() => error = 'Pick a customer and a valid start date.');
                  return;
                }
                final en = st.add(const Duration(days: 29));
                try {
                  await b.saveSubscription(
                    customerId: customer!,
                    plan: plan,
                    startsOn: st.toIso8601String().substring(0, 10),
                    endsOn: en.toIso8601String().substring(0, 10),
                    verified: verified,
                  );
                  await onSaved();
                  if (c.mounted) Navigator.pop(c);
                } catch (_) {
                  set(() => error = 'Could not save. Nothing was changed.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Active subscriptions',
        '${d.activeSubscribers} customers with a verified plan today.',
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _saffron,
            foregroundColor: _cream,
          ),
          onPressed: () => add(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add subscription'),
        ),
      ),
      _card(
        pad: EdgeInsets.zero,
        child: Column(
          children: [
            for (final s in d.subs)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _creamMuted)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        d.names[s['customer_id']] ?? 'Customer',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        s['plan'] == 'double' ? 'Double Tiffe' : 'Daily Tiffe',
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        '${s['starts_on']} to ${s['ends_on']}',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: s['verified'] == true
                            ? (d.isActive(s)
                                  ? _chip(
                                      'Active',
                                      _forest,
                                      const Color(0x1A1B3B2B),
                                    )
                                  : _chip(
                                      'Ended',
                                      _muted,
                                      const Color(0xFFF0EBDD),
                                    ))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _chip(
                                    'Unverified',
                                    _saffron,
                                    const Color(0x1AE86324),
                                  ),
                                  if (s['id'] != null)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 32),
                                      ),
                                      onPressed: () async {
                                        try {
                                          await b.verifySubscription(
                                            '${s['id']}',
                                          );
                                          await onSaved();
                                        } catch (_) {}
                                      },
                                      child: const Text('Verify payment'),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            if (d.subs.isEmpty)
              Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No subscriptions yet. A plan picked in the phone app demo is not saved here until you add it.',
                  style: TextStyle(color: _muted),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _MenuManager extends StatelessWidget {
  final AdminData d;
  final TiffeBackend b;
  const _MenuManager(this.d, this.b);
  Future<void> addBhaji(BuildContext context) => showDialog<void>(
    context: context,
    builder: (c) => _AddBhajiDialog(backend: b),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Menu & Daily Item Stock Status',
        'Toggle bhaji availability in customer apps.',
        FilledButton.icon(
          onPressed: () => addBhaji(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Bhaji', style: TextStyle(fontSize: 12)),
        ),
      ),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final m in d.menu)
            SizedBox(
              width: _cw(context),
              child: _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['name']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _forest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${m['description'] ?? ''}',
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: m['available'] == true,
                      onChanged: (value) async {
                        try {
                          await b.saveMenu(
                            id: m['id'] as String,
                            name: '${m['name']}',
                            description: '${m['description'] ?? ''}',
                            available: value,
                          );
                        } catch (_) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Item status could not be saved.',
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class _Customers extends StatelessWidget {
  final AdminData d;
  final String query;
  final ValueChanged<String> onQuery;
  const _Customers(this.d, this.query, this.onQuery);

  (String, Color, Color) plan(Map c) {
    final mine = d.subs.where((s) => s['customer_id'] == c['id']).toList();
    final act = mine.where(d.isActive).toList();
    if (act.isNotEmpty) {
      return (
        act.first['plan'] == 'double' ? 'Double Tiffe' : 'Daily Tiffe',
        _forest,
        const Color(0x1A1B3B2B),
      );
    }
    if (mine.any((s) => s['verified'] != true)) {
      return ('Awaiting payment', _saffron, const Color(0x1AE86324));
    }
    if (mine.isNotEmpty) return ('Plan ended', _muted, const Color(0xFFF0EBDD));
    return ('No plan', _muted, const Color(0xFFF0EBDD));
  }

  String joined(Object? v) {
    final t = DateTime.tryParse('$v');
    if (t == null) return '';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Joined ${t.day} ${m[t.month - 1]} ${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rows = [
      for (final c in d.customers)
        if (q.isEmpty ||
            '${c['name']} ${c['phone']} ${c['area']}'.toLowerCase().contains(q))
          c,
    ]..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Customers', '${rows.length} customers'),
        SizedBox(
          width: 420,
          child: TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: 'Search name, phone or area',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _creamMuted),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const _EmptyNote('No customers match that search.')
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final c in rows)
                SizedBox(
                  width: _cw(context),
                  child: _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              (c['name'] as String?)?.trim().isNotEmpty == true
                                  ? c['name']
                                  : 'Unnamed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _forest,
                              ),
                            ),
                            _chip(plan(c).$1, plan(c).$2, plan(c).$3),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${c['phone'] ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if ('${c['area'] ?? ''}'.isNotEmpty) '${c['area']}',
                            joined(c['created_at']),
                          ].where((e) => e.isNotEmpty).join(' · '),
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String t;
  const _EmptyNote(this.t);
  @override
  Widget build(BuildContext context) => _card(
    child: Text(t, style: TextStyle(color: _muted)),
  );
}

/// Counts include only today's active kitchen queue, not cancelled or delivered.
class KitchenCounts {
  final int tiffins;
  final Map<String, int> bhajis;
  const KitchenCounts(this.tiffins, this.bhajis);
  factory KitchenCounts.from(AdminData d, List<Map<String, dynamic>> items) {
    final rows = d.todayOrders
        .where(
          (o) => {'Confirmed', 'Preparing', 'Packed'}.contains(o['status']),
        )
        .toList();
    final ids = rows.map((o) => o['id']).toSet();
    final counts = <String, int>{};
    for (final i in items.where((i) => ids.contains(i['order_id']))) {
      final n = '${i['item_name'] ?? 'Unnamed bhaji'}';
      counts[n] = (counts[n] ?? 0) + 1;
    }
    return KitchenCounts(
      rows.fold<int>(0, (n, o) => n + ((o['quantity'] as num?)?.toInt() ?? 0)),
      counts,
    );
  }
}

class KitchenHub extends StatefulWidget {
  final AdminData d;
  final TiffeBackend b;
  final String role;
  final List<Map<String, dynamic>> items;
  final String? error;
  final Future<void> Function() onSync;
  const KitchenHub({
    super.key,
    required this.d,
    required this.b,
    this.role = 'owner',
    required this.items,
    this.error,
    required this.onSync,
  });
  @override
  State<KitchenHub> createState() => _KitchenHubState();
}

class _KitchenHubState extends State<KitchenHub> {
  Timer? clock;
  String? error;
  bool busy = false;
  bool? autoConfirm;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    widget.b.currentSettings().then((v) {
      if (mounted) setState(() => autoConfirm = v?['kitchen_auto_accept'] == true);
    }).catchError((_) {});
  }

  /// Owner-controlled switch for automatic confirmation of new orders. Staff
  /// tap statuses by hand while this is off (the default).
  Future<void> setAutoConfirm(bool on) async {
    final prev = autoConfirm;
    setState(() {
      autoConfirm = on;
      error = null;
    });
    try {
      await widget.b.client
          .rpc('set_kitchen_auto_accept', params: {'p_enabled': on});
    } catch (_) {
      if (mounted)
        setState(() {
          autoConfirm = prev;
          error = 'Could not update auto-confirm. Check the connection and try again.';
        });
    }
  }

  /// Assign a rider straight from the Ready card so the kitchen need not open
  /// All Orders. Payment verification stays a prerequisite.
  Future<void> assign(Map<String, dynamic> o, String riderId) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.b.assignRider(o['id'] as String, riderId);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Could not assign the rider. Refresh and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Future<void> act(Map<String, dynamic> o, String label, String status) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$label?'),
        content: Text(
          'This changes the live order to $status.${status == 'Cancelled' ? ' Payment refunds are not automatic.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.b.advance(o['id'] as String, status);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Server refused the update. Refresh and check payment, rider and current status.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String age(Map o) {
    final created = DateTime.tryParse('${o['created_at']}');
    if (created == null) return 'Order time unavailable';
    final n = DateTime.now().toUtc().difference(created.toUtc()).inMinutes;
    return '${n < 0 ? 0 : n} min elapsed';
  }

  Widget upcomingCard(AdminData d) {
    final rows = d.laterOrders;
    return _card(
      pad: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: _muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'UPCOMING ORDERS (${rows.length})',
                  style: const TextStyle(
                    color: _saffron,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Other orders for later delivery dates. Not counted in the totals above.',
            style: TextStyle(fontSize: 9, color: _muted),
          ),
          Divider(color: _creamMuted, height: 24),
          if (rows.isEmpty)
            Text(
              'No upcoming orders.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          for (final o in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(
                pad: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${'${o['id']}'.substring(0, 6).toUpperCase()} • ${_slot(o)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: _forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Delivery ${o['delivery_date']} • ${o['status']}',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d.nameOf(o),
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Qty: ${o['quantity'] ?? 0} Tiffin (${((o['quantity'] as num?)?.toInt() ?? 0) * 3} Chapatis, ${o['quantity'] ?? 0} Rice)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _forest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final name
                            in widget.items
                                .where((i) => i['order_id'] == o['id'])
                                .map((i) => '${i['item_name']}')
                                .toSet())
                          _chip(name, _saffron, const Color(0xFF4A2D17)),
                      ],
                    ),
                    if ('${o['instructions'] ?? ''}'.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Note: ${o['instructions']}',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: _muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final count = KitchenCounts.from(d, widget.items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          pad: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LIVE KITCHEN PREPARATION SUMMARY (PUNE BATCHES)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _forest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Counts today's deliveries (${d.today}) only - resets at midnight IST. Upcoming orders stay visible in the queue below.",
                style: TextStyle(fontSize: 10, color: _muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(
                    'Auto-Calculated Quantities',
                    _saffron,
                    const Color(0xFF4A2D17),
                  ),
                  if (widget.role == 'owner' && autoConfirm != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Auto-confirm new orders',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        Switch(
                          value: autoConfirm!,
                          onChanged: busy ? null : setAutoConfirm,
                        ),
                      ],
                    ),
                  TextButton.icon(
                    onPressed: widget.onSync,
                    icon: const Icon(Icons.sync, size: 14),
                    label: const Text('Sync', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(
                    onPressed: () => checkStaffUpdateManually(context),
                    icon: const Icon(Icons.system_update, size: 14),
                    label: const Text(
                      'Updates',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              Divider(color: _creamMuted, height: 26),
              LayoutBuilder(
                builder: (c, box) {
                  final w = (box.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final m in [
                        ('TOTAL TIFFINS', '${count.tiffins}', 'Active Queue'),
                        (
                          'CHAPATIS (3/TIFFIN)',
                          '${count.tiffins * 3} Pcs',
                          'Freshly pressed',
                        ),
                        (
                          'RICE PORTIONS',
                          '${count.tiffins} Port.',
                          'Steamed & Jeera',
                        ),
                      ])
                        SizedBox(
                          width: w,
                          child: _card(
                            pad: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.$1,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _muted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  m.$2,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: m.$1.startsWith('CHAPATIS')
                                        ? _saffron
                                        : Colors.white,
                                  ),
                                ),
                                Text(
                                  m.$3,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(
                        width: w,
                        child: _card(
                          pad: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BHAJI PORTIONS BREAKDOWN',
                                style: TextStyle(fontSize: 9, color: _muted),
                              ),
                              const SizedBox(height: 6),
                              if (widget.error != null)
                                Text(
                                  widget.error!,
                                  style: const TextStyle(fontSize: 10),
                                )
                              else if (count.bhajis.isEmpty)
                                Text(
                                  'No bhajis in active queue',
                                  style: TextStyle(fontSize: 10, color: _muted),
                                )
                              else
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: [
                                    for (final e in count.bhajis.entries)
                                      _chip(
                                        '${e.key}: ${e.value} port.',
                                        Colors.white,
                                        _saffron,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (busy) const LinearProgressIndicator(),
        for (final state in ['Confirmed', 'Preparing', 'Packed']) ...[
          const SizedBox(height: 18),
          _card(
            pad: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: state == 'Packed'
                          ? const Color(0xFF10B981)
                          : _saffron,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${state == 'Confirmed'
                            ? 'NEW ORDERS'
                            : state == 'Preparing'
                            ? 'PREPARING'
                            : 'READY FOR PICKUP'} (${d.queueFor(state).length})',
                        style: TextStyle(
                          color: state == 'Packed'
                              ? _okBright
                              : _saffron,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  state == 'Confirmed'
                      ? 'Action Required'
                      : state == 'Preparing'
                      ? 'Cooking & Packing'
                      : 'Awaiting Delivery Partner',
                  style: TextStyle(fontSize: 9, color: _muted),
                ),
                Divider(color: _creamMuted, height: 24),
                if (d.queueFor(state).isEmpty)
                  Text(
                    'No orders in this queue.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                for (final o in d.queueFor(state))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _card(
                      pad: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state == 'Confirmed')
                            Align(
                              alignment: Alignment.centerRight,
                              child: _chip(
                                age(o),
                                Colors.black,
                                const Color(0xFFF59E0B),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            '#${'${o['id']}'.substring(0, 6).toUpperCase()} • ${_slot(o)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: _forest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o['subscription_id'] == null
                                ? 'One-time'
                                : 'Monthly Sub',
                            style: TextStyle(fontSize: 10, color: _muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Delivery ${o['delivery_date']}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _saffron,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _card(
                            pad: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.nameOf(o),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Qty: ${o['quantity'] ?? 0} Tiffin (${((o['quantity'] as num?)?.toInt() ?? 0) * 3} Chapatis, ${o['quantity'] ?? 0} Rice)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _forest,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: [
                                    for (final name
                                        in widget.items
                                            .where(
                                              (i) => i['order_id'] == o['id'],
                                            )
                                            .map((i) => '${i['item_name']}')
                                            .toSet())
                                      _chip(
                                        name,
                                        _saffron,
                                        const Color(0xFF4A2D17),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if ('${o['instructions'] ?? ''}'.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Note: ${o['instructions']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: _muted,
                                ),
                              ),
                            ),
                          if (state == 'Packed')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Partner: ${d.riderName(o['assigned_to'])}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                            ),
                          if (state == 'Packed' &&
                              widget.role == 'owner' &&
                              o['payment_status'] == 'verified' &&
                              o['assigned_to'] == null &&
                              d.riders.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: PopupMenuButton<String>(
                                enabled: !busy,
                                onSelected: (r) => assign(o, r),
                                itemBuilder: (_) => [
                                  for (final r in d.riders)
                                    PopupMenuItem(
                                      value: r['user_id'] as String,
                                      child: Text(d.riderName(r['user_id'])),
                                    ),
                                ],
                                child: Container(
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _saffron),
                                  ),
                                  child: const Text(
                                    'Assign delivery partner',
                                    style: TextStyle(
                                      color: _saffron,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (state == 'Confirmed')
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            act(o, 'Accept Order', 'Preparing'),
                                  child: const Text(
                                    'Accept Order',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              if (state == 'Preparing')
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => act(
                                          o,
                                          'Mark Ready for Pickup',
                                          'Packed',
                                        ),
                                  child: const Text(
                                    'Mark Ready for Pickup',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              if (state == 'Packed')
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                  onPressed:
                                      busy ||
                                          widget.role != 'owner' ||
                                          o['payment_status'] != 'verified' ||
                                          o['assigned_to'] == null
                                      ? null
                                      : () => act(
                                          o,
                                          'Confirm Handover',
                                          'Out for Delivery',
                                        ),
                                  child: const Text(
                                    'Confirm Handover',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              if (state != 'Packed' && widget.role == 'owner')
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: _dangerBg,
                                    foregroundColor: _dangerFg,
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            act(o, 'Reject order', 'Cancelled'),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          if (state == 'Packed' &&
                              (o['payment_status'] != 'verified' ||
                                  o['assigned_to'] == null))
                            Text(
                              'Verify payment and assign a rider in All Orders before handover.',
                              style: TextStyle(fontSize: 10, color: _muted),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (d.laterOrders.isNotEmpty) ...[
          const SizedBox(height: 18),
          upcomingCard(d),
        ],
      ],
    );
  }
}

class _Fleet extends StatelessWidget {
  final AdminData d;
  const _Fleet(this.d);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Delivery Fleet',
        'Enrolled riders and their current assigned orders. No GPS tracking.',
      ),
      if (d.riders.isEmpty) const _EmptyNote('No delivery staff enrolled.'),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final r in d.riders)
            SizedBox(
              width: _cw(context),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.riderName(r['user_id']),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _forest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${d.orders.where((o) => o['assigned_to'] == r['user_id'] && !{'Delivered', 'Cancelled'}.contains(o['status'])).length} active assigned orders',
                    ),
                    for (final o in d.orders.where(
                      (o) =>
                          o['assigned_to'] == r['user_id'] &&
                          !{'Delivered', 'Cancelled'}.contains(o['status']),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${d.nameOf(o)} · ${o['delivery_date']} · ${o['status']}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

Future<void> confirmAdminAction(
  BuildContext context,
  String label,
  Future<void> Function() action,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('$label?'),
      content: const Text('This updates the live customer order.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (yes != true) return;
  try {
    await action();
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update refused. Refresh before trying again.'),
        ),
      );
  }
}

class _PartnerHeader extends StatelessWidget {
  final String manager, role;
  final int screen;
  final ValueChanged<int> onTab;
  final VoidCallback onSignOut;
  const _PartnerHeader({
    required this.manager,
    required this.role,
    required this.screen,
    required this.onTab,
    required this.onSignOut,
  });
  @override
  Widget build(BuildContext c) => Container(
    color: _headerBg,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _saffron,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Tiffie Central Kitchen',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _forest,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _liveBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              color: _okBright,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pune Kitchen Hub • Pune, MH',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    staffDark.value ? 'Switch to light mode' : 'Switch to dark mode',
                icon: Icon(
                  staffDark.value
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: _muted,
                ),
                onPressed: () => setStaffDark(!staffDark.value),
              ),
              PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: _saffron,
                  child: Text(
                    manager.isNotEmpty ? manager[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onSelected: (v) {
                  if (v == 'logout') {
                    onSignOut();
                  } else if (v == 'update') {
                    checkStaffUpdateManually(c);
                  } else {
                    onTab(int.parse(v));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      '$manager\n${role == 'owner' ? 'Outlet Manager' : 'Kitchen Staff'}',
                    ),
                  ),
                  if (role == 'owner')
                    const PopupMenuItem(value: '4', child: Text('Customers')),
                  if (role == 'owner')
                    const PopupMenuItem(value: '0', child: Text('Overview')),
                  const PopupMenuItem(
                    value: 'update',
                    child: Text('Check for updates'),
                  ),
                  const PopupMenuItem(value: 'logout', child: Text('Sign out')),
                ],
              ),
            ],
          ),
        ),
        if (role == 'owner')
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                for (final i in [5, 1, 3, 2, 6])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: screen == i
                            ? _saffron
                            : Colors.transparent,
                        foregroundColor: screen == i
                            ? Colors.white
                            : _muted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => onTab(i),
                      icon: Icon(_PartnerHubState.nav[i].$1, size: 15),
                      label: Text(
                        _PartnerHubState.nav[i].$2,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _AddBhajiDialog extends StatefulWidget {
  final TiffeBackend backend;
  const _AddBhajiDialog({required this.backend});
  @override
  State<_AddBhajiDialog> createState() => _AddBhajiDialogState();
}

class _AddBhajiDialogState extends State<_AddBhajiDialog> {
  final name = TextEditingController(), description = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Add Bhaji'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Bhaji name',
              hintText: 'e.g. Aloo Jeera',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved as available in the live customer catalog.',
            style: TextStyle(fontSize: 12),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (name.text.trim().isEmpty) {
                  setState(() => error = 'Enter a bhaji name.');
                  return;
                }
                setState(() {
                  saving = true;
                  error = null;
                });
                try {
                  await widget.backend.saveMenu(
                    name: name.text.trim(),
                    description: description.text.trim(),
                    available: true,
                  );
                  if (c.mounted) Navigator.pop(c);
                } catch (_) {
                  if (mounted)
                    setState(() {
                      saving = false;
                      error = 'Could not save. Check your connection and owner access.';
                    });
                }
              },
        child: Text(saving ? 'Saving...' : 'Add to catalog'),
      ),
    ],
  );
}
