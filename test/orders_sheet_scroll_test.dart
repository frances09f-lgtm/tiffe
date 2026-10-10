import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/orders_screen.dart';

void main() {
  testWidgets('pick sheet scrolls and keeps Save visible on a small phone', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 520);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final names = [for (var i = 0; i < 14; i++) 'Bhaji $i'];
    await t.pumpWidget(
      MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: w!,
        ),
        home: GOrders(
          orders: const [],
          slots: [
            GSlot(
              'a',
              'Lunch',
              'Today',
              '1 PM',
              'Change until 12:00 PM today',
              ['Bhaji 0', 'Bhaji 1'],
              defaultBhajis: ['Bhaji 0', 'Bhaji 1'],
            ),
          ],
          bhajiOptions: [for (final n in names) GBhajiOption(n)],
          onChangeSlot: (s, b) async => null,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Change bhajis'));
    await t.pumpAndSettle();
    await t.tap(find.text('Change bhajis'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final save = find.textContaining('Save');
    expect(save, findsOneWidget);
    final r = t.getRect(save);
    expect(r.bottom, lessThanOrEqualTo(520));
    expect(t.getRect(find.text('Bhaji 13')).bottom, greaterThan(save.evaluate().isEmpty ? 0 : r.top));
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -3000));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Bhaji 13')).bottom, lessThanOrEqualTo(t.getRect(find.textContaining('Save')).top));
    expect(
      t.getRect(find.textContaining('Save')).bottom,
      lessThanOrEqualTo(520),
    );
  });

  testWidgets('cancelled orders are not under Completed', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      const MaterialApp(
        home: GOrders(
          orders: [
            GOrder(
              'A',
              'One-Time Order',
              'Delivered',
              'x + y',
              'Yesterday',
              '₹100',
            ),
            GOrder(
              'B',
              'One-Time Order',
              'Cancelled',
              'x + y',
              'Yesterday',
              '₹100',
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled & refunded'), findsOneWidget);
    await t.tap(find.text('Completed'));
    await t.pumpAndSettle();
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('Cancelled'), findsNothing);
    await t.tap(find.text('Cancelled & refunded'));
    await t.pumpAndSettle();
    expect(find.text('Cancelled'), findsWidgets);
  });
}
