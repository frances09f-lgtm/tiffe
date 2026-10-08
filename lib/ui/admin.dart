import 'package:flutter/material.dart';

import 'admin_ops.dart';

import '../domain/tiffin.dart';
import 'app.dart' show cream, green, ink, muted, panel;

const stages = [
  'Confirmed',
  'Preparing',
  'Packed',
  'Out for Delivery',
  'Delivered',
];

class KitchenOrder {
  final String id, name, area;
  final List<List<String>> tiffins;
  String status;
  KitchenOrder(
    this.id,
    this.name,
    this.area,
    this.tiffins, {
    this.status = 'Confirmed',
  });
  int get extras =>
      tiffins.fold(0, (n, ids) => n + (ids.length > 2 ? ids.length - 2 : 0));
}

List<KitchenOrder> demoOrders() => [
  KitchenOrder('TF-1041', 'Aditi Kulkarni', 'Kothrud', [
    ['batata', 'matki'],
  ], status: 'Preparing'),
  KitchenOrder('TF-1042', 'Rohan Deshmukh', 'Baner', [
    ['baingan', 'matki', 'mix'],
    ['batata', 'cabbage'],
  ], status: 'Packed'),
  KitchenOrder('TF-1043', 'Neha Patil', 'Aundh', [
    ['vatana', 'aloo'],
  ], status: 'Confirmed'),
  KitchenOrder('TF-1044', 'Sameer Joshi', 'Wakad', [
    ['mirchi', 'batata', 'matki'],
  ], status: 'Out for Delivery'),
  KitchenOrder('TF-1045', 'Priya Shah', 'Kothrud', [
    ['mix', 'cabbage'],
    ['aloo', 'vatana', 'baingan'],
  ], status: 'Preparing'),
  KitchenOrder('TF-1046', 'Aniket Pawar', 'Baner', [
    ['batata', 'matki'],
  ], status: 'Delivered'),
];
Map<String, int> demand(List<KitchenOrder> orders) {
  final counts = {for (final b in menu) b.id: 0};
  for (final o in orders.where(
    (o) => !['Cancelled', 'Refunded', 'Failed'].contains(o.status),
  )) {
    for (final t in o.tiffins) {
      for (final b in t) {
        counts[b] = (counts[b] ?? 0) + 1;
      }
    }
  }
  return counts;
}

class KitchenApp extends StatelessWidget {
  const KitchenApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tiffe Kitchen',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'TiffeSans',
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: cream,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'TiffeSans'),
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'TiffeSans'),
        ),
      ),
    ),
    home: const AdminOps(),
  );
}

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({super.key});
  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
  String filter = 'All';
  String query = '';
  int tab = 0;
  final orders = demoOrders();
  Widget heading(String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 7),
      Text(sub, style: const TextStyle(color: muted, fontSize: 14)),
    ],
  );
  Widget metric(String label, String value, IconData icon) => panel(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0E3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: green,
                ),
              ),
              Text(label, style: const TextStyle(color: muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.sizeOf(c).width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Container(
              width: 230,
              padding: const EdgeInsets.all(24),
              color: green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.bento_rounded, color: cream, size: 36),
                  const SizedBox(height: 10),
                  const Text(
                    'Tiffe',
                    style: TextStyle(
                      color: cream,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'KITCHEN & DELIVERY',
                    style: TextStyle(
                      color: Color(0xFFC6D6C0),
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 42),
                  ...[
                    'Overview',
                    'Orders',
                    'Daily menu',
                    'Delivery',
                  ].asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: tab == e.key
                            ? const Color(0xFF427156)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Icon(
                            [
                              Icons.space_dashboard_outlined,
                              Icons.receipt_long_outlined,
                              Icons.restaurant_menu,
                              Icons.delivery_dining,
                            ][e.key],
                            color: cream,
                          ),
                          title: Text(
                            e.value,
                            style: const TextStyle(color: cream, fontSize: 14),
                          ),
                          onTap: () => setState(() => tab = e.key),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Made at home.\nMade for Pune.',
                    style: TextStyle(color: Color(0xFFC6D6C0), height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Demo workspace',
                    style: TextStyle(color: Color(0xFFC6D6C0), fontSize: 11),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE7E9DD)),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          const Text(
                            'Tiffe Kitchen',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: green,
                            ),
                          ),
                        if (wide)
                          const Text(
                            'Kitchen workspace',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        const Spacer(),
                        const Chip(
                          label: Text(
                            'Demo data',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE8EEDF),
                          child: Icon(Icons.person_outline, color: green),
                        ),
                      ],
                    ),
                  ),
                  if (!wide)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          4,
                          (i) => Padding(
                            padding: const EdgeInsets.all(6),
                            child: ChoiceChip(
                              label: Text(
                                [
                                  'Overview',
                                  'Orders',
                                  'Daily menu',
                                  'Delivery',
                                ][i],
                              ),
                              selected: tab == i,
                              onSelected: (_) => setState(() => tab = i),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 28 : 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: tab == 0
                            ? overview()
                            : tab == 1
                            ? orderPage()
                            : tab == 2
                            ? menuPage()
                            : deliveryPage(),
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

  Widget overview() {
    final counts = demand(orders);
    final tiffins = orders.fold(0, (n, o) => n + o.tiffins.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Good food starts here.',
          'Today’s kitchen plan · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (c, b) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final m in [
                ('Today’s tiffins', '$tiffins', Icons.bento_outlined),
                (
                  'Extra portions',
                  '${orders.fold(0, (n, o) => n + o.extras)}',
                  Icons.add_circle_outline,
                ),
                (
                  'Ready to dispatch',
                  '${orders.where((o) => o.status == 'Packed').length}',
                  Icons.inventory_2_outlined,
                ),
              ])
                SizedBox(
                  width: b.maxWidth >= 700 ? (b.maxWidth - 32) / 3 : b.maxWidth,
                  child: metric(m.$1, m.$2, m.$3),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (c, b) => Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(
                width: b.maxWidth >= 850 ? (b.maxWidth - 20) * .56 : b.maxWidth,
                child: panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bhaji demand',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Calculated from every tiffin selection',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ...menu.map(
                        (bh) => Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  bh.image,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bh.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    LinearProgressIndicator(
                                      value: counts[bh.id]! / 6,
                                      minHeight: 4,
                                      color: green,
                                      backgroundColor: const Color(0xFFEAF0E3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Text(
                                '${counts[bh.id]}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: b.maxWidth >= 850 ? (b.maxWidth - 20) * .44 : b.maxWidth,
                child: panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today’s orders',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'A calm view of a busy kitchen.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      ...orders
                          .take(5)
                          .map(
                            (o) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          o.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: ink,
                                          ),
                                        ),
                                        Text(
                                          '${o.id} · ${o.tiffins.length} tiffin${o.tiffins.length > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  statusChip(o.status),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => tab = 1),
                        child: const Text('Manage all orders'),
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
  }

  Widget statusChip(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: status == 'Delivered'
          ? const Color(0xFFE2EFDB)
          : status == 'Packed'
          ? const Color(0xFFFFECCD)
          : const Color(0xFFF0F2EB),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: const TextStyle(
        fontSize: 11,
        color: green,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget orderPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Every dabba, accounted for.',
        'Customer choices, kitchen progress and dispatch.',
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: 480,
        child: TextField(
          onChanged: (v) => setState(() => query = v.toLowerCase()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search order ID, customer or Pune area',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E6D8)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['All', ...stages]
            .map(
              (s) => ChoiceChip(
                label: Text(
                  '$s (${orders.where((o) => s == 'All' || o.status == s).length})',
                ),
                selected: filter == s,
                onSelected: (_) => setState(() => filter = s),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      ...orders
          .where(
            (o) =>
                (filter == 'All' || o.status == filter) &&
                ('${o.id} ${o.name} ${o.area}'.toLowerCase().contains(query)),
          )
          .map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${o.id} · ${o.name}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        statusChip(o.status),
                        Text(
                          '${o.tiffins.length} tiffins · ${o.area}',
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...o.tiffins.asMap().entries.map(
                      (e) => Text(
                        'Tiffin ${e.key + 1}: ${e.value.map((id) => menu.firstWhere((b) => b.id == id).name).join(' + ')}',
                        style: const TextStyle(color: ink, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: stages
                          .map(
                            (s) => ChoiceChip(
                              label: Text(
                                s,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: o.status == s,
                              onSelected: (_) => setState(() => o.status = s),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
    ],
  );
  Widget menuPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Today’s eight favourites.',
        'A fresh menu for ${DateTime.now().day}/${DateTime.now().month} · Demo menu',
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (c, b) => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: menu
              .map(
                (bh) => SizedBox(
                  width: b.maxWidth >= 800
                      ? (b.maxWidth - 48) / 4
                      : (b.maxWidth - 16) / 2,
                  child: panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            bh.image,
                            width: double.infinity,
                            height: 130,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bh.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bh.description,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Available',
                          style: TextStyle(color: green, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 24),
      panel(
        child: const Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: green),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Sunday sweet: Sheera\nFor active subscribers only',
                style: TextStyle(color: ink),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Menu editing and publishing arrive in the next admin update.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
  Widget deliveryPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'The last mile, made simple.',
        'Demo dispatch board · real customer contact data is not loaded',
      ),
      const SizedBox(height: 24),
      ...orders
          .where(
            (o) =>
                o.status == 'Packed' ||
                o.status == 'Out for Delivery' ||
                o.status == 'Delivered',
          )
          .map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        Text(
                          o.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        statusChip(o.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${o.id} · ${o.tiffins.length} tiffins · ${o.area}, Pune',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      o.tiffins
                          .map(
                            (t) => t
                                .map(
                                  (id) =>
                                      menu.firstWhere((b) => b.id == id).name,
                                )
                                .join(' + '),
                          )
                          .join('\n'),
                      style: const TextStyle(color: ink, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        const OutlinedButton(
                          onPressed: null,
                          child: Text('Navigate'),
                        ),
                        const OutlinedButton(
                          onPressed: null,
                          child: Text('Call'),
                        ),
                        FilledButton(
                          onPressed: o.status == 'Delivered'
                              ? null
                              : () => setState(() => o.status = 'Delivered'),
                          child: Text(
                            o.status == 'Delivered'
                                ? 'Delivered'
                                : 'Mark delivered',
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
}
