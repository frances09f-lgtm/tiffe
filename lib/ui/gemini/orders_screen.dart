import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'home_screen.dart';
import 'toast.dart';

class GOrder {
  final String id, kind, status, title, when, total;
  final bool live;
  final String? placed, due;

  /// Simulated status for a demo order. `status` stays the true one.
  final String? demoStatus;
  bool get demo => demoStatus != null;
  const GOrder(
    this.id,
    this.kind,
    this.status,
    this.title,
    this.when,
    this.total, {
    this.live = false,
    this.demoStatus,
    this.placed,
    this.due,
  });
}

bool isHistoryOrder(GOrder o) =>
    const ['Delivered', 'Cancelled', 'Failed', 'Refunded'].contains(o.status);

/// One order card (status, title, total, Track/Order Details).
class GOrderCard extends StatelessWidget {
  final GOrder o;
  final ValueChanged<GOrder>? onTrack;
  const GOrderCard(this.o, {super.key, this.onTrack});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      color: GColors.card,
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
                '${o.id} • ${o.kind}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: gText(10.5, w: FontWeight.w600, c: GColors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              o.demoStatus ?? o.status,
              style: gText(
                11.5,
                w: FontWeight.w700,
                c: o.live ? GColors.saffron : GColors.ink,
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
                color: GColors.alt(const Color(0xFFE8EBE9), GColors.chip),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.restaurant, size: 22, color: GColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: gText(14, w: FontWeight.w700, c: GColors.ink),
                  ),
                  const SizedBox(height: 2),
                  if (o.due != null || o.placed == null)
                    Text(
                      o.due ?? o.when,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: gText(11, c: GColors.grey),
                    ),
                  if (o.placed != null)
                    Text(
                      'Placed ${o.placed}',
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
        Divider(height: 1, color: GColors.line),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  o.total,
                  style: gText(12, w: FontWeight.w700, c: GColors.ink),
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
                    isHistoryOrder(o) ? 'Order Details' : 'Track Details',
                    style: gText(12, w: FontWeight.w700, c: GColors.ink),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: GColors.ink),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// One bhaji the user can pick, with its picture asset (or none).
class GBhajiOption {
  final String name;
  final String? image;
  const GBhajiOption(this.name, [this.image]);
}

/// One planned tiffin (lunch or dinner) on a given day.
class GSlot {
  /// Stable key, for example `2026-10-10:lunch`.
  final String id;
  final String slot, day, time, cutoff;
  final List<String> bhajis, defaultBhajis;
  final bool custom, locked;
  final Map<String, String?> images;
  const GSlot(
    this.id,
    this.slot,
    this.day,
    this.time,
    this.cutoff,
    this.bhajis, {
    this.defaultBhajis = const [],
    this.custom = false,
    this.locked = false,
    this.images = const {},
  });
  String? imageFor(String name) => images[name];
}

/// Orders page: only undelivered orders up front, daily lunch and dinner
/// cards for plan users, and a Completed dropdown for delivered, cancelled,
/// failed and refunded orders.
class GOrders extends StatefulWidget {
  final List<GOrder> orders;
  final List<GSlot> slots;
  final List<GBhajiOption> bhajiOptions;

  /// Saves a bhaji change. Returns an error text, or null when it worked.
  final Future<String?> Function(GSlot slot, List<String> bhajis)? onChangeSlot;
  final ValueChanged<GOrder>? onTrack;
  final ValueChanged<int>? onTab;
  final String emptyText;
  const GOrders({
    super.key,
    required this.orders,
    this.slots = const [],
    this.bhajiOptions = const [],
    this.onChangeSlot,
    this.onTrack,
    this.onTab,
    this.emptyText = 'No orders yet.',
  });
  @override
  State<GOrders> createState() => _GOrdersState();
}

class _GOrdersState extends State<GOrders> {
  bool open = false;
  bool openClosed = false;

  Future<void> _change(GSlot s) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickSheet(slot: s, options: widget.bhajiOptions),
    );
    if (picked == null || !mounted) return;
    final err = await widget.onChangeSlot?.call(s, picked);
    if (!mounted) return;
    gToast(
      context,
      err ?? '${s.slot} bhajis updated for ${s.day}.',
      error: err != null,
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Text(
      t,
      style: gText(16, w: FontWeight.w800, c: GColors.ink),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final active = [
      for (final o in widget.orders)
        if (!isHistoryOrder(o)) o,
    ];
    final done = [
      for (final o in widget.orders)
        if (o.status == 'Delivered') o,
    ];
    final closed = [
      for (final o in widget.orders)
        if (isHistoryOrder(o) && o.status != 'Delivered') o,
    ];
    final days = <String>[];
    for (final s in widget.slots) {
      if (!days.contains(s.day)) days.add(s.day);
    }
    final nothing = active.isEmpty && widget.slots.isEmpty;
    return Scaffold(
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
            child: nothing && done.isEmpty && closed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        widget.emptyText,
                        textAlign: TextAlign.center,
                        style: gText(14, c: GColors.grey, height: 1.5),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    children: [
                      if (active.isNotEmpty) ...[
                        _title('On the way'),
                        for (final o in active) ...[
                          GOrderCard(o, onTrack: widget.onTrack),
                          const SizedBox(height: 16),
                        ],
                      ],
                      for (final d in days) ...[
                        _title(d),
                        for (final s in widget.slots)
                          if (s.day == d) ...[
                            GSlotCard(slot: s, onChange: () => _change(s)),
                            const SizedBox(height: 16),
                          ],
                      ],
                      if (nothing)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              Icon(
                                Icons.ramen_dining_outlined,
                                size: 40,
                                color: GColors.grey,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Nothing pending right now.\nOrder a tiffin from the Menu.',
                                textAlign: TextAlign.center,
                                style: gText(
                                  13.5,
                                  c: GColors.grey,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (done.isNotEmpty) _completed(done),
                      if (closed.isNotEmpty) ...[
                        if (done.isNotEmpty) const SizedBox(height: 12),
                        _completed(
                          closed,
                          title: 'Cancelled & refunded',
                          icon: Icons.cancel_outlined,
                          isOpen: openClosed,
                          toggle: () =>
                              setState(() => openClosed = !openClosed),
                        ),
                      ],
                    ],
                  ),
          ),
          GBottomNav(tab: 3, onTab: widget.onTab),
        ],
      ),
    );
  }

  Widget _completed(
    List<GOrder> done, {
    String title = 'Completed',
    IconData icon = Icons.check_circle_outline,
    bool? isOpen,
    VoidCallback? toggle,
  }) {
    final open = isOpen ?? this.open;
    return Column(
      children: [
        GestureDetector(
          onTap: toggle ?? () => setState(() => this.open = !this.open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: GColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GColors.line),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: GColors.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: gText(14, w: FontWeight.w700, c: GColors.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: GColors.chip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${done.length}',
                    style: gText(11.5, w: FontWeight.w700, c: GColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: GColors.grey,
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 16),
          for (final o in done) ...[
            GOrderCard(o, onTrack: widget.onTrack),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }
}

class GSlotCard extends StatelessWidget {
  final GSlot slot;
  final VoidCallback onChange;
  const GSlotCard({super.key, required this.slot, required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      color: GColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GColors.line),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              slot.slot == 'Lunch'
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_outlined,
              size: 16,
              color: GColors.saffron,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${slot.slot} • ${slot.time}',
                style: gText(11.5, w: FontWeight.w700, c: GColors.grey),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: GColors.saffronTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Pending',
                style: gText(11, w: FontWeight.w700, c: GColors.saffron),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final b in slot.bhajis.take(2))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: slot.imageFor(b) == null
                      ? Container(
                          width: 48,
                          height: 48,
                          color: GColors.chip,
                          child: Icon(
                            Icons.restaurant,
                            size: 20,
                            color: GColors.grey,
                          ),
                        )
                      : Image.asset(
                          slot.imageFor(b)!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.bhajis.join(' + '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: gText(14, w: FontWeight.w700, c: GColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    slot.custom ? 'Your pick' : 'Default bhajis',
                    style: gText(
                      11,
                      w: FontWeight.w600,
                      c: slot.custom ? GColors.saffron : GColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: GColors.line),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                slot.locked ? 'Locked, kitchen is preparing' : slot.cutoff,
                style: gText(11, c: GColors.grey, height: 1.35),
              ),
            ),
            const SizedBox(width: 8),
            if (slot.locked)
              Icon(Icons.lock_outline, size: 18, color: GColors.grey)
            else
              Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: onChange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GColors.ink, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 15, color: GColors.ink),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Change bhajis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: gText(
                              12,
                              w: FontWeight.w700,
                              c: GColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _PickSheet extends StatefulWidget {
  final GSlot slot;
  final List<GBhajiOption> options;
  const _PickSheet({required this.slot, required this.options});
  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  late final List<String> sel = [...widget.slot.bhajis];
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: GColors.cream,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose bhajis for ${widget.slot.slot}',
            style: gText(18, w: FontWeight.w800, c: GColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.slot.day} • ${widget.slot.time} • pick exactly 2',
            style: gText(12, c: GColors.grey),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in widget.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (sel.contains(e.name)) {
                            sel.remove(e.name);
                          } else if (sel.length < 2) {
                            sel.add(e.name);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel.contains(e.name)
                                  ? GColors.saffron
                                  : GColors.line,
                              width: sel.contains(e.name) ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: e.image == null
                                    ? Container(
                                        width: 40,
                                        height: 40,
                                        color: GColors.chip,
                                        child: Icon(
                                          Icons.restaurant,
                                          size: 18,
                                          color: GColors.grey,
                                        ),
                                      )
                                    : Image.asset(
                                        e.image!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.name,
                                  style: gText(
                                    13.5,
                                    w: FontWeight.w700,
                                    c: GColors.ink,
                                  ),
                                ),
                              ),
                              Icon(
                                sel.contains(e.name)
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: sel.contains(e.name)
                                    ? GColors.saffron
                                    : GColors.grey,
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GButton(
            sel.length == 2 ? 'Save' : 'Pick ${2 - sel.length} more',
            onPressed: sel.length == 2
                ? () => Navigator.pop(context, [...sel])
                : null,
          ),
          const SizedBox(height: 6),
          if (widget.slot.defaultBhajis.length == 2)
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pop(context, [...widget.slot.defaultBhajis]),
                child: Text(
                  'Use default bhajis',
                  style: gText(13, w: FontWeight.w700, c: GColors.grey),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
