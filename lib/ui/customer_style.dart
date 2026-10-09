import 'package:flutter/material.dart';

import 'app.dart' show Logo;

ThemeData customerTheme(BuildContext context) {
  final base = Theme.of(context);
  final dark = base.brightness == Brightness.dark;
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF131C17)
        : const Color(0xFFF9F9FB),
    colorScheme: base.colorScheme.copyWith(
      primary: dark ? const Color(0xFFA5D0B9) : const Color(0xFF012D1D),
      secondary: const Color(0xFF9E4300),
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: dark ? const Color(0xFF131C17) : const Color(0xFFF9F9FB),
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF012D1D),
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class CustomerStyle extends StatelessWidget {
  final Widget child;
  const CustomerStyle({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      Theme(data: customerTheme(context), child: child);
}

class CustomerSplash extends StatelessWidget {
  const CustomerSplash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4332),
              borderRadius: BorderRadius.circular(48),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'HOME-COOKED. EVERY DAY.',
                  style: TextStyle(
                    color: Color(0xFFFFB690),
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 36),
                const Logo(size: 110),
                const SizedBox(height: 24),
                const Text(
                  'Tiffe.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 52,
                    color: Color(0xFFC1ECD4),
                  ),
                ),
                const Text(
                  'A little home, in every dabba.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 19),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/food/hero.jpg',
                    height: 145,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 32),
                const LinearProgressIndicator(
                  color: Color(0xFFFF8843),
                  backgroundColor: Color(0xFF274E3D),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Making yourself at home...',
                  style: TextStyle(color: Color(0xFFC1ECD4)),
                ),
                const SizedBox(height: 28),
                const Text(
                  'MADE AT HOME. MADE FOR PUNE.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFA5D0B9),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CustomerWelcome extends StatelessWidget {
  final VoidCallback onContinue;
  const CustomerWelcome({super.key, required this.onContinue});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onContinue,
                  child: const Text('Skip'),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.asset(
                  'assets/food/hero.jpg',
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Your daily dabba,\nsorted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fresh home-cooked food. Your choice of bhaji. A little less planning, every day.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              const _WelcomeBenefit(
                icon: Icons.restaurant_outlined,
                title: 'Your favourites, your choice',
                body: 'Choose 2 bhajis per tiffin. Add extras when you feel like it.',
              ),
              const _WelcomeBenefit(
                icon: Icons.calendar_month_outlined,
                title: 'One meal or a monthly routine',
                body: 'Browse Daily Tiffe, Double Tiffe and one-time meals.',
              ),
              const _WelcomeBenefit(
                icon: Icons.delivery_dining_outlined,
                title: 'From kitchen to doorstep',
                body: 'See preparation and delivery updates for your orders.',
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onContinue,
                label: const Text('Get started'),
                icon: const Icon(Icons.arrow_forward),
              ),
              TextButton(
                onPressed: onContinue,
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WelcomeBenefit extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _WelcomeBenefit({
    required this.icon,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202D24)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFC1ECD4),
            child: Icon(icon, color: const Color(0xFF012D1D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CustomerOffline extends StatelessWidget {
  final bool busy;
  final VoidCallback onRetry;
  const CustomerOffline({super.key, required this.busy, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const Logo(size: 110),
                const SizedBox(height: 24),
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFF9E4300),
                  size: 36,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kitchen signal lost',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tiffe could not connect. No order has been placed.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check your Wi-Fi or mobile data, then try again. We cannot confirm live meals or delivery updates until the connection returns.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(busy ? 'Connecting...' : 'Retry'),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF202D24)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your saved preferences stay on this device. Retrying does not place an order.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
