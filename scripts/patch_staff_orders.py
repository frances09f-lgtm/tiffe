#!/usr/bin/env python3
"""Staff 1.0.8: every order in the Live Kitchen queues whatever its delivery date,
delivery date on each card, and the All Orders Today filter also lists orders
placed today. Idempotent. Run from the repo root."""
import pathlib

P = pathlib.Path('lib/staff/partner_hub.dart')
s = P.read_text()
if 'todayFilterOrders' in s:
    print('already applied')
    raise SystemExit(0)


def sub(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:70])
    s = s.replace(old, new)


sub("""  bool isActive(Map s) =>
      s['verified'] == true &&""", """  /// IST calendar day (yyyy-MM-dd) an order was placed on.
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
      s['verified'] == true &&""")
sub("      'Today' => d.todayOrders,", "      'Today' => d.todayFilterOrders,")
sub("    final rows = d.upcomingOrders;\n    return _card(", "    final rows = d.laterOrders;\n    return _card(")
sub("'Later delivery dates. Not counted in the totals above.'", "'Other orders for later delivery dates. Not counted in the totals above.'")
sub("PREPARING'\n                            : 'READY FOR PICKUP'} (${d.todayOrders.where((o) => o['status'] == state).length})'", "PREPARING'\n                            : 'READY FOR PICKUP'} (${d.queueFor(state).length})'")
sub("if (!d.todayOrders.any((o) => o['status'] == state))", "if (d.queueFor(state).isEmpty)")
sub("""for (final o in d.todayOrders.where(
                  (o) => o['status'] == state,
                ))""", "for (final o in d.queueFor(state))")
sub("""                                : 'Monthly Sub',
                            style: const TextStyle(fontSize: 10, color: _muted),
                          ),
                          const SizedBox(height: 12),""", """                                : 'Monthly Sub',
                            style: const TextStyle(fontSize: 10, color: _muted),
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
                          const SizedBox(height: 12),""")
sub("""        const SizedBox(height: 18),
        upcomingCard(d),
      ],""", """        if (d.laterOrders.isNotEmpty) ...[
          const SizedBox(height: 18),
          upcomingCard(d),
        ],
      ],""")
P.write_text(s)
print('patched')
