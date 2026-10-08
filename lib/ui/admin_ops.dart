import 'package:flutter/material.dart';

import '../domain/tiffin.dart';
import 'app.dart' show cream, green, ink, muted, panel;
import 'admin.dart' show KitchenOrder, demoOrders, demand, stages;

const destinations = [
  'Dashboard',
  'Orders',
  'Subscriptions',
  'Customers',
  'Daily Menu',
  'Bhajis',
  'Sunday Sweet',
  'Kitchen',
  'Packing',
  'Delivery',
  'Payments',
  'Reports',
  'Staff',
  'Settings',
  'Notifications',
  'Audit Log',
];
const navIcons = [
  Icons.dashboard_outlined,
  Icons.receipt_long_outlined,
  Icons.event_repeat,
  Icons.people_outline,
  Icons.restaurant_menu,
  Icons.eco_outlined,
  Icons.cake_outlined,
  Icons.soup_kitchen_outlined,
  Icons.inventory_2_outlined,
  Icons.delivery_dining,
  Icons.account_balance_wallet_outlined,
  Icons.bar_chart,
  Icons.badge_outlined,
  Icons.settings_outlined,
  Icons.notifications_outlined,
  Icons.history,
];

class AdminOps extends StatefulWidget {
  const AdminOps({super.key});
  @override
  State<AdminOps> createState() => _AdminOpsState();
}

class _AdminOpsState extends State<AdminOps> {
  bool signedIn = false, published = false, usual = true;
  String role = 'Owner',
      page = 'Dashboard',
      filter = 'All',
      query = '',
      sweet = 'Gulab Jamun',
      target = 'Active subscribers';
  final orders = demoOrders();
  final prepared = <String, int>{};
  final packing = <String, Set<String>>{};
  final assigned = <String, String>{'TF-1044': 'Rahul', 'TF-1046': 'Rahul'};
  final unavailable = <String>{};
  final audit = <String>[];
  final areas = <String, bool>{
    'Kothrud': true,
    'Baner': true,
    'Wakad': true,
    'Hinjawadi': false,
    'Viman Nagar': false,
    'Aundh': true,
    'Hadapsar': false,
  };
  final prices = <String, int>{
    'Daily subscription / month': 1500,
    'Double subscription / month': 3000,
    'One-time tiffin': 80,
    'Extra bhaji': 10,
    'Subscription delivery / month': 199,
    'One-time delivery': 20,
  };
  final notes = TextEditingController();
  String cutoff = '09:00 AM',
      pause = '12 Oct - 16 Oct',
      subscription = 'Active';
  List<String> get allowed => role == 'Owner'
      ? destinations
      : role == 'Kitchen'
      ? ['Daily Menu', 'Orders', 'Bhajis', 'Kitchen', 'Packing']
      : ['Delivery'];
  List<KitchenOrder> get active => orders
      .where((o) => !['Cancelled', 'Failed', 'Refunded'].contains(o.status))
      .toList();
  List<KitchenOrder> get visible => role == 'Delivery'
      ? orders.where((o) => assigned[o.id] == 'Rahul').toList()
      : orders;
  int get quantity => active.fold(0, (n, o) => n + o.tiffins.length);
  void change(String message, VoidCallback fn) {
    setState(() {
      fn();
      audit.insert(0, '${TimeOfDay.now().format(context)} | $role | $message');
    });
  }

  void go(String v) {
    if (allowed.contains(v)) setState(() => page = v);
  }

  Widget title(String a, String b) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(b, style: const TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
  Widget badge(String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: v == 'Delivered' || v == 'Paid'
          ? const Color(0xFFE3EEDD)
          : v == 'Packed'
          ? const Color(0xFFFFEDCE)
          : const Color(0xFFF0F2EB),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      v,
      style: const TextStyle(
        color: green,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget button(String label, VoidCallback? fn) =>
      FilledButton(onPressed: fn, child: Text(label));
  Widget tiles(List<(String, String, IconData)> items) => LayoutBuilder(
    builder: (c, b) => Wrap(
      spacing: 14,
      runSpacing: 14,
      children: items
          .map(
            (m) => SizedBox(
              width: b.maxWidth >= 800
                  ? (b.maxWidth - 42) / 4
                  : b.maxWidth >= 500
                  ? (b.maxWidth - 14) / 2
                  : b.maxWidth,
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(m.$3, color: green, size: 23),
                    const SizedBox(height: 18),
                    Text(
                      m.$2,
                      style: const TextStyle(
                        fontSize: 29,
                        color: green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      m.$1,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
  Widget section(String label, Widget child) => panel(
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
  Widget two(Widget a, Widget b) => LayoutBuilder(
    builder: (c, s) => s.maxWidth >= 900
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: a),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: b),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: 18), b],
          ),
  );
  Widget field(String label, String value, {ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!signedIn) return login();
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Scaffold(
      drawer: wide ? null : Drawer(backgroundColor: green, child: nav()),
      body: Row(
        children: [
          if (wide) SizedBox(width: 224, child: nav()),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    color: Colors.white,
                    child: Row(
                      children: [
                        if (!wide)
                          Builder(
                            builder: (c) => IconButton(
                              onPressed: () => Scaffold.of(c).openDrawer(),
                              icon: const Icon(Icons.menu),
                            ),
                          ),
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => query = v.toLowerCase()),
                            onSubmitted: (_) => go('Orders'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search orders, customers or area',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        badge('Demo only'),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          backgroundColor: cream,
                          child: Text(
                            role.substring(0, 1),
                            style: const TextStyle(color: green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 28 : 18),
                      child: SizedBox(width: double.infinity, child: content()),
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

  Widget nav() => Material(
    color: green,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Icon(Icons.bento_rounded, color: cream, size: 29),
                SizedBox(width: 12),
                Text(
                  'Tiffe',
                  style: TextStyle(
                    color: cream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 0, 16),
            child: Text(
              'PLAN · PREPARE · DELIVER',
              style: TextStyle(
                color: Color(0xFFC7D7C2),
                fontSize: 9,
                letterSpacing: 1.3,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: allowed
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: ListTile(
                        dense: true,
                        selected: s == page,
                        selectedTileColor: const Color(0xFF427156),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          navIcons[destinations.indexOf(s)],
                          color: cream,
                          size: 20,
                        ),
                        title: Text(
                          s,
                          style: const TextStyle(color: cream, fontSize: 13),
                        ),
                        onTap: () {
                          go(s);
                          if (MediaQuery.sizeOf(context).width < 1100) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(color: Colors.white24),
          Text(
            '$role workspace',
            style: const TextStyle(color: cream, fontWeight: FontWeight.w700),
          ),
          TextButton.icon(
            onPressed: () => setState(() => signedIn = false),
            icon: const Icon(Icons.logout, color: cream, size: 18),
            label: const Text('Logout', style: TextStyle(color: cream)),
          ),
        ],
      ),
    ),
  );
  Widget login() => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bento_rounded, color: green, size: 46),
                const SizedBox(height: 12),
                const Text(
                  'Tiffe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    color: green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Rozcha dabba. Tumchya choice cha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Plan the day. Feed the city.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 24),
                field('Email / Mobile', '', onChanged: (_) => {}),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Demo role'),
                  items: ['Owner', 'Kitchen', 'Delivery']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (s) => setState(() => role = s!),
                ),
                const SizedBox(height: 20),
                button(
                  'Enter demo',
                  () => setState(() {
                    signedIn = true;
                    page = allowed.first;
                  }),
                ),
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Password recovery'),
                      content: const Text(
                        'No accounts are connected in this UI preview. Secure login and recovery require the backend.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
                const Text(
                  'UI preview only. Do not enter real credentials.\nNo secure authentication, saved sessions or live customer data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget content() {
    switch (page) {
      case 'Dashboard':
        return overview();
      case 'Orders':
        return orderPage();
      case 'Kitchen':
        return kitchen();
      case 'Packing':
        return pack();
      case 'Daily Menu':
      case 'Bhajis':
        return menuPage();
      case 'Delivery':
        return delivery();
      case 'Subscriptions':
        return subscriptions();
      case 'Customers':
        return customers();
      case 'Sunday Sweet':
        return sweets();
      case 'Payments':
        return payments();
      case 'Reports':
        return reports();
      case 'Staff':
        return staff();
      case 'Settings':
        return settings();
      case 'Notifications':
        return notifications();
      case 'Audit Log':
        return auditPage();
      default:
        return const SizedBox();
    }
  }

  Widget overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Good morning, Tiffe.',
        'Today\'s operations · 9 Oct 2026 · Fictional demo dataset',
      ),
      tiles([
        ('Today\'s tiffins', '$quantity', Icons.bento_outlined),
        ('Active subscribers', '4', Icons.people_outline),
        ('Today\'s revenue', '₹5,008', Icons.payments_outlined),
        (
          'Pending delivery',
          '${active.where((o) => o.status != 'Delivered').length}',
          Icons.delivery_dining,
        ),
      ]),
      const SizedBox(height: 20),
      section(
        'Today, from stove to doorstep',
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: stages
              .map(
                (s) => ActionChip(
                  label: Text(
                    '$s   ${active.where((o) => o.status == s).length}',
                  ),
                  onPressed: () => setState(() {
                    page = 'Orders';
                    filter = s;
                  }),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 20),
      two(
        section('Bhaji demand', demandRows(edit: false)),
        section(
          'Needs your attention',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              alert('Preparation still needed', 'Kitchen'),
              alert('Tomorrow\'s menu is not published', 'Daily Menu'),
              alert('1 pending payment', 'Payments'),
              alert('Review service areas', 'Settings'),
              const SizedBox(height: 14),
              const Text(
                '8 tiffins · 24 chapatis · 8 rice portions',
                style: TextStyle(color: green, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget alert(String text, String destination) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFA87728)),
    title: Text(text, style: const TextStyle(fontSize: 13)),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () => go(destination),
  );
  Widget demandRows({required bool edit}) {
    final d = demand(active);
    return Column(
      children: menu.map((b) {
        final n = d[b.id] ?? 0;
        final p = prepared[b.id] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  b.image,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Required $n · Prepared $p · Remaining ${n > p ? n - p : 0}',
                      style: TextStyle(
                        fontSize: 11,
                        color: n > p ? const Color(0xFFA87728) : muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: n == 0 ? 1 : (p / n).clamp(0, 1),
                      minHeight: 4,
                      color: green,
                      backgroundColor: cream,
                    ),
                  ],
                ),
              ),
              if (edit)
                IconButton(
                  onPressed: p >= n
                      ? null
                      : () => change(
                          'Prepared ${b.name}',
                          () => prepared[b.id] = p + 1,
                        ),
                  icon: const Icon(Icons.add_circle_outline, color: green),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget kitchen() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Cook with a clear plan.',
        'Kitchen · 9 Oct 2026 · Excludes cancelled, failed and refunded orders',
      ),
      tiles([
        ('Tiffins', '$quantity', Icons.bento),
        ('Chapatis required', '${quantity * 3}', Icons.restaurant),
        ('Rice portions', '$quantity', Icons.rice_bowl),
        (
          'Extra bhaji portions',
          '${active.fold(0, (n, o) => n + o.extras)}',
          Icons.add_circle_outline,
        ),
      ]),
      const SizedBox(height: 20),
      two(
        section('Preparation quantities', demandRows(edit: true)),
        section(
          'Kitchen handover',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Prepare bhajis to the required count.\n2. Track prepared portions with +.\n3. Pack each tiffin against its own selections.',
                style: TextStyle(color: muted, height: 1.8),
              ),
              const SizedBox(height: 20),
              button('Open packing checklist', () => go('Packing')),
              const SizedBox(height: 18),
              const Text(
                'Quantities reflect this demo dataset. Updates reset when the app restarts.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget pack() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Every tiffin. Checked twice.',
        'Packing · Confirmed and Preparing orders · Check all items before packing',
      ),
      ...active.where((o) => ['Confirmed', 'Preparing'].contains(o.status)).map((
        o,
      ) {
        final items = [
          for (var i = 0; i < o.tiffins.length; i++) ...[
            'Tiffin ${i + 1}: 3 Chapati',
            'Tiffin ${i + 1}: Rice',
            ...o.tiffins[i].map(
              (id) =>
                  'Tiffin ${i + 1}: ${menu.firstWhere((b) => b.id == id).name}',
            ),
          ],
        ];
        final checked = packing.putIfAbsent(o.id, () => {});
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: section(
            '${o.id} · ${o.name} · ${o.tiffins.length} tiffins',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: items
                      .map(
                        (s) => FilterChip(
                          label: Text(s),
                          selected: checked.contains(s),
                          onSelected: (v) => setState(
                            () => v ? checked.add(s) : checked.remove(s),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: button(
                    'Mark Packed',
                    checked.length == items.length
                        ? () => change(
                            '${o.id} marked Packed',
                            () => o.status = 'Packed',
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );
  Widget orderPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Every dabba, accounted for.',
        'Order details and status history · 9 Oct 2026',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['All', ...stages, 'Cancelled', 'Failed', 'Refunded']
            .map(
              (s) => ChoiceChip(
                label: Text(s),
                selected: filter == s,
                onSelected: (_) => setState(() => filter = s),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      ...visible
          .where(
            (o) =>
                (filter == 'All' || o.status == filter) &&
                '${o.id} ${o.name} ${o.area}'.toLowerCase().contains(query),
          )
          .map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: section(
                '${o.id} · ${o.name}',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      children: [
                        badge(o.status),
                        Text(
                          '${o.area} · ${o.tiffins.length} tiffins · ${o.id == 'TF-1043' || o.id == 'TF-1044' ? 'One-time' : 'Subscription'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...o.tiffins.asMap().entries.map(
                      (e) => Text(
                        'Tiffin ${e.key + 1}: ${e.value.map((id) => menu.firstWhere((b) => b.id == id).name).join(' + ')}',
                        style: const TextStyle(fontSize: 13, height: 1.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: () => details(o),
                          child: const Text('View details'),
                        ),
                        DropdownButton<String>(
                          value: o.status,
                          items: [...stages, 'Cancelled', 'Failed', 'Refunded']
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (s) => change(
                            '${o.id}: ${o.status} to $s',
                            () => o.status = s!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    ],
  );
  void details(KitchenOrder o) => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('${o.id} · ${o.name}'),
      content: Text(
        'Fictional customer · Phone not loaded\n${o.area}, Pune · Street address not loaded\n${o.tiffins.length} tiffins · ${o.extras} extra bhajis\nExtras: ₹${o.extras * 10}\nOne-time base ₹80/tiffin + ₹20 delivery\nSubscription: monthly delivery ₹199, not charged per order\nSweet: none (Friday)\nStatus: ${o.status}\nCreated: 9 Oct 2026, 08:00 (demo)\nDelivery instruction: call at gate (demo)',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Widget menuPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        page == 'Bhajis'
            ? 'Eight favourites, one kitchen.'
            : 'Plan tomorrow\'s plate.',
        'Demo menu · Exactly 8 bhajis · 9 Oct 2026',
      ),
      Wrap(
        spacing: 12,
        children: [
          badge(published ? 'Published locally' : 'Draft'),
          button(
            'Publish demo menu',
            () => change('Menu published in demo', () => published = true),
          ),
        ],
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (c, b) => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: menu
              .map(
                (m) => SizedBox(
                  width: b.maxWidth >= 900
                      ? (b.maxWidth - 48) / 4
                      : b.maxWidth >= 500
                      ? (b.maxWidth - 16) / 2
                      : b.maxWidth,
                  child: panel(
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              m.image,
                              width: double.infinity,
                              height: 130,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.description,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Available',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: !unavailable.contains(m.id),
                            onChanged: (v) => change(
                              '${m.name} availability: $v',
                              () => v
                                  ? unavailable.remove(m.id)
                                  : unavailable.add(m.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Catalog editing, food uploads and customer-app publishing are not connected. Historical order selections stay unchanged.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
    ],
  );
  Widget subscriptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Keep the daily habit going.',
        'Demo subscriptions · ₹1,500 Daily / ₹3,000 Double · Delivery ₹199/month',
      ),
      tiles([
        ('Active', '4', Icons.event_available),
        ('Paused', '1', Icons.pause_circle_outline),
        ('Renewing this week', '2', Icons.update),
        ('Expired', '1', Icons.event_busy),
      ]),
      const SizedBox(height: 20),
      section(
        'Subscription register',
        Column(
          children: [
            for (final name in [
              'Aditi Kulkarni',
              'Rohan Deshmukh',
              'Priya Shah',
              'Aniket Pawar',
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                subtitle: const Text('1 Oct - 31 Oct 2026 · Paid'),
                trailing: badge('Active'),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      section(
        'Pause management · Rahul Patil',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily plan · $subscription'),
            const SizedBox(height: 14),
            field('Pause dates', pause, onChanged: (s) => pause = s),
            button(
              'Save demo pause',
              () => change(
                'Rahul pause changed: $pause',
                () => subscription = 'Paused',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Demo record only. Date validation and subscription scheduling require backend.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    ],
  );
  Widget customers() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'People behind every dabba.',
        'Fictional customer profiles · No live contacts',
      ),
      section(
        'Customer register',
        Column(
          children: orders
              .where((o) => '${o.name} ${o.area}'.toLowerCase().contains(query))
              .map(
                (o) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: cream,
                    child: Text(o.name.substring(0, 1)),
                  ),
                  title: Text(o.name),
                  subtitle: Text('${o.area}, Pune · Phone not loaded'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => details(o),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
  Widget delivery() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'The last mile, made simple.',
        '${role == 'Delivery' ? 'Rahul\'s assigned deliveries only' : 'Dispatch and assignments'} · Fictional addresses',
      ),
      tiles([
        ('Orders visible', '${visible.length}', Icons.receipt),
        (
          'Delivered',
          '${visible.where((o) => o.status == 'Delivered').length}',
          Icons.check_circle_outline,
        ),
        (
          'On the road',
          '${visible.where((o) => o.status == 'Out for Delivery').length}',
          Icons.delivery_dining,
        ),
        (
          'Packed',
          '${visible.where((o) => o.status == 'Packed').length}',
          Icons.inventory_2_outlined,
        ),
      ]),
      const SizedBox(height: 20),
      ...visible
          .where(
            (o) =>
                ['Packed', 'Out for Delivery', 'Delivered'].contains(o.status),
          )
          .map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: section(
                '${o.id} · ${o.name}',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${o.area}, Pune · ${o.tiffins.length} tiffins'),
                    const SizedBox(height: 12),
                    badge(o.status),
                    const SizedBox(height: 12),
                    if (role == 'Owner')
                      DropdownButton<String>(
                        value: assigned[o.id],
                        hint: const Text('Assign delivery partner'),
                        items: ['Rahul', 'Sagar']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (s) => change(
                          '${o.id} assigned to $s',
                          () => assigned[o.id] = s!,
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      children: [
                        const OutlinedButton(
                          onPressed: null,
                          child: Text('Route unavailable'),
                        ),
                        button(
                          'Mark delivered',
                          o.status == 'Delivered'
                              ? null
                              : () => change(
                                  '${o.id} delivered',
                                  () => o.status = 'Delivered',
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Street address and phone not loaded. No calls or routes in this demo.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
    ],
  );
  Widget sweets() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'A little Sunday happiness.',
        'Sunday, 11 Oct 2026 · Subscribers only · One-time orders excluded',
      ),
      section(
        'Choose Sunday\'s sweet',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cake_outlined, size: 60, color: green),
            const SizedBox(height: 18),
            DropdownButton<String>(
              value: sweet,
              items: [
                'Gulab Jamun',
                'Shrikhand',
                'Basundi',
                'Sheera',
                'Puran Poli',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (s) =>
                  change('Sunday sweet changed to $s', () => sweet = s!),
            ),
            const SizedBox(height: 20),
            button(
              'Save Sunday sweet',
              () => change('Sunday sweet saved: $sweet', () => {}),
            ),
            const SizedBox(height: 16),
            const Text(
              'Local demo configuration. Sunday eligibility and cutoff enforcement require backend.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
  Widget payments() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Every rupee, accounted for.',
        'Illustrative receipts · No payment gateway or financial records connected',
      ),
      tiles([
        ('One-time paid', '₹110', Icons.payments_outlined),
        ('Subscription receipts', '₹4,898', Icons.event_repeat),
        ('Pending', '₹100', Icons.hourglass_empty),
        ('Refunded', '₹0', Icons.undo),
      ]),
      const SizedBox(height: 20),
      section(
        'Demo payment ledger',
        Column(
          children: [
            for (final row in [
              ('Rohan Deshmukh', '₹3,199', 'Paid'),
              ('Aditi Kulkarni', '₹1,699', 'Paid'),
              ('Sameer Joshi', '₹110', 'Paid'),
              ('Neha Patil', '₹100', 'Pending'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.$1),
                subtitle: Text('${row.$2} · 9 Oct 2026'),
                trailing: badge(row.$3),
              ),
          ],
        ),
      ),
    ],
  );
  Widget reports() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'See the pattern. Plan better.',
        'Demo report · Today · Counts derived from sample order selections',
      ),
      tiles([
        ('Orders', '${orders.length}', Icons.receipt),
        (
          'Completed',
          '${orders.where((o) => o.status == 'Delivered').length}',
          Icons.check_circle_outline,
        ),
        (
          'Cancelled',
          '${orders.where((o) => o.status == 'Cancelled').length}',
          Icons.cancel_outlined,
        ),
        (
          'Extra portions',
          '${active.fold(0, (n, o) => n + o.extras)}',
          Icons.add,
        ),
      ]),
      const SizedBox(height: 20),
      section(
        'Bhaji popularity · Today',
        Column(
          children: menu
              .map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          m.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (demand(active)[m.id] ?? 0) / 8,
                          minHeight: 14,
                          color: green,
                          backgroundColor: cream,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('${demand(active)[m.id]}'),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Date ranges, exports and revenue trends require historical backend data.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
  Widget staff() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'One kitchen. One team.',
        'Role preview · No real accounts or permissions created',
      ),
      section(
        'Team directory',
        Column(
          children: [
            for (final s in [
              ('Owner', 'Full access'),
              ('Kitchen', 'Menu, orders, preparation, packing'),
              ('Rahul · Delivery', 'Assigned deliveries only'),
              ('Sagar · Delivery', 'Assigned deliveries only'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined, color: green),
                title: Text(s.$1),
                subtitle: Text(s.$2),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Role-restricted demo navigation is not security. Authentication and backend authorization are still required.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Set the rules for a good day.',
        'Owner workspace · Local demo changes only',
      ),
      two(
        section(
          'Pricing · New orders only',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...prices.entries.map(
                (e) => field(
                  e.key,
                  '${e.value}',
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) prices[e.key] = n;
                  },
                ),
              ),
              button(
                'Save demo prices',
                () => change('Pricing saved locally', () => {}),
              ),
              const SizedBox(height: 12),
              const Text(
                'Production prices must be validated server-side. Historical orders retain their original amounts.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        section(
          'Daily cutoff',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field('Selection cutoff', cutoff, onChanged: (s) => cutoff = s),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Use My Usual fallback',
                  style: TextStyle(fontSize: 13),
                ),
                value: usual,
                onChanged: (s) => change('My Usual: $s', () => usual = s),
              ),
              button(
                'Save cutoff',
                () => change('Cutoff saved: $cutoff', () => {}),
              ),
              const SizedBox(height: 18),
              const Text(
                'After cutoff, selection edits are staff-only. Enforcement needs the backend.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      section(
        'Pune delivery areas',
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: areas.entries
              .map(
                (e) => FilterChip(
                  label: Text(e.key),
                  selected: e.value,
                  onSelected: (v) => change(
                    '${e.key} serviceable: $v',
                    () => areas[e.key] = v,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'These are example service areas, not a promise of coverage. Kitchen address and payment settings are not configured.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
  Widget notifications() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'The right update, to the right people.',
        'Notification composer · Preview only · No messages are sent',
      ),
      section(
        'Compose announcement',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: target,
              items: [
                'All customers',
                'Active subscribers',
                'One-time customers',
                'Specific customer',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (s) => setState(() => target = s!),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Announcement',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            button(
              'Preview announcement',
              () => showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('To: $target'),
                  content: Text(
                    notes.text.isEmpty
                        ? 'Enter an announcement first.'
                        : notes.text,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close preview'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget auditPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'A clear trail of every change.',
        'Session-only audit log · Demo actors · Resets on restart',
      ),
      section(
        'Recent activity',
        audit.isEmpty
            ? const Text(
                'No changes in this session yet.',
                style: TextStyle(color: muted),
              )
            : Column(
                children: audit
                    .map(
                      (s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history, color: green),
                        title: Text(s, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
              ),
      ),
    ],
  );
}
