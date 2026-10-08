import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/store.dart';
import '../domain/tiffin.dart';

const cream = Color(0xFFFAF8F0),
    green = Color(0xFF285A3F),
    ink = Color(0xFF263A2E),
    muted = Color(0xFF738074),
    orange = Color(0xFFD49045);
String dayLabel(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

class TiffeApp extends StatelessWidget {
  final TiffeStore store;
  const TiffeApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tiffe',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: cream,
      ),
      fontFamily: 'TiffeSans',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 15, height: 1.45),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'TiffeSans',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'TiffeSans', fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'TiffeSans', fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDCE2D7)),
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
    ),
    home: Splash(store: store),
  );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 72});
  @override
  Widget build(BuildContext c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: green,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    child: Icon(Icons.bento_rounded, color: cream, size: size * .59),
  );
}

class Splash extends StatefulWidget {
  final TiffeStore store;
  const Splash({super.key, required this.store});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => widget.store.onboarded
                ? Shell(store: widget.store)
                : Onboarding(store: widget.store),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: Center(
      child: FadeTransition(
        opacity: controller,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: .86, end: 1.0).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
              ),
              child: const Logo(size: 96),
            ),
            const SizedBox(height: 22),
            const Text(
              'Tiffe',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: green,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Rozcha dabba. Tumchya choice cha.',
              style: TextStyle(color: muted, fontSize: 16),
            ),
            const SizedBox(height: 48),
            const Text(
              'MADE AT HOME. MADE FOR PUNE.',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class Onboarding extends StatefulWidget {
  final TiffeStore store;
  const Onboarding({super.key, required this.store});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  String area = 'Kothrud';
  final form = GlobalKey<FormState>();
  final phone = TextEditingController(),
      otp = TextEditingController(),
      name = TextEditingController(),
      address = TextEditingController();
  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    name.dispose();
    address.dispose();
    super.dispose();
  }

  void next() async {
    if (!form.currentState!.validate()) return;
    if (step < 2) {
      setState(() => step++);
      return;
    }
    widget.store
      ..phone = phone.text
      ..name = name.text.trim()
      ..address = address.text.trim()
      ..area = area
      ..onboarded = true;
    await widget.store.save();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Shell(store: widget.store)),
      );
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Logo(),
              const SizedBox(height: 32),
              Text(
                [
                  'Your daily dabba,\nsorted.',
                  'A little verification.',
                  'Make yourself\nat home.',
                ][step],
                style: const TextStyle(
                  fontSize: 36,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  color: ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                [
                  'Fresh home-cooked food. Your choice of bhaji. Every single day.',
                  'Enter your code and make yourself at home.',
                  'Just your name and where your Tiffe should arrive.',
                ][step],
                style: const TextStyle(color: muted, fontSize: 16),
              ),
              const SizedBox(height: 28),
              const Chip(label: Text('Tiffe Demo')),
              const SizedBox(height: 20),
              if (step == 0)
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '+91  ',
                  ),
                  validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                      ? null
                      : 'Enter a valid 10-digit Indian mobile number',
                ),
              if (step == 1) ...[
                Text(
                  'Demo OTP: 123456 • +91 ${phone.text}',
                  style: const TextStyle(color: green),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: otp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: '6-digit OTP'),
                  validator: (v) =>
                      v == '123456' ? null : 'Use the demo code 123456',
                ),
              ],
              if (step == 2) ...[
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) =>
                      (v ?? '').trim().length >= 2 ? null : 'Enter your name',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Flat, building and street',
                  ),
                  validator: (v) => (v ?? '').trim().length >= 8
                      ? null
                      : 'Add a complete delivery address',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: area,
                  decoration: const InputDecoration(labelText: 'Pune area'),
                  items:
                      [
                            'Kothrud',
                            'Baner',
                            'Aundh',
                            'Wakad',
                            'Viman Nagar',
                            'Other area',
                          ]
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                  onChanged: (a) => setState(() => area = a!),
                  validator: (v) => v == 'Other area'
                      ? "Tiffe isn't delivering to your area yet."
                      : null,
                ),
                if (area == 'Other area')
                  TextButton(
                    onPressed: () => showDialog(
                      context: c,
                      builder: (_) => AlertDialog(
                        title: const Text('Not in your area yet'),
                        content: const Text(
                          'The waitlist is not open yet. Check back soon.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('View waitlist'),
                  ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: next,
                  child: Text(
                    step == 0
                        ? 'Continue'
                        : step == 1
                        ? 'Verify code'
                        : 'Meet your Tiffe',
                  ),
                ),
              ),
              if (step > 0)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => step--),
                    child: const Text('Go back'),
                  ),
                ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Rozcha dabba. Tumchya choice cha.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  final TiffeStore store;
  const Shell({super.key, required this.store});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  bool tomorrow = false;
  DateTime get date => DateTime.now().add(Duration(days: tomorrow ? 1 : 0));
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: widget.store,
    builder: (c, _) => Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [home(c), menuPage(c), orders(c), plans(c), profile(c)],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE4ECDC),
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    ),
  );
  Widget title(String heading, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: muted)),
      ],
    ),
  );
  Widget scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
    children: children,
  );
  void select({bool oneTime = false}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          SelectionPage(store: widget.store, date: date, oneTime: oneTime),
    ),
  );
  Widget home(BuildContext c) => scroll([
    Row(
      children: [
        const Logo(size: 40),
        const SizedBox(width: 10),
        const Text(
          'Tiffe',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: green,
          ),
        ),
        const Spacer(),
        const Icon(Icons.location_on_outlined, size: 17, color: green),
        Flexible(
          child: Text(
            '${widget.store.area}, Pune',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: green, fontSize: 12),
          ),
        ),
      ],
    ),
    const SizedBox(height: 26),
    Text(
      'Good ${DateTime.now().hour < 12
          ? 'morning'
          : DateTime.now().hour < 17
          ? 'afternoon'
          : 'evening'}, ${widget.store.name.split(' ').first}',
      style: const TextStyle(color: muted, fontSize: 15),
    ),
    title("Today's Tiffe", 'A little home, in every dabba.'),
    ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Image.asset(
            'assets/food/hero.jpg',
            height: 215,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'HOME-COOKED. ALWAYS.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: green,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    const Text(
      'Simple food. Full heart.',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
    ),
    const SizedBox(height: 5),
    const Text(
      '3 chapatis · Rice · Your choice of 2 bhajis',
      style: TextStyle(color: muted, fontSize: 13),
    ),
    const SizedBox(height: 22),
    panel(
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: green, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.plan == Plan.none
                      ? 'Your daily routine starts here'
                      : widget.store.plan == Plan.daily
                      ? 'Daily Plan'
                      : 'Double Plan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  widget.store.plan == Plan.none
                      ? 'Home-cooked meals from ₹1,500/month'
                      : '₹${Pricing.monthly(widget.store.plan)}/month · ${Pricing.quantity(widget.store.plan)} tiffin${widget.store.plan == Plan.double ? 's' : ''} every day',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => tab = 3),
            icon: const Icon(Icons.arrow_forward, color: green),
          ),
        ],
      ),
    ),
    const SizedBox(height: 26),
    Row(
      children: [
        const Expanded(
          child: Text(
            "Today's Menu",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              tab = 1;
              tomorrow = false;
            });
          },
          child: const Text('See all 8'),
        ),
      ],
    ),
    const Text(
      'Eight bhajis. Two favourites. Your call.',
      style: TextStyle(color: muted, fontSize: 13),
    ),
    const SizedBox(height: 14),
    SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  menu[i].image,
                  height: 95,
                  width: 118,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                menu[i].name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(height: 18),
    FilledButton(
      onPressed: () {
        setState(() => tomorrow = false);
        select();
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text('Choose your bhaji', textAlign: TextAlign.center),
          ),
          SizedBox(width: 10),
          Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    ),
    const SizedBox(height: 18),
    panel(
      color: const Color(0xFFF2EBDD),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_outlined, color: orange),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tomorrow's menu",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Plan a little. Relax a lot.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => tomorrow = true);
              select();
            },
            child: const Text('Choose →'),
          ),
        ],
      ),
    ),
    if (Pricing.sweet(DateTime.now(), widget.store.plan)) ...[
      const SizedBox(height: 16),
      panel(
        color: const Color(0xFFFFEED5),
        child: const Text(
          '☀ Sunday Special\nSheera is included with your subscriber Tiffe.',
        ),
      ),
    ],
    const SizedBox(height: 18),
    const Text(
      'MADE AT HOME. MADE FOR PUNE.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10, color: muted, letterSpacing: 1),
    ),
  ]);
  Widget menuPage(BuildContext c) => scroll([
    title('The daily menu', 'Fresh from our home kitchen in Pune.'),
    SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Today')),
        ButtonSegment(value: true, label: Text('Tomorrow')),
      ],
      selected: {tomorrow},
      onSelectionChanged: (v) => setState(() => tomorrow = v.first),
    ),
    const SizedBox(height: 20),
    Text(
      '${dayLabel(date)} · 8 bhajis',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 6),
    const Text(
      'Eight fresh choices from our kitchen.',
      style: TextStyle(color: muted, fontSize: 12),
    ),
    const SizedBox(height: 20),
    ...menu.map(
      (b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: panel(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  b.image,
                  height: 72,
                  width: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      b.description,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.circle, color: green, size: 9),
            ],
          ),
        ),
      ),
    ),
    FilledButton(onPressed: select, child: const Text('Choose for this date')),
  ]);
  Widget orders(BuildContext c) => scroll([
    title('Your dabbas', 'One less thing to think about.'),
    panel(
      child: const Column(
        children: [
          SizedBox(height: 28),
          Icon(Icons.lunch_dining_outlined, size: 64, color: green),
          SizedBox(height: 20),
          Text(
            'Your first Tiffe is waiting.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            'Your dabbas will appear here. Choose your bhajis and start your daily routine.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          SizedBox(height: 28),
        ],
      ),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: () => select(oneTime: true),
      child: const Text('Try a one-time Tiffe · ₹80'),
    ),
  ]);
  Widget plans(BuildContext c) => scroll([
    title(
      'A little routine.\nA lot of comfort.',
      'Your daily food, without the daily planning.',
    ),
    const Text(
      'SUBSCRIPTIONS',
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 2,
        color: muted,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 16),
    planCard(Plan.daily, 'Daily', 'One good meal, every day.', '1'),
    const SizedBox(height: 18),
    planCard(Plan.double, 'Double', 'Two dabbas. Twice the comfort.', '2'),
    const SizedBox(height: 20),
    panel(
      color: const Color(0xFFF1EADF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Just want one today?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'One-time Tiffe · ₹80\n3 chapatis, rice and 2 bhajis. No Sunday sweet.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => select(oneTime: true),
            child: const Text('Try a Tiffe →'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    const Text(
      '3 chapatis. Rice. Your favourites. Every day.',
      style: TextStyle(color: muted, fontSize: 12),
    ),
  ]);
  Widget planCard(Plan p, String label, String sub, String qty) => panel(
    color: p == Plan.daily ? green : Colors.white,
    child: DefaultTextStyle(
      style: TextStyle(
        color: p == Plan.daily ? cream : ink,
        fontFamily: 'TiffeSans',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (p == Plan.daily)
                const Chip(
                  label: Text(
                    'EVERYDAY FAVOURITE',
                    style: TextStyle(fontSize: 9),
                  ),
                ),
            ],
          ),
          Text(sub, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 22),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '₹${Pricing.monthly(p)}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const TextSpan(
                  text: ' / month',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...[
            '$qty tiffin${p == Plan.double ? 's' : ''} every day',
            '2 bhajis ${p == Plan.double ? 'per tiffin ' : ''}included',
            'Extra bhaji ₹10 each',
            'Sunday sweet included',
          ].map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF9DBB86),
                  ),
                  const SizedBox(width: 10),
                  Text(s),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p == Plan.daily ? cream : green,
                foregroundColor: p == Plan.daily ? green : cream,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Checkout(
                    store: widget.store,
                    plan: p,
                    date: DateTime.now(),
                    selections: const [],
                  ),
                ),
              ),
              child: Text(widget.store.plan == p ? 'View plan' : 'Subscribe'),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> openHelpline(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this app. Call +91 72491 19955, or add this number in WhatsApp.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this app. Call +91 72491 19955, or add this number in WhatsApp.',
            ),
          ),
        );
      }
    }
  }

  Widget profile(BuildContext c) => scroll([
    title('Your corner', 'Make Tiffe feel like you.'),
    panel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE6EDDC),
            child: Text(
              widget.store.name.isEmpty
                  ? 'T'
                  : widget.store.name[0].toUpperCase(),
              style: const TextStyle(
                color: green,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '+91 ${widget.store.phone}',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery address',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(widget.store.address),
          Text(
            '${widget.store.area}, Pune',
            style: const TextStyle(color: muted),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Usual',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            widget.store.usual
                .map((id) => menu.firstWhere((b) => b.id == id).name)
                .join(' + '),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your favourites, one tap away. Save them from the bhaji selection screen.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    OutlinedButton(
      onPressed: () => setState(() => tab = 3),
      child: const Text('View or change plan'),
    ),
    const SizedBox(height: 20),
    panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help & support',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sourabh - CEO',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiffe helpline',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const SelectableText(
            '+91 72491 19955',
            style: TextStyle(
              color: green,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: cream,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => openHelpline(
                      c,
                      Uri(scheme: 'tel', path: '+917249119955'),
                    ),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDCF0DE),
                      foregroundColor: green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () =>
                        openHelpline(c, Uri.https('wa.me', '917249119955')),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Opens your dialler or WhatsApp. Nothing is called or sent automatically.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text(
      'Tiffe v3 · Demo',
      textAlign: TextAlign.center,
      style: TextStyle(color: muted, fontSize: 12),
    ),
  ]);
}

Widget panel({required Widget child, Color color = Colors.white}) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE7E9DD)),
    boxShadow: const [
      BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 5)),
    ],
  ),
  child: child,
);

class SelectionPage extends StatefulWidget {
  final TiffeStore store;
  final DateTime date;
  final bool oneTime;
  const SelectionPage({
    super.key,
    required this.store,
    required this.date,
    this.oneTime = false,
  });
  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  int tiffin = 0;
  late List<List<String>> picked;
  int get quantity => widget.oneTime ? 1 : Pricing.quantity(widget.store.plan);
  @override
  void initState() {
    super.initState();
    picked = List.generate(
      quantity,
      (i) => widget.store.selected(widget.date, i),
    );
  }

  List<String> get selected => picked[tiffin];
  int get extra =>
      picked.fold(0, (sum, ids) => sum + Pricing.extras(ids.length));
  void toggle(Bhaji b) {
    if (!b.available) return;
    HapticFeedback.selectionClick();
    setState(
      () =>
          selected.contains(b.id) ? selected.remove(b.id) : selected.add(b.id),
    );
  }

  void usual() {
    setState(
      () => picked[tiffin] = widget.store.usual
          .where((id) => menu.any((b) => b.id == id && b.available))
          .toList(),
    );
  }

  Future<void> confirm() async {
    if (picked.any((ids) => ids.length < 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least 2 bhajis for each tiffin.'),
        ),
      );
      return;
    }
    if (widget.oneTime || widget.store.plan == Plan.none) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Checkout(
            store: widget.store,
            plan: Plan.none,
            date: widget.date,
            selections: picked,
          ),
        ),
      );
      return;
    }
    for (var i = 0; i < picked.length; i++) {
      await widget.store.saveSelection(widget.date, i, picked[i]);
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Your choices are saved'),
        content: Text(
          '${dayLabel(widget.date)} · $quantity tiffin${quantity > 1 ? 's' : ''}\n${picked.map((ids) => ids.map((id) => menu.firstWhere((b) => b.id == id).name).join(' + ')).join('\n')}\n${extra == 0 ? '2 bhajis per tiffin included' : 'Extra bhajis: ₹$extra'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Choose your bhaji',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${dayLabel(widget.date)} · ${widget.oneTime ? 'One-time Tiffe' : 'Your daily dabba'}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${selected.length} / 2 selected',
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Pick any 2. Add a little more.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'First 2 included · Each extra bhaji +₹10',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              if (quantity == 2) ...[
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Tiffin 1')),
                    ButtonSegment(value: 1, label: Text('Tiffin 2')),
                  ],
                  selected: {tiffin},
                  onSelectionChanged: (s) => setState(() => tiffin = s.first),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: usual,
                    icon: const Icon(Icons.favorite_border, size: 18),
                    label: const Text('Use My Usual'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: selected.length < 2
                        ? null
                        : () async {
                            widget.store.usual = List.of(selected);
                            await widget.store.save();
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                const SnackBar(
                                  content: Text('My Usual saved.'),
                                ),
                              );
                            }
                          },
                    child: const Text('Save as usual'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 228,
            ),
            itemCount: 8,
            itemBuilder: (c, i) {
              final b = menu[i];
              final checked = selected.contains(b.id);
              return Semantics(
                button: true,
                selected: checked,
                label:
                    '${b.name}. ${checked ? 'Selected' : 'Not selected'}. ${b.description}',
                child: InkWell(
                  onTap: () => toggle(b),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: checked ? const Color(0xFFEFF3E8) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: checked ? green : const Color(0xFFE4E8DC),
                        width: checked ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                              child: Image.asset(
                                b.image,
                                height: 130,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: checked
                                      ? green
                                      : Colors.white.withValues(alpha: .9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: checked ? green : Colors.white,
                                  ),
                                ),
                                child: Icon(
                                  checked ? Icons.check : Icons.add,
                                  color: checked ? Colors.white : green,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 0),
                          child: Text(
                            b.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 5, 10, 0),
                          child: Text(
                            b.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: muted,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE6E8DF))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      extra == 0
                          ? '2 bhajis per tiffin included'
                          : 'Extra bhaji +₹$extra',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${picked.fold<int>(0, (sum, p) => sum + p.length)} selected',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: picked.every((ids) => ids.length >= 2)
                        ? confirm
                        : null,
                    child: Text(
                      widget.oneTime || widget.store.plan == Plan.none
                          ? 'Review tiffin'
                          : 'Save choices',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class Checkout extends StatefulWidget {
  final TiffeStore store;
  final Plan plan;
  final DateTime date;
  final List<List<String>> selections;
  const Checkout({
    super.key,
    required this.store,
    required this.plan,
    required this.date,
    required this.selections,
  });
  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  final instructions = TextEditingController();
  @override
  void dispose() {
    instructions.dispose();
    super.dispose();
  }

  int get extra =>
      widget.selections.fold(0, (sum, ids) => sum + Pricing.extras(ids.length));
  int get delivery => Pricing.deliveryFor(widget.plan);
  int get base => widget.plan == Plan.none ? 80 : Pricing.monthly(widget.plan);
  Widget line(String text, String amount, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: total ? 20 : 15,
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: total ? 24 : 16,
            fontWeight: total ? FontWeight.w800 : FontWeight.w600,
            color: green,
          ),
        ),
      ],
    ),
  );
  Future<void> finish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm your Tiffe'),
        content: Text(
          '₹${base + extra + delivery} including ₹$delivery ${widget.plan == Plan.none ? 'delivery' : 'monthly delivery'}.\n\nDemo checkout. No money is charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    if (widget.plan != Plan.none) {
      widget.store.plan = widget.plan;
      await widget.store.save();
    } else {
      for (var i = 0; i < widget.selections.length; i++) {
        await widget.store.saveSelection(widget.date, i, widget.selections[i]);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.plan == Plan.none ? 'Choices saved.' : 'Your plan is ready.',
        ),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentSuccessPreview(plan: widget.plan, date: widget.date),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Your Tiffe, reviewed')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'A clear checkout. No surprises.',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Fresh food. Clear prices.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.plan == Plan.none
                    ? 'One-time Tiffe · ${dayLabel(widget.date)}'
                    : widget.plan == Plan.daily
                    ? 'Daily subscription'
                    : 'Double subscription',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.plan == Plan.none
                    ? '3 chapatis · Rice · 2 bhajis'
                    : '${Pricing.quantity(widget.plan)} tiffin${widget.plan == Plan.double ? 's' : ''} every day\n3 chapatis, rice and 2 bhajis per tiffin',
              ),
              ...widget.selections.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Tiffin ${e.key + 1}: ${e.value.map((id) => menu.firstWhere((b) => b.id == id).name).join(', ')}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.plan == Plan.none
                    ? 'No Sunday sweet for one-time orders.'
                    : 'Sunday sweet included for active subscribers.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        panel(
          child: Column(
            children: [
              line(
                widget.plan == Plan.none ? 'Tiffin × 1' : 'Plan / month',
                '₹$base',
              ),
              if (extra > 0) line('Extra bhajis', '₹$extra'),
              line('Subtotal', '₹${base + extra}'),
              line(
                widget.plan == Plan.none ? 'Delivery' : 'Delivery / month',
                '₹$delivery',
              ),
              const Divider(),
              line(
                widget.plan == Plan.none ? 'Total' : 'Total / month',
                '₹${base + extra + delivery}',
                total: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Delivery is ₹199/month for subscriptions and ₹20 for a one-time tiffin. Shown clearly before confirmation.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deliver to',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.store.name}\n${widget.store.address}\n${widget.store.area}, Pune',
              ),
              const SizedBox(height: 8),
              const Text('', style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: instructions,
          maxLines: 2,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Delivery instructions (optional)',
            hintText: 'E.g. leave with the security desk',
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline, color: green),
          title: Text('Demo payment'),
          subtitle: Text('No card, UPI or wallet is charged in this build.'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: finish,
          child: const Text('Complete demo payment'),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

class DeliveryTrackingPreview extends StatefulWidget {
  final Plan plan;
  final DateTime date;
  const DeliveryTrackingPreview({
    super.key,
    required this.plan,
    required this.date,
  });
  @override
  State<DeliveryTrackingPreview> createState() =>
      _DeliveryTrackingPreviewState();
}

class _DeliveryTrackingPreviewState extends State<DeliveryTrackingPreview> {
  Timer? timer;
  bool? notificationsEnabled;
  int minutes = 24;
  Future<void> startNotifications() async {
    try {
      final enabled = await const MethodChannel('tiffe/delivery_notifications')
          .invokeMethod<bool>('start');
      if (mounted) setState(() => notificationsEnabled = enabled == true);
    } catch (_) {
      if (mounted) setState(() => notificationsEnabled = false);
    }
  }

  String get status => minutes == 0
      ? 'Tiffin arrived'
      : minutes <= 18
      ? 'Tiffin is coming'
      : minutes <= 22
      ? 'Tiffin left'
      : 'Getting your Tiffe ready';
  @override
  void initState() {
    super.initState();
    startNotifications();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (minutes > 0) {
        setState(() => minutes--);
      } else {
        timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Logo(size: 42),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE3EEDB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 44, color: green),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your Tiffe journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: ink,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your daily dabba is on its way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 15),
            ),
            const SizedBox(height: 20),
            panel(
              color: const Color(0xFFEFF3E8),
              child: Column(
                children: [
                  Text(
                    minutes == 0
                        ? 'Your Tiffin has arrived!'
                        : 'Will deliver in a few minutes',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    minutes == 0 ? 'Enjoy your meal.' : '$minutes min',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (24 - minutes) / 24,
                    color: green,
                    backgroundColor: const Color(0xFFD7E4CD),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 5,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Simulated delivery · 1 second = 1 minute',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (notificationsEnabled == false)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Phone notifications are off. Allow notifications in App settings for delivery alerts.',
                  style: TextStyle(color: muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(status),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0E7D8)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      minutes == 0
                          ? Icons.notifications_active_outlined
                          : Icons.delivery_dining,
                      color: green,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            minutes == 0
                                ? 'Your Tiffe is here. Enjoy your meal!'
                                : minutes <= 18
                                ? 'A warm meal is getting closer.'
                                : minutes <= 22
                                ? 'Your dabba has left the kitchen.'
                                : 'The kitchen is getting your dabba ready.',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            panel(
              child: Column(
                children: [
                  Text(
                    widget.plan == Plan.none
                        ? 'Your Tiffe'
                        : widget.plan == Plan.daily
                        ? 'Daily Tiffe'
                        : 'Double Tiffe',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '3 chapatis · Rice · Your chosen bhajis',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: green, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Tiffe'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}

class PaymentSuccessPreview extends StatelessWidget {
  final Plan plan;
  final DateTime date;
  const PaymentSuccessPreview({
    super.key,
    required this.plan,
    required this.date,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Logo(size: 54),
              const SizedBox(height: 40),
              Container(
                width: 108,
                height: 108,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3EEDB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 64, color: green),
              ),
              const SizedBox(height: 28),
              const Text(
                'Payment successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ink,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Tiffe is confirmed.\nA little home is on its way.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 16),
              ),
              const SizedBox(height: 28),
              panel(
                child: Column(
                  children: [
                    Text(
                      plan == Plan.none
                          ? 'Your Tiffe'
                          : plan == Plan.daily
                          ? 'Daily Tiffe'
                          : 'Double Tiffe',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '3 chapatis · Rice · Your chosen bhajis',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: green, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeliveryTrackingPreview(plan: plan, date: date),
                    ),
                  ),
                  child: const Text('Track my Tiffe'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Tiffe'),
              ),
              const SizedBox(height: 28),
              const Text(
                'Rozcha dabba. Tumchya choice cha.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
