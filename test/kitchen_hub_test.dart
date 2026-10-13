import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/web_admin/admin_site.dart';

import 'web_admin_test.dart' show WebBackend, open, today;

void main() {
  test('prep excludes closed and departed, counts actual selected rows', () {
    final d = AdminData(
      orders: [
        {
          'id': '1',
          'delivery_date': today,
          'status': 'Preparing',
          'quantity': 2,
        },
        {
          'id': '2',
          'delivery_date': today,
          'status': 'Cancelled',
          'quantity': 4,
        },
        {
          'id': '3',
          'delivery_date': today,
          'status': 'Out for Delivery',
          'quantity': 1,
        },
      ],
      subs: [],
      customers: [],
      menu: [],
      riders: [],
      today: today,
    );
    final c = KitchenCounts.from(d, [
      {'order_id': '1', 'item_name': 'Matki'},
      {'order_id': '1', 'item_name': 'Matki'},
      {'order_id': '2', 'item_name': 'Matki'},
    ]);
    expect(c.tiffins, 2);
    expect(c.bhajis['Matki'], 2);
  });
  testWidgets(
    'manual kitchen controls require confirmation and use existing statuses',
    (t) async {
      final b = WebBackend();
      await open(t, 1440, backend: b);
      expect(find.text('Live Kitchen'), findsWidgets);
      expect(find.text('Accept Order'), findsOneWidget);
      await t.tap(find.text('Accept Order'));
      await t.pumpAndSettle();
      expect(b.advancedTo, isNull);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(b.advancedTo, isNull);
      await t.tap(find.text('Accept Order'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirm'));
      await t.pumpAndSettle();
      expect(b.advancedTo, 'Preparing');
      expect(find.text('Confirm Handover'), findsOneWidget);
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm Handover'),
      );
      expect(button.onPressed, isNull);
    },
  );
}
