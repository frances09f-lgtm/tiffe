import 'dart:math';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../domain/tiffin.dart' as food;
import '../ui/app.dart' show palette, panel, Logo, TiffePalette;
import 'backend.dart';

bool isCompleteProfile(Map<String, dynamic>? profile) =>
    profile != null &&
    [
      'name',
      'phone',
      'address',
      'area',
    ].every((key) => (profile[key] as String? ?? '').trim().isNotEmpty);

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
        return LiveWorkspace(
          key: ValueKey(b.userId),
          backend: b,
          store: widget.store,
        );
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
                    fontFamily: widget.admin ? 'TiffeSans' : 'PlusJakartaSans',
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
  TiffePalette get uiPalette => TiffePalette(
    Theme.of(context).brightness == Brightness.dark,
    stitch: widget.role == null,
  );
  BuildContext? themedContext;
  BuildContext get routeContext => themedContext ?? context;
  int tab = 0;
  late final menuStream = widget.backend.menu().asBroadcastStream();
  late final orderStream = widget.backend
      .orders(customer: widget.role == null)
      .asBroadcastStream();
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
  bool profileComplete = false;
  StreamSubscription<List<Map<String, dynamic>>>? menuListener,
      planListener,
      orderListener;
  Map<String, dynamic>? cfg;
  List<Map<String, dynamic>> menuRows = [];
  List<Map<String, dynamic>> subRows = [];
  List<Map<String, dynamic>> orderRows = [];
  @override
  void initState() {
    super.initState();
    loadProfile();
    loadSettings();
    menuListener = menuStream.listen((rows) {
      if (mounted) setState(() => menuRows = rows);
    }, onError: (Object _) {});
    orderListener = orderStream.listen((rows) {
      if (mounted) setState(() => orderRows = rows);
    }, onError: (Object _) {});
    planListener = subscriptionStream?.listen((rows) {
      if (mounted) setState(() => subRows = rows);
    }, onError: (Object _) {});
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
      final row = await widget.backend.currentSettings().timeout(
        const Duration(seconds: 12),
      );
      if (mounted) setState(() => cfg = row);
    } catch (_) {}
  }

  List<String> get areas =>
      ((cfg?['areas'] as List?) ?? const []).cast<String>();

  Future<void> loadProfile() async {
    if (mounted) {
      setState(() {
        loaded = false;
        profileError = null;
      });
    }
    try {
      final p = await widget.backend.profile().timeout(
        const Duration(seconds: 12),
      );
      if (p != null) {
        name.text = p['name'] as String? ?? '';
        phone.text = p['phone'] as String? ?? '';
        address.text = p['address'] as String? ?? '';
        area.text = p['area'] as String? ?? '';
      }
      if (mounted) {
        setState(() {
          loaded = true;
          profileComplete = isCompleteProfile(p);
        });
      }
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
    menuListener?.cancel();
    orderListener?.cancel();
    planListener?.cancel();
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
          Icon(icon, size: 42, color: uiPalette.green),
          const SizedBox(height: 16),
          Text(
            heading,
            style: TextStyle(
              color: uiPalette.ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: uiPalette.muted),
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
    initialData: identical(stream, menuStream)
        ? menuRows
        : identical(stream, subscriptionStream)
        ? subRows
        : identical(stream, orderStream)
        ? orderRows
        : null,
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
      context: routeContext,
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
      context: routeContext,
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
      context: routeContext,
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
      context: routeContext,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Assign rider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: riders
                .map(
                  (r) => ListTile(
                    title: Text(
                      (r['name'] as String? ?? '').trim().isNotEmpty
                          ? r['name'] as String
                          : 'Rider ${(r['user_id'] as String).substring(0, 8)}',
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

  String foodImage(String title) {
    for (final item in food.menu) {
      if (item.name == title) return item.image;
    }
    return 'assets/food/hero.jpg';
  }

  Widget section(
    String title,
    String body, {
    IconData icon = Icons.restaurant_outlined,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: uiPalette.green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  style: TextStyle(color: uiPalette.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget serviceAreas() => section(
    'Around your neighbourhood',
    areas.isEmpty ? 'Delivery areas are loading.' : areas.join(' · '),
    icon: Icons.location_on_outlined,
  );

  Widget homeIntro(bool admin) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/food/hero.jpg',
          width: double.infinity,
          height: 210,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 18),
      Text(
        admin ? 'Good food starts here.' : 'Simple food. Full heart.',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        '3 chapatis · Rice · Your choice of 2 bhajis',
        style: TextStyle(color: uiPalette.muted),
      ),
      const SizedBox(height: 20),
      if (!admin) ...[
        section(
          'Your daily routine starts here',
          'Explore Daily and Double Tiffe, or choose a one-time meal.',
          icon: Icons.calendar_month_outlined,
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: cfg == null ? null : openOrder,
              child: const Text('Order a tiffin'),
            ),
            OutlinedButton(
              onPressed: () => setState(() => tab = 3),
              child: const Text('Explore plans'),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ] else
        section(
          'Kitchen workspace',
          'Keep the menu fresh, prepare incoming orders, verify received payments and assign delivery riders.',
          icon: Icons.soup_kitchen_outlined,
        ),
      serviceAreas(),
      Text(
        'From our kitchen',
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        'Pick your favourites. The first two bhajis in each tiffin are included.',
        style: TextStyle(color: uiPalette.muted),
      ),
      const SizedBox(height: 16),
    ],
  );

  String money(String key) => cfg?[key] == null
      ? '...'
      : '₹${((cfg![key] as num) / 100).toStringAsFixed(0)}';

  Widget planCatalogue({bool admin = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 18),
      const Text(
        'Find your daily routine',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        'Home-cooked meals, without the daily planning.',
        style: TextStyle(color: uiPalette.muted),
      ),
      const SizedBox(height: 18),
      for (final doublePlan in [false, true])
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!admin) ...[
                  eyebrow(
                    doublePlan ? 'TWICE THE COMFORT' : 'DAILY HOMEMADE MEALS',
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  doublePlan ? 'Double Tiffe' : 'Daily Tiffe',
                  style: TextStyle(
                    fontSize: 26,
                    fontFamily: admin ? 'TiffeSans' : 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  doublePlan
                      ? 'Two dabbas. Twice the comfort.'
                      : 'One good meal, every day.',
                ),
                const SizedBox(height: 20),
                Text(
                  '${money(doublePlan ? 'double_price_paise' : 'daily_price_paise')} / month',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: uiPalette.green,
                  ),
                ),
                const SizedBox(height: 16),
                for (final benefit in [
                  doublePlan ? '2 tiffins every day' : '1 tiffin every day',
                  '3 chapatis, rice and 2 bhajis per tiffin',
                  'Extra bhaji ${money('extra_bhaji_paise')} each',
                  'Sunday sweet for active subscribers',
                  'Delivery ${money('monthly_delivery_paise')} / month',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: uiPalette.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(benefit)),
                      ],
                    ),
                  ),
                if (!admin) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/food/hero.jpg',
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Monthly plans are set up by the kitchen after payment confirmation.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      section(
        'Just want one today?',
        'One-time Tiffe ${money('one_time_price_paise')} + ${money('one_time_delivery_paise')} delivery. 3 chapatis, rice and 2 bhajis. No Sunday sweet.',
      ),
      if (!admin) orderCta(),
      const SizedBox(height: 18),
      serviceAreas(),
    ],
  );

  Widget orderGuide(bool admin) => Column(
    children: [
      const SizedBox(height: 18),
      section(
        admin ? 'From kitchen to doorstep' : 'Your next dabba starts here',
        admin
            ? 'Confirmed / Preparing / Packed / Out for Delivery / Delivered. Dispatch needs verified payment and an assigned rider.'
            : 'Choose a delivery date and two favourite bhajis per tiffin. Follow kitchen preparation and delivery updates here.',
        icon: Icons.delivery_dining_outlined,
      ),
      if (!admin) orderCta(),
      const SizedBox(height: 16),
      section(
        'Every tiffin includes',
        '3 chapatis, rice and 2 bhajis. Choose extra bhajis for ${money('extra_bhaji_paise')} each.',
      ),
      serviceAreas(),
      OutlinedButton(
        onPressed: () => setState(() => tab = admin ? 1 : 3),
        child: Text(admin ? 'Manage menu' : 'Browse plans'),
      ),
    ],
  );

  Widget customerMenuCards(List<Map<String, dynamic>> rows) => Column(
    children: [
      for (final m in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF202D24)
                  : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Image.asset(
                        foodImage(m['name']),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: m['available'] == true
                                ? const Color(0xFFC1ECD4)
                                : const Color(0xFFFFDBCB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            m['available'] == true
                                ? 'Available'
                                : 'Unavailable',
                            style: const TextStyle(
                              color: Color(0xFF012D1D),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        eyebrow('Home-style bhaji'),
                        Text(
                          m['name'],
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          m['description'] ?? '',
                          style: TextStyle(color: uiPalette.muted, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.restaurant_outlined,
                              size: 18,
                              color: Color(0xFF9E4300),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pick 2 bhajis per tiffin. Extras ${money('extra_bhaji_paise')} each.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget menus() => data(
    menuStream,
    (rows) => rows.isEmpty
        ? empty(
            'The kitchen is getting ready',
            'Today\'s menu will appear here when the kitchen publishes it.',
            Icons.soup_kitchen_outlined,
          )
        : widget.role == null
        ? customerMenuCards(rows)
        : Column(
            children: rows
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: panel(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              foodImage(m['name'] as String),
                              width: 86,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
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
                                  style: TextStyle(color: uiPalette.muted),
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
  Widget orderProgress(Map<String, dynamic> order) {
    const statuses = [
      'Confirmed',
      'Preparing',
      'Packed',
      'Out for Delivery',
      'Delivered',
    ];
    final step = statuses.indexOf(order['status'] as String);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        eyebrow('Delivery progress'),
        for (var i = 0; i < statuses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: i < step
                      ? const Color(0xFF012D1D)
                      : i == step
                      ? const Color(0xFFFF8843)
                      : const Color(0xFFEDEEF0),
                  child: Icon(
                    i < step
                        ? Icons.check
                        : i == step
                        ? Icons.delivery_dining
                        : Icons.circle_outlined,
                    size: 17,
                    color: i <= step ? Colors.white : const Color(0xFF717973),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statuses[i],
                    style: TextStyle(
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                      color: i == step
                          ? const Color(0xFF9E4300)
                          : uiPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (order['status'] == 'Out for Delivery' && order['eta_at'] == null)
          const Text('The kitchen has not shared an arrival time yet.'),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget customerEmptyOrders() => panel(
    child: Column(
      children: [
        const SizedBox(height: 12),
        const Logo(size: 92),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDBCB),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'EMPTY DABBA ALERT',
            style: TextStyle(
              color: Color(0xFF783100),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'No orders yet',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your confirmed meals and delivery updates will appear here. Start with a monthly routine or order one tiffin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: uiPalette.muted),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() => tab = 3),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Explore monthly plans'),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'One-time Tiffe ${money('one_time_price_paise')} + ${money('one_time_delivery_paise')} delivery',
          style: const TextStyle(color: Color(0xFF9E4300), fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget orders() => data(
    orderStream,
    (rows) => rows.isEmpty
        ? widget.role == null
              ? customerEmptyOrders()
              : empty(
                  'No orders to prepare',
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
                          if (widget.role == null) ...[
                            const SizedBox(height: 20),
                            orderProgress(o),
                          ],
                          if (o['status'] == 'Out for Delivery' &&
                              widget.role != null)
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
                                style: TextStyle(color: uiPalette.muted),
                              ),
                            if (o['status'] == 'Packed' &&
                                (o['payment_status'] != 'verified' ||
                                    o['assigned_to'] == null))
                              Text(
                                'Dispatch needs verified payment and a rider.',
                                style: TextStyle(
                                  color: uiPalette.muted,
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
                          style: TextStyle(color: uiPalette.green),
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
      context: routeContext,
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
      context: routeContext,
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
        setState(() {
          profileComplete = true;
          if (widget.role == null) tab = 0;
        });
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
      context: routeContext,
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

  Widget profile({bool onboarding = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panel(
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: uiPalette.green.withValues(alpha: .12),
              child: Icon(
                Icons.person_outline,
                color: uiPalette.green,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onboarding
                        ? 'Make yourself at home'
                        : name.text.isEmpty
                        ? 'Your profile'
                        : name.text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    onboarding
                        ? 'A few details so your dabba reaches you.'
                        : 'Your details, your daily dabba.',
                    style: TextStyle(color: uiPalette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (!loaded && profileError == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (loaded)
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Delivery details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Used only to get your meal to the right doorstep.',
                style: TextStyle(color: uiPalette.muted),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              areas.isEmpty
                  ? TextField(
                      controller: area,
                      decoration: const InputDecoration(
                        labelText: 'Delivery area',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: areas.contains(area.text)
                          ? area.text
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Delivery area',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: areas
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => area.text = v ?? ''),
                    ),
              const SizedBox(height: 16),
              TextField(
                controller: address,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: const InputDecoration(
                  labelText: 'House, building & street',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              if (profileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    profileError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: saving ? null : saveProfile,
                icon: const Icon(Icons.check),
                label: Text(
                  saving
                      ? 'Saving...'
                      : onboarding
                      ? 'Save & continue'
                      : 'Save details',
                ),
              ),
            ],
          ),
        ),
      if (!loaded && profileError != null) ...[
        Text(
          profileError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: loadProfile,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
      const SizedBox(height: 20),
      if (!onboarding)
        panel(
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark mode'),
                  subtitle: const Text('A softer view after sunset'),
                  value: widget.store.darkMode,
                  onChanged: widget.store.setDarkMode,
                  secondary: const Icon(Icons.dark_mode_outlined),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: changePassword,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: widget.backend.signOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );
  @override
  Widget build(BuildContext c) {
    if (widget.role != null) return workspaceBuild(c);
    final dark = Theme.of(c).brightness == Brightness.dark;
    final theme = Theme.of(c).copyWith(
      scaffoldBackgroundColor: dark
          ? const Color(0xFF131C17)
          : const Color(0xFFF9F9FB),
      colorScheme: Theme.of(c).colorScheme.copyWith(
        primary: dark ? const Color(0xFFA5D0B9) : const Color(0xFF012D1D),
        secondary: const Color(0xFF9E4300),
      ),
      textTheme: Theme.of(c).textTheme.apply(fontFamily: 'Inter'),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF131C17)
            : const Color(0xFFF9F9FB),
        foregroundColor: uiPalette.ink,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF202D24) : Colors.white,
        indicatorColor: const Color(0xFFC1ECD4),
        height: 76,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF012D1D),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          themedContext = context;
          return workspaceBuild(context);
        },
      ),
    );
  }

  Widget eyebrow(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: Color(0xFF9E4300),
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget subscriptionSummary() {
    final sub = activeSubscription;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8843),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sub == null ? 'HOME-COOKED. EVERY DAY.' : 'ACTIVE SUBSCRIPTION',
              style: const TextStyle(
                color: Color(0xFF341100),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            sub == null
                ? 'A little home, in every dabba.'
                : (sub['plan'] == 'double' ? 'Double Tiffe' : 'Daily Tiffe'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub == null
                ? 'Choose your favourite bhajis, or find your monthly routine.'
                : '${sub['starts_on']} to ${sub['ends_on']}',
            style: const TextStyle(color: Color(0xFFC1ECD4), height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children:
                [
                      FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF012D1D),
                      ),
                    ]
                    .map(
                      (style) => FilledButton(
                        style: style,
                        onPressed: () => setState(() => tab = 3),
                        child: const Text('Explore plans'),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget customerHome() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hello, ${name.text.trim().split(' ').first}',
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Fresh homemade food. Your daily comfort.',
        style: TextStyle(color: uiPalette.muted),
      ),
      const SizedBox(height: 20),
      subscriptionSummary(),
      const SizedBox(height: 22),
      ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Image.asset(
              'assets/food/hero.jpg',
              width: double.infinity,
              height: 230,
              fit: BoxFit.cover,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xDD012D1D)],
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR HOME-STYLE DABBA',
                    style: TextStyle(
                      color: Color(0xFFFFDBCB),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Simple food. Full heart.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      section(
        'Inside every dabba',
        '3 chapatis, rice and your choice of 2 bhajis. Extra bhajis ${money('extra_bhaji_paise')} each.',
      ),
      orderCta(),
      const SizedBox(height: 24),
      eyebrow("Inside today's dabba"),
      menus(),
      const SizedBox(height: 18),
      serviceAreas(),
    ],
  );

  Widget workspaceBuild(BuildContext c) {
    final admin = widget.role != null;
    if (!admin && !profileComplete) {
      return Scaffold(
        appBar: AppBar(title: const Text('Welcome to Tiffe')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Complete your profile',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  profile(onboarding: true),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
        title: admin
            ? const Text('Tiffe kitchen')
            : Row(
                children: [
                  const Logo(size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DELIVERING TO',
                          style: TextStyle(
                            color: Color(0xFF9E4300),
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          area.text.isEmpty
                              ? 'Your home'
                              : 'Home · ${area.text}',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
          key: ValueKey(tab),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              titles[tab],
              style: TextStyle(
                color: palette(c).ink,
                fontSize: admin ? 30 : 24,
                fontFamily: admin ? 'TiffeSans' : 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (tab == 0 && !admin) customerHome(),
            if (tab == 0 && admin) ...[
              Text(
                admin
                    ? 'Live updates from your kitchen.'
                    : 'A little home, in every dabba.',
                style: TextStyle(color: palette(c).muted),
              ),
              const SizedBox(height: 18),
              homeIntro(admin),
              menus(),
            ],
            if (tab == 1) ...[
              section(
                'Choose your favourites',
                'Two bhajis per tiffin included. Extra bhajis ${money('extra_bhaji_paise')} each.',
              ),
              if (!admin) orderCta(),
              const SizedBox(height: 16),
              menus(),
              serviceAreas(),
            ],
            if (tab == 2) ...[orders(), orderGuide(admin)],
            if (tab == 3 && !admin) ...[
              eyebrow('Homemade meals, delivered daily'),
              planCatalogue(),
              plan(),
            ],
            if (tab == 3 && admin) ...[
              planCatalogue(admin: true),
              plansAdmin(),
            ],
            if (tab == 4) ...[
              profile(),
              const SizedBox(height: 24),
              if (!admin) ...[
                eyebrow('Your subscription'),
                subscriptionSummary(),
                const SizedBox(height: 24),
              ],
            ],
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
    var total = oneTime * tiffins.length + delivery;
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
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Delivery date: ${deliveryDate()}',
                  style: TextStyle(color: palette(c).muted),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/food/hero.jpg',
                    height: 105,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MAKE IT YOUR DABBA',
                  style: TextStyle(
                    color: Color(0xFF9E4300),
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(c).brightness == Brightness.dark
                        ? const Color(0xFF202D24)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill details',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.subscription == null
                            ? '${tiffins.length} tiffin${tiffins.length == 1 ? '' : 's'} · ₹${((widget.cfg['one_time_price_paise'] as int? ?? 0) * tiffins.length) ~/ 100}'
                            : 'Base meals covered by your active plan',
                      ),
                      if (widget.subscription == null)
                        Text(
                          'Delivery · ₹${(widget.cfg['one_time_delivery_paise'] as int? ?? 0) ~/ 100}',
                        ),
                      Text(
                        'Extra bhajis · ₹${(tiffins.fold<int>(0, (sum, t) => sum + (t.length > 2 ? t.length - 2 : 0)) * extra)}',
                      ),
                      const Divider(height: 28),
                      Text(
                        widget.subscription == null
                            ? 'To pay · ₹${pricePaise ~/ 100}'
                            : 'Extras to pay · ₹${pricePaise ~/ 100}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF012D1D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
