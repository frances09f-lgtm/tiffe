import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';

import 'live_content_test.dart';

void main() {
  testWidgets('delivered orders move from active list to history', (t) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    final backend = ContentBackend()
      ..orderRows = [
        {
          'id': 'a',
          'delivery_date': '2026-10-10',
          'quantity': 1,
          'status': 'Preparing',
          'total_paise': 10000,
          'payment_status': 'verified',
          'eta_at': null,
        },
        {
          'id': 'b',
          'delivery_date': '2026-10-09',
          'quantity': 2,
          'status': 'Delivered',
          'total_paise': 20000,
          'payment_status': 'verified',
          'eta_at': null,
        },
      ];
    await t.pumpWidget(
      TiffeApp(
        store: store,
        startScreen: LiveWorkspace(backend: backend, store: store),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Orders').last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Order history'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Order history'), findsOneWidget);
    expect(find.text('2026-10-10'), findsWidgets);
    expect(find.text('2 Tiffins · Delivered'), findsOneWidget);
    // the delivered order has no progress tracker of its own
    expect(find.text('2026-10-09'), findsOneWidget);
  });
}
