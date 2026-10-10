import 'package:flutter/material.dart';

import 'auth_screens.dart';

/// Home page of the Tiffie redesign. All values are parameters so real data
/// can be wired in later; the preview uses the prototype's sample text.
class GHome extends StatelessWidget {
  final String address, name, subtitle;
  final String planTitle, planSubtitle, todayMeal, todayStatus;
  final String thaliImage;
  final String thaliTitle, thaliBlurb, thaliPrice, thaliTag;
  final String thaliNote;
  final String featuredHeading, monthlySub;
  final bool showPause, showFeatured, hasPlan, showBell;
  final String todayLabel;
  final VoidCallback? onQuickOne, onQuickMonthly;
  final VoidCallback? onViewSchedule, onPauseTomorrow, onViewMenu, onOrder;
  final int tab;
  final ValueChanged<int>? onTab;
  final int? updateBuild;
  final VoidCallback? onUpdate;
  const GHome({
    super.key,
    required this.address,
    required this.name,
    required this.subtitle,
    required this.planTitle,
    required this.planSubtitle,
    required this.todayMeal,
    required this.todayStatus,
    this.thaliNote = 'Homemade daily',
    this.featuredHeading = 'Today’s Most Ordered Bhaji',
    this.monthlySub = 'Save up to 20% with monthly subscription',
    this.todayLabel = 'Today’s Bhaji: ',
    this.showPause = true,
    this.hasPlan = true,
    this.showBell = true,
    this.updateBuild,
    this.onUpdate,
    this.showFeatured = true,
    this.onQuickOne,
    this.onQuickMonthly,
    this.thaliImage = 'assets/food/batata.jpg',
    required this.thaliTitle,
    required this.thaliBlurb,
    required this.thaliPrice,
    required this.thaliTag,
    this.onViewSchedule,
    this.onPauseTomorrow,
    this.onViewMenu,
    this.onOrder,
    this.tab = 0,
    this.onTab,
  });

  Widget _circle(IconData i, {Color color = Colors.white}) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: Color(0xFF2B4D3C),
      shape: BoxShape.circle,
    ),
    child: Icon(i, size: 20, color: color),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _header(context),
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (updateBuild != null) ...[
                          _updateBanner(),
                          const SizedBox(height: 12),
                        ],
                        _planCard(),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                featuredHeading,
                                style: gText(
                                  17,
                                  w: FontWeight.w700,
                                  c: GColors.green,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: onViewMenu,
                              child: Text(
                                'View Full Menu',
                                style: gText(
                                  13,
                                  w: FontWeight.w700,
                                  c: GColors.saffron,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (showFeatured) ...[
                          _thaliCard(),
                          const SizedBox(height: 26),
                        ],
                        _quickOrder(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _nav(),
      ],
    ),
  );

  Widget _updateBanner() => GestureDetector(
    onTap: onUpdate,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GColors.saffron,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update available: Tiffe v$updateBuild. Tap to update.',
              style: gText(12.5, w: FontWeight.w700, c: Colors.white),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white, size: 20),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: GColors.green,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    padding: EdgeInsets.fromLTRB(
      24,
      MediaQuery.of(context).padding.top + 12,
      24,
      78,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _circle(Icons.location_on, color: GColors.saffron),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DELIVERING TO',
                    style: gText(
                      9,
                      w: FontWeight.w600,
                      c: const Color(0xFFB9C6BE),
                      spacing: .6,
                    ),
                  ),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gText(14, w: FontWeight.w600, c: Colors.white),
                  ),
                ],
              ),
            ),
            if (showBell) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              _circle(Icons.notifications_none),
            ],
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Namaste, $name 🙏',
                    style: gText(24, w: FontWeight.w700, c: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: gText(12, c: const Color(0xFFD6DDD8))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC9D4F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GColors.saffron, width: 2),
              ),
              child: Text(
                name.isEmpty ? '' : name[0].toUpperCase(),
                style: gText(20, w: FontWeight.w700, c: GColors.green),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _planCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: GColors.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        if (hasPlan)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
              decoration: const BoxDecoration(
                color: GColors.green,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: Text(
                'ACTIVE PLAN',
                style: gText(
                  9.5,
                  w: FontWeight.w700,
                  c: Colors.white,
                  spacing: .5,
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, hasPlan ? 34 : 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EBE9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available_outlined,
                      size: 22,
                      color: GColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planTitle,
                          style: gText(
                            14.5,
                            w: FontWeight.w700,
                            c: GColors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(planSubtitle, style: gText(11.5, c: GColors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: GColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$todayLabel$todayMeal',
                        style: gText(11.5, w: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      todayStatus,
                      textAlign: TextAlign.left,
                      style: gText(
                        11.5,
                        w: FontWeight.w700,
                        c: GColors.saffron,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _planButton(
                      'View Schedule',
                      const Color(0xFFE8EBE9),
                      icon: Icons.calendar_today_outlined,
                      onTap: onViewSchedule,
                    ),
                  ),
                  if (showPause) const SizedBox(width: 10),
                  if (showPause)
                    Expanded(
                      child: _planButton(
                        'Pause Tomorrow',
                        const Color(0xFFF0EBDD),
                        onTap: onPauseTomorrow,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _planButton(
    String label,
    Color bg, {
    IconData? icon,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: GColors.green),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: gText(12, w: FontWeight.w700, c: GColors.green),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _thaliCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: GColors.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(thaliImage, fit: BoxFit.cover),
              if (thaliTag.isNotEmpty)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: GColors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: GColors.saffron,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          thaliTag,
                          style: gText(11, w: FontWeight.w700, c: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              if (thaliPrice.isNotEmpty)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: GColors.saffron,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      thaliPrice,
                      style: gText(12, w: FontWeight.w700, c: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thaliTitle,
                style: gText(15, w: FontWeight.w700, c: GColors.green),
              ),
              const SizedBox(height: 6),
              Text(
                thaliBlurb,
                style: gText(11.5, c: GColors.grey, height: 1.4),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: GColors.line),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: GColors.saffron,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      thaliNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gText(11.5, w: FontWeight.w600, c: GColors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onOrder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: GColors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Order Now',
                        style: gText(12, w: FontWeight.w700, c: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _quickCard(
    IconData icon,
    Color tint,
    Color fg,
    String title,
    String sub,
    VoidCallback? onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: fg),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: gText(12, w: FontWeight.w700, c: GColors.green),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: gText(10, c: GColors.grey, height: 1.35),
          ),
        ],
      ),
    ),
  );

  Widget _quickOrder() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Quick Order Options',
        style: gText(16, w: FontWeight.w700, c: GColors.green),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _quickCard(
                Icons.restaurant,
                const Color(0x1AE86324),
                GColors.saffron,
                'One-Time Bhaji',
                'Order a single bhaji instantly',
                onQuickOne,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                Icons.repeat,
                const Color(0x1A1B3B2B),
                GColors.green,
                'Monthly Tiffin',
                monthlySub,
                onQuickMonthly,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _nav() => GBottomNav(tab: tab, onTab: onTab);
}

class GBottomNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int>? onTab;
  const GBottomNav({super.key, required this.tab, this.onTab});

  @override
  Widget build(BuildContext context) {
    const items = [
      [Icons.home_outlined, Icons.home, 'Home'],
      [Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'],
      [Icons.repeat, Icons.repeat, 'Plans'],
      [Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'],
      [Icons.person_outline, Icons.person, 'Profile'],
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: GColors.line)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTab?.call(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (i == tab ? items[i][1] : items[i][0]) as IconData,
                        size: 24,
                        color: i == tab ? GColors.saffron : GColors.grey,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i][2] as String,
                        style: gText(
                          11,
                          w: i == tab ? FontWeight.w700 : FontWeight.w500,
                          c: i == tab ? GColors.saffron : GColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
