import 'package:flutter/material.dart';

import 'auth_screens.dart';

enum GStepState { done, current, pending }

class GTrackStep {
  final String label;
  final GStepState state;
  final String? note;
  const GTrackStep(this.label, this.state, {this.note});
}

/// Order tracking page of the Tiffie redesign. All values are parameters.
class GTrack extends StatelessWidget {
  /// Tests switch this off so pumpAndSettle can finish.
  static bool animate = true;
  final String orderId, subtitle;
  final List<GTrackStep> steps;
  final VoidCallback? onMap;
  final VoidCallback? onBack;
  const GTrack({
    super.key,
    required this.orderId,
    required this.subtitle,
    required this.steps,
    this.onMap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: GColors.green,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 16,
            24,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0x1FFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Order $orderId',
                        style: gText(20, w: FontWeight.w700, c: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: gText(12.5, c: const Color(0xFFD6DDD8), height: 1.4),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: GColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Progress',
                    style: gText(16, w: FontWeight.w700, c: GColors.green),
                  ),
                  const SizedBox(height: 18),
                  for (final s in steps) _step(context, s),
                ],
              ),
            ),
          ),
        ),
        if (onMap != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: GButton('Live Map Tracking', onPressed: onMap),
          ),
      ],
    ),
  );

  Widget _step(BuildContext context, GTrackStep s) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: switch (s.state) {
            GStepState.done => const Icon(
              Icons.check_circle_outline,
              size: 26,
              color: GColors.saffron,
            ),
            GStepState.current => const _Spinner(),
            GStepState.pending => const Icon(
              Icons.radio_button_unchecked,
              size: 26,
              color: Color(0xFFC9C4B8),
            ),
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: gText(
                    14,
                    w: s.state == GStepState.pending
                        ? FontWeight.w500
                        : FontWeight.w600,
                    c: s.state == GStepState.pending
                        ? GColors.grey
                        : GColors.green,
                    height: 1.3,
                  ),
                ),
                if (s.note != null) ...[
                  const SizedBox(height: 2),
                  Text(s.note!, style: gText(12, c: GColors.grey)),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Spinning marker for the current step; static when animations are off.
class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!GTrack.animate || MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: const Icon(Icons.autorenew, size: 26, color: GColors.saffron),
  );
}

/// Live Delivery Tracking page. The map is passed in (it is a labelled
/// preview); headline and detail are real kitchen data only.
class GLive extends StatelessWidget {
  final String headline, detail;
  final Widget map;
  const GLive({
    super.key,
    required this.headline,
    required this.detail,
    required this.map,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: GColors.green,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 16,
            24,
            24,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0x1FFFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Live Delivery Tracking',
                    style: gText(20, w: FontWeight.w700, c: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: GColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE9DC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          size: 28,
                          color: GColors.saffron,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headline,
                              style: gText(
                                16,
                                w: FontWeight.w800,
                                c: GColors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detail,
                              style: gText(12, c: GColors.grey, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                map,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
