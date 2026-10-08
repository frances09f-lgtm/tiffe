import 'package:flutter/material.dart';

import 'scheduled_tracking.dart';
import '../domain/delivery_schedule.dart';

import '../data/store.dart';
import '../domain/tiffin.dart';
import 'app.dart' show panel, dayLabel, SelectionPage, TiffeState;

bool canChangeBhaji(DateTime delivery, DateTime now) =>
    now.isBefore(DateTime(delivery.year, delivery.month, delivery.day, 9));

class SubscriberOrders extends StatefulWidget {
  final TiffeStore store;
  final DateTime? clock;
  const SubscriberOrders({super.key, required this.store, this.clock});
  @override
  State<SubscriberOrders> createState() => _SubscriberOrdersState();
}

class _SubscriberOrdersState extends TiffeState<SubscriberOrders> {
  TiffeStore get store => widget.store;
  DateTime? get clock => widget.clock;
  DateTime get now => clock ?? DateTime.now();
  DateTime get today => DateTime(now.year, now.month, now.day);
  List<String> picks(DateTime date, int tiffin) {
    final ids = store.selected(date, tiffin);
    return ids.isEmpty ? store.usual : ids;
  }

  Widget label(String value) => Padding(
    padding: EdgeInsets.fromLTRB(0, 22, 0, 10),
    child: Text(
      value,
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: tink),
    ),
  );
  Widget pill(String value) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tone(Color(0xFFE4EDDF)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      value,
      style: TextStyle(
        color: tgreen,
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
          padding: EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiffin ${i + 1}',
                style: TextStyle(fontWeight: FontWeight.w700, color: tink),
              ),
              SizedBox(height: 3),
              Text(
                picks(date, i)
                    .map((id) => menu.firstWhere((b) => b.id == id).name)
                    .join(' + '),
                style: TextStyle(color: tink, fontSize: 14),
              ),
              if (!history && store.selected(date, i).isEmpty)
                Text('My Usual', style: TextStyle(fontSize: 11, color: tmuted)),
            ],
          ),
        ),
      Text(
        '3 Chapati + Rice per tiffin',
        style: TextStyle(color: tmuted, fontSize: 12),
      ),
      if (Pricing.sweet(date, store.plan)) ...[
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.cake_outlined, color: tgreen, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sunday Sweet Included\nFree for subscribers',
                style: TextStyle(
                  color: tgreen,
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
            SizedBox(height: 14),
            Text('Covered by your ₹${Pricing.monthly(store.plan)}/month plan'),
            Text(
              'Extra bhajis: ₹${List.generate(Pricing.quantity(store.plan), (i) => Pricing.extras(picks(date, i).length)).fold(0, (a, b) => a + b)}',
              style: TextStyle(color: tmuted, fontSize: 12),
            ),
            SizedBox(height: 12),
            Text(
              'Delivery: ₹199/month, charged with your subscription. No per-meal base charge.',
              style: TextStyle(color: tmuted, fontSize: 12),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Close')),
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
            Icon(Icons.bento_outlined, color: tgreen),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '${Pricing.quantity(store.plan)} Tiffin${store.plan == Plan.double ? 's' : ''}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            pill(
              future
                  ? 'Scheduled'
                  : DeliverySchedule.status(now) == 'Scheduled'
                  ? 'Preparing'
                  : DeliverySchedule.status(now),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(dayLabel(date), style: TextStyle(color: tmuted, fontSize: 11)),
        SizedBox(height: 16),
        meals(date),
        SizedBox(height: 12),
        Text(
          'Covered by your ₹${Pricing.monthly(store.plan)}/month plan',
          style: TextStyle(
            color: tgreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 14),
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
              child: Text('Change Bhaji'),
            ),
          ),
        if (future)
          Text(
            'Change before 9:00 AM on delivery day',
            style: TextStyle(color: tmuted, fontSize: 11),
          ),
        if (!future)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => details(c, date),
              child: Text('View Details'),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: store,
    builder: (c, _) => ListView(
      padding: EdgeInsets.fromLTRB(22, 24, 22, 28),
      children: [
        Text(
          'Your daily Tiffe.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: tink,
            letterSpacing: -.7,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'A meal plan. Not a daily checkout.',
          style: TextStyle(color: tmuted),
        ),
        SizedBox(height: 20),
        panel(
          color: tgreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Tiffe Plan',
                style: TextStyle(
                  color: tcream,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '₹${Pricing.monthly(store.plan)}/month · ${Pricing.quantity(store.plan)} Tiffin${store.plan == Plan.double ? 's' : ''} Daily',
                style: TextStyle(color: tcream, fontSize: 14),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  pill('Active'),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Next delivery: Today',
                      style: TextStyle(color: tcream, fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
        SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) => ScheduledTracking(plan: store.plan),
            ),
          ),
          icon: Icon(Icons.delivery_dining),
          label: Text('Track daily delivery · 8 PM'),
        ),
        label('Today'),
        dayCard(c, today, future: false),
        label('Tomorrow'),
        dayCard(c, today.add(Duration(days: 1)), future: true),
        label('History'),
        SizedBox(height: 10),
        for (var ago = 1; ago <= 2; ago++)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dayLabel(today.subtract(Duration(days: ago))),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      pill('Delivered'),
                    ],
                  ),
                  SizedBox(height: 12),
                  meals(today.subtract(Duration(days: ago)), history: true),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
