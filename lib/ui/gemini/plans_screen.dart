import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'home_screen.dart' show GBottomNav;

class GPlan {
  final String name, subtitle, price;
  final String? mrp, savePill, badge, pill;
  final List<String> bullets;
  final bool popular;
  const GPlan({
    required this.name,
    required this.subtitle,
    required this.price,
    this.mrp,
    this.savePill,
    this.badge,
    this.pill,
    this.bullets = const [],
    this.popular = false,
  });
}

/// Tiffin Subscriptions page of the Tiffie redesign. All values are
/// parameters; the live app supplies the plans.
class GPlans extends StatelessWidget {
  final String subtitle;
  final List<GPlan> plans;
  final void Function(GPlan plan)? onSelect;
  final VoidCallback? onBack;

  /// Index of the plan the customer has chosen; its button reads Active Plan.
  final int? activeIndex;

  /// When set, the bottom nav shows with Plans selected (tab 2).
  final ValueChanged<int>? onTab;
  const GPlans({
    super.key,
    required this.subtitle,
    required this.plans,
    this.onSelect,
    this.onBack,
    this.onTab,
    this.activeIndex,
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
                        'Tiffin Subscriptions',
                        style: gText(20, w: FontWeight.w700, c: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                style: gText(
                  13,
                  c: Colors.white.withValues(alpha: .8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            children: [
              for (var i = 0; i < plans.length; i++)
                _card(plans[i], active: i == activeIndex),
            ],
          ),
        ),
        if (onTab != null) GBottomNav(tab: 2, onTab: onTab),
      ],
    ),
  );

  Widget _card(GPlan p, {bool active = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: p.popular ? GColors.green : GColors.line,
          width: p.popular ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: p.popular ? 8 : 0),
                  child: Text(
                    p.name,
                    style: gText(21, w: FontWeight.w800, c: GColors.green),
                  ),
                ),
                const SizedBox(height: 6),
                Text(p.subtitle, style: gText(13, c: GColors.grey)),
                const SizedBox(height: 18),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.price,
                        style: gText(
                          27,
                          w: FontWeight.w800,
                          c: GColors.saffron,
                        ),
                      ),
                      if (p.mrp != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          p.mrp!,
                          style: gText(
                            14,
                            c: GColors.grey,
                          ).copyWith(decoration: TextDecoration.lineThrough),
                        ),
                      ],
                      if (p.savePill != null || p.pill != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEDE6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.savePill ?? p.pill!,
                            style: gText(
                              12,
                              w: FontWeight.w700,
                              c: GColors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (p.bullets.isNotEmpty) const SizedBox(height: 16),
                for (final b in p.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check, size: 18, color: GColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b,
                            style: gText(
                              13.5,
                              c: GColors.charcoal,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onSelect == null || active ? null : () => onSelect!(p),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFE3EDE7)
                          : p.popular
                          ? GColors.green
                          : const Color(0xFFF0EBE0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (active) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 20,
                            color: GColors.green,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          active ? 'Active Plan' : 'Select This Plan',
                          style: gText(
                            15,
                            w: FontWeight.w700,
                            c: active || !p.popular
                                ? GColors.green
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (p.badge != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: const BoxDecoration(
                  color: GColors.saffron,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  p.badge!,
                  style: gText(
                    11,
                    w: FontWeight.w800,
                    c: Colors.white,
                  ).copyWith(letterSpacing: .6),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Plans built from the kitchen's settings, so prices are never hard-coded.
/// [dailyPaise] is the 1-a-day price, [doublePaise] the 2-a-day price.
List<GPlan> tiffinPlans({
  required num doublePaise,
  required num dailyPaise,
  required num deliveryPaise,
}) {
  String rs(num paise) {
    final v = (paise / 100).round().toString();
    final b = StringBuffer('₹');
    for (var i = 0; i < v.length; i++) {
      if (i > 0 && (v.length - i) % 3 == 0 && v.length > 3) b.write(',');
      b.write(v[i]);
    }
    return b.toString();
  }

  return [
    GPlan(
      name: 'Monthly Homestyle Thali',
      subtitle: 'Lunch & Dinner for 30 Days (60 Meals)',
      price: rs(doublePaise),
      badge: 'MOST POPULAR',
      popular: true,
      bullets: const [
        '3 Soft Chapatis, Dal, Rice & Sabzi per meal',
        'Free delivery in insulated thermal bags',
        'Unlimited meal pause / date extension',
      ],
    ),
    GPlan(
      name: 'Monthly Lunch Plan',
      subtitle: 'Lunch Only for 30 Days (30 Meals)',
      price: rs(dailyPaise),
      pill: 'Best for Office',
    ),
  ];
}
