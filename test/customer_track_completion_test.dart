import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';

import 'package:tiffe/ui/gemini/home_screen.dart' show GBottomNav;

import 'live_shell_test.dart' show DataBackend;

class TrackBackend extends DataBackend {
  final controller = StreamController<List<Map<String, dynamic>>>();
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      controller.stream;
}

void main() {
  testWidgets(
      'delivery completing on the tracker returns to Orders with a message',
      (t) async {
    t.view.physicalSize = const Size(390, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    final now = DateTime.now().toUtc();
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    Map<String, dynamic> order(String status) => {
          'id': 'aaaaaaaa-1',
          'delivery_date': day,
          'quantity': 1,
          'status': status,
          'total_paise': 10000,
          'payment_status': 'verified',
          'eta_at': null,
          'subscription_id': null,
          'created_at': now.toIso8601String(),
        };
    final b = TrackBackend();
    addTearDown(b.controller.close);
    await store.prefs.setBool('profile_complete_${b.userId}', true);
    await t.pumpWidget(
      TiffeApp(
        store: store,
        startScreen: LiveWorkspace(backend: b, store: store),
      ),
    );
    b.controller.add([order('Preparing')]);
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(GBottomNav),
        matching: find.text('Orders'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Track Details').first);
    await t.pumpAndSettle();
    expect(find.textContaining('Track Details'), findsNothing);

    // The kitchen marks it delivered while the tracker is open.
    b.controller.add([order('Delivered')]);
    await t.pump();
    await t.pump();
    expect(find.textContaining('delivered. Enjoy your meal'), findsOneWidget);
    await t.pumpAndSettle();
    // Tracker popped; Orders tab is showing again with its Track Details row
    // replaced by the delivered history section.
    expect(find.textContaining('Meal being prepared'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
