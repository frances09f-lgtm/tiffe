// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';

import '../live/backend.dart';
import 'staff_backend.dart';
import '../live/live_app.dart';
import 'staff_policy.dart';
import 'partner_hub.dart';

class StaffGate extends StatelessWidget {
  final TiffeBackend backend;
  const StaffGate({super.key, required this.backend});
  @override
  Widget build(BuildContext c) => StreamBuilder(
    stream: backend.authChanges,
    builder: (c, s) {
      if (backend.userId == null) {
        return SignIn(backend: backend, admin: true, showIntro: false);
      }
      return FutureBuilder<String?>(
        future: backend.role(),
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!StaffPolicy.canEnter(s.data))
            return Scaffold(
              appBar: AppBar(title: const Text('Tiffe Staff')),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.hasError
                          ? 'Could not verify staff access. Try again.'
                          : 'Staff access is not enabled for this account.',
                    ),
                    TextButton(
                      onPressed: backend.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          return s.data == 'delivery'
              ? StaffHome(backend: backend, role: s.data!)
              : PartnerHub(backend: backend, role: s.data!);
        },
      );
    },
  );
}

class StaffHome extends StatefulWidget {
  final TiffeBackend backend;
  final String role;
  const StaffHome({super.key, required this.backend, required this.role});
  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  late Stream<List<Map<String, dynamic>>> orders;
  int tab = 0;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    orders = widget.backend.staffOrders(widget.role);
  }

  Future<void> update(Map<String, dynamic> o) async {
    final next = StaffPolicy.next(widget.role, o);
    if (next == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Mark $next?'),
        content: const Text('This updates the live customer order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Update'),
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
      await widget.backend.advance(o['id'], next);
    } catch (_) {
      if (mounted)
        setState(
          () =>
              error = 'Server refused the update. Refresh before trying again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify(Map<String, dynamic> o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Verify payment received?'),
        content: Text(
          'Only confirm after checking receipt of Rs ${(o['total_paise'] as num) / 100}. This changes live payment status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm received'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.backend.verifyPayment(o['id']);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not verify payment. No success claimed.');
    }
  }

  Future<void> assign(Map<String, dynamic> o) async {
    try {
      final riders = await widget.backend.deliveryStaff();
      if (!mounted) return;
      if (riders.isEmpty) {
        setState(() => error = 'No delivery accounts enabled yet.');
        return;
      }
      final chosen = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Assign delivery person'),
          children: riders
              .map(
                (r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, r['user_id']),
                  child: Text(
                    (r['name'] as String?)?.isNotEmpty == true
                        ? r['name']
                        : 'Unnamed delivery account',
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (chosen != null) await widget.backend.assignRider(o['id'], chosen);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not assign this order.');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.role == 'delivery' ? 'My deliveries' : 'Tiffe Staff'),
      actions: [
        IconButton(
          onPressed: busy
              ? null
              : () {
                  setState(() {
                    orders = widget.backend.staffOrders(widget.role);
                    error = null;
                  });
                },
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: widget.backend.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    bottomNavigationBar: StaffPolicy.canCustomers(widget.role)
        ? NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.people),
                label: 'Customers',
              ),
            ],
          )
        : null,
    body: Column(
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (busy) const LinearProgressIndicator(),
        Expanded(child: tab == 1 ? customers() : orderList()),
      ],
    ),
  );
  Widget customers() => FutureBuilder<List<Map<String, dynamic>>>(
    future: widget.backend.customers(),
    builder: (c, s) {
      if (s.hasError)
        return const Center(child: Text('Could not load customers.'));
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(
        children: s.data!
            .map(
              (p) => ListTile(
                title: Text('${p['name'] ?? 'Unnamed'}'),
                subtitle: Text('${p['phone'] ?? ''}\n${p['area'] ?? ''}'),
              ),
            )
            .toList(),
      );
    },
  );
  Widget orderList() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: orders,
    builder: (c, s) {
      if (s.hasError)
        return const Center(
          child: Text('Could not load orders. Check connection and refresh.'),
        );
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final rows = s.data!
          .where(
            (o) => StaffPolicy.visible(widget.role, widget.backend.userId!, o),
          )
          .toList();
      if (rows.isEmpty)
        return Center(
          child: Text(
            widget.role == 'delivery'
                ? 'No orders assigned to you.'
                : 'No orders yet.',
          ),
        );
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (c, i) {
          final o = rows[i];
          final address = Map<String, dynamic>.from(
            o['address_snapshot'] as Map? ?? {},
          );
          final next = StaffPolicy.next(widget.role, o);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${o['delivery_date']} · ${o['meal'] ?? 'Meal not set'}',
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${address['name'] ?? 'Customer'} · ${o['quantity']} tiffin(s)',
                  ),
                  Text('${address['address'] ?? ''}\n${address['area'] ?? ''}'),
                  Text('${address['phone'] ?? ''}'),
                  const Divider(),
                  Text('Status: ${o['status']}'),
                  Text('Payment: ${o['payment_status']}'),
                  if (o['departed_at'] != null)
                    Text('Departed: ${o['departed_at']}'),
                  if (o['eta_at'] != null) Text('ETA: ${o['eta_at']}'),
                  if (o['delivered_at'] != null)
                    Text('Delivered: ${o['delivered_at']}'),
                  if (o['instructions']?.toString().isNotEmpty == true)
                    Text('Note: ${o['instructions']}'),
                  if (widget.role == 'owner' &&
                      o['status'] == 'Packed' &&
                      next == null)
                    const Text(
                      'Dispatch needs verified payment and a delivery person.',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (next != null)
                        FilledButton(
                          onPressed: busy ? null : () => update(o),
                          child: Text('Mark $next'),
                        ),
                      if (widget.role == 'owner' &&
                          o['payment_status'] != 'verified')
                        TextButton(
                          onPressed: busy ? null : () => verify(o),
                          child: const Text('Verify received payment'),
                        ),
                      if (StaffPolicy.canAssign(widget.role))
                        TextButton(
                          onPressed: busy ? null : () => assign(o),
                          child: Text(
                            o['assigned_to'] == null
                                ? 'Assign delivery person'
                                : 'Reassign delivery person',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
