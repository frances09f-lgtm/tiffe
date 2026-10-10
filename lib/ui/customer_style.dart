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
    backgroundColor: const Color(0xFFF9F9FB),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4332),
              borderRadius: BorderRadius.circular(48),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33012D1D),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF274E3D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Color(0xFFFF8843)),
                      SizedBox(width: 8),
                      Text(
                        'HOME-COOKED. EVERY DAY.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                          fontSize: 10.5,
                          letterSpacing: .6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF214B3A),
                  ),
                  child: Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1B4332), Color(0xFF0B2E20)],
                        ),
                      ),
                      child: const Center(child: Logo(size: 78)),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tiffe',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        height: 1,
                        color: Color(0xFFC1ECD4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, bottom: 5),
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF8843),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Rozcha dabba. Tumchya choice cha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF274E3D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '3 chapatis  •  rice  •  2 bhajis of your choice',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3324),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/food/hero.jpg',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your daily dabba',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Pick your two favourite bhajis',
                              style: TextStyle(
                                color: Color(0xFFC1ECD4),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 200,
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF8843), Color(0xFFFFDBCB)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Making yourself at home...',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
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
                child: GestureDetector(
                  onTap: onContinue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEEF0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF414844),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/food/hero.jpg',
                      height: 288,
                      width: double.infinity,
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
                            Icon(
                              Icons.verified_outlined,
                              size: 14,
                              color: Color(0xFF9E4300),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'HOME-COOKED. EVERY DAY.',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: .3,
                                fontWeight: FontWeight.w700,
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
              const SizedBox(height: 22),
              const Text(
                'Your daily dabba,\nsorted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fresh home-cooked food. Your choice of bhaji. A little less planning, every day.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF414844),
                ),
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
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                label: const Text('Get started'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                iconAlignment: IconAlignment.end,
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
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202D24)
            : const Color(0xFFF3F3F6),
        borderRadius: BorderRadius.circular(8),
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
                Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFFFDBCB), Color(0x00FFDBCB)],
                    ),
                  ),
                  child: const Center(child: Logo(size: 104)),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFF9E4300),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SIMMER PAUSED',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Color(0xFF9E4300),
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Kitchen signal lost',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 28,
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
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
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
