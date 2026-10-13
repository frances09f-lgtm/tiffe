// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';

import 'package:flutter/material.dart';

import '../live/backend.dart';

const _forest = Color(0xFF1B3B2B);
const _forestLight = Color(0xFF2C5E45);
const _cream = Color(0xFFFBF9F5);
const _creamMuted = Color(0xFFE6E0D3);
const _saffron = Color(0xFFE86324);
const _muted = Color(0xFF666666);
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
  const PartnerHub({super.key, required this.backend, required this.role});
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
  String? itemsError;
  bool autoAccept = false, autoKnown = false;

  @override
  void initState() {
    super.initState();
    os = widget.backend.orders().listen((r) async {
      if (!mounted) return;
      setState(() => orders = r);
      try {
        final got = await widget.backend.orderItems(
          r.map((o) => o['id'] as String).toList(),
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
    });
    ms = widget.backend.menu().listen((r) => setState(() => menu = r));
    reload();
  }

  Future<void> reload() async {
    try {
      final v = await widget.backend.currentSettings();
      if (mounted)
        setState(() {
          autoAccept = v?['kitchen_auto_accept'] == true;
          autoKnown = v?.containsKey('kitchen_auto_accept') == true;
        });
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
    (Icons.soup_kitchen_outlined, 'Live Kitchen'),
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
        autoAccept: autoAccept,
        autoKnown: autoKnown,
        onAuto: (v) async {
          await widget.backend.client.rpc(
            'set_kitchen_auto_accept',
            params: {'p_enabled': v},
          );
          await reload();
        },
      ),
      _ => _Fleet(d),
    };
    return Theme(
      data: ThemeData(
        fontFamily: _font,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(seedColor: _forest),
        useMaterial3: true,
      ),
      child: Scaffold(
        body: Column(
          children: [
            if (wide) _Header(compact: false),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide && widget.role == 'owner')
                    _Sidebar(screen, (i) => setState(() => screen = i)),
                  Expanded(
                    child: SingleChildScrollView(
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
                ],
              ),
            ),
          ],
        ),
        appBar: wide
            ? null
            : AppBar(
                title: const Text('Tiffe Partner Hub'),
                actions: [
                  IconButton(onPressed: reload, icon: const Icon(Icons.sync)),
                  IconButton(
                    onPressed: widget.backend.signOut,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
        drawer: wide
            ? null
            : Drawer(
                child: SafeArea(
                  child: ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Tiffe Staff',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final i
                          in widget.role == 'owner'
                              ? [5, 1, 3, 2, 6, 4, 0]
                              : [5])
                        ListTile(
                          leading: Icon(nav[i].$1),
                          title: Text(nav[i].$2),
                          selected: screen == i,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => screen = i);
                          },
                        ),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: wide || widget.role != 'owner'
            ? null
            : NavigationBar(
                selectedIndex: [5, 1, 3, 6].contains(screen)
                    ? [5, 1, 3, 6].indexOf(screen)
                    : 0,
                onDestinationSelected: (i) =>
                    setState(() => screen = [5, 1, 3, 6][i]),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.soup_kitchen_outlined),
                    label: 'Kitchen',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.restaurant_menu),
                    label: 'Menu',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.delivery_dining),
                    label: 'Fleet',
                  ),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool compact;
  const _Header({this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
    color: _forest,
    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28, vertical: 14),
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
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiffe Staff',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                'Kitchen operations and subscriptions',
                style: TextStyle(color: Color(0xB3FBF9F5), fontSize: 11),
              ),
            ],
          ),
        ),
        if (!compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _forestLight.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 9, color: Color(0xFF34D399)),
                SizedBox(width: 8),
                Text(
                  'Connected to live data',
                  style: TextStyle(
                    color: _cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _Sidebar(this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: _creamMuted)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < _PartnerHubState.nav.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: i == selected ? _forest : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _PartnerHubState.nav[i].$1,
                        size: 18,
                        color: i == selected ? Colors.white : _muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _PartnerHubState.nav[i].$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: i == selected ? Colors.white : _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _forest,
                ),
              ),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: _muted, fontSize: 13)),
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
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: _creamMuted),
  ),
  child: child,
);

Widget _chip(String t, Color fg, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
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
                style: const TextStyle(
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
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: _forest,
          ),
        ),
        const SizedBox(height: 4),
        Text(note, style: const TextStyle(color: _muted, fontSize: 12)),
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
                    const Expanded(
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
  const head = TextStyle(
    color: _muted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );
  Widget row(List<Widget> c, {bool h = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: h ? _cream : null,
      border: const Border(top: BorderSide(color: _creamMuted)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < c.length; i++)
          Expanded(flex: const [2, 3, 2, 3, 3][i], child: c[i]),
      ],
    ),
  );
  if (rows.isEmpty) {
    return const Padding(
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
            style: const TextStyle(fontSize: 13, color: _muted),
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
      'Today' => d.todayOrders,
      'Delivered' => [
        for (final o in all)
          if (o['status'] == 'Delivered') o,
      ],
      _ => all,
    };
    return [...rows]..sort((a, b) {
      final c = '${a['delivery_date']}'.compareTo('${b['delivery_date']}');
      if (c != 0) return filter == 'Open' ? c : -c;
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
                style: const TextStyle(
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${rupees((o['total_paise'] as num?) ?? 0)} · ${verified ? 'Paid' : 'Payment pending'}',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Rider: ${d.riderName(o['assigned_to'])}',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!verified)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => confirmAdminAction(
                      context,
                      'Verify payment received',
                      () => b.verifyPayment(o['id'] as String),
                    ),
                    child: const Text('Verify payment'),
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
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _forest),
                      ),
                      child: const Text(
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
                    style: FilledButton.styleFrom(backgroundColor: _forest),
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
          style: FilledButton.styleFrom(backgroundColor: _forest),
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
                decoration: const BoxDecoration(
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
                        style: const TextStyle(color: _muted),
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
              const Padding(
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
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title('Menu & bhaji manager', 'Bhajis customers can pick from.'),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _forest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${m['description'] ?? ''}',
                            style: const TextStyle(color: _muted, fontSize: 13),
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
                borderSide: const BorderSide(color: _creamMuted),
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
                              style: const TextStyle(
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
                          style: const TextStyle(color: _muted, fontSize: 12),
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
    child: Text(t, style: const TextStyle(color: _muted)),
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
  final bool autoAccept, autoKnown;
  final Future<void> Function(bool)? onAuto;
  final Future<void> Function() onSync;
  const KitchenHub({
    super.key,
    required this.d,
    required this.b,
    this.role = 'owner',
    required this.items,
    this.error,
    this.autoAccept = false,
    this.autoKnown = false,
    this.onAuto,
    required this.onSync,
  });
  @override
  State<KitchenHub> createState() => _KitchenHubState();
}

class _KitchenHubState extends State<KitchenHub> {
  Timer? clock;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
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
    return 'Waiting ${n < 0 ? 0 : n} min · no automatic expiry';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final count = KitchenCounts.from(d, widget.items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Live Kitchen',
          'Today\'s kitchen queue, customer choices and handover.',
          TextButton.icon(
            onPressed: widget.onSync,
            icon: const Icon(Icons.sync),
            label: const Text('Sync'),
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto-Accept Orders',
                style: TextStyle(fontWeight: FontWeight.w700, color: _forest),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.autoAccept,
                onChanged: !widget.autoKnown || busy || widget.role != 'owner'
                    ? null
                    : (v) async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(
                              v
                                  ? 'Enable Auto-Accept?'
                                  : 'Use manual acceptance?',
                            ),
                            content: Text(
                              v
                                  ? 'New Confirmed orders move to Preparing on the server, even with this app closed. Existing orders are unchanged.'
                                  : 'New orders stay Confirmed until accepted. Existing orders are unchanged.',
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
                        if (yes != true) return;
                        try {
                          await widget.onAuto?.call(v);
                        } catch (_) {
                          if (mounted)
                            setState(
                              () => error = 'Auto-Accept could not be saved.',
                            );
                        }
                      },
                title: Text(
                  widget.autoAccept
                      ? 'Auto-Accept Orders: ON'
                      : 'Auto-Accept Orders: OFF',
                ),
                subtitle: Text(
                  widget.autoKnown
                      ? 'Server setting applies to new orders only.'
                      : 'Could not verify the server setting. Sync to retry.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (c, box) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in [
                ('Tiffins', count.tiffins),
                ('Chapatis', count.tiffins * 3),
                ('Rice', count.tiffins),
              ])
                SizedBox(
                  width: (box.maxWidth - 16) / 3,
                  child: _card(
                    pad: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${metric.$2}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _forest,
                          ),
                        ),
                        Text(
                          metric.$1,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '3 chapatis and 1 rice portion per tiffin',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bhaji portions breakdown',
                style: TextStyle(
                  color: _forest,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.error != null)
                Text(widget.error!)
              else if (count.bhajis.isEmpty)
                const Text('No selected bhajis in the active queue.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in count.bhajis.entries)
                      _chip(
                        '${e.key}: ${e.value} portions',
                        _forest,
                        const Color(0x1A1B3B2B),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              const Text(
                'Each order-item row is one selected portion. Includes extra bhajis.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (busy) const LinearProgressIndicator(),
        for (final state in ['Confirmed', 'Preparing', 'Packed']) ...[
          const SizedBox(height: 24),
          Text(
            '${switch (state) {
              'Confirmed' => 'New Orders',
              'Preparing' => 'Preparing',
              _ => 'Ready for Pickup',
            }} (${d.todayOrders.where((o) => o['status'] == state).length})',
            style: const TextStyle(
              color: _forest,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          if (!d.todayOrders.any((o) => o['status'] == state))
            const _EmptyNote('No orders in this queue.'),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final o in d.todayOrders.where((o) => o['status'] == state))
                SizedBox(
                  width: _cw(context),
                  child: _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${'${o['id']}'.substring(0, 6).toUpperCase()} · ${_slot(o)}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.nameOf(o),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: _forest,
                          ),
                        ),
                        Text(
                          '${o['quantity'] ?? 0} tiffin(s) · ${o['subscription_id'] == null ? 'One-time' : 'Subscription'}',
                        ),
                        if (state == 'Confirmed')
                          Text(
                            age(o),
                            style: const TextStyle(
                              color: _saffron,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          widget.items
                              .where((i) => i['order_id'] == o['id'])
                              .map((i) => '${i['item_name']}')
                              .join(' · '),
                        ),
                        if ('${o['instructions'] ?? ''}'.isNotEmpty)
                          Text('Note: ${o['instructions']}'),
                        if (state == 'Packed')
                          Text('Partner: ${d.riderName(o['assigned_to'])}'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (state == 'Confirmed') ...[
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => act(o, 'Accept Order', 'Preparing'),
                                child: const Text('Accept Order'),
                              ),
                              if (widget.role == 'owner')
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            act(o, 'Reject order', 'Cancelled'),
                                  child: const Text('Reject'),
                                ),
                            ] else if (state == 'Preparing')
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => act(
                                        o,
                                        'Mark Ready for Pickup',
                                        'Packed',
                                      ),
                                child: const Text('Mark Ready for Pickup'),
                              )
                            else
                              FilledButton(
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
                                child: const Text('Confirm Handover'),
                              ),
                          ],
                        ),
                        if (state == 'Preparing' && widget.role == 'owner')
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => act(o, 'Reject order', 'Cancelled'),
                            child: const Text('Reject'),
                          ),
                        if (state == 'Packed' &&
                            (o['payment_status'] != 'verified' ||
                                o['assigned_to'] == null))
                          const Text(
                            'Verify payment and assign a rider in All Orders before handover.',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
                      style: const TextStyle(
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
