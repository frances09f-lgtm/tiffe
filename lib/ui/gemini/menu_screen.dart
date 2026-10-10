import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'home_screen.dart';

class GMenuItem {
  final String title, blurb, price, tag, image;
  final bool special;
  const GMenuItem(
    this.title,
    this.blurb,
    this.price,
    this.tag,
    this.image, {
    this.special = false,
  });
}

/// Menu page of the Tiffie redesign (prototype). Items are parameters.
class GMenu extends StatefulWidget {
  final List<String> categories;

  /// One list of items per category, in the same order as [categories].
  final List<List<GMenuItem>> items;
  final int initialCategory;

  /// false: one bhaji per row (list). true: two per row (grid).
  final bool grid;
  final VoidCallback? onWeekly;
  final ValueChanged<List<GMenuItem>>? onOrder;
  final int required;
  final List<int> initialSelected;
  final ValueChanged<int>? onTab;
  const GMenu({
    super.key,
    required this.categories,
    required this.items,
    this.onWeekly,
    this.onOrder,
    this.initialCategory = 0,
    this.grid = true,
    this.required = 2,
    this.initialSelected = const [],
    this.onTab,
  });

  @override
  State<GMenu> createState() => _GMenuState();
}

class _GMenuState extends State<GMenu> {
  late int _cat = widget.initialCategory;
  late final Map<int, Set<int>> _picks = {
    widget.initialCategory: {...widget.initialSelected},
  };
  Set<int> get _sel => _picks.putIfAbsent(_cat, () => <int>{});
  List<GMenuItem> get _items => widget.items[_cat];

  void _toggle(int i) => setState(() {
    if (_sel.contains(i)) {
      _sel.remove(i);
    } else if (_sel.length < widget.required) {
      _sel.add(i);
    }
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
            0,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Today’s Menu',
                          style: gText(20, w: FontWeight.w800, c: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onWeekly,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: GColors.saffron,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Weekly Schedule',
                              style: gText(
                                12,
                                w: FontWeight.w700,
                                c: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 24),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.categories.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _cat = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: i == _cat
                                  ? GColors.saffron
                                  : const Color(0x1AFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.categories[i],
                              style: gText(
                                12,
                                w: i == _cat
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                c: i == _cat ? Colors.white : GColors.cream,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.grid
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 248,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _gridCard(i, _items[i]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _card(i, _items[i]),
                ),
        ),
        _bar(),
        GBottomNav(tab: 1, onTab: widget.onTab),
      ],
    ),
  );

  Widget _bar() {
    final n = _sel.length;
    final ready = n == widget.required;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: GColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n of ${widget.required} selected',
                  style: gText(14, w: FontWeight.w700, c: GColors.green),
                ),
                const SizedBox(height: 2),
                Text(
                  ready
                      ? 'Ready to order'
                      : 'Pick ${widget.required} bhajis to order',
                  style: gText(11, c: GColors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: ready
                ? () => widget.onOrder?.call([for (final i in _sel) _items[i]])
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: ready ? GColors.green : const Color(0xFFD9DDD9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Order',
                style: gText(
                  14,
                  w: FontWeight.w700,
                  c: ready ? Colors.white : const Color(0xFF8A908C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(int idx, GMenuItem it) => Container(
    padding: const EdgeInsets.all(16),
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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            it.image,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        it.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: gText(14, w: FontWeight.w700, c: GColors.green),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      it.price,
                      style: gText(
                        12.5,
                        w: FontWeight.w700,
                        c: GColors.saffron,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  it.blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: gText(10.5, c: GColors.grey, height: 1.4),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: it.special
                                ? const Color(0x1AE86324)
                                : const Color(0xFFE8EBE9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            it.tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: gText(
                              10,
                              w: FontWeight.w600,
                              c: it.special ? GColors.saffron : GColors.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _selectBtn(idx),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _gridCard(int idx, GMenuItem it) {
    final on = _sel.contains(idx);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: on ? GColors.saffron : GColors.line,
          width: on ? 1.6 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(it.image, fit: BoxFit.cover),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      it.tag,
                      style: gText(
                        9.5,
                        w: FontWeight.w700,
                        c: it.special ? GColors.saffron : GColors.green,
                      ),
                    ),
                  ),
                ),
                if (on)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: GColors.saffron,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      it.title,
                      style: gText(13, w: FontWeight.w700, c: GColors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  it.price,
                  style: gText(12, w: FontWeight.w700, c: GColors.saffron),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              it.blurb,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: gText(10, c: GColors.grey, height: 1.35),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: _selectBtn(idx, fill: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectBtn(int idx, {bool fill = false}) {
    final on = _sel.contains(idx);
    final locked = !on && _sel.length >= widget.required;
    return GestureDetector(
      onTap: locked ? null : () => _toggle(idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? GColors.saffron
              : locked
              ? const Color(0xFFEDEDED)
              : GColors.green,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              on ? Icons.check : Icons.add,
              size: 14,
              color: locked ? const Color(0xFF8A908C) : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              on ? 'Selected' : 'Select',
              style: gText(
                12,
                w: FontWeight.w700,
                c: locked ? const Color(0xFF8A908C) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
