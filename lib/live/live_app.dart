import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../ui/app.dart' show palette, panel, Logo;
import 'backend.dart';

class LiveGate extends StatefulWidget {
  final TiffeBackend? backend;
  final TiffeStore store;
  final bool admin;
  const LiveGate({
    super.key,
    required this.backend,
    required this.store,
    this.admin = false,
  });
  @override
  State<LiveGate> createState() => _LiveGateState();
}

class _LiveGateState extends State<LiveGate> {
  @override
  Widget build(BuildContext c) {
    if (widget.backend == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tiffe')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'Unable to connect to Tiffe. Please try again later.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final b = widget.backend!;
    return StreamBuilder(
      stream: b.authChanges,
      builder: (c, s) {
        if (b.userId == null) return SignIn(backend: b, admin: widget.admin);
        if (widget.admin) {
          return FutureBuilder<String?>(
            future: b.role(),
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (s.hasError) {
                return Scaffold(
                  body: Center(
                    child: Text('Unable to verify staff access. Try again.'),
                  ),
                );
              }
              if (s.data == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Tiffe kitchen')),
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Staff access has not been enabled for this account.',
                        ),
                        TextButton(
                          onPressed: b.signOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return LiveWorkspace(
                backend: b,
                store: widget.store,
                role: s.data,
              );
            },
          );
        }
        return LiveWorkspace(backend: b, store: widget.store);
      },
    );
  }
}

String authErrorMessage(AuthException error, {required bool registering}) {
  switch (error.code) {
    case 'user_already_exists':
    case 'email_exists':
      return 'An account with this email already exists. Sign in instead.';
    case 'email_address_not_authorized':
      return 'Tiffe cannot send confirmation emails yet. New account signup is not available right now.';
    case 'email_not_confirmed':
      return 'Confirm your email before signing in.';
    case 'invalid_credentials':
      return 'Email or password is incorrect. Try signing in again.';
    case 'weak_password':
      return 'Choose a stronger password with at least 8 characters.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Too many attempts. Wait a few minutes before trying again.';
    case 'signup_disabled':
    case 'email_provider_disabled':
      return 'New account signup is not available right now.';
    default:
      return registering
          ? 'Could not create your account. Try again later, or sign in if you already have one.'
          : 'Could not sign in. Check your email and password.';
  }
}

class SignIn extends StatefulWidget {
  final TiffeBackend backend;
  final bool admin;
  const SignIn({super.key, required this.backend, this.admin = false});
  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  bool registering = false;
  String? notice;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final loginEmail = BackendConfig.loginEmail(
      email.text,
      admin: widget.admin && !registering,
    );
    if (!loginEmail.contains('@') ||
        password.text.isEmpty ||
        (registering && password.text.length < 8)) {
      setState(
        () => error = registering
            ? 'Enter your email and a password of at least 8 characters.'
            : 'Enter your email and password.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (registering) {
        final response = await widget.backend.signUp(
          email.text.trim(),
          password.text,
        );
        if (mounted && response.session == null) {
          setState(
            () => notice =
                'Check your email to confirm your account, then sign in.',
          );
        }
      } else {
        await widget.backend.signIn(loginEmail, password.text);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => error = authErrorMessage(e, registering: registering));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not reach Tiffe. Check your internet connection and try again.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Logo(size: 62)),
                const SizedBox(height: 30),
                Text(
                  widget.admin
                      ? 'Your kitchen, connected.'
                      : 'A little home. One sign-in away.',
                  style: TextStyle(
                    color: palette(c).ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.admin
                      ? 'Sign in with your staff account.'
                      : 'Sign in to see your meals, plan and deliveries.',
                  style: TextStyle(color: palette(c).muted),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: widget.admin && !registering
                        ? 'Admin ID or email'
                        : 'Email',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => busy ? null : submit(),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Please wait...'
                        : registering
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      notice!,
                      style: TextStyle(color: palette(c).green),
                    ),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          registering = !registering;
                          error = null;
                          notice = null;
                        }),
                  child: Text(
                    registering
                        ? 'Already have an account? Sign in'
                        : 'New to Tiffe? Create account',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.admin
                      ? 'Staff roles are enabled only by the Tiffe owner.'
                      : 'Confirm your email to keep your account secure.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette(c).muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LiveWorkspace extends StatefulWidget {
  final TiffeBackend backend;
  final TiffeStore store;
  final String? role;
  const LiveWorkspace({
    super.key,
    required this.backend,
    required this.store,
    this.role,
  });
  @override
  State<LiveWorkspace> createState() => _LiveWorkspaceState();
}

class _LiveWorkspaceState extends State<LiveWorkspace> {
  int tab = 0;
  late final menuStream = widget.backend.menu().asBroadcastStream();
  late final orderStream = widget.backend.orders(customer: widget.role == null);
  late final subscriptionStream = widget.role == null
      ? widget.backend.subscriptions().asBroadcastStream()
      : null;
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      area = TextEditingController();
  bool saving = false;
  String? profileError;
  bool loaded = false;
  Map<String, dynamic>? cfg;
  List<Map<String, dynamic>> menuRows = [];
  List<Map<String, dynamic>> subRows = [];
  @override
  void initState() {
    super.initState();
    loadProfile();
    loadSettings();
    menuStream.listen((rows) {
      if (mounted) setState(() => menuRows = rows);
    });
    subscriptionStream?.listen((rows) {
      if (mounted) setState(() => subRows = rows);
    });
  }

  Map<String, dynamic>? get activeSubscription {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final r in subRows) {
      if (r['verified'] == true &&
          (r['starts_on'] as String).compareTo(day) <= 0 &&
          (r['ends_on'] as String).compareTo(day) >= 0) {
        return r;
      }
    }
    return null;
  }

  Future<void> loadSettings() async {
    try {
      final row = await widget.backend.currentSettings();
      if (mounted) setState(() => cfg = row);
    } catch (_) {}
  }

  List<String> get areas =>
      ((cfg?['areas'] as List?) ?? const []).cast<String>();

  Future<void> loadProfile() async {
    try {
      final p = await widget.backend.profile();
      if (p != null) {
        name.text = p['name'] as String? ?? '';
        phone.text = p['phone'] as String? ?? '';
        address.text = p['address'] as String? ?? '';
        area.text = p['area'] as String? ?? '';
      }
      if (mounted) setState(() => loaded = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => profileError = 'Could not load your profile. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    area.dispose();
    super.dispose();
  }

  Widget empty(String heading, String body, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: panel(
      child: Column(
        children: [
          Icon(icon, size: 42, color: palette(context).green),
          const SizedBox(height: 16),
          Text(
            heading,
            style: TextStyle(
              color: palette(context).ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: palette(context).muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  Widget data(
    Stream<List<Map<String, dynamic>>> stream,
    Widget Function(List<Map<String, dynamic>>) render,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: stream,
    builder: (c, s) {
      if (s.hasError) {
        return empty(
          'Could not load updates',
          'Check your connection and try again.',
          Icons.cloud_off,
        );
      }
      if (!s.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return render(s.data!);
    },
  );
  Future<void> editMenu([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['name'] ?? '');
    final description = TextEditingController(text: item?['description'] ?? '');
    bool available = item?['available'] == true, busy = false;
    String? error;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(item == null ? 'Add bhaji' : 'Edit bhaji'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Bhaji name'),
                ),
                TextField(
                  controller: description,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                SwitchListTile(
                  title: const Text('Available'),
                  value: available,
                  onChanged: busy ? null : (v) => set(() => available = v),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty) {
                        set(() => error = 'Enter a bhaji name.');
                        return;
                      }
                      set(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await widget.backend.saveMenu(
                          id: item?['id'],
                          name: title.text.trim(),
                          description: description.text.trim(),
                          available: available,
                        );
                        if (c.mounted) Navigator.pop(c);
                      } catch (_) {
                        if (c.mounted) {
                          set(() {
                            busy = false;
                            error = 'Could not save the menu. Try again.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
  }

  String? nextStatus(Map<String, dynamic> o) {
    if (widget.role == 'delivery') {
      return o['status'] == 'Out for Delivery' ? 'Delivered' : null;
    }
    if (widget.role == 'owner' || widget.role == 'kitchen') {
      return switch (o['status']) {
        'Confirmed' => 'Preparing',
        'Preparing' => 'Packed',
        'Packed' => widget.role == 'owner' ? 'Out for Delivery' : null,
        _ => null,
      };
    }
    return null;
  }

  Future<void> advance(Map<String, dynamic> order) async {
    final status = nextStatus(order);
    if (status == null) return;
    final etaMinutes = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Mark as $status?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This updates the order immediately.'),
            if (status == 'Out for Delivery') ...[
              const SizedBox(height: 12),
              TextField(
                controller: etaMinutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Arrives in (minutes, optional)',
                ),
              ),
            ],
          ],
        ),
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
    // Dispose after the dialog's exit animation stops using the controller.
    Future.delayed(const Duration(milliseconds: 400), etaMinutes.dispose);
    if (approved != true) return;
    final minutes = int.tryParse(etaMinutes.text.trim());
    try {
      await widget.backend.advance(
        order['id'],
        status,
        eta: minutes == null
            ? null
            : DateTime.now().add(Duration(minutes: minutes)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update this order. Refresh and try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> verifyPayment(Map<String, dynamic> order) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Verify payment?'),
        content: Text(
          'Confirm Rs ${(order['total_paise'] as int) / 100} was received for this order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.backend.verifyPayment(order['id'] as String);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify payment. Try again.')),
        );
      }
    }
  }

  Future<void> assignRider(Map<String, dynamic> order) async {
    List<Map<String, dynamic>> riders;
    try {
      riders = await widget.backend.deliveryStaff();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load riders. Try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (riders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No delivery staff yet. Add riders in Supabase first.'),
        ),
      );
      return;
    }
    String? chosen;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Assign rider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: riders
                .map(
                  (r) => ListTile(
                    title: Text(
                      'Rider ${(r['user_id'] as String).substring(0, 8)}',
                    ),
                    leading: Icon(
                      chosen == r['user_id']
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: palette(c).green,
                    ),
                    onTap: () => set(() => chosen = r['user_id'] as String),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosen == null ? null : () => Navigator.pop(c, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (approved != true || chosen == null) return;
    try {
      await widget.backend.assignRider(order['id'] as String, chosen!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not assign the rider. Try again.'),
          ),
        );
      }
    }
  }

  Widget menus() => data(
    menuStream,
    (rows) => rows.isEmpty
        ? empty(
            'The kitchen is getting ready',
            'Today\'s menu will appear here when the kitchen publishes it.',
            Icons.soup_kitchen_outlined,
          )
        : Column(
            children: rows
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: panel(
                      child: Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: palette(context).green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(m['description'] ?? ''),
                                Text(
                                  m['available'] == true
                                      ? 'Available'
                                      : 'Unavailable',
                                  style: TextStyle(
                                    color: palette(context).muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.role == 'owner' ||
                              widget.role == 'kitchen')
                            IconButton(
                              onPressed: () => editMenu(m),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit bhaji',
                            ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
  Widget orders() => data(
    orderStream,
    (rows) => rows.isEmpty
        ? empty(
            widget.role == null ? 'No orders yet' : 'No orders to prepare',
            widget.role == null
                ? 'Your confirmed meals and delivery updates will appear here.'
                : 'Customer orders will appear here as they are placed.',
            Icons.receipt_long_outlined,
          )
        : Column(
            children: rows
                .map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o['delivery_date'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '${o['quantity']} Tiffin${o['quantity'] == 2 ? 's' : ''} · ${o['status']}',
                          ),
                          Text(
                            '₹${(o['total_paise'] as int) / 100} · ${o['payment_status']}',
                          ),
                          if (o['status'] == 'Out for Delivery')
                            Text(
                              o['eta_at'] == null
                                  ? 'Arrival time not available'
                                  : 'Estimated arrival: ${o['eta_at']}',
                            ),
                          if (nextStatus(o) != null)
                            FilledButton(
                              onPressed: () => advance(o),
                              child: Text('Mark ${nextStatus(o)}'),
                            ),
                          if (widget.role == 'owner') ...[
                            if (o['payment_status'] != 'verified')
                              FilledButton.tonal(
                                onPressed: () => verifyPayment(o),
                                child: const Text('Verify payment'),
                              ),
                            if (o['assigned_to'] == null)
                              TextButton(
                                onPressed: () => assignRider(o),
                                child: const Text('Assign rider'),
                              )
                            else
                              Text(
                                'Rider assigned',
                                style: TextStyle(color: palette(context).muted),
                              ),
                            if (o['status'] == 'Packed' &&
                                (o['payment_status'] != 'verified' ||
                                    o['assigned_to'] == null))
                              Text(
                                'Dispatch needs verified payment and a rider.',
                                style: TextStyle(
                                  color: palette(context).muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
  Widget plan() => data(subscriptionStream!, (rows) {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final active = rows
        .where(
          (r) =>
              r['verified'] == true &&
              r['starts_on'].compareTo(day) <= 0 &&
              r['ends_on'].compareTo(day) >= 0,
        )
        .toList();
    return active.isEmpty
        ? empty(
            'No active subscription',
            'Your verified Tiffe plan will appear here once it is set up. Subscription payments are not available yet.',
            Icons.calendar_month_outlined,
          )
        : Column(
            children: active
                .map(
                  (p) => panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active subscription',
                          style: TextStyle(color: palette(context).green),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p['plan'] == 'double'
                              ? 'Double Tiffe'
                              : 'Daily Tiffe',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('${p['starts_on']} to ${p['ends_on']}'),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
  });
  int plansVersion = 0;

  Future<void> editSubscription() async {
    List<Map<String, dynamic>> customers;
    try {
      customers = await widget.backend.customers();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load customers. Try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customer profiles yet.')),
      );
      return;
    }
    String? customerId;
    String plan = 'daily';
    bool verified = true, busy = false;
    String? error;
    final start = TextEditingController(), end = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add subscription'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: customerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: customers
                      .map(
                        (cu) => DropdownMenuItem(
                          value: cu['id'] as String,
                          child: Text(
                            '${cu['name'] ?? 'Unnamed'} · ${cu['phone'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : (v) => set(() => customerId = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: plan,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily Tiffe'),
                    ),
                    DropdownMenuItem(
                      value: 'double',
                      child: Text('Double Tiffe'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => set(() => plan = v ?? 'daily'),
                ),
                TextField(
                  controller: start,
                  decoration: const InputDecoration(
                    labelText: 'Starts on (YYYY-MM-DD)',
                  ),
                ),
                TextField(
                  controller: end,
                  decoration: const InputDecoration(
                    labelText: 'Ends on (YYYY-MM-DD)',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Payment verified'),
                  value: verified,
                  onChanged: busy ? null : (v) => set(() => verified = v),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final dateOk = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (customerId == null ||
                          !dateOk.hasMatch(start.text.trim()) ||
                          !dateOk.hasMatch(end.text.trim())) {
                        set(() => error = 'Pick a customer and valid dates.');
                        return;
                      }
                      set(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await widget.backend.saveSubscription(
                          customerId: customerId!,
                          plan: plan,
                          startsOn: start.text.trim(),
                          endsOn: end.text.trim(),
                          verified: verified,
                        );
                        if (c.mounted) Navigator.pop(c);
                        if (mounted) setState(() => plansVersion++);
                      } catch (_) {
                        if (c.mounted) {
                          set(() {
                            busy = false;
                            error = 'Could not save. Try again.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      start.dispose();
      end.dispose();
    });
  }

  Widget plansAdmin() => FutureBuilder<List<List<Map<String, dynamic>>>>(
    key: ValueKey(plansVersion),
    future: Future.wait([
      widget.backend.allSubscriptions(),
      widget.backend.customers(),
    ]),
    builder: (c, s) {
      if (s.hasError) {
        return empty(
          'Could not load plans',
          'Check your connection and try again.',
          Icons.cloud_off,
        );
      }
      if (!s.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final subs = s.data![0];
      final names = {for (final cu in s.data![1]) cu['id']: cu['name']};
      return Column(
        children: [
          ...subs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names[p['customer_id']] as String? ?? 'Unknown customer',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${p['plan'] == 'double' ? 'Double Tiffe' : 'Daily Tiffe'} · ${p['starts_on']} to ${p['ends_on']}',
                    ),
                    Text(
                      p['verified'] == true ? 'Payment verified' : 'Unverified',
                      style: TextStyle(color: palette(c).muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (subs.isEmpty)
            empty(
              'No subscriptions yet',
              'Add one after a customer pays for a monthly plan.',
              Icons.calendar_month_outlined,
            ),
          FilledButton.icon(
            onPressed: editSubscription,
            icon: const Icon(Icons.add),
            label: const Text('Add subscription'),
          ),
        ],
      );
    },
  );

  Widget orderCta() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: FilledButton.icon(
      onPressed: cfg == null ? null : openOrder,
      icon: const Icon(Icons.add_shopping_cart_outlined),
      label: const Text('Order a tiffin'),
    ),
  );

  Future<void> openOrder() async {
    final placed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => OrderSheet(
        backend: widget.backend,
        cfg: cfg!,
        menuRows: menuRows,
        subscription: activeSubscription,
      ),
    );
    if (placed == true && mounted) {
      setState(() => tab = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed - the kitchen has it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> saveProfile() async {
    if (name.text.trim().isEmpty ||
        !RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone.text.trim()) ||
        address.text.trim().isEmpty ||
        area.text.trim().isEmpty) {
      setState(
        () => profileError =
            'Enter your name, valid phone, delivery address and area.',
      );
      return;
    }
    setState(() {
      saving = true;
      profileError = null;
    });
    try {
      await widget.backend.saveProfile(
        name: name.text.trim(),
        phone: phone.text.trim(),
        address: address.text.trim(),
        area: area.text.trim(),
      );
      final stored = await widget.backend.profile();
      if (stored == null ||
          stored['name'] != name.text.trim() ||
          stored['phone'] != phone.text.trim() ||
          stored['address'] != address.text.trim() ||
          stored['area'] != area.text.trim()) {
        throw StateError('Profile readback did not match');
      }
      if (mounted) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF75D58A),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Profile updated successfully',
                    style: TextStyle(
                      color: dark ? Colors.white : const Color(0xFF303030),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: dark ? const Color(0xFF303030) : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              side: dark
                  ? BorderSide.none
                  : const BorderSide(color: Colors.black, width: 1),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => profileError =
              'Could not save. Your changes have not been confirmed.',
        );
      }
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> changePassword() async {
    final password = TextEditingController();
    bool busy = false;
    String? error;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Change password'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (password.text.length < 8) {
                        set(() => error = 'Use at least 8 characters.');
                        return;
                      }
                      set(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await widget.backend.changePassword(password.text);
                        if (c.mounted) Navigator.pop(c);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password changed. Use it next time you sign in.',
                              ),
                            ),
                          );
                        }
                      } on AuthException catch (e) {
                        if (c.mounted) {
                          set(() {
                            busy = false;
                            error = e.code == 'same_password'
                                ? 'Choose a different password.'
                                : 'Could not change password. Try again.';
                          });
                        }
                      } catch (_) {
                        if (c.mounted) {
                          set(() {
                            busy = false;
                            error = 'Could not change password. Check your connection.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving...' : 'Save password'),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), password.dispose);
  }

  Widget profile() => Column(
    children: [
      panel(
        child: Material(
          color: Colors.transparent,
          child: SwitchListTile(
            title: const Text('Dark mode'),
            value: widget.store.darkMode,
            onChanged: widget.store.setDarkMode,
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (!loaded && profileError == null) const CircularProgressIndicator(),
      if (loaded) ...[
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: address,
          decoration: const InputDecoration(labelText: 'Delivery address'),
        ),
        const SizedBox(height: 12),
        areas.isEmpty
            ? TextField(
                controller: area,
                decoration: const InputDecoration(labelText: 'Area'),
              )
            : DropdownButtonFormField<String>(
                initialValue: areas.contains(area.text) ? area.text : null,
                decoration: const InputDecoration(labelText: 'Area'),
                items: {...areas, area.text}
                    .where((a) => a.isNotEmpty)
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => area.text = v ?? ''),
              ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving ? null : saveProfile,
          child: Text(saving ? 'Saving...' : 'Save profile'),
        ),
      ],
      if (profileError != null) Text(profileError!),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: changePassword,
        child: const Text('Change password'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: widget.backend.signOut,
        child: const Text('Sign out'),
      ),
    ],
  );
  @override
  Widget build(BuildContext c) {
    final admin = widget.role != null;
    final titles = admin
        ? ['Kitchen overview', 'Menu', 'Orders', 'Plans', 'Workspace']
        : [
            'Today\'s Tiffe',
            'Menu',
            'Orders',
            'Your Tiffe plan',
            'Your corner',
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Tiffe${admin ? ' kitchen' : ''}'),
        actions: admin
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(widget.role!),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              titles[tab],
              style: TextStyle(
                color: palette(c).ink,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (tab == 0) ...[
              Text(
                admin
                    ? 'Live updates from your kitchen.'
                    : 'A little home, in every dabba.',
                style: TextStyle(color: palette(c).muted),
              ),
              const SizedBox(height: 18),
              menus(),
              if (!admin) orderCta(),
            ],
            if (tab == 1) ...[menus(), if (!admin) orderCta()],
            if (tab == 2) orders(),
            if (tab == 3 && !admin) plan(),
            if (tab == 3 && admin) plansAdmin(),
            if (tab == (admin ? 4 : 4)) profile(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          if (!admin)
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Plan',
            ),
          if (admin)
            const NavigationDestination(
              icon: Icon(Icons.card_membership_outlined),
              label: 'Plans',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class OrderSheet extends StatefulWidget {
  final TiffeBackend backend;
  final Map<String, dynamic> cfg;
  final List<Map<String, dynamic>> menuRows;
  final Map<String, dynamic>? subscription;
  const OrderSheet({
    super.key,
    required this.backend,
    required this.cfg,
    required this.menuRows,
    this.subscription,
  });
  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  final instructions = TextEditingController();
  late final List<Set<String>> tiffins = [
    {},
    if (widget.subscription?['plan'] == 'double') {},
  ];
  bool busy = false;
  String? error;
  late final String idempotencyKey = newOrderKey();

  static String newOrderKey() {
    final r = Random();
    final h = List.generate(32, (_) => r.nextInt(16));
    h[12] = 4;
    h[16] = 8 + r.nextInt(4);
    final s = h.map((e) => e.toRadixString(16)).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-'
        '${s.substring(16, 20)}-${s.substring(20)}';
  }

  static DateTime istNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  String deliveryDate() {
    final cutoff = (widget.cfg['cutoff_time'] as String? ?? '09:00:00')
        .split(':')
        .map(int.parse)
        .toList();
    var d = istNow();
    final cutoffToday = DateTime(d.year, d.month, d.day, cutoff[0], cutoff[1]);
    if (!d.isBefore(cutoffToday)) d = d.add(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get pricePaise {
    final extra = widget.cfg['extra_bhaji_paise'] as int? ?? 0;
    if (widget.subscription != null) {
      var total = 0;
      for (final t in tiffins) {
        if (t.length > 2) total += (t.length - 2) * extra;
      }
      return total;
    }
    final oneTime = widget.cfg['one_time_price_paise'] as int? ?? 0;
    final delivery = widget.cfg['one_time_delivery_paise'] as int? ?? 0;
    var total = (oneTime + delivery) * tiffins.length;
    for (final t in tiffins) {
      if (t.length > 2) total += (t.length - 2) * extra;
    }
    return total;
  }

  @override
  void dispose() {
    instructions.dispose();
    super.dispose();
  }

  Future<void> place() async {
    for (final t in tiffins) {
      if (t.length < 2 || t.length > 8) {
        setState(() => error = 'Pick 2 to 8 bhajis for each tiffin.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.backend.placeOrder(
        date: deliveryDate(),
        tiffins: tiffins.map((t) => t.toList()).toList(),
        idempotencyKey: idempotencyKey,
        instructions: instructions.text.trim(),
        subscriptionId: widget.subscription?['id'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e
              .toString()
              .replaceFirst(RegExp(r'^\w*Exception[: ]*'), '')
              .trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.cfg;
    final extra = (available['extra_bhaji_paise'] as int? ?? 0) ~/ 100;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Builder(
        builder: (c) {
          final rows = widget.menuRows
              .where((m) => m['available'] == true)
              .toList();
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Order a tiffin',
                  style: TextStyle(
                    color: palette(c).ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Delivery date: ${deliveryDate()}',
                  style: TextStyle(color: palette(c).muted),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < tiffins.length; i++) ...[
                  Text(
                    'Tiffin ${i + 1}: pick 2 to 8 bhajis'
                    '${extra > 0 ? ' (extra ₹$extra each after the first two)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rows
                        .map(
                          (m) => FilterChip(
                            label: Text(m['name'] as String),
                            selected: tiffins[i].contains(m['id'] as String),
                            onSelected: busy
                                ? null
                                : (v) => setState(() {
                                    error = null;
                                    if (v) {
                                      tiffins[i].add(m['id'] as String);
                                    } else {
                                      tiffins[i].remove(m['id'] as String);
                                    }
                                  }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                ],
                if (tiffins.length < 2 && widget.subscription == null)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => setState(() => tiffins.add({})),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a second tiffin'),
                  ),
                TextField(
                  controller: instructions,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Note for the kitchen (optional)',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subscription != null
                      ? pricePaise == 0
                            ? 'Covered by your Tiffe plan.'
                            : 'Extras: ₹${pricePaise ~/ 100}. The rest is covered by your plan.'
                      : 'Total: ₹${pricePaise ~/ 100}. Online payment is not in the app yet - Tiffe confirms payment with you directly.',
                  style: TextStyle(color: palette(c).muted),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : place,
                    child: Text(busy ? 'Placing...' : 'Place order'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
