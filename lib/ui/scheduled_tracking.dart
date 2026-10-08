import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/delivery_schedule.dart';
import '../domain/tiffin.dart';
import 'app.dart' show panel, Logo, TiffeState;

class ScheduledTracking extends StatefulWidget {
  final Plan plan;
  final DateTime? clock;
  const ScheduledTracking({super.key, required this.plan, this.clock});
  @override
  State<ScheduledTracking> createState() => _ScheduledTrackingState();
}

class _ScheduledTrackingState extends TiffeState<ScheduledTracking> {
  Timer? timer;
  DateTime get now => widget.clock ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    if (widget.clock == null) {
      timer = Timer.periodic(Duration(seconds: 1), (_) {
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
      appBar: AppBar(title: Text('Track my Tiffe')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Logo(size: 40)),
              SizedBox(height: 24),
              Text(
                scheduled
                    ? 'Your evening is sorted.'
                    : arrived
                    ? 'A little home has arrived.'
                    : 'Good food is getting closer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: tink,
                  letterSpacing: -.6,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Daily delivery · 8:00 PM · Pune time',
                textAlign: TextAlign.center,
                style: TextStyle(color: tmuted, fontSize: 13),
              ),
              SizedBox(height: 24),
              panel(
                color: tgreen,
                child: Column(
                  children: [
                    Text(
                      scheduled
                          ? 'Leaves the kitchen in'
                          : arrived
                          ? 'Enjoy your meal.'
                          : 'Estimated arrival in',
                      style: TextStyle(color: tcream, fontSize: 15),
                    ),
                    SizedBox(height: 12),
                    Text(
                      scheduled
                          ? DeliverySchedule.countdown(now)
                          : arrived
                          ? 'Delivered'
                          : '${DeliverySchedule.remainingMinutes(now)} min',
                      style: TextStyle(
                        color: tcream,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      status,
                      style: TextStyle(
                        color: tcream,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
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
                                  color: tone(Color(0xFFDCE7D5)),
                                ),
                              ),
                              Positioned(
                                left: 27,
                                top: 66,
                                child: Container(
                                  height: 4,
                                  width: travel * progress,
                                  color: tgreen,
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
                                  child: Icon(
                                    Icons.delivery_dining,
                                    size: 40,
                                    color: tgreen,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      scheduled
                          ? 'We\'ll start your journey at 8 PM.'
                          : arrived
                          ? 'Your Tiffe is here. Enjoy your meal!'
                          : status == 'Tiffe left'
                          ? 'Your dabba has left the kitchen.'
                          : 'A warm meal is on its way to you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: DeliverySchedule.progress(now),
                      minHeight: 6,
                      color: tgreen,
                      backgroundColor: tone(tcream),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plan == Plan.double
                          ? '2 Tiffins Daily'
                          : '1 Tiffin Daily',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '3 Chapati + Rice + Your chosen bhajis',
                      style: TextStyle(color: tmuted, fontSize: 13),
                    ),
                    if (widget.plan != Plan.none) ...[
                      SizedBox(height: 8),
                      Text(
                        'Covered by your ₹${Pricing.monthly(widget.plan)}/month plan',
                        style: TextStyle(color: tgreen, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(c),
                child: Text('Back to my Tiffe'),
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
        backgroundColor: on ? tgreen : tone(tcream),
        child: Icon(icon, color: on ? onAccent : tmuted),
      ),
      SizedBox(height: 10),
      Text(text, style: TextStyle(fontSize: 11, color: tmuted)),
    ],
  );
}
