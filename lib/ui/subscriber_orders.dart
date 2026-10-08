import 'package:flutter/material.dart';

import '../data/store.dart';
import '../domain/tiffin.dart';
import 'app.dart' show green, cream, ink, muted, panel, dayLabel, SelectionPage;

bool canChangeBhaji(DateTime delivery, DateTime now) =>
    now.isBefore(DateTime(delivery.year, delivery.month, delivery.day, 9));

class SubscriberOrders extends StatelessWidget {
  final TiffeStore store;
  final DateTime? clock;
  const SubscriberOrders({super.key, required this.store, this.clock});
  DateTime get now => clock ?? DateTime.now();
  DateTime get today => DateTime(now.year, now.month, now.day);
  List<String> picks(DateTime date, int tiffin) {
    final ids = store.selected(date, tiffin);
    return ids.isEmpty ? store.usual : ids;
  }

  Widget label(String value) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
    child: Text(
      value,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
  );
  Widget pill(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFE4EDDF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: green,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget meals(DateTime date, {bool history = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < Pricing.quantity(store.plan); i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiffin ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              const SizedBox(height: 3),
              Text(
                picks(date, i)
                    .map((id) => menu.firstWhere((b) => b.id == id).name)
                    .join(' + '),
                style: const TextStyle(color: ink, fontSize: 14),
              ),
              if (!history && store.selected(date, i).isEmpty)
                const Text(
                  'My Usual',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ),
        ),
      const Text(
        '3 Chapati + Rice per tiffin',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      if (Pricing.sweet(date, store.plan)) ...[
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.cake_outlined, color: green, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sunday Sweet Included\nFree for subscribers',
                style: TextStyle(
                  color: green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
  void details(BuildContext c, DateTime date) => showDialog(
    context: c,
    builder: (c) => AlertDialog(
      title: Text('Your Tiffe · ${dayLabel(date)}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            meals(date),
            const SizedBox(height: 14),
            Text('Covered by your ₹${Pricing.monthly(store.plan)}/month plan'),
            Text(
              'Extra bhajis: ₹${List.generate(Pricing.quantity(store.plan), (i) => Pricing.extras(picks(date, i).length)).fold(0, (a, b) => a + b)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Delivery: ₹199/month, charged with your subscription. No per-meal base charge.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Widget dayCard(
    BuildContext c,
    DateTime date, {
    required bool future,
  }) => panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bento_outlined, color: green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${Pricing.quantity(store.plan)} Tiffin${store.plan == Plan.double ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            pill(future ? 'Scheduled' : 'Preparing'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          dayLabel(date),
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        meals(date),
        const SizedBox(height: 12),
        Text(
          'Covered by your ₹${Pricing.monthly(store.plan)}/month plan',
          style: const TextStyle(
            color: green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (future)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canChangeBhaji(date, now)
                  ? () {
                      if (!canChangeBhaji(date, clock ?? DateTime.now())) {
                        return;
                      }
                      Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) =>
                              SelectionPage(store: store, date: date),
                        ),
                      );
                    }
                  : null,
              child: const Text('Change Bhaji'),
            ),
          ),
        if (future)
          const Text(
            'Change before 9:00 AM on delivery day',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        if (!future)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => details(c, date),
              child: const Text('View Details'),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: store,
    builder: (c, _) => ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      children: [
        const Text(
          'Your daily Tiffe.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A meal plan. Not a daily checkout.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        panel(
          color: green,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Tiffe Plan',
                style: TextStyle(
                  color: cream,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '₹${Pricing.monthly(store.plan)}/month · ${Pricing.quantity(store.plan)} Tiffin${store.plan == Plan.double ? 's' : ''} Daily',
                style: const TextStyle(color: cream, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  pill('Active'),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Next delivery: Today',
                      style: TextStyle(color: cream, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        label('Today'),
        dayCard(c, today, future: false),
        label('Tomorrow'),
        dayCard(c, today.add(const Duration(days: 1)), future: true),
        label('History'),
        const SizedBox(height: 10),
        for (var ago = 1; ago <= 2; ago++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dayLabel(today.subtract(Duration(days: ago))),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      pill('Delivered'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  meals(today.subtract(Duration(days: ago)), history: true),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
