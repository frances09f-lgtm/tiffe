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
          decoration: BoxDecoration(
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
                color: GColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: GColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Progress',
                    style: gText(16, w: FontWeight.w700, c: GColors.ink),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < steps.length; i++)
                    _step(context, steps[i], i == steps.length - 1),
                ],
              ),
            ),
          ),
        ),
        if (onMap != null || steps.isNotEmpty)
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

  Widget _step(BuildContext context, GTrackStep s, bool last) => Padding(
    padding: EdgeInsets.only(bottom: last ? 4 : 0),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              SizedBox(width: 28, height: 28, child: _icon(s)),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: s.state == GStepState.done
                          ? GColors.saffron
                          : GColors.alt(const Color(0xFFE3DED3), GColors.line),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : 26),
              child: _stepText(s),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _icon(GTrackStep s) => switch (s.state) {
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
  };

  Widget _stepText(GTrackStep s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        s.label,
        style: gText(
          14,
          w: s.state == GStepState.pending ? FontWeight.w500 : FontWeight.w600,
          c: s.state == GStepState.pending ? GColors.grey : GColors.ink,
          height: 1.3,
        ),
      ),
      if (s.note != null) ...[
        const SizedBox(height: 2),
        Text(s.note!, style: gText(12, c: GColors.grey)),
      ],
    ],
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

  /// Dials the real delivery partner; null hides the button.
  final VoidCallback? onCall;
  const GLive({
    super.key,
    required this.headline,
    required this.detail,
    required this.map,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
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
                    color: GColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: GColors.line),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: GColors.saffronTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pedal_bike,
                          size: 38,
                          color: Color(0xFFF1A27C),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: gText(20, w: FontWeight.w800, c: GColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: gText(13, c: GColors.grey, height: 1.45),
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
        if (onCall != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: GestureDetector(
              onTap: onCall,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: GColors.green,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.call, color: GColors.saffron, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Call Delivery Partner',
                        style: gText(15, w: FontWeight.w700, c: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
