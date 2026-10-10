import 'package:flutter/material.dart';

import 'auth_screens.dart';

Widget _flowCard(Widget child, {Color? bg, bool selected = false}) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 18),
  padding: const EdgeInsets.all(22),
  decoration: BoxDecoration(
    color: bg ?? GColors.card,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(
      color: selected ? GColors.green : GColors.line,
      width: selected ? 2 : 1,
    ),
  ),
  child: child,
);

Widget _flowHeader(BuildContext context, String title) => Padding(
  padding: EdgeInsets.fromLTRB(
    24,
    MediaQuery.of(context).padding.top + 16,
    24,
    16,
  ),
  child: Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: GColors.alt(const Color(0xFFF0EBE0), GColors.chip),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back, size: 20, color: GColors.ink),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: gText(21, w: FontWeight.w800, c: GColors.ink),
          ),
        ),
      ),
    ],
  ),
);

Widget _line(String a, String b, {bool big = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      Expanded(
        child: Text(
          a,
          style: gText(
            big ? 16 : 14,
            w: big ? FontWeight.w800 : FontWeight.w500,
            c: big ? GColors.ink : GColors.grey,
          ),
        ),
      ),
      Text(
        b,
        style: gText(
          big ? 18 : 14,
          w: big ? FontWeight.w800 : FontWeight.w700,
          c: big ? GColors.saffron : GColors.charcoal,
        ),
      ),
    ],
  ),
);

/// Subscription Checkout: plan, delivery address and the real bill.
class GPlanCheckout extends StatelessWidget {
  final String planName, planPrice, deliveryPrice, total;
  final String addressTitle, addressLines;
  final VoidCallback? onProceed;

  /// Overrides for the one-time order checkout, which shares this layout.
  final String title, cardTitle, note, priceLabel, buttonLabel;
  const GPlanCheckout({
    this.title = 'Subscription Checkout',
    this.cardTitle = 'Selected Plan',
    this.note = 'Start and end dates are confirmed by the kitchen once your payment is verified.',
    this.priceLabel = 'Plan Price',
    this.buttonLabel = '',
    super.key,
    required this.planName,
    required this.planPrice,
    required this.deliveryPrice,
    required this.total,
    required this.addressTitle,
    required this.addressLines,
    this.onProceed,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        _flowHeader(context, title),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            children: [
              _flowCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardTitle,
                      style: gText(16, w: FontWeight.w800, c: GColors.ink),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            planName,
                            style: gText(14.5, w: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          planPrice,
                          style: gText(
                            15,
                            w: FontWeight.w800,
                            c: GColors.saffron,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      note,
                      style: gText(12.5, c: GColors.grey, height: 1.45),
                    ),
                  ],
                ),
              ),
              _flowCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Address',
                      style: gText(16, w: FontWeight.w800, c: GColors.ink),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: GColors.cream,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: GColors.saffron,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addressTitle,
                                  style: gText(
                                    14,
                                    w: FontWeight.w700,
                                    c: GColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  addressLines,
                                  style: gText(
                                    12.5,
                                    c: GColors.grey,
                                    height: 1.4,
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
              _flowCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Breakdown',
                      style: gText(16, w: FontWeight.w800, c: GColors.ink),
                    ),
                    const SizedBox(height: 10),
                    _line(priceLabel, planPrice),
                    _line('Delivery Charges', deliveryPrice),
                    _line('Taxes & Packaging', 'Included'),
                    Divider(height: 22, color: GColors.line),
                    _line('Total Payable', total, big: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: GButton(
            buttonLabel.isEmpty ? 'Proceed to Payment ($total)' : buttonLabel,
            onPressed: onProceed,
          ),
        ),
      ],
    ),
  );
}

/// Select Payment Method, as designed. Nothing here moves money.
class GPlanPay extends StatefulWidget {
  final String total;
  final VoidCallback? onPay;
  const GPlanPay({super.key, required this.total, this.onPay});
  @override
  State<GPlanPay> createState() => _GPlanPayState();
}

class _GPlanPayState extends State<GPlanPay> {
  int sel = 0;

  Widget _opt(int i, IconData icon, String title, String sub, {Color? ic}) =>
      GestureDetector(
        onTap: () => setState(() => sel = i),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: sel == i ? GColors.green : GColors.line,
              width: sel == i ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: ic ?? GColors.ink, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: gText(14.5, w: FontWeight.w700, c: GColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(sub, style: gText(12, c: GColors.grey)),
                  ],
                ),
              ),
              Icon(
                sel == i ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel == i ? GColors.green : GColors.alt(const Color(0xFFD9D3C5), GColors.line),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        _flowHeader(context, 'Select Payment Method'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            children: [
              _opt(
                0,
                Icons.smartphone,
                'UPI (Google Pay / PhonePe / Paytm)',
                'Instant secure payment',
                ic: GColors.saffron,
              ),
              _opt(
                1,
                Icons.credit_card,
                'Credit / Debit Card',
                'Visa, Mastercard, RuPay',
              ),
              _opt(
                2,
                Icons.account_balance_wallet_outlined,
                'Net Banking',
                'All major Indian banks',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: GButton(
            'Pay ${widget.total} Securely',
            color: GColors.green,
            onPressed: widget.onPay,
          ),
        ),
      ],
    ),
  );
}

/// Subscription Confirmed, as designed.
/// After Pay: a circular processing animation (like GPay), then the tick and
/// the confirmation. [task] runs during the animation and returns an error
/// text, or null when it worked. On an error the page closes and [onError]
/// gets the text, so a failed action never looks confirmed.
class GPlanConfirmed extends StatefulWidget {
  final VoidCallback? onDone, onSecondary;
  final String title, body, doneLabel;
  final String? secondaryLabel;
  final Future<String?> Function()? task;
  final void Function(String error)? onError;
  final Duration minProcessing;
  const GPlanConfirmed({
    super.key,
    this.onDone,
    this.onSecondary,
    this.title = 'Subscription Confirmed!',
    this.body = 'Your monthly tiffin plan has been activated successfully. Your first meal arrives tomorrow at 1:00 PM.',
    this.doneLabel = 'Go to Home Dashboard',
    this.secondaryLabel,
    this.task,
    this.onError,
    this.minProcessing = const Duration(milliseconds: 2200),
  });
  @override
  State<GPlanConfirmed> createState() => _GPlanConfirmedState();
}

class _GPlanConfirmedState extends State<GPlanConfirmed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final err = widget.task == null ? null : await widget.task!();
    if (widget.minProcessing > Duration.zero) {
      await Future<void>.delayed(widget.minProcessing);
    }
    if (!mounted) return;
    if (err != null) {
      widget.onError?.call(err);
      return;
    }
    setState(() => done = true);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Back is blocked here: while the task runs it must not drop the spinner,
    // and afterwards the buttons are the way out. Errors close the page in code.
    canPop: false,
    child: Scaffold(
      backgroundColor: GColors.cream,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: done
                          ? AnimatedBuilder(
                              animation: _c,
                              builder: (_, _) {
                                final t = Curves.elasticOut.transform(
                                  _c.value.clamp(0.0, 1.0),
                                );
                                return Transform.scale(
                                  scale: t,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: GColors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 52,
                                      color: GColors.saffron,
                                    ),
                                  ),
                                );
                              },
                            )
                          : const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 6,
                                color: GColors.saffron,
                                backgroundColor: Color(0xFFE8E2D6),
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      done ? widget.title : 'Processing payment...',
                      textAlign: TextAlign.center,
                      style: gText(24, w: FontWeight.w800, c: GColors.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      done ? widget.body : 'Please do not close the app.',
                      textAlign: TextAlign.center,
                      style: gText(14, c: GColors.grey, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (done)
            Padding(
              padding: EdgeInsets.fromLTRB(
                32,
                4,
                32,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.secondaryLabel != null) ...[
                    GestureDetector(
                      onTap: widget.onSecondary,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GColors.alt(const Color(0xFFF0EBE0), GColors.chip),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          widget.secondaryLabel!,
                          style: gText(
                            15,
                            w: FontWeight.w700,
                            c: GColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GButton(widget.doneLabel, onPressed: widget.onDone ?? () {}),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
