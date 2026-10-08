import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/delivery_schedule.dart';
import '../domain/tiffin.dart';
import 'app.dart' show green, cream, ink, muted, panel, Logo;

class ScheduledTracking extends StatefulWidget {
  final Plan plan;
  final DateTime? clock;
  const ScheduledTracking({super.key, required this.plan, this.clock});
  @override
  State<ScheduledTracking> createState() => _ScheduledTrackingState();
}

class _ScheduledTrackingState extends State<ScheduledTracking> {
  Timer? timer;
  DateTime get now => widget.clock ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    if (widget.clock == null) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final status = DeliverySchedule.status(now);
    final scheduled = status == 'Scheduled';
    final arrived = status == 'Tiffe arrived';
    return Scaffold(
      appBar: AppBar(title: const Text('Track my Tiffe')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Logo(size: 40)),
              const SizedBox(height: 24),
              Text(
                scheduled
                    ? 'Your evening is sorted.'
                    : arrived
                    ? 'A little home has arrived.'
                    : 'Good food is getting closer.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: ink,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Daily delivery · 8:00 PM · Pune time',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              panel(
                color: green,
                child: Column(
                  children: [
                    Text(
                      scheduled
                          ? 'Leaves the kitchen in'
                          : arrived
                          ? 'Enjoy your meal.'
                          : 'Estimated arrival in',
                      style: const TextStyle(color: cream, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scheduled
                          ? DeliverySchedule.countdown(now)
                          : arrived
                          ? 'Delivered'
                          : '${DeliverySchedule.remainingMinutes(now)} min',
                      style: const TextStyle(
                        color: cream,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      status,
                      style: const TextStyle(
                        color: cream,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 135,
                      child: LayoutBuilder(
                        builder: (c, b) {
                          final progress = DeliverySchedule.progress(now);
                          final travel = b.maxWidth - 54;
                          return Stack(
                            children: [
                              Positioned(
                                left: 27,
                                right: 27,
                                top: 66,
                                child: Container(
                                  height: 4,
                                  color: const Color(0xFFDCE7D5),
                                ),
                              ),
                              Positioned(
                                left: 27,
                                top: 66,
                                child: Container(
                                  height: 4,
                                  width: travel * progress,
                                  color: green,
                                ),
                              ),
                              Positioned(
                                top: 39,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    routeIcon(
                                      Icons.soup_kitchen_outlined,
                                      'Kitchen',
                                      true,
                                    ),
                                    routeIcon(
                                      Icons.delivery_dining,
                                      'On the way',
                                      progress >= .5,
                                    ),
                                    routeIcon(
                                      Icons.home_outlined,
                                      'Your doorstep',
                                      arrived,
                                    ),
                                  ],
                                ),
                              ),
                              if (!scheduled && !arrived)
                                Positioned(
                                  top: 0,
                                  left: 7 + travel * progress,
                                  child: const Icon(
                                    Icons.delivery_dining,
                                    size: 40,
                                    color: green,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scheduled
                          ? 'We\'ll start your journey at 8 PM.'
                          : arrived
                          ? 'Your Tiffe is here. Enjoy your meal!'
                          : status == 'Tiffe left'
                          ? 'Your dabba has left the kitchen.'
                          : 'A warm meal is on its way to you.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: DeliverySchedule.progress(now),
                      minHeight: 6,
                      color: green,
                      backgroundColor: cream,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plan == Plan.double
                          ? '2 Tiffins Daily'
                          : '1 Tiffin Daily',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '3 Chapati + Rice + Your chosen bhajis',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    if (widget.plan != Plan.none) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Covered by your ₹${Pricing.monthly(widget.plan)}/month plan',
                        style: const TextStyle(color: green, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Back to my Tiffe'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget routeIcon(IconData icon, String text, bool on) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 27,
        backgroundColor: on ? green : cream,
        child: Icon(icon, color: on ? cream : muted),
      ),
      const SizedBox(height: 10),
      Text(text, style: const TextStyle(fontSize: 11, color: muted)),
    ],
  );
}
