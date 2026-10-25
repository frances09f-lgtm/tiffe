#!/usr/bin/env python3
"""Staff v6: Upcoming list in Live Kitchen and newest-first All Orders.

Touches only lib/staff/partner_hub.dart display code, plus the paired version
bump in pubspec.yaml and lib/live/bug_report.dart. Payment, login, role and
order-action code is not edited. Safe to re-run: it does nothing once applied.
"""
import pathlib
import sys

HUB = pathlib.Path('lib/staff/partner_hub.dart')
PUB = pathlib.Path('pubspec.yaml')
BUG = pathlib.Path('lib/live/bug_report.dart')


def swap(text, old, new, label):
    if text.count(old) != 1:
        sys.exit(f'patch anchor not found exactly once: {label}')
    return text.replace(old, new)


hub = HUB.read_text()
if 'get upcomingOrders' not in hub:
    hub = swap(
        hub,
        """  List<Map<String, dynamic>> get todayOrders => [
    for (final o in orders)
      if (o['delivery_date'] == today) o,
  ];
""",
        """  List<Map<String, dynamic>> get todayOrders => [
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
""",
        'upcoming getter',
    )
    hub = swap(
        hub,
        """    return [...rows]..sort((a, b) {
      final c = '${a['delivery_date']}'.compareTo('${b['delivery_date']}');
      if (c != 0) return filter == 'Open' ? c : -c;
      return (a['meal'] == 'dinner' ? 1 : 0).compareTo(
        b['meal'] == 'dinner' ? 1 : 0,
      );
    });""",
        """    // Newest order first, so a fresh order is the top card.
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
    });""",
        'newest-first sort',
    )
    hub = swap(
        hub,
        """  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final count = KitchenCounts.from(d, widget.items);""",
        """  Widget upcomingCard(AdminData d) {
    final rows = d.upcomingOrders;
    return _card(
      pad: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: _muted),
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
          const Text(
            'Later delivery dates. Not counted in the totals above.',
            style: TextStyle(fontSize: 9, color: _muted),
          ),
          const Divider(color: _creamMuted, height: 24),
          if (rows.isEmpty)
            const Text(
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Delivery ${o['delivery_date']} • ${o['status']}',
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d.nameOf(o),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Qty: ${o['quantity'] ?? 0} Tiffin (${((o['quantity'] as num?)?.toInt() ?? 0) * 3} Chapatis, ${o['quantity'] ?? 0} Rice)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
                          style: const TextStyle(
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
    final count = KitchenCounts.from(d, widget.items);""",
        'upcoming card',
    )
    hub = swap(
        hub,
        """          ),
        ],
      ],
    );
  }
}

class _Fleet extends StatelessWidget {""",
        """          ),
        ],
        const SizedBox(height: 18),
        upcomingCard(d),
      ],
    );
  }
}

class _Fleet extends StatelessWidget {""",
        'upcoming placement',
    )
    HUB.write_text(hub)

pub = PUB.read_text()
if 'version: 1.0.49+49' not in pub:
    PUB.write_text(swap(pub, 'version: 1.0.47+47', 'version: 1.0.49+49', 'pubspec version'))
bug = BUG.read_text()
if "appVersion = '1.0.49+49'" not in bug:
    BUG.write_text(swap(bug, "appVersion = '1.0.47+47'", "appVersion = '1.0.49+49'", 'bug_report version'))
print('staff v6 patch applied')
