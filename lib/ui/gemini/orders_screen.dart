import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'home_screen.dart';

class GOrder {
  final String id, kind, status, title, when, total;
  final bool live;
  const GOrder(
    this.id,
    this.kind,
    this.status,
    this.title,
    this.when,
    this.total, {
    this.live = false,
  });
}

/// Orders page of the Tiffie redesign (prototype). Orders are parameters.
class GOrders extends StatelessWidget {
  final List<GOrder> orders;
  final ValueChanged<GOrder>? onTrack;
  final ValueChanged<int>? onTab;
  final String emptyText;
  const GOrders({
    super.key,
    required this.orders,
    this.onTrack,
    this.onTab,
    this.emptyText = 'No orders yet.',
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
            MediaQuery.of(context).padding.top + 24,
            24,
            24,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'My Orders & Tiffins',
              style: gText(20, w: FontWeight.w800, c: Colors.white),
            ),
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: gText(14, c: GColors.grey, height: 1.5),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  children: [
                    for (final o in orders.where((o) => !_isHistory(o))) ...[
                      _card(o),
                      const SizedBox(height: 16),
                    ],
                    if (orders.any(_isHistory)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          'Order history',
                          style: gText(
                            18,
                            w: FontWeight.w800,
                            c: GColors.green,
                          ),
                        ),
                      ),
                      for (final o in orders.where(_isHistory)) ...[
                        _card(o),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
        ),
        GBottomNav(tab: 2, onTab: onTab),
      ],
    ),
  );

  bool _isHistory(GOrder o) =>
      const ['Delivered', 'Cancelled', 'Failed', 'Refunded'].contains(o.status);

  Widget _card(GOrder o) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GColors.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                o.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gText(10.5, w: FontWeight.w600, c: GColors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              o.status,
              style: gText(
                11.5,
                w: FontWeight.w700,
                c: o.live ? GColors.saffron : GColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EBE9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.restaurant,
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
                    o.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: gText(14, w: FontWeight.w700, c: GColors.green),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${o.when} • ${o.kind}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gText(11, c: GColors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: GColors.line),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  o.total,
                  style: gText(12, w: FontWeight.w700, c: GColors.green),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onTrack?.call(o),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isHistory(o) ? 'Order Details' : 'Track Details',
                    style: gText(12, w: FontWeight.w700, c: GColors.green),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: GColors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
