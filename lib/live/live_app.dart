import 'dart:math';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';

import '../ui/gemini/edit_profile_screen.dart';
import '../ui/gemini/toast.dart';

import '../ui/tracking_map.dart';
import 'bug_report.dart';
import 'update_check.dart';
import '../ui/gemini/auth_screens.dart';
import '../ui/gemini/home_screen.dart';
import '../ui/gemini/menu_screen.dart';
import '../ui/gemini/orders_screen.dart';
import '../ui/gemini/profile_screen.dart';
import '../ui/gemini/track_screen.dart';

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
        if (b.userId == null) {
          return SignIn(
            backend: b,
            admin: widget.admin,
            showIntro: !widget.admin,
          );
        }
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
  final bool showIntro;
  const SignIn({
    super.key,
    required this.backend,
    this.admin = false,
    this.showIntro = false,
  });
  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  bool registering = false;
  int stage = 0; // 0 splash, 1 onboarding, 2 login
  String? notice;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!widget.showIntro) stage = 2;
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
  Widget build(BuildContext c) {
    if (widget.admin) return adminBuild(c);
    if (stage == 0) return GSplash(onStart: () => setState(() => stage = 1));
    if (stage == 1) {
      return GOnboarding(
        continueLabel: 'Continue',
        onSkip: () => setState(() => stage = 2),
        onContinue: () => setState(() => stage = 2),
      );
    }
    return GEmailLogin(
      busy: busy,
      error: error,
      notice: notice,
      onToggle: () => setState(() {
        registering = !registering;
        error = null;
        notice = null;
      }),
      onSubmit: (e, p, reg) {
        email.text = e;
        password.text = p;
        registering = reg;
        return submit();
      },
    );
  }

  Widget adminBuild(BuildContext c) => Scaffold(
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

class _LiveWorkspaceState extends State<LiveWorkspace>
    with WidgetsBindingObserver {
  DateTime? lastFlush;
  Timer? flushTimer;

  /// Retries reports saved on the phone. At most once a minute.
  void retryReports() {
    final now = DateTime.now();
    if (lastFlush != null &&
        now.difference(lastFlush!) < const Duration(minutes: 1)) {
      return;
    }
    lastFlush = now;
    BugReports.flush(
      widget.backend.client,
      widget.store.prefs,
    ).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) retryReports();
  }

  bool _lastDark = false;
  TiffePalette get uiPalette {
    // A pushed page can rebuild while this state is being torn down; keep the
    // last known brightness then. (Do not use debugIsActive: it is always
    // false in release builds.)
    if (mounted) {
      try {
        _lastDark = Theme.of(context).brightness == Brightness.dark;
      } catch (_) {}
    }
    return TiffePalette(_lastDark, stitch: widget.role == null);
  }

  BuildContext? themedContext;
  BuildContext get routeContext => themedContext ?? context;
  int tab = 0;
  bool oneTimeView = false;
  String selectedPlan = 'daily';
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
    WidgetsBinding.instance.addObserver(this);
    retryReports();
    if (TrackingMap.animateDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) UpdateCheck.run(context, widget.store.prefs);
      });
      flushTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => retryReports(),
      );
    }
    // Returning customer: skip the profile form while the profile loads.
    profileComplete =
        widget.role == null &&
        (widget.store.prefs.getBool(_completeKey) ?? false);
    UpdateCheck.restore(widget.store.prefs);
    UpdateCheck.available.addListener(_onUpdate);
    loadSettings();
    menuListener = menuStream.listen((rows) {
      if (mounted) setState(() => menuRows = rows);
    }, onError: (Object _) {});
    orderListener = orderStream.listen((rows) {
      if (mounted) setState(() => orderRows = rows);
      if (widget.role == null && mounted) loadItems();
    }, onError: (Object _) {});
    planListener = subscriptionStream?.listen((rows) {
      if (mounted) setState(() => subRows = rows);
    }, onError: (Object _) {});
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  /// order id -> chosen bhaji names per tiffin (from order_items).
  Map<String, List<List<String>>> itemsByOrder = {};
  Future<void> loadItems() async {
    try {
      final rows = await widget.backend.orderItems([
        for (final o in orderRows) o['id'] as String,
      ]);
      final m = <String, Map<int, List<String>>>{};
      for (final r in rows) {
        final n = r['item_name'];
        if (n is! String || n.isEmpty) continue;
        m
            .putIfAbsent(r['order_id'] as String, () => {})
            .putIfAbsent((r['tiffin'] as num?)?.toInt() ?? 1, () => [])
            .add(n);
      }
      final out = {
        for (final e in m.entries)
          e.key: [for (final k in (e.value.keys.toList()..sort())) e.value[k]!],
      };
      if (mounted) setState(() => itemsByOrder = out);
    } catch (_) {}
  }

  String _orderTitle(Map<String, dynamic> o) {
    final t = itemsByOrder[o['id']];
    if (t != null && t.isNotEmpty) {
      return t.length == 1
          ? t[0].join(', ')
          : [
              for (var i = 0; i < t.length; i++)
                'Tiffin ${i + 1}: ${t[i].join(', ')}',
            ].join(' · ');
    }
    return '${o['quantity']} Tiffin${o['quantity'] == 1 ? '' : 's'}';
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

  String get _completeKey => 'profile_complete_${widget.backend.userId}';

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
        widget.store.prefs.setBool(_completeKey, profileComplete);
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
    WidgetsBinding.instance.removeObserver(this);
    flushTimer?.cancel();
    menuListener?.cancel();
    UpdateCheck.available.removeListener(_onUpdate);
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
        gToast(context, 'Could not update this order. Refresh and try again.');
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
        gToast(context, 'Could not verify payment. Try again.');
      }
    }
  }

  Future<void> assignRider(Map<String, dynamic> order) async {
    List<Map<String, dynamic>> riders;
    try {
      riders = await widget.backend.deliveryStaff();
    } catch (_) {
      if (mounted) {
        gToast(context, 'Could not load riders. Try again.');
      }
      return;
    }
    if (!mounted) return;
    if (riders.isEmpty) {
      gToast(context, 'No delivery staff yet. Add riders in Supabase first.');
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
        gToast(context, 'Could not assign the rider. Try again.');
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

  Widget planScreen() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 4),
      const Text(
        'MAA KE HAATH KA KHANA',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFF8843),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Wholesome Homemade Meals, Delivered Daily',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: uiPalette.green,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Say goodbye to your daily meal planning. Choose your routine and two favourite bhajis per tiffin.',
        style: TextStyle(color: uiPalette.muted, fontSize: 14.5, height: 1.5),
      ),
      const SizedBox(height: 16),
      planToggle(),
      const SizedBox(height: 16),
      if (!oneTimeView)
        for (final dbl in [false, true]) planCard(dbl)
      else
        oneTimeCard(),
      serviceAreas(),
      plan(),
    ],
  );

  Widget planToggle() {
    Widget seg(String label, bool on, VoidCallback tap) => Expanded(
      child: GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF012D1D) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : uiPalette.muted,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: uiPalette.dark
            ? const Color(0xFF2C3D30)
            : const Color(0xFFEDEEF0),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          seg(
            'Monthly Plans',
            !oneTimeView,
            () => setState(() => oneTimeView = false),
          ),
          seg(
            'One-Time',
            oneTimeView,
            () => setState(() => oneTimeView = true),
          ),
        ],
      ),
    );
  }

  Widget planCard(bool dbl) {
    final key = dbl ? 'double' : 'daily';
    final selected = selectedPlan == key;
    final name = dbl ? 'Double Tiffe' : 'Daily Tiffe';
    return GestureDetector(
      onTap: () => setState(() => selectedPlan = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: uiPalette.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: selected ? uiPalette.green : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dbl
                            ? 'TWICE THE DAILY COMFORT'
                            : 'DAILY HOMEMADE MEALS',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w700,
                          color: uiPalette.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dbl
                            ? 'Two independent dabbas every day'
                            : 'One home-style dabba every day',
                        style: TextStyle(color: uiPalette.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? uiPalette.green : const Color(0xFFC1C8C2),
                  size: 26,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: uiPalette.dark
                  ? const Color(0xFF2C3D30)
                  : const Color(0xFFF3F3F6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(dbl ? 'double_price_paise' : 'daily_price_paise'),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: uiPalette.green,
                    ),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'MONTHLY PLAN',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9E4300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'INSIDE EVERY TIFFIN',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .8,
                color: uiPalette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ['3 Chapatis', 'Rice', '2 Bhajis']) infoChip(t),
              ],
            ),
            const SizedBox(height: 14),
            for (final benefit in [
              dbl ? '2 tiffins every day' : '1 tiffin every day',
              'Sunday sweet for active subscribers',
              'Delivery ${money('monthly_delivery_paise')} / month',
              'Extra bhaji ${money('extra_bhaji_paise')} each',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: uiPalette.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8843),
                  foregroundColor: const Color(0xFF341100),
                  minimumSize: const Size(0, 52),
                ),
                onPressed: cfg == null
                    ? null
                    : () => Navigator.of(routeContext).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlanReview(
                            isDouble: dbl,
                            cfg: cfg!,
                            name: name_,
                            phone: phone.text.trim(),
                            area: area.text.trim(),
                            address: address.text.trim(),
                          ),
                        ),
                      ),
                child: const Text('Subscribe to this plan'),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/food/hero.jpg',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get name_ => name.text.trim();

  Widget oneTimeCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: uiPalette.surface,
      borderRadius: BorderRadius.circular(32),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ONE-TIME TIFFE',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: .8,
            fontWeight: FontWeight.w700,
            color: uiPalette.green,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Just one today?',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: uiPalette.dark
              ? const Color(0xFF2C3D30)
              : const Color(0xFFF3F3F6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money('one_time_price_paise'),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: uiPalette.green,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '+ ${money('one_time_delivery_paise')} delivery',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E4300),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ['3 Chapatis', 'Rice', '2 Bhajis']) infoChip(t),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'No Sunday sweet with a one-time tiffin. Extra bhaji ${money('extra_bhaji_paise')} each.',
          style: TextStyle(color: uiPalette.muted, fontSize: 13.5),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF8843),
              foregroundColor: const Color(0xFF341100),
              minimumSize: const Size(0, 52),
            ),
            onPressed: cfg == null ? null : openOrder,
            child: const Text('Order a tiffin →'),
          ),
        ),
      ],
    ),
  );

  String? selectedDay;
  static String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get earliestOrderDay {
    final cutoff = (cfg?['cutoff_time'] as String? ?? '09:00:00')
        .split(':')
        .map(int.parse)
        .toList();
    var d = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final cutoffToday = DateTime(d.year, d.month, d.day, cutoff[0], cutoff[1]);
    final nowLocal = DateTime(d.year, d.month, d.day, d.hour, d.minute);
    if (!nowLocal.isBefore(cutoffToday)) d = d.add(const Duration(days: 1));
    return ymd(d);
  }

  Widget mealCalendar(List<Map<String, dynamic>> rows) {
    final dark = uiPalette.dark;
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final start = DateTime(now.year, now.month, now.day);
    final today = ymd(start);
    final end = start.add(const Duration(days: 29));
    final lead = start.weekday - 1;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final o in rows) {
      byDay.putIfAbsent(o['delivery_date'] as String, () => []).add(o);
    }
    final completed = rows.where((o) => o['status'] == 'Delivered').length;
    final todayCount = (byDay[today] ?? []).length;
    final upcoming = rows
        .where(
          (o) =>
              (o['delivery_date'] as String).compareTo(today) > 0 &&
              o['status'] != 'Delivered',
        )
        .length;
    final sub = activeSubscription;
    bool inPlan(String d) =>
        sub != null &&
        (sub['starts_on'] as String).compareTo(d) <= 0 &&
        (sub['ends_on'] as String).compareTo(d) >= 0;
    Widget stat(IconData i, String n, String l, Color bg, {bool hi = false}) =>
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: hi ? const Color(0xFFFFDBCB) : uiPalette.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: bg,
                  child: Icon(i, size: 15, color: const Color(0xFF012D1D)),
                ),
                const SizedBox(height: 6),
                Text(
                  n.padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: hi ? const Color(0xFF341100) : null,
                  ),
                ),
                Text(
                  l,
                  style: TextStyle(
                    fontSize: 11,
                    color: hi ? const Color(0xFF341100) : null,
                  ),
                ),
              ],
            ),
          ),
        );
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var i = 0; i < 30; i++) {
      final d = start.add(Duration(days: i));
      final key = ymd(d);
      final os = byDay[key] ?? [];
      final delivered = os.any((o) => o['status'] == 'Delivered');
      final isToday = key == today;
      final sel = selectedDay == key;
      Color bg = dark ? const Color(0xFF2C3D30) : const Color(0xFFF3F3F6);
      Color fg = uiPalette.ink;
      if (delivered) {
        bg = const Color(0xFFE5F4EB);
      } else if (os.isNotEmpty || inPlan(key)) {
        bg = const Color(0xFFE5F4EB);
      }
      if (isToday) {
        bg = const Color(0xFFFF8843);
        fg = const Color(0xFF341100);
      }
      if (sel) {
        bg = const Color(0xFF012D1D);
        fg = Colors.white;
      }
      cells.add(
        GestureDetector(
          onTap: () => setState(() => selectedDay = key),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(
                    Icons.circle,
                    size: 5,
                    color: os.isEmpty
                        ? Colors.transparent
                        : delivered
                        ? const Color(0xFF012D1D)
                        : const Color(0xFF9E4300),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final day = selectedDay ?? today;
    final dayOrders = byDay[day] ?? [];
    final canOrder = cfg != null && day.compareTo(earliestOrderDay) >= 0;
    final dd = DateTime.parse(day);
    const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: uiPalette.green,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your next 30 days',
          style: TextStyle(color: uiPalette.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            stat(
              Icons.check,
              '$completed',
              'Completed',
              const Color(0xFFC1ECD4),
            ),
            stat(
              Icons.shopping_basket_outlined,
              '$todayCount',
              'Today',
              const Color(0xFFFF8843),
              hi: true,
            ),
            stat(
              Icons.event_available_outlined,
              '$upcoming',
              'Upcoming',
              const Color(0xFFC1ECD4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: uiPalette.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: Color(0xFF9E4300),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Meal Schedule',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.34,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEEF0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Tap date to inspect',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF414844),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 11,
                            color: uiPalette.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Fixed height so narrow phones cannot squash the day cells.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent: 44,
                ),
                children: cells,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final l in [
                    if (completed > 0) ['Delivered', const Color(0xFF012D1D)],
                    ['Today', const Color(0xFFFF8843)],
                    ['Order placed', const Color(0xFF9E4300)],
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: l[1] as Color),
                        const SizedBox(width: 5),
                        Text(
                          l[0] as String,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '${wk[dd.weekday - 1].toUpperCase()}, ${months[dd.month - 1].toUpperCase()} ${dd.day}',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9E4300),
          ),
        ),
        const SizedBox(height: 6),
        if (dayOrders.isEmpty)
          Text(
            inPlan(day)
                ? 'Your plan covers this day. No order has been placed for it yet.'
                : 'No order placed for this day.',
            style: TextStyle(color: uiPalette.muted),
          )
        else
          for (final o in dayOrders)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: uiPalette.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${o['quantity']} tiffin${o['quantity'] == 2 ? 's' : ''} - ${o['status']}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        if (canOrder && dayOrders.isEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFDBCB),
                foregroundColor: const Color(0xFF783100),
                minimumSize: const Size(0, 52),
              ),
              onPressed: () => openOrder(date: day),
              icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
              label: Text(
                'Order a tiffin for ${wk[dd.weekday - 1]}, ${months[dd.month - 1]} ${dd.day}',
              ),
            ),
          ),
        ] else if (!canOrder && dayOrders.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              day.compareTo(today) < 0
                  ? 'This day has passed.'
                  : 'Orders for this day have closed (cutoff passed).',
              style: TextStyle(color: uiPalette.muted, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget trackingCard({bool compact = false}) {
    Map<String, dynamic>? live;
    for (final o in orderRows) {
      if (o['status'] == 'Out for Delivery') live = o;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TrackingMap(
        compact: compact,
        area: area.text.trim(),
        kitchenStatus: live?['status'] as String?,
        etaText: live == null
            ? null
            : live['eta_at'] == null
            ? 'The kitchen has not shared an arrival time yet.'
            : 'Kitchen estimate: ${live['eta_at']}.',
      ),
    );
  }

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

  Widget scheduleStrip() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dark = uiPalette.dark;
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = now.add(Duration(days: i));
          final today = i == 0;
          final fg = today ? Colors.white : uiPalette.ink;
          return Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: today
                  ? const Color(0xFF012D1D)
                  : dark
                  ? const Color(0xFF202D24)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: today
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    today ? 'TODAY' : wd[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: .4,
                      fontWeight: FontWeight.w700,
                      color: today ? const Color(0xFFA5D0B9) : uiPalette.muted,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  Text(
                    today ? 'Live menu' : 'Not posted',
                    style: TextStyle(
                      fontSize: 9,
                      color: today ? Colors.white : uiPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget infoChip(String text, {bool filled = false, IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF012D1D)
              : (uiPalette.dark ? const Color(0xFF202D24) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          boxShadow: filled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : uiPalette.ink,
              ),
            ),
          ],
        ),
      );

  Widget customerMenuScreen() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: Color(0xFF9E4300),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Kitchen Tiffin Menu',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDBCB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF783100),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      scheduleStrip(),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          infoChip('All Bhajis', filled: true, icon: Icons.restaurant),
          infoChip('2 included'),
          infoChip('Extras ${money('extra_bhaji_paise')}'),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: uiPalette.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/food/hero.jpg',
                    width: double.infinity,
                    height: 210,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFF012D1D)),
                          SizedBox(width: 6),
                          Text(
                            'YOUR HOME-STYLE DABBA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                              color: Color(0xFF012D1D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC1ECD4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'From our kitchen',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF012D1D),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Your Daily Homestyle Dabba',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color: uiPalette.dark
                      ? const Color(0xFF2C3D30)
                      : const Color(0xFFF3F3F6),
                  child: Column(
                    children: [
                      const Text(
                        'PRICE',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: .6,
                          color: Color(0xFF9E4300),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        money('one_time_price_paise'),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF012D1D),
                        ),
                      ),
                      Text(
                        '+ ${money('one_time_delivery_paise')} delivery',
                        style: TextStyle(fontSize: 10, color: uiPalette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A simple homemade meal. Pick your two favourite bhajis from the kitchen\'s current menu.',
              style: TextStyle(
                color: uiPalette.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: uiPalette.dark
                    ? const Color(0xFF2C3D30)
                    : const Color(0xFFF3F3F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lunch_dining_outlined,
                        size: 18,
                        color: Color(0xFF9E4300),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Inside every tiffin',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '3 items',
                        style: TextStyle(fontSize: 11, color: uiPalette.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final t in [
                    '3 chapatis',
                    'Rice',
                    '2 bhajis of your choice',
                  ])
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: uiPalette.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: cfg == null ? null : openOrder,
                child: const Text('Order a tiffin'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      eyebrow("Today's bhajis"),
      menus(),
      const SizedBox(height: 6),
      serviceAreas(),
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
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFFFB68F)
                                : const Color(0xFF9E4300))
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
            children: [
              ...(widget.role == null
                      ? rows.where((o) => o['status'] != 'Delivered')
                      : rows)
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
                  ),
              if (widget.role == null) ..._historySection(rows),
            ],
          ),
  );

  /// Delivered orders leave the active list and are shown here.
  List<Widget> _historySection(List<Map<String, dynamic>> rows) {
    final done = rows.where((o) => o['status'] == 'Delivered').toList();
    if (done.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      section(
        'Order history',
        '${done.length} delivered order${done.length == 1 ? '' : 's'}',
        icon: Icons.history,
      ),
      const SizedBox(height: 12),
      for (final o in done)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: panel(
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D5B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${o['delivery_date']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${o['quantity']} Tiffin${o['quantity'] == 2 ? 's' : ''} · Delivered',
                      ),
                    ],
                  ),
                ),
                Text('₹${(o['total_paise'] as int) / 100}'),
              ],
            ),
          ),
        ),
    ];
  }

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
        gToast(context, 'Could not load customers. Try again.');
      }
      return;
    }
    if (!mounted) return;
    if (customers.isEmpty) {
      gToast(context, 'No customer profiles yet.');
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

  Future<void> openOrder({String? date}) async {
    final placed = await Navigator.of(routeContext).push<bool>(
      MaterialPageRoute<bool>(
        builder: (c) => OrderSheet(
          backend: widget.backend,
          cfg: cfg!,
          menuRows: menuRows,
          subscription: activeSubscription,
          date: date,
          customerName: name.text.trim(),
          phone: phone.text.trim(),
          area: area.text.trim(),
          address: address.text.trim(),
        ),
      ),
    );
    if (placed == true && mounted) {
      setState(() => tab = 2);
      gToast(context, 'Order placed - the kitchen has it.');
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
        gToast(context, 'Profile updated successfully!');
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
                          gToast(
                            context,
                            'Password changed. Use it next time you sign in.',
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

  static const tabNames = ['Home', 'Menu', 'Orders', 'Plan', 'Profile'];

  Future<void> reportProblem() async {
    final comment = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(sheet).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report a problem',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'One tap sends the app version, the screen you were on and recent errors. Typing is optional.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What went wrong? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheet, true),
                child: const Text('Send report'),
              ),
            ),
          ],
        ),
      ),
    );
    if (send != true) return;
    BugLog.screen = widget.role == null
        ? const ['Home', 'Menu', 'Orders', 'Profile'][tab.clamp(0, 3)]
        : tabNames[tab.clamp(0, 4)];
    final result = await BugReports.send(
      widget.backend.client,
      widget.store.prefs,
      BugReports.build(
        comment: comment.text,
        role: widget.role ?? 'customer',
        userId: widget.backend.userId,
      ),
    );
    if (!mounted) return;
    gToast(context, switch (result) {
      ReportResult.sent => 'Report sent. Thank you.',
      ReportResult.queued => 'Saved on this phone. It will be sent later.',
      ReportResult.full => 'Could not send, and the saved list on this phone is full. Please try again later.',
    });
  }

  Widget profile({bool onboarding = false, bool settings = true}) => Column(
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
      if (!onboarding && settings)
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
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('Check for updates'),
                  subtitle: Text('Version $appVersion'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => UpdateCheck.run(
                    context,
                    widget.store.prefs,
                    manual: true,
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report a problem'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: reportProblem,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      if (settings)
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
        // The selected pill is light green in both modes, so its icon must
        // be dark green (the default turned near-white in dark mode).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF012D1D)
                : dark
                ? const Color(0xFFCBD6CC)
                : const Color(0xFF414844),
          ),
        ),
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
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFFB68F)
            : const Color(0xFF9E4300),
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget subscriptionSummary({bool compact = false}) {
    final sub = activeSubscription;
    final planName = sub == null
        ? null
        : (sub['plan'] == 'double' ? 'Double Tiffe' : 'Daily Tiffe');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33012D1D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8843),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: Color(0xFF341100),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sub == null
                        ? 'HOMEMADE. EVERY DAY.'
                        : 'ACTIVE ${planName!.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Color(0xFF341100),
                      fontSize: 10.5,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            sub == null ? 'Your next dabba starts here' : planName!,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub == null
                ? 'Choose your favourite bhajis. Confirm your meal so the kitchen can prepare it.'
                : '${sub['starts_on']} to ${sub['ends_on']}',
            style: const TextStyle(
              color: Color(0xFFA5D0B9),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Flexible(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF012D1D),
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: cfg == null ? null : openOrder,
                    icon: const Icon(Icons.lunch_dining_outlined, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Choose my dabba'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => setState(() => tab = 3),
                  child: const Text(
                    'My Plan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget infoPill(String text, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: uiPalette.dark ? const Color(0xFF2C3D30) : const Color(0xFFEDEEF0),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget cutoffStrip() {
    final cut = (cfg?['cutoff_time'] as String? ?? '').split(':');
    final label = cut.length >= 2
        ? 'Cutoff ${cut[0]}:${cut[1]}'
        : 'Cutoff time';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: uiPalette.dark
            ? const Color(0xFF2C3D30)
            : const Color(0xFFEDEEF0),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF012D1D),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Today's Tiffe",
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: uiPalette.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget customerHome() {
    final first = name.text.trim().split(' ').first;
    final extra = money('extra_bhaji_paise');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $first! 🍲',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: uiPalette.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fresh homemade food for your daily routine.',
                    style: TextStyle(color: uiPalette.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEEF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 20,
                color: Color(0xFF414844),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        cutoffStrip(),
        const SizedBox(height: 20),
        subscriptionSummary(),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: uiPalette.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/food/hero.jpg',
                      width: double.infinity,
                      height: 208,
                      fit: BoxFit.cover,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [.35, 1],
                            colors: [
                              Colors.transparent,
                              const Color(0xCC012D1D),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_outlined,
                              size: 13,
                              color: Color(0xFF9E4300),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'HOME-STYLE TIFFIN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .4,
                                color: Color(0xFF012D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR DAILY DABBA',
                                  style: TextStyle(
                                    color: Color(0xFFFFDBCB),
                                    fontSize: 10,
                                    letterSpacing: .8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '3 Chapatis, Rice & Your Favourite Bhajis',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: Colors.white,
                                    fontSize: 19,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Text(
                              '2 bhajis\nincluded',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF012D1D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: uiPalette.dark
                      ? const Color(0xFF2C3D30)
                      : const Color(0xFFF3F3F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    for (final t in ['3 chapatis', 'Rice', '2 bhajis'])
                      Expanded(
                        child: Text(
                          t,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your home-style tiffin, with two bhajis of your choice. Add another favourite for $extra each.',
                style: TextStyle(
                  color: uiPalette.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        eyebrow("Inside today's dabba"),
        menus(),
        const SizedBox(height: 18),
        serviceAreas(),
      ],
    );
  }

  // ---- Redesigned customer shell (Home, Menu, Orders, Profile) ----
  final ValueNotifier<int> _rev = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _rev.value++;
  }

  static String _istDay([int plusDays = 0]) {
    final d = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30, days: 0))
        .add(Duration(days: plusDays));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _niceDay(String iso) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${int.parse(p[2])} ${m[int.parse(p[1]) - 1]} ${p[0]}';
  }

  Future<void> _push(String title, Widget Function() body) {
    final themeData = Theme.of(routeContext);
    return Navigator.of(routeContext).push(
      MaterialPageRoute<void>(
        builder: (c) => Theme(
          data: themeData,
          child: Scaffold(
            backgroundColor: themeData.brightness == Brightness.dark
                ? themeData.scaffoldBackgroundColor
                : const Color(0xFFFBF9F5),
            appBar: AppBar(
              title: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            body: SafeArea(
              child: ValueListenableBuilder<int>(
                valueListenable: _rev,
                builder: (_, _, _) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [body()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _helpPage() => _push(
    'Help & Support',
    () => panel(
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Check for updates'),
              subtitle: Text('Version $appVersion'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => UpdateCheck.run(
                routeContext,
                widget.store.prefs,
                manual: true,
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report a problem'),
              trailing: const Icon(Icons.chevron_right),
              onTap: reportProblem,
            ),
          ],
        ),
      ),
    ),
  );

  void _editProfilePage() {
    final email = widget.backend.client.auth.currentUser?.email ?? '';
    Navigator.of(routeContext).push(
      MaterialPageRoute<void>(
        builder: (c) => ValueListenableBuilder<int>(
          valueListenable: _rev,
          builder: (c2, _, _) => GEditProfile(
            name: name,
            phone: phone,
            address: address,
            email: email,
            area: area.text,
            areas: areas,
            onArea: (v) => setState(() => area.text = v),
            error: profileError,
            saving: saving,
            loaded: loaded,
            onPassword: changePassword,
            onSave: () async {
              await saveProfile();
              if (mounted && profileError == null && c2.mounted) {
                Navigator.of(c2).maybePop();
              }
            },
          ),
        ),
      ),
    );
  }

  void _subscriptionPage() => _push(
    'My Tiffin Subscription',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        subscriptionSummary(),
        const SizedBox(height: 20),
        planScreen(),
      ],
    ),
  );

  void _schedulePage() => _push(
    'Your schedule',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [data(orderStream, mealCalendar)],
    ),
  );

  static String _shortId(String id) =>
      (id.length > 6 ? id.substring(0, 6) : id).toUpperCase();

  static String? _clock(Object? iso, {bool day = false}) {
    final d = iso is String ? DateTime.tryParse(iso)?.toLocal() : null;
    if (d == null) return null;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final t =
        '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
    if (!day) return t;
    final n = DateTime.now();
    if (d.year == n.year && d.month == n.month && d.day == n.day) {
      return 'Today, $t';
    }
    return '${_niceDay('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}').replaceFirst(' ${d.year}', '')}, $t';
  }

  /// Real delivery time: the kitchen ETA if set, else the kitchen's
  /// delivery_time setting on the delivery date.
  String? _dueText(Map<String, dynamic> o) {
    final eta = _clock(o['eta_at'], day: true);
    if (eta != null) return 'Arriving by $eta';
    final dt = (cfg?['delivery_time'] as String? ?? '').split(':');
    if (dt.length < 2) return null;
    final hh = int.tryParse(dt[0]), mm = int.tryParse(dt[1]);
    if (hh == null || mm == null) return null;
    final h = hh % 12 == 0 ? 12 : hh % 12;
    final day = o['delivery_date'] as String;
    final n = DateTime.now();
    final today =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    return 'Delivery ${day == today ? 'today' : _niceDay(day)} around $h:${mm.toString().padLeft(2, '0')} ${hh >= 12 ? 'PM' : 'AM'}';
  }

  /// rider_name / rider_phone columns on the order win; the name falls back
  /// to Mukesh (owner decision) while out for delivery. Phone is never invented.
  static String? _riderName(Map<String, dynamic> o) {
    final n = o['rider_name'];
    if (n is String && n.trim().isNotEmpty) return n.trim();
    // Owner decision: until real rider data exists, Mukesh is the delivery
    // partner for orders that are out for delivery.
    return o['status'] == 'Out for Delivery' ? 'Mukesh' : null;
  }

  static String? _riderPhone(Map<String, dynamic> o) {
    final n = o['rider_phone'];
    final d = n is String ? n.replaceAll(RegExp(r'[^0-9+]'), '') : '';
    return d.length >= 8 ? d : null;
  }

  void _livePage(String id) {
    Navigator.of(routeContext).push(
      MaterialPageRoute<void>(
        builder: (c) => ValueListenableBuilder<int>(
          valueListenable: _rev,
          builder: (c2, _, _) {
            Map<String, dynamic>? row;
            for (final o in orderRows) {
              if ('#${_shortId(o['id'] as String)}' == id) row = o;
            }
            final eta = row == null ? null : _clock(row['eta_at'], day: true);
            final rider = row == null ? null : _riderName(row);
            final phone = row == null ? null : _riderPhone(row);
            return GLive(
              headline: eta != null
                  ? 'Arriving by $eta'
                  : row?['status'] == 'Out for Delivery'
                  ? 'On its way'
                  : '${row?['status'] ?? 'Order'}',
              detail: rider != null
                  ? 'Delivery partner $rider has your order. The kitchen ${eta != null ? 'estimate is above' : 'has not shared an arrival time yet'}.'
                  : eta != null
                  ? 'Your order is out for delivery.'
                  : 'The kitchen has not shared an arrival time yet.',
              map: trackingCard(compact: true),
              onCall: phone == null
                  ? null
                  : () => UpdateCheck.opener(Uri.parse('tel:$phone')),
            );
          },
        ),
      ),
    );
  }

  void _trackPage(String id) {
    Map<String, dynamic>? find() {
      for (final o in orderRows) {
        if ('#${_shortId(o['id'] as String)}' == id) return o;
      }
      return null;
    }

    final nav = Navigator.of(routeContext);
    nav.push(
      MaterialPageRoute<void>(
        builder: (c) => ValueListenableBuilder<int>(
          valueListenable: _rev,
          builder: (c2, _, _) {
            final row = mounted ? find() : null;
            if (row == null) {
              return GTrack(
                orderId: id,
                subtitle: 'Order details are not available right now.',
                steps: const [],
              );
            }
            const order = [
              'Confirmed',
              'Preparing',
              'Packed',
              'Out for Delivery',
              'Delivered',
            ];
            final status = row['status'] as String;
            final at = order.indexOf(status);
            final out = status == 'Out for Delivery';
            final rider = _riderName(row);
            String label(String st, bool done) => switch (st) {
              'Confirmed' => 'Order Confirmed',
              'Preparing' =>
                done
                    ? 'Meal Prepared in Hygienic Kitchen'
                    : 'Meal being prepared in the kitchen',
              'Packed' =>
                done ? 'Packed in Insulated Thermal Bag' : 'Packing your order',
              'Out for Delivery' =>
                rider == null
                    ? 'Out for Delivery'
                    : 'Out for Delivery (Delivery Partner: $rider)',
              _ => 'Delivered',
            };
            return GTrack(
              orderId: id,
              subtitle:
                  '${row['subscription_id'] == null ? 'One-time' : 'Subscription'} • $status • ${row['quantity']} Tiffin${row['quantity'] == 1 ? '' : 's'}',
              steps: at < 0
                  ? [GTrackStep(status, GStepState.pending)]
                  : [
                      // All steps always: done, current (spinner), upcoming.
                      for (var i = 0; i < order.length; i++)
                        GTrackStep(
                          label(
                            order[i],
                            i != at || i == 0 || order[i] == 'Delivered',
                          ),
                          i < at ||
                                  (i == at &&
                                      (i == 0 || order[i] == 'Delivered'))
                              ? GStepState.done
                              : i == at
                              ? GStepState.current
                              : GStepState.pending,
                          note: order[i] == 'Out for Delivery' && out
                              ? (row['eta_at'] == null
                                    ? 'The kitchen has not shared an arrival time yet.'
                                    : 'Kitchen estimate: ${_clock(row['eta_at'], day: true) ?? row['eta_at']}')
                              : null,
                        ),
                    ],
              onMap: out ? () => _livePage(id) : null,
            );
          },
        ),
      ),
    );
  }

  Future<void> _orderBhajis(List<String> names) async {
    if (cfg == null) return;
    final ids = <String>[
      for (final n in names)
        for (final m in menuRows)
          if (m['name'] == n && m['available'] == true) m['id'] as String,
    ];
    final placed = await Navigator.of(routeContext).push<bool>(
      MaterialPageRoute<bool>(
        builder: (c) => OrderSheet(
          backend: widget.backend,
          cfg: cfg!,
          menuRows: menuRows,
          subscription: activeSubscription,
          customerName: name.text.trim(),
          phone: phone.text.trim(),
          area: area.text.trim(),
          address: address.text.trim(),
          initialBhajis: ids,
        ),
      ),
    );
    if (placed == true && mounted) {
      setState(() => tab = 2);
      gToast(context, 'Order placed - the kitchen has it.');
    }
  }

  Widget customerShell() {
    final t = tab.clamp(0, 3);
    void go(int i) => setState(() => tab = i);
    final avail = menuRows.where((m) => m['available'] == true).toList();
    var email = '';
    try {
      email = widget.backend.client.auth.currentUser?.email ?? '';
    } catch (_) {}
    final first = name.text.trim().split(' ').first;
    Widget body;
    switch (t) {
      case 1:
        body = GMenu(
          categories: const ['Today’s Menu'],
          items: [
            [
              for (final m in avail)
                GMenuItem(
                  m['name'] as String,
                  (m['description'] as String?) ?? '',
                  '',
                  '',
                  foodImage(m['name'] as String),
                ),
            ],
          ],
          showWeekly: false,
          maxPick: 8,
          extraRupees: ((cfg?['extra_bhaji_paise'] as num?) ?? 0) ~/ 100,
          onTab: go,
          onOrder: (sel) => _orderBhajis([for (final i in sel) i.title]),
        );
      case 2:
        body = GOrders(
          orders: [
            for (final o in orderRows)
              GOrder(
                '#${_shortId(o['id'] as String)}',
                o['subscription_id'] == null ? 'One-time' : 'Subscription',
                o['status'] as String,
                _orderTitle(o),
                _niceDay(o['delivery_date'] as String),
                '₹${((o['total_paise'] as num) / 100).toStringAsFixed(0)} · ${o['payment_status']}',
                live: o['status'] == 'Out for Delivery',
                placed: _clock(o['created_at'], day: true),
                due: _dueText(o),
              ),
          ],
          emptyText: 'No orders yet. Order a tiffin from the Menu and it will show up here.',
          onTab: go,
          onTrack: (o) => _trackPage(o.id),
        );
      case 3:
        body = GProfile(
          name: name.text.trim().isEmpty ? 'Your profile' : name.text.trim(),
          contact: email,
          showAddresses: false,
          showNotifications: false,
          onEdit: _editProfilePage,
          onSubscription: _subscriptionPage,
          onHelp: _helpPage,
          version: 'v$currentBuild',
          onUpdate: () =>
              UpdateCheck.run(routeContext, widget.store.prefs, manual: true),
          onLogout: widget.backend.signOut,
          onTab: go,
        );
      default:
        final sub = activeSubscription;
        Map<String, dynamic>? today;
        for (final o in orderRows) {
          if (o['delivery_date'] == _istDay()) today = o;
        }
        final monthlyFrom = cfg == null
            ? ''
            : 'From ${money('daily_price_paise')} / month + ${money('monthly_delivery_paise')} delivery';
        final feat = avail.isEmpty ? null : avail.first;
        body = GHome(
          updateBuild: UpdateCheck.available.value,
          onUpdate: () => UpdateCheck.opener(Uri.parse(updatePage)),
          address: area.text.isEmpty ? 'Your home' : 'Home · ${area.text}',
          name: first.isEmpty ? 'there' : first,
          subtitle: 'Rozcha dabba. Tumchya choice cha.',
          planTitle: sub == null
              ? 'No active plan'
              : sub['plan'] == 'double'
              ? 'Double Tiffe'
              : 'Daily Tiffe',
          planSubtitle: sub == null
              ? 'Order one tiffin or start a monthly plan'
              : 'Valid till ${_niceDay(sub['ends_on'] as String)}',
          todayLabel: 'Today: ',
          todayMeal: today == null
              ? 'No order yet'
              : '${today['quantity']} Tiffin${today['quantity'] == 1 ? '' : 's'}',
          todayStatus: today == null ? '' : today['status'] as String,
          showPause: false,
          hasPlan: sub != null,
          showBell: false,
          showFeatured: feat != null,
          featuredHeading: 'On Today’s Menu',
          thaliImage: feat == null
              ? 'assets/food/hero.jpg'
              : foodImage(feat['name'] as String),
          thaliTitle: feat == null ? '' : feat['name'] as String,
          thaliBlurb: feat == null
              ? ''
              : (feat['description'] as String?) ?? '',
          thaliPrice: '',
          thaliTag: '',
          thaliNote: 'Homemade daily',
          monthlySub: monthlyFrom,
          onViewSchedule: _schedulePage,
          onViewMenu: () => go(1),
          onOrder: () =>
              _orderBhajis(feat == null ? const [] : [feat['name'] as String]),
          onQuickOne: () => go(1),
          onQuickMonthly: _subscriptionPage,
          onTab: go,
        );
    }
    return Theme(data: Theme.of(routeContext), child: body);
  }

  Widget workspaceBuild(BuildContext c) {
    final admin = widget.role != null;
    if (!admin && profileComplete) return customerShell();
    if (!admin && !profileComplete && !loaded && profileError == null) {
      // Profile still loading: neutral screen, not the profile form.
      return const Scaffold(
        backgroundColor: Color(0xFFFBF9F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
            : tab == 3
            ? const Text(
                'Plan Customization',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              )
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
            : [
                IconButton(
                  tooltip: 'Report a problem',
                  onPressed: reportProblem,
                  icon: const Icon(Icons.flag_outlined),
                ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () => setState(() => tab = 4),
                  icon: const Icon(Icons.person_outline),
                ),
              ],
      ),
      body: SafeArea(
        child: ListView(
          key: ValueKey(tab),
          padding: EdgeInsets.all(admin ? 24 : 20),
          children: [
            if (admin)
              Text(
                titles[tab],
                style: TextStyle(
                  color: palette(c).ink,
                  fontSize: admin ? 30 : 24,
                  fontFamily: admin ? 'TiffeSans' : 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                ),
              ),
            SizedBox(height: admin ? 12 : 4),
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
            if (tab == 1 && !admin) customerMenuScreen(),
            if (tab == 1 && admin) ...[
              section(
                'Choose your favourites',
                'Two bhajis per tiffin included. Extra bhajis ${money('extra_bhaji_paise')} each.',
              ),
              const SizedBox(height: 16),
              menus(),
              serviceAreas(),
            ],
            if (tab == 2) ...[
              if (!admin) trackingCard(),
              if (!admin) data(orderStream, mealCalendar),
              orders(),
              orderGuide(admin),
            ],
            if (tab == 3 && !admin) planScreen(),
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
  final String? date;
  final String customerName, phone, area, address;
  final List<String> initialBhajis;
  const OrderSheet({
    super.key,
    required this.backend,
    required this.cfg,
    required this.menuRows,
    this.subscription,
    this.date,
    this.customerName = '',
    this.phone = '',
    this.area = '',
    this.address = '',
    this.initialBhajis = const [],
  });
  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  final instructions = TextEditingController();
  late final List<Set<String>> tiffins = [
    {...widget.initialBhajis},
    if (widget.subscription?['plan'] == 'double') {},
  ];
  bool busy = false;
  String? error;
  late final String idempotencyKey = newOrderKey();

  @override
  void initState() {
    super.initState();
    // No complete selection yet: send the customer straight to the Menu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tiffins[0].length < 2) _pick(0);
    });
  }

  int get _firstIncomplete {
    for (var i = 0; i < tiffins.length; i++) {
      if (tiffins[i].length < 2) return i;
    }
    return -1;
  }

  /// Bhajis are chosen on the Menu page; checkout only uses the result.
  Future<bool> _pick(int i) async {
    final avail = widget.menuRows.where((m) => m['available'] == true).toList();
    final extraR = ((widget.cfg['extra_bhaji_paise'] as num?) ?? 0) ~/ 100;
    final names = {
      for (final m in avail) m['name'] as String: m['id'] as String,
    };
    final chosen = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (c) => GMenu(
          categories: const ['Today’s Menu'],
          items: [
            [
              for (final m in avail)
                GMenuItem(
                  m['name'] as String,
                  (m['description'] as String?) ?? '',
                  '',
                  '',
                  food.menu.any((f) => f.name == m['name'])
                      ? food.menu.firstWhere((f) => f.name == m['name']).image
                      : 'assets/food/hero.jpg',
                ),
            ],
          ],
          showWeekly: false,
          maxPick: 8,
          extraRupees: extraR,
          initialSelected: [
            for (var k = 0; k < avail.length; k++)
              if (tiffins[i].contains(avail[k]['id'])) k,
          ],
          onTab: (_) => Navigator.of(c).maybePop(),
          onOrder: (sel) =>
              Navigator.of(c).pop([for (final it in sel) names[it.title]!]),
        ),
      ),
    );
    if (chosen == null || !mounted) return false;
    setState(() {
      error = null;
      tiffins[i] = {...chosen};
    });
    return true;
  }

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
    if (widget.date != null) return widget.date!;
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

  String _names(Set<String> ids) => [
    for (final m in widget.menuRows)
      if (ids.contains(m['id'])) m['name'] as String,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final extra = (widget.cfg['extra_bhaji_paise'] as int? ?? 0) ~/ 100;
    final extras =
        tiffins.fold<int>(
          0,
          (sum, t) => sum + (t.length > 2 ? t.length - 2 : 0),
        ) *
        extra;
    final oneTime = (widget.cfg['one_time_price_paise'] as int? ?? 0) ~/ 100;
    final delivery =
        (widget.cfg['one_time_delivery_paise'] as int? ?? 0) ~/ 100;
    final sub = widget.subscription != null;
    Widget card(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: GColors.line),
      ),
      child: child,
    );
    Widget h(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        t,
        style: gText(17, w: FontWeight.w700, c: GColors.green),
      ),
    );
    Widget line(String l, String r, {bool bold = false, Color? rc}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l,
              style: gText(
                14,
                w: bold ? FontWeight.w800 : FontWeight.w500,
                c: bold ? GColors.green : GColors.charcoal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            r,
            style: gText(
              14,
              w: FontWeight.w700,
              c: rc ?? (bold ? GColors.saffron : GColors.green),
            ),
          ),
        ],
      ),
    );
    final total = '₹${pricePaise ~/ 100}';
    final addressLines = [
      if (widget.address.isNotEmpty) widget.address,
      if (widget.area.isNotEmpty) widget.area,
      if (widget.phone.isNotEmpty) widget.phone,
    ];
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: GColors.cream,
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'PlusJakartaSans'),
      ),
      child: Scaffold(
        backgroundColor: GColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1ECE2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: GColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Order Checkout',
                          style: gText(
                            24,
                            w: FontWeight.w800,
                            c: GColors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  children: [
                    card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          h('Delivery Address'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F4EE),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: GColors.saffron,
                                  size: 26,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.customerName.isEmpty
                                            ? 'Delivery address'
                                            : widget.customerName,
                                        style: gText(
                                          14,
                                          w: FontWeight.w700,
                                          c: GColors.green,
                                        ),
                                      ),
                                      for (final l in addressLines)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ),
                                          child: Text(
                                            l,
                                            style: gText(
                                              13,
                                              c: GColors.grey,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Delivery date: ${deliveryDate()}',
                                          style: gText(
                                            12,
                                            w: FontWeight.w600,
                                            c: GColors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          h('Kitchen Notes'),
                          TextField(
                            controller: instructions,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              labelText: 'Note for the kitchen (optional)',
                            ),
                          ),
                        ],
                      ),
                    ),
                    card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          h('Order Summary'),
                          for (var i = 0; i < tiffins.length; i++) ...[
                            line(
                              tiffins[i].isEmpty
                                  ? 'Tiffin ${i + 1}: no bhajis picked yet'
                                  : 'Tiffin ${i + 1} (${_names(tiffins[i])})',
                              sub ? 'In your plan' : '₹$oneTime',
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: busy ? null : () => _pick(i),
                                style: TextButton.styleFrom(
                                  foregroundColor: GColors.saffron,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: gText(12.5, w: FontWeight.w700),
                                ),
                                child: Text(
                                  tiffins[i].isEmpty
                                      ? 'Pick bhajis from the Menu'
                                      : 'Change bhajis in the Menu',
                                ),
                              ),
                            ),
                          ],
                          if (tiffins.length < 2 && !sub)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        setState(() => tiffins.add({}));
                                        final ok = await _pick(1);
                                        if (!ok && mounted) {
                                          setState(() => tiffins.removeLast());
                                        }
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: GColors.saffron,
                                  padding: EdgeInsets.zero,
                                  textStyle: gText(12.5, w: FontWeight.w700),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add a second tiffin'),
                              ),
                            ),
                          if (extras > 0) line('Extra bhajis', '₹$extras'),
                          line(
                            'Delivery Charge',
                            sub
                                ? 'In your plan'
                                : delivery == 0
                                ? 'FREE'
                                : '₹$delivery',
                          ),
                          const Divider(height: 24, color: GColors.line),
                          line(
                            sub ? 'Extras to pay' : 'Total Amount',
                            total,
                            bold: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sub
                                ? pricePaise == 0
                                      ? 'Covered by your Tiffe plan.'
                                      : 'Extras: $total. The rest is covered by your plan.'
                                : 'Total: $total. Online payment is not in the app yet - Tiffe confirms payment with you directly.',
                            style: gText(12.5, c: GColors.grey, height: 1.4),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                error!,
                                style: gText(13, c: const Color(0xFFB3261E)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: GButton(
                  busy
                      ? 'Placing...'
                      : _firstIncomplete >= 0
                      ? 'Pick bhajis from the Menu'
                      : pricePaise == 0
                      ? 'Place Order'
                      : 'Pay $total & Place Order',
                  onPressed: busy
                      ? null
                      : _firstIncomplete >= 0
                      ? () => _pick(_firstIncomplete)
                      : place,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanReview extends StatelessWidget {
  final bool isDouble;
  final Map<String, dynamic> cfg;
  final String name, phone, area, address;
  const PlanReview({
    super.key,
    required this.isDouble,
    required this.cfg,
    required this.name,
    required this.phone,
    required this.area,
    required this.address,
  });
  String rs(String k) => '₹${((cfg[k] as num) / 100).toStringAsFixed(0)}';
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF202D24) : Colors.white;
    final muted = dark ? const Color(0xFFAEB9AE) : const Color(0xFF738074);
    final planKey = isDouble ? 'double_price_paise' : 'daily_price_paise';
    final total =
        ((cfg[planKey] as num) + (cfg['monthly_delivery_paise'] as num)) / 100;
    final planName = isDouble ? 'Double Tiffe' : 'Daily Tiffe';
    Widget card(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    Widget line(String l, String r, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(
                fontSize: big ? 22 : 15,
                fontWeight: big ? FontWeight.w700 : FontWeight.w400,
                fontFamily: big ? 'PlusJakartaSans' : null,
              ),
            ),
          ),
          Text(
            r,
            style: TextStyle(
              fontSize: big ? 22 : 15,
              fontWeight: big ? FontWeight.w700 : FontWeight.w400,
              fontFamily: big ? 'PlusJakartaSans' : null,
            ),
          ),
        ],
      ),
    );
    Widget chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C3D30) : const Color(0xFFF3F3F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        t,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: dark
            ? const Color(0xFF131C17)
            : const Color(0xFFF9F9FB),
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter'),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: dark
              ? const Color(0xFF131C17)
              : const Color(0xFFF9F9FB),
          scrolledUnderElevation: 0,
          title: const Text(
            'Review Your Plan',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF2C3D30)
                      : const Color(0xFFEDEEF0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xFF012D1D),
                      child: Text(
                        '1',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Review & Address',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC1ECD4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'MONTHLY HOMEMADE MEALS',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: .4,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF012D1D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            planName,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          rs(planKey),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isDouble
                          ? '2 tiffins a day, each with your choice of two bhajis.'
                          : '1 tiffin a day, with your choice of two bhajis.',
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('3 Chapatis'),
                        chip('Rice'),
                        chip('2 Bhajis / tiffin'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Start and end dates are confirmed by the kitchen when your payment is verified.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                    if (area.isNotEmpty)
                      Text(area, style: TextStyle(color: muted, fontSize: 14)),
                    if (phone.isNotEmpty)
                      Text(phone, style: TextStyle(color: muted, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      'Edit your address from Profile.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Details',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    line('Monthly plan', rs(planKey)),
                    line('Monthly delivery', rs('monthly_delivery_paise')),
                    const Divider(height: 24),
                    line('Total', '₹${total.toStringAsFixed(0)}', big: true),
                    const SizedBox(height: 6),
                    Text(
                      'Extra bhajis are charged on each meal, not included here (${rs('extra_bhaji_paise')} each).',
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                  onPressed: null,
                  child: const Text('Request subscription'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Subscription requests are not open in the app yet. Nothing is charged or booked from this page.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
