import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'admin_controls_test.dart' show OwnerBackend;
import 'staff_kitchen_v9_test.dart' show dataWith, istToday, order;

void main() {
  testWidgets('Staff hub light mode: dark ink, persisted toggle', (t) async {
    SharedPreferences.setMockInitialValues({});
    staffDark.value = true;
    addTearDown(() => staffDark.value = true);

    Widget harness() => ValueListenableBuilder<bool>(
      valueListenable: staffDark,
      builder:
          (context, dark, _) => MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: KitchenHub(
                  d: dataWith([order('ord-0001', istToday, 'Packed')]),
                  b: OwnerBackend(),
                  role: 'owner',
                  items: const [],
                  onSync: () async {},
                ),
              ),
            ),
          ),
    );

    Text title() => t.widget<Text>(
      find.text('LIVE KITCHEN PREPARATION SUMMARY (PUNE BATCHES)'),
    );

    await t.pumpWidget(harness());
    await t.pumpAndSettle();
    // Dark theme (default): light ink.
    expect(title().style?.color, const Color(0xFFF4F4F5));

    await setStaffDark(false);
    await t.pumpAndSettle();
    // Light theme: dark ink on the light surfaces.
    expect(title().style?.color, const Color(0xFF18181B));

    // The choice survives a restart.
    staffDark.value = true;
    await loadStaffTheme();
    expect(staffDark.value, isFalse);
  });
}
