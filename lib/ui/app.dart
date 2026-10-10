import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/store.dart';
import '../domain/tiffin.dart';
import 'subscriber_orders.dart';
import 'scheduled_tracking.dart';
import '../domain/delivery_schedule.dart';

const cream = Color(0xFFFAF8F0),
    green = Color(0xFF285A3F),
    ink = Color(0xFF263A2E),
    muted = Color(0xFF738074),
    orange = Color(0xFFD49045);

class TiffePalette {
  final bool dark;
  final bool stitch;
  const TiffePalette(this.dark, {this.stitch = false});
  Color get cream => stitch ? const Color(0xFFF9F9FB) : const Color(0xFFFAF8F0);
  Color get green => dark
      ? const Color(0xFFA8D4A5)
      : stitch
      ? const Color(0xFF012D1D)
      : const Color(0xFF285A3F);
  Color get ink => dark
      ? const Color(0xFFF1F0E5)
      : stitch
      ? const Color(0xFF1A1C1E)
      : const Color(0xFF263A2E);
  Color get muted => dark ? const Color(0xFFAEB9AE) : const Color(0xFF738074);
  Color get surface => dark ? const Color(0xFF202D24) : Colors.white;
  Color tone(Color color) {
    if (!dark) return color;
    if (color == const Color(0xFF285A3F)) return const Color(0xFF304C38);
    if (color == Colors.white) return surface;
    if (color.computeLuminance() > .5) return const Color(0xFF2C3D30);
    return color;
  }
}

TiffePalette palette(BuildContext c) => TiffePalette(
  Theme.of(c).brightness == Brightness.dark,
  stitch: Theme.of(c).colorScheme.primary == const Color(0xFF012D1D),
);

abstract class TiffeState<T extends StatefulWidget> extends State<T> {
  Color get tcream => palette(context).cream;
  Color get tgreen => palette(context).green;
  Color get tink => palette(context).ink;
  Color get tmuted => palette(context).muted;
  Color get surface => palette(context).surface;
  Color get onAccent => Theme.of(context).colorScheme.onPrimary;
  Color tone(Color color) => palette(context).tone(color);
}

ThemeData tiffeDarkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF131C17),
  fontFamily: 'TiffeSans',
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFA8D4A5),
    brightness: Brightness.dark,
    primary: const Color(0xFFA8D4A5),
    onPrimary: const Color(0xFF15251A),
    surface: const Color(0xFF202D24),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFFF1F0E5), fontSize: 15, height: 1.45),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF131C17),
    foregroundColor: Color(0xFFF1F0E5),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      textStyle: const TextStyle(
        fontFamily: 'TiffeSans',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    fillColor: const Color(0xFF202D24),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    contentPadding: const EdgeInsets.all(18),
  ),
);
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
  final Widget? startScreen;
  const TiffeApp({super.key, required this.store, this.startScreen});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: tiffeDarkTheme(),
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
      home: startScreen ?? Splash(store: store),
    ),
  );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 72});
  @override
  Widget build(BuildContext c) => Image.asset(
    'assets/brand/tiffe-logo.png',
    width: size,
    height: size,
    semanticLabel: 'Tiffe circular tiffin logo',
    fit: BoxFit.contain,
  );
}

class Splash extends StatefulWidget {
  final TiffeStore store;
  const Splash({super.key, required this.store});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends TiffeState<Splash>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    )..forward();
    timer = Timer(Duration(milliseconds: 1100), () {
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
              child: Logo(size: 96),
            ),
            SizedBox(height: 22),
            Text(
              'Tiffe',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: tgreen,
                letterSpacing: -2,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Rozcha dabba. Tumchya choice cha.',
              style: TextStyle(color: tmuted, fontSize: 16),
            ),
            SizedBox(height: 48),
            Text(
              'MADE AT HOME. MADE FOR PUNE.',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: tmuted),
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

class _OnboardingState extends TiffeState<Onboarding> {
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
        padding: EdgeInsets.all(28),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              Logo(),
              SizedBox(height: 32),
              Text(
                [
                  'Your daily dabba,\nsorted.',
                  'A little verification.',
                  'Make yourself\nat home.',
                ][step],
                style: TextStyle(
                  fontSize: 36,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  color: tink,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 14),
              Text(
                [
                  'Fresh home-cooked food. Your choice of bhaji. Every single day.',
                  'Enter your code and make yourself at home.',
                  'Just your name and where your Tiffe should arrive.',
                ][step],
                style: TextStyle(color: tmuted, fontSize: 16),
              ),
              SizedBox(height: 28),
              Chip(label: Text('Tiffe Demo')),
              SizedBox(height: 20),
              if (step == 0)
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
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
                  style: TextStyle(color: tgreen),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: otp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(labelText: '6-digit OTP'),
                  validator: (v) =>
                      v == '123456' ? null : 'Use the demo code 123456',
                ),
              ],
              if (step == 2) ...[
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(labelText: 'Your name'),
                  validator: (v) =>
                      (v ?? '').trim().length >= 2 ? null : 'Enter your name',
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: address,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Flat, building and street',
                  ),
                  validator: (v) => (v ?? '').trim().length >= 8
                      ? null
                      : 'Add a complete delivery address',
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: area,
                  decoration: InputDecoration(labelText: 'Pune area'),
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
                        title: Text('Not in your area yet'),
                        content: Text(
                          'The waitlist is not open yet. Check back soon.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                    child: Text('View waitlist'),
                  ),
              ],
              SizedBox(height: 28),
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
                    child: Text('Go back'),
                  ),
                ),
              SizedBox(height: 24),
              Center(
                child: Text(
                  'Rozcha dabba. Tumchya choice cha.',
                  style: TextStyle(color: tmuted, fontSize: 13),
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

class _ShellState extends TiffeState<Shell> {
  int tab = 0;
  bool tomorrow = false;
  Timer? dailyTimer;
  String? openedJourney;
  Plan? scheduledPlan;
  Future<void> syncDailyReminders() async {
    if (scheduledPlan == widget.store.plan) return;
    scheduledPlan = widget.store.plan;
    try {
      await MethodChannel('tiffe/delivery_notifications').invokeMethod<bool>(
        widget.store.plan == Plan.none ? 'cancelDaily' : 'scheduleDaily',
      );
    } catch (_) {
      /* Device reminders are unavailable on non-Android builds. */
    }
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(syncDailyReminders);
    syncDailyReminders();
    dailyTimer = Timer.periodic(
      Duration(seconds: 1),
      (_) => checkDailyJourney(),
    );
  }

  bool checkingJourney = false;
  Future<void> checkDailyJourney() async {
    if (checkingJourney ||
        !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true ||
        widget.store.plan == Plan.none) {
      return;
    }
    checkingJourney = true;
    bool tapped = false;
    try {
      tapped =
          await MethodChannel('tiffe/delivery_notifications')
              .invokeMethod<bool>('consumeDailyTap') ??
          false;
    } catch (_) {}
    checkingJourney = false;
    final now = DateTime.now();
    final key = DeliverySchedule.departure(now).toIso8601String();
    if (mounted &&
        (tapped || (DeliverySchedule.inJourney(now) && openedJourney != key)) &&
        ModalRoute.of(context)?.isCurrent == true) {
      openedJourney = key;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduledTracking(plan: widget.store.plan),
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(syncDailyReminders);
    dailyTimer?.cancel();
    super.dispose();
  }

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
        backgroundColor: surface,
        indicatorColor: tone(Color(0xFFE4ECDC)),
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
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
    padding: EdgeInsets.only(top: 12, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: tink,
            letterSpacing: -.8,
          ),
        ),
        SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: tmuted)),
      ],
    ),
  );
  Widget scroll(List<Widget> children) => ListView(
    padding: EdgeInsets.fromLTRB(22, 12, 22, 28),
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
        Logo(size: 40),
        SizedBox(width: 10),
        Text(
          'Tiffe',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: tgreen,
          ),
        ),
        Spacer(),
        Icon(Icons.location_on_outlined, size: 17, color: tgreen),
        Flexible(
          child: Text(
            '${widget.store.area}, Pune',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tgreen, fontSize: 12),
          ),
        ),
      ],
    ),
    SizedBox(height: 26),
    Text(
      'Good ${DateTime.now().hour < 12
          ? 'morning'
          : DateTime.now().hour < 17
          ? 'afternoon'
          : 'evening'}, ${widget.store.name.split(' ').first}',
      style: TextStyle(color: tmuted, fontSize: 15),
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
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: tone(tcream),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'HOME-COOKED. ALWAYS.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: tgreen,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    SizedBox(height: 14),
    Text(
      'Simple food. Full heart.',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: tink),
    ),
    SizedBox(height: 5),
    Text(
      '3 chapatis · Rice · Your choice of 2 bhajis',
      style: TextStyle(color: tmuted, fontSize: 13),
    ),
    SizedBox(height: 22),
    panel(
      child: Row(
        children: [
          Icon(Icons.calendar_month, color: tgreen, size: 28),
          SizedBox(width: 14),
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
                  style: TextStyle(fontWeight: FontWeight.w700, color: tink),
                ),
                Text(
                  widget.store.plan == Plan.none
                      ? 'Home-cooked meals from ₹1,500/month'
                      : '₹${Pricing.monthly(widget.store.plan)}/month · ${Pricing.quantity(widget.store.plan)} tiffin${widget.store.plan == Plan.double ? 's' : ''} every day',
                  style: TextStyle(fontSize: 12, color: tmuted),
                ),
              ],
            ),
          ),
          if (widget.store.plan == Plan.none)
            IconButton(
              onPressed: () => setState(() => tab = 3),
              icon: Icon(Icons.arrow_forward, color: tgreen),
            ),
        ],
      ),
    ),
    SizedBox(height: 26),
    Row(
      children: [
        Expanded(
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
          child: Text('See all 8'),
        ),
      ],
    ),
    Text(
      'Eight bhajis. Two favourites. Your call.',
      style: TextStyle(color: tmuted, fontSize: 13),
    ),
    SizedBox(height: 14),
    SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 8,
        separatorBuilder: (_, _) => SizedBox(width: 12),
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
              SizedBox(height: 8),
              Text(
                menu[i].name,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
    SizedBox(height: 18),
    FilledButton(
      onPressed: () {
        setState(() => tomorrow = false);
        select();
      },
      child: Row(
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
    SizedBox(height: 18),
    panel(
      color: Color(0xFFF2EBDD),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, color: orange),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tomorrow's menu",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Plan a little. Relax a lot.',
                  style: TextStyle(fontSize: 12, color: tmuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => tomorrow = true);
              select();
            },
            child: Text('Choose →'),
          ),
        ],
      ),
    ),
    if (Pricing.sweet(DateTime.now(), widget.store.plan)) ...[
      SizedBox(height: 16),
      panel(
        color: Color(0xFFFFEED5),
        child: Text(
          '☀ Sunday Special\nSheera is included with your subscriber Tiffe.',
        ),
      ),
    ],
    SizedBox(height: 18),
    Text(
      'MADE AT HOME. MADE FOR PUNE.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10, color: tmuted, letterSpacing: 1),
    ),
  ]);
  Widget menuPage(BuildContext c) => scroll([
    title('The daily menu', 'Fresh from our home kitchen in Pune.'),
    SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: false, label: Text('Today')),
        ButtonSegment(value: true, label: Text('Tomorrow')),
      ],
      selected: {tomorrow},
      onSelectionChanged: (v) => setState(() => tomorrow = v.first),
    ),
    SizedBox(height: 20),
    Text(
      '${dayLabel(date)} · 8 bhajis',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    SizedBox(height: 6),
    Text(
      'Eight fresh choices from our kitchen.',
      style: TextStyle(color: tmuted, fontSize: 12),
    ),
    SizedBox(height: 20),
    ...menu.map(
      (b) => Padding(
        padding: EdgeInsets.only(bottom: 12),
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
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name, style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      b.description,
                      style: TextStyle(color: tmuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.circle, color: tgreen, size: 9),
            ],
          ),
        ),
      ),
    ),
    FilledButton(onPressed: select, child: Text('Choose for this date')),
  ]);
  Widget orders(BuildContext c) => widget.store.plan != Plan.none
      ? SubscriberOrders(store: widget.store)
      : scroll([
          title('Your dabbas', 'One less thing to think about.'),
          panel(
            child: Column(
              children: [
                SizedBox(height: 28),
                Icon(Icons.lunch_dining_outlined, size: 64, color: tgreen),
                SizedBox(height: 20),
                Text(
                  'Your first Tiffe is waiting.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                Text(
                  'Your dabbas will appear here. Choose your bhajis and start your daily routine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tmuted),
                ),
                SizedBox(height: 28),
              ],
            ),
          ),
          SizedBox(height: 20),
          FilledButton(
            onPressed: () => select(oneTime: true),
            child: Text('Try a one-time Tiffe · ₹80'),
          ),
        ]);
  Widget plans(BuildContext c) => widget.store.plan != Plan.none
      ? scroll([
          title('Your Tiffe plan', 'A little routine. A lot of comfort.'),
          panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: tgreen),
                    SizedBox(width: 8),
                    Text(
                      'Active subscription',
                      style: TextStyle(
                        color: tgreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  widget.store.plan == Plan.daily
                      ? 'Daily Tiffe'
                      : 'Double Tiffe',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  '₹${Pricing.monthly(widget.store.plan)}/month · ${Pricing.quantity(widget.store.plan)} tiffin${widget.store.plan == Plan.double ? 's' : ''} every day',
                ),
                SizedBox(height: 16),
                Text(
                  '2 bhajis per tiffin included · Sunday sweet included',
                  style: TextStyle(color: tmuted),
                ),
              ],
            ),
          ),
        ])
      : scroll([
          title(
            'A little routine.\nA lot of comfort.',
            'Your daily food, without the daily planning.',
          ),
          Text(
            'SUBSCRIPTIONS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: tmuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          planCard(Plan.daily, 'Daily', 'One good meal, every day.', '1'),
          SizedBox(height: 18),
          planCard(
            Plan.double,
            'Double',
            'Two dabbas. Twice the comfort.',
            '2',
          ),
          SizedBox(height: 20),
          panel(
            color: Color(0xFFF1EADF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Just want one today?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'One-time Tiffe · ₹80\n3 chapatis, rice and 2 bhajis. No Sunday sweet.',
                  style: TextStyle(color: tmuted),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => select(oneTime: true),
                  child: Text('Try a Tiffe →'),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Text(
            '3 chapatis. Rice. Your favourites. Every day.',
            style: TextStyle(color: tmuted, fontSize: 12),
          ),
        ]);
  Widget planCard(Plan p, String label, String sub, String qty) => panel(
    color: p == Plan.daily ? tgreen : Colors.white,
    child: DefaultTextStyle(
      style: TextStyle(
        color: p == Plan.daily ? tcream : tink,
        fontFamily: 'TiffeSans',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              Spacer(),
              if (p == Plan.daily)
                Chip(
                  label: Text(
                    'EVERYDAY FAVOURITE',
                    style: TextStyle(fontSize: 9),
                  ),
                ),
            ],
          ),
          Text(sub, style: TextStyle(fontSize: 13)),
          SizedBox(height: 22),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '₹${Pricing.monthly(p)}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                TextSpan(text: ' / month', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          SizedBox(height: 20),
          ...[
            '$qty tiffin${p == Plan.double ? 's' : ''} every day',
            '2 bhajis ${p == Plan.double ? 'per tiffin ' : ''}included',
            'Extra bhaji ₹10 each',
            'Sunday sweet included',
          ].map(
            (s) => Padding(
              padding: EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF9DBB86),
                  ),
                  SizedBox(width: 10),
                  Text(s),
                ],
              ),
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p == Plan.daily ? tcream : tgreen,
                foregroundColor: p == Plan.daily ? green : onAccent,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Checkout(
                    store: widget.store,
                    plan: p,
                    date: DateTime.now(),
                    selections: [],
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
          SnackBar(
            content: Text(
              'Could not open this app. Call +91 72491 19955, or add this number in WhatsApp.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open this app. Call +91 72491 19955, or add this number in WhatsApp.',
            ),
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Log out of Tiffe?'),
        content: const Text(
          'Your saved profile and bhaji choices will stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await const MethodChannel('tiffe/delivery_notifications')
          .invokeMethod<bool>('cancelDaily')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    widget.store.onboarded = false;
    await widget.store.save();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => Onboarding(store: widget.store)),
      (_) => false,
    );
  }

  Widget profile(BuildContext c) => scroll([
    title('Your corner', 'Make Tiffe feel like you.'),
    panel(
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.dark_mode_outlined, color: tgreen),
          title: Text(
            'Dark mode',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            widget.store.darkMode
                ? 'A softer glow for the evening.'
                : 'Switch to a softer evening look.',
            style: TextStyle(color: tmuted, fontSize: 12),
          ),
          value: widget.store.darkMode,
          onChanged: widget.store.setDarkMode,
        ),
      ),
    ),
    SizedBox(height: 20),
    panel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: tone(Color(0xFFE6EDDC)),
            child: Text(
              widget.store.name.isEmpty
                  ? 'T'
                  : widget.store.name[0].toUpperCase(),
              style: TextStyle(
                color: tgreen,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  '+91 ${widget.store.phone}',
                  style: TextStyle(color: tmuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            icon: Icon(Icons.edit_outlined, color: tgreen),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfilePage(store: widget.store),
              ),
            ),
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
            'Delivery address',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(widget.store.address),
          Text('${widget.store.area}, Pune', style: TextStyle(color: tmuted)),
        ],
      ),
    ),
    SizedBox(height: 20),
    panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Usual',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          SizedBox(height: 8),
          Text(
            widget.store.usual
                .map((id) => menu.firstWhere((b) => b.id == id).name)
                .join(' + '),
          ),
          SizedBox(height: 8),
          Text(
            'Your favourites, one tap away. Save them from the bhaji selection screen.',
            style: TextStyle(color: tmuted, fontSize: 12),
          ),
        ],
      ),
    ),
    SizedBox(height: 20),
    if (widget.store.plan == Plan.none)
      OutlinedButton(
        onPressed: () => setState(() => tab = 3),
        child: Text('Explore plans'),
      )
    else
      panel(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: tgreen),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '${widget.store.plan == Plan.daily ? 'Daily' : 'Double'} Tiffe · Active subscription',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
            'Help & support',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          SizedBox(height: 12),
          Text(
            'Sourabh - CEO',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text('Tiffe helpline', style: TextStyle(color: tmuted, fontSize: 13)),
          SizedBox(height: 6),
          SelectableText(
            '+91 72491 19955',
            style: TextStyle(
              color: tgreen,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: tgreen,
                      foregroundColor: onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => openHelpline(
                      c,
                      Uri(scheme: 'tel', path: '+917249119955'),
                    ),
                    icon: Icon(Icons.call_outlined, size: 18),
                    label: Text('Call'),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: tone(Color(0xFFDCF0DE)),
                      foregroundColor: tgreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () =>
                        openHelpline(c, Uri.https('wa.me', '917249119955')),
                    icon: Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('WhatsApp'),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Opens your dialler or WhatsApp. Nothing is called or sent automatically.',
            style: TextStyle(color: tmuted, fontSize: 12),
          ),
        ],
      ),
    ),
    SizedBox(height: 20),
    OutlinedButton.icon(
      onPressed: logout,
      icon: const Icon(Icons.logout),
      label: const Text('Log out'),
    ),
    SizedBox(height: 24),
    Text(
      'Tiffe · Local preview',
      textAlign: TextAlign.center,
      style: TextStyle(color: tmuted, fontSize: 12),
    ),
  ]);
}

Widget panel({required Widget child, Color color = Colors.white}) => Builder(
  builder: (context) => Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: palette(context).tone(color),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: palette(context).tone(Color(0xFFE7E9DD))),
      boxShadow: [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  ),
);

class SelectionPage extends StatefulWidget {
  final TiffeStore store;
  final DateTime date;
  final bool oneTime;
  final DateTime? clock;
  const SelectionPage({
    super.key,
    required this.store,
    required this.date,
    this.oneTime = false,
    this.clock,
  });
  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends TiffeState<SelectionPage> {
  int tiffin = 0;
  late List<List<String>> picked;
  late DateTime deliveryDate;
  bool movedToTomorrow = false;
  DateTime get now => widget.clock ?? DateTime.now();
  int get quantity => widget.oneTime ? 1 : Pricing.quantity(widget.store.plan);
  @override
  void initState() {
    super.initState();
    deliveryDate = widget.date;
    if (!widget.oneTime &&
        widget.store.plan != Plan.none &&
        !canChangeBhaji(deliveryDate, now)) {
      deliveryDate = DateTime(now.year, now.month, now.day + 1);
      movedToTomorrow = true;
    }
    picked = List.generate(
      quantity,
      (i) => widget.store.selected(deliveryDate, i),
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
    if (!widget.oneTime &&
        widget.store.plan != Plan.none &&
        !canChangeBhaji(deliveryDate, now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selection cutoff has passed for this delivery.'),
        ),
      );
      return;
    }
    if (picked.any((ids) => ids.length < 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Choose at least 2 bhajis for each tiffin.')),
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
            date: deliveryDate,
            selections: picked,
          ),
        ),
      );
      return;
    }
    for (var i = 0; i < picked.length; i++) {
      await widget.store.saveSelection(deliveryDate, i, picked[i]);
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Your choices are saved'),
        content: Text(
          '${dayLabel(deliveryDate)} · $quantity tiffin${quantity > 1 ? 's' : ''}\n${picked.map((ids) => ids.map((id) => menu.firstWhere((b) => b.id == id).name).join(' + ')).join('\n')}\n${extra == 0 ? '2 bhajis per tiffin included' : 'Extra bhajis: ₹$extra'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Choose your bhaji',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(22, 4, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (movedToTomorrow) ...[
                Text(
                  "Today's menu is locked - you're picking for tomorrow",
                  style: TextStyle(
                    color: tgreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dayLabel(deliveryDate)} · ${widget.oneTime ? 'One-time Tiffe' : 'Your daily dabba'}',
                      style: TextStyle(color: tmuted, fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${selected.length} / 2 selected',
                    style: TextStyle(
                      color: tgreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Pick any 2. Add a little more.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'First 2 included · Each extra bhaji +₹10',
                style: TextStyle(color: tmuted, fontSize: 13),
              ),
              if (quantity == 2) ...[
                SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text('Tiffin 1')),
                    ButtonSegment(value: 1, label: Text('Tiffin 2')),
                  ],
                  selected: {tiffin},
                  onSelectionChanged: (s) => setState(() => tiffin = s.first),
                ),
              ],
              SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: [
                  TextButton.icon(
                    onPressed: usual,
                    icon: Icon(Icons.favorite_border, size: 18),
                    label: Text('Use My Usual'),
                  ),
                  TextButton(
                    onPressed: selected.length < 2
                        ? null
                        : () async {
                            widget.store.usual = List.of(selected);
                            await widget.store.save();
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(content: Text('My Usual saved.')),
                              );
                            }
                          },
                    child: Text('Save as usual'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent:
                  130 + 98 * MediaQuery.textScalerOf(c).scale(1).clamp(1, 2),
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
                    duration: Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: checked ? tone(Color(0xFFEFF3E8)) : surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: checked ? tgreen : Color(0xFFE4E8DC),
                        width: checked ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
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
                                duration: Duration(milliseconds: 180),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: checked
                                      ? tgreen
                                      : Colors.white.withValues(alpha: .9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: checked ? tgreen : surface,
                                  ),
                                ),
                                child: Icon(
                                  checked ? Icons.check : Icons.add,
                                  color: checked ? onAccent : green,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(12, 10, 10, 0),
                          child: Text(
                            b.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tink,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(12, 5, 10, 0),
                          child: Text(
                            b.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: tmuted,
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
          padding: EdgeInsets.fromLTRB(22, 12, 22, 12),
          decoration: BoxDecoration(
            color: surface,
            border: Border(top: BorderSide(color: Color(0xFFE6E8DF))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        extra == 0
                            ? '2 bhajis per tiffin included'
                            : 'Extra bhaji +₹$extra',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${picked.fold<int>(0, (sum, p) => sum + p.length)} selected',
                      style: TextStyle(color: tmuted, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 12),
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

class _CheckoutState extends TiffeState<Checkout> {
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
    padding: EdgeInsets.symmetric(vertical: 10),
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
            color: tgreen,
          ),
        ),
      ],
    ),
  );
  Future<void> finish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Confirm your Tiffe'),
        content: Text(
          '₹${base + extra + delivery} including ₹$delivery ${widget.plan == Plan.none ? 'delivery' : 'monthly delivery'}.\n\nDemo checkout. No money is charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Continue'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    if (widget.plan != Plan.none) {
      widget.store.plan = widget.plan;
      await widget.store.save();
    }
    for (var i = 0; i < widget.selections.length; i++) {
      await widget.store.saveSelection(widget.date, i, widget.selections[i]);
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
    appBar: AppBar(title: Text('Your Tiffe, reviewed')),
    body: ListView(
      padding: EdgeInsets.all(22),
      children: [
        Text(
          'A clear checkout. No surprises.',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Fresh food. Clear prices.',
          style: TextStyle(color: tmuted, fontSize: 13),
        ),
        SizedBox(height: 24),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                widget.plan == Plan.none
                    ? '3 chapatis · Rice · 2 bhajis'
                    : '${Pricing.quantity(widget.plan)} tiffin${widget.plan == Plan.double ? 's' : ''} every day\n3 chapatis, rice and 2 bhajis per tiffin',
              ),
              ...widget.selections.asMap().entries.map(
                (e) => Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Tiffin ${e.key + 1}: ${e.value.map((id) => menu.firstWhere((b) => b.id == id).name).join(', ')}',
                  ),
                ),
              ),
              SizedBox(height: 10),
              Text(
                widget.plan == Plan.none
                    ? 'No Sunday sweet for one-time orders.'
                    : 'Sunday sweet included for active subscribers.',
                style: TextStyle(color: tmuted, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
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
              Divider(),
              line(
                widget.plan == Plan.none ? 'Total' : 'Total / month',
                '₹${base + extra + delivery}',
                total: true,
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Delivery is ₹199/month for subscriptions and ₹20 for a one-time tiffin. Shown clearly before confirmation.',
          style: TextStyle(color: tmuted, fontSize: 12),
        ),
        SizedBox(height: 20),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deliver to',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                '${widget.store.name}\n${widget.store.address}\n${widget.store.area}, Pune',
              ),
              SizedBox(height: 8),
              Text('', style: TextStyle(color: tmuted, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 20),
        TextField(
          controller: instructions,
          maxLines: 2,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: 'Delivery instructions (optional)',
            hintText: 'E.g. leave with the security desk',
          ),
        ),
        SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline, color: tgreen),
          title: Text('Demo payment'),
          subtitle: Text('No card, UPI or wallet is charged in this build.'),
        ),
        SizedBox(height: 18),
        FilledButton(onPressed: finish, child: Text('Complete demo payment')),
        SizedBox(height: 16),
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

class _DeliveryTrackingPreviewState
    extends TiffeState<DeliveryTrackingPreview> {
  Timer? timer;
  bool? notificationsEnabled;
  int minutes = 24;
  Future<void> startNotifications() async {
    try {
      final enabled = await MethodChannel('tiffe/delivery_notifications')
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
    timer = Timer.periodic(Duration(seconds: 1), (_) {
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
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 8),
            Logo(size: 42),
            SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Color(0xFFE3EEDB),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 44, color: tgreen),
            ),
            SizedBox(height: 18),
            Text(
              'Your Tiffe journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: tink,
                letterSpacing: -.8,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your daily dabba is on its way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tmuted, fontSize: 15),
            ),
            SizedBox(height: 20),
            panel(
              color: Color(0xFFEFF3E8),
              child: Column(
                children: [
                  Text(
                    minutes == 0
                        ? 'Your Tiffin has arrived!'
                        : 'Will deliver in a few minutes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    minutes == 0 ? 'Enjoy your meal.' : '$minutes min',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: tgreen,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    status,
                    style: TextStyle(
                      color: tgreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (24 - minutes) / 24,
                    color: tgreen,
                    backgroundColor: Color(0xFFD7E4CD),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 5,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Simulated delivery · 1 second = 1 minute',
                    style: TextStyle(color: tmuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (notificationsEnabled == false)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Phone notifications are off. Allow notifications in App settings for delivery alerts.',
                  style: TextStyle(color: tmuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 14),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(status),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: Color(0xFFE0E7D8)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      minutes == 0
                          ? Icons.notifications_active_outlined
                          : Icons.delivery_dining,
                      color: tgreen,
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: TextStyle(
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
                            style: TextStyle(color: tmuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14),
            panel(
              child: Column(
                children: [
                  Text(
                    widget.plan == Plan.none
                        ? 'Your Tiffe'
                        : widget.plan == Plan.daily
                        ? 'Daily Tiffe'
                        : 'Double Tiffe',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '3 chapatis · Rice · Your chosen bhajis',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tgreen, fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Back to Tiffe'),
              ),
            ),
            SizedBox(height: 10),
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
  Widget build(BuildContext context) {
    final green = palette(context).green;
    final ink = palette(context).ink;
    final muted = palette(context).muted;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(28),
            child: Column(
              children: [
                Logo(size: 54),
                SizedBox(height: 40),
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: Color(0xFFE3EEDB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 64, color: green),
                ),
                SizedBox(height: 28),
                Text(
                  'Payment successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    letterSpacing: -.8,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your Tiffe is confirmed.\nA little home is on its way.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 16),
                ),
                SizedBox(height: 28),
                panel(
                  child: Column(
                    children: [
                      Text(
                        plan == Plan.none
                            ? 'Your Tiffe'
                            : plan == Plan.daily
                            ? 'Daily Tiffe'
                            : 'Double Tiffe',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '3 chapatis · Rice · Your chosen bhajis',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: green, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
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
                    child: Text('Track my Tiffe'),
                  ),
                ),
                SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Back to Tiffe'),
                ),
                SizedBox(height: 28),
                Text(
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
}

class EditProfilePage extends StatefulWidget {
  final TiffeStore store;
  const EditProfilePage({super.key, required this.store});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends TiffeState<EditProfilePage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, phone, address;
  late String area;
  bool saving = false;
  static const areas = ['Kothrud', 'Baner', 'Aundh', 'Wakad', 'Viman Nagar'];
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.store.name);
    phone = TextEditingController(text: widget.store.phone);
    address = TextEditingController(text: widget.store.address);
    area = widget.store.area;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    widget.store
      ..name = name.text.trim()
      ..phone = phone.text.trim()
      ..address = address.text.trim()
      ..area = area;
    await widget.store.save();
    if (!mounted) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF75D58A), size: 22),
            SizedBox(width: 10),
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
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A little about you.',
                style: TextStyle(
                  color: tink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your name and delivery details up to date.',
                style: TextStyle(color: tmuted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (v) =>
                    (v ?? '').trim().length >= 2 ? null : 'Enter your name',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                ),
                validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                    ? null
                    : 'Enter a valid 10-digit Indian mobile number',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: address,
                maxLines: 3,
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
                items: {...areas, area}
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (value) => setState(() => area = value!),
                validator: (v) => areas.contains(v)
                    ? null
                    : "Tiffe isn't delivering to your area yet.",
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving...' : 'Save profile'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: saving ? null : () => Navigator.pop(c),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
