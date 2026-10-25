import 'package:flutter/material.dart';

import '../domain/tiffin.dart';
import 'app.dart' show panel, Logo, TiffeState;

class ScheduledTracking extends StatefulWidget {
  final Plan plan;
  final DateTime? clock;
  final String? staffStatus;
  const ScheduledTracking({
    super.key,
    required this.plan,
    this.clock,
    this.staffStatus,
  });
  @override
  State<ScheduledTracking> createState() => _ScheduledTrackingState();
}

class _ScheduledTrackingState extends TiffeState<ScheduledTracking> {
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('Track my Tiffe')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Logo(size: 40)),
            SizedBox(height: 24),
            panel(
              child: Column(
                children: [
                  Icon(Icons.restaurant_outlined, color: tgreen, size: 40),
                  SizedBox(height: 16),
                  Text(
                    widget.staffStatus ?? 'Waiting for staff update',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Order status changes only when staff update it in Tiffe Staff. Open your order details to see the latest status.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tmuted, height: 1.4),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            panel(
              child: Column(
                children: [
                  Text(
                    widget.plan == Plan.double
                        ? '2 Tiffins Daily'
                        : '1 Tiffin Daily',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '3 Chapati + Rice + Your chosen bhajis',
                    style: TextStyle(color: tmuted),
                  ),
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
