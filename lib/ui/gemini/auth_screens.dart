import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Palette sampled from the Gemini "Tiffie" design system page.
class GColors {
  /// Dark mode switch. The app sets it from the saved choice.
  static bool dark = false;
  static Color _p(Color light, Color dk) => dark ? dk : light;

  /// Keeps an exact light colour, swaps to [dk] in dark mode.
  static Color alt(Color light, Color dk) => _p(light, dk);

  /// Brand green: headers, filled buttons, selected fills.
  static Color get green =>
      _p(const Color(0xFF1B3B2B), const Color(0xFF1F4631));

  /// Titles, icons and green text on the page background.
  static Color get ink => _p(const Color(0xFF1B3B2B), const Color(0xFFE4EFE8));
  static Color get cream =>
      _p(const Color(0xFFFBF9F5), const Color(0xFF0E1511));
  static Color get card => _p(Colors.white, const Color(0xFF17211B));
  static const saffron = Color(0xFFE86324);
  static Color get charcoal =>
      _p(const Color(0xFF222222), const Color(0xFFECEFEA));
  static Color get grey => _p(const Color(0xFF666666), const Color(0xFFA3AFA8));
  static Color get line => _p(const Color(0xFFE8E2D6), const Color(0xFF263329));
  static Color get chip => _p(const Color(0xFFF0EBDD), const Color(0xFF1F2B24));
  static Color get dangerBg =>
      _p(const Color(0xFFFEF2F2), const Color(0xFF2B1A1A));
  static Color get dangerLine =>
      _p(const Color(0xFFFECACA), const Color(0xFF5C2B2B));
  static Color get saffronTint =>
      _p(const Color(0xFFFDEEE5), const Color(0xFF2E1D14));
  static Color get tint => _p(const Color(0x1A1B3B2B), const Color(0x26E4EFE8));
}

const gFont = 'PlusJakartaSans';

TextStyle gText(
  double size, {
  FontWeight w = FontWeight.w400,
  Color? c,
  double? height,
  double? spacing,
}) => TextStyle(
  fontFamily: gFont,
  fontSize: size,
  fontWeight: w,
  color: c ?? GColors.charcoal,
  height: height,
  letterSpacing: spacing,
);

class GButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  const GButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.color = GColors.saffron,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 56,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: color.withValues(alpha: .28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: .45),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(
        label,
        style: gText(15, w: FontWeight.w700, c: Colors.white),
      ),
    ),
  );
}

class GBack extends StatelessWidget {
  const GBack({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: () => Navigator.maybePop(context),
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: GColors.chip, shape: BoxShape.circle),
        child: Icon(Icons.arrow_back, size: 20, color: GColors.charcoal),
      ),
    ),
  );
}

/// Fork and knife crossed, drawn to match the Tiffie mark.
class _CrossedUtensils extends CustomPainter {
  const _CrossedUtensils();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final u = size.width / 100;
    Offset o(double x, double y) => Offset(x * u, y * u);
    // knife: handle bottom-right up to a blade at top-left
    canvas.drawLine(o(74, 74), o(42, 42), p);
    final blade = Path()
      ..moveTo(o(42, 42).dx, o(42, 42).dy)
      ..lineTo(o(28, 28).dx, o(28, 28).dy)
      ..quadraticBezierTo(
        o(34, 22).dx,
        o(34, 22).dy,
        o(44, 30).dx,
        o(44, 30).dy,
      )
      ..lineTo(o(52, 38).dx, o(52, 38).dy);
    canvas.drawPath(blade, p);
    // fork: handle bottom-left up to three tines at top-right
    canvas.drawLine(o(26, 74), o(58, 42), p);
    canvas.drawLine(o(49, 33), o(67, 51), p);
    canvas.drawLine(o(49, 33), o(60, 22), p);
    canvas.drawLine(o(58, 42), o(71, 29), p);
    canvas.drawLine(o(67, 51), o(78, 40), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 1. Splash
class GSplash extends StatelessWidget {
  final VoidCallback onStart;
  const GSplash({super.key, required this.onStart});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.green,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          children: [
            const Spacer(flex: 5),
            Transform.rotate(
              angle: .07,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: GColors.saffron,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 28,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const CustomPaint(painter: _CrossedUtensils()),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Tiffie',
              style: gText(34, w: FontWeight.w700, c: Colors.white),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Ghar Ka Swaad, Delivered Fresh Daily. Authentic homemade tiffins crafted with love.',
                textAlign: TextAlign.center,
                style: gText(13.5, c: const Color(0xFFD6DDD8), height: 1.4),
              ),
            ),
            const Spacer(flex: 5),
            GButton('Get Started', onPressed: onStart),
          ],
        ),
      ),
    ),
  );
}

/// 2. Onboarding
class GOnboarding extends StatelessWidget {
  final VoidCallback onSkip, onContinue;
  final String continueLabel;
  const GOnboarding({
    super.key,
    this.continueLabel = 'Continue with Mobile',
    required this.onSkip,
    required this.onContinue,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                height: 288,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/food/hero.jpg', fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xB3000000)],
                          stops: [.35, 1],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Text(
                          'Homemade Bhaji, Delivered Fresh Daily',
                          textAlign: TextAlign.center,
                          style: gText(
                            17,
                            w: FontWeight.w700,
                            c: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Like Mother’s Kitchen',
              textAlign: TextAlign.center,
              style: gText(23, w: FontWeight.w700, c: GColors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'A daily tiffin of soft chapatis, rice and two bhajis of your choice, made fresh in a home kitchen.',
              textAlign: TextAlign.center,
              style: gText(13.5, c: GColors.grey, height: 1.45),
            ),
            const Spacer(flex: 2),
            GButton(continueLabel, onPressed: onContinue),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip',
                style: gText(15, w: FontWeight.w600, c: GColors.grey),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 3. Login (mobile number). Any 10 digits are accepted; nothing is stored.
class GLogin extends StatefulWidget {
  final void Function(String number) onOtp;
  const GLogin({super.key, required this.onOtp});
  @override
  State<GLogin> createState() => _GLoginState();
}

class _GLoginState extends State<GLogin> {
  final ctl = TextEditingController();
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GBack(),
            const Spacer(flex: 3),
            Text(
              'Welcome Back',
              style: gText(26, w: FontWeight.w700, c: GColors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your mobile number to sign in or create your Tiffie account.',
              style: gText(13.5, c: GColors.grey, height: 1.4),
            ),
            const SizedBox(height: 28),
            Text(
              'MOBILE NUMBER',
              style: gText(12, w: FontWeight.w700, spacing: .6),
            ),
            const SizedBox(height: 10),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: GColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GColors.line),
              ),
              child: Row(
                children: [
                  Text('+91', style: gText(14.5, w: FontWeight.w700)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: ctl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: gText(14.5, w: FontWeight.w500),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '9876543210',
                        hintStyle: gText(16, c: const Color(0xFFB5B5B5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GButton(
              'Get OTP',
              onPressed: ctl.text.length == 10
                  ? () => widget.onOtp(ctl.text)
                  : null,
            ),
            const Spacer(flex: 4),
            Center(
              child: Text.rich(
                TextSpan(
                  style: gText(12, c: GColors.grey, height: 1.5),
                  children: [
                    const TextSpan(
                      text: 'By continuing, you agree to Tiffie’s ',
                    ),
                    TextSpan(
                      text: 'Terms of Service & Privacy Policy',
                      style: gText(12, w: FontWeight.w600, c: GColors.ink),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 4. OTP. Any 4 digits are accepted; nothing is stored.
class GOtp extends StatefulWidget {
  final String number;
  final VoidCallback onVerified;
  const GOtp({super.key, required this.number, required this.onVerified});
  @override
  State<GOtp> createState() => _GOtpState();
}

class _GOtpState extends State<GOtp> {
  final ctl = TextEditingController();
  final focus = FocusNode();
  int left = 48;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left > 0 && mounted) setState(() => left--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    ctl.dispose();
    focus.dispose();
    super.dispose();
  }

  String get clock => '00:${left.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final code = ctl.text;
    return Scaffold(
      backgroundColor: GColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GBack(),
              const Spacer(flex: 3),
              Text(
                'Verify OTP',
                style: gText(26, w: FontWeight.w700, c: GColors.ink),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: gText(13.5, c: GColors.grey, height: 1.4),
                  children: [
                    const TextSpan(
                      text: 'We have sent a 4-digit verification code to ',
                    ),
                    TextSpan(
                      text: '+91 ${widget.number}',
                      style: gText(
                        13.5,
                        w: FontWeight.w700,
                        c: GColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: focus.requestFocus,
                child: Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Container(
                            width: 62,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: GColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: i == code.length && focus.hasFocus
                                    ? GColors.saffron
                                    : GColors.line,
                              ),
                            ),
                            child: Text(
                              i < code.length ? code[i] : '',
                              style: gText(24, w: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: ctl,
                          focusNode: focus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onChanged: (_) => setState(() {}),
                          showCursor: false,
                          enableInteractiveSelection: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text.rich(
                    TextSpan(
                      style: gText(13, c: GColors.grey),
                      children: [
                        const TextSpan(text: 'Didn’t receive code? '),
                        TextSpan(
                          text: 'Resend',
                          style: gText(13, w: FontWeight.w700, c: GColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    clock,
                    style: gText(13, w: FontWeight.w700, c: GColors.saffron),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GButton(
                'Verify & Proceed',
                color: GColors.green,
                onPressed: code.length == 4 ? widget.onVerified : null,
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs the four screens in order. Nothing is stored.
class GAuthFlow extends StatelessWidget {
  final WidgetBuilder home;
  const GAuthFlow({super.key, required this.home});

  void _push(BuildContext c, Widget w) =>
      Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context) => GSplash(
    onStart: () => _push(
      context,
      Builder(
        builder: (c) =>
            GOnboarding(onSkip: () => _login(c), onContinue: () => _login(c)),
      ),
    ),
  );

  void _login(BuildContext c) => _push(
    c,
    Builder(
      builder: (c2) => GLogin(
        onOtp: (n) => _push(
          c2,
          Builder(
            builder: (c3) => GOtp(
              number: n,
              onVerified: () => Navigator.of(c3).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: home),
                (_) => false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Email + password sign in / create account, in the approved login look.
class GEmailLogin extends StatefulWidget {
  final Future<void> Function(String email, String password, bool registering)
  onSubmit;
  final bool busy;
  final String? error, notice;
  final VoidCallback? onToggle;
  final VoidCallback? onBack;
  const GEmailLogin({
    super.key,
    required this.onSubmit,
    this.busy = false,
    this.error,
    this.notice,
    this.onToggle,
    this.onBack,
  });
  @override
  State<GEmailLogin> createState() => _GEmailLoginState();
}

class _GEmailLoginState extends State<GEmailLogin> {
  final email = TextEditingController(), password = TextEditingController();
  bool registering = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool secret = false,
    TextInputType? type,
    Iterable<String>? hints,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: gText(12, w: FontWeight.w700, spacing: .6)),
      const SizedBox(height: 8),
      Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: GColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GColors.line),
        ),
        child: TextField(
          controller: c,
          obscureText: secret,
          keyboardType: type,
          autofillHints: hints,
          style: gText(14.5, w: FontWeight.w500),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onBack != null)
                  GestureDetector(onTap: widget.onBack, child: const GBack()),
                const SizedBox(height: 48),
                Text(
                  registering ? 'Create your account' : 'Welcome Back',
                  style: gText(26, w: FontWeight.w700, c: GColors.ink),
                ),
                const SizedBox(height: 10),
                Text(
                  registering
                      ? 'Use your email and a password of at least 8 characters.'
                      : 'Sign in with your email to see your meals, plan and deliveries.',
                  style: gText(13.5, c: GColors.grey, height: 1.4),
                ),
                const SizedBox(height: 28),
                _field(
                  'EMAIL',
                  email,
                  type: TextInputType.emailAddress,
                  hints: const [AutofillHints.username],
                ),
                const SizedBox(height: 16),
                _field(
                  'PASSWORD',
                  password,
                  secret: true,
                  hints: const [AutofillHints.password],
                ),
                if (widget.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      widget.error!,
                      style: gText(12.5, c: const Color(0xFFC62828)),
                    ),
                  ),
                if (widget.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      widget.notice!,
                      style: gText(12.5, c: GColors.ink),
                    ),
                  ),
                const SizedBox(height: 20),
                GButton(
                  widget.busy
                      ? 'Please wait...'
                      : registering
                      ? 'Create account'
                      : 'Sign in',
                  onPressed: widget.busy
                      ? null
                      : () => widget.onSubmit(
                          email.text,
                          password.text,
                          registering,
                        ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: widget.busy
                        ? null
                        : () {
                            setState(() => registering = !registering);
                            widget.onToggle?.call();
                          },
                    child: Text(
                      registering
                          ? 'Already have an account? Sign in'
                          : 'New to Tiffe? Create account',
                      style: gText(13, w: FontWeight.w600, c: GColors.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Confirm your email to keep your account secure.',
                    textAlign: TextAlign.center,
                    style: gText(12, c: GColors.grey, height: 1.5),
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
