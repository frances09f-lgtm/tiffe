import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/partner_hub.dart';

import 'partner_hub_test.dart' show WebBackend;

class B extends WebBackend {
  String? saved;
  @override
  Future<void> saveMenu({
    String? id,
    required String name,
    required String description,
    required bool available,
  }) async {
    saved = name;
  }
}

void main() {
  testWidgets('add bhaji validates name and saves through catalog contract', (
    t,
  ) async {
    for (final f in [
      ('PlusJakartaSans', 'Jakarta-400.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(f.$1)
        ..addFont(rootBundle.load('assets/fonts/${f.$2}'));
      await loader.load();
    }
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    final b = B();
    await t.pumpWidget(
      MaterialApp(
        builder: (c, child) =>
            RepaintBoundary(key: const Key('shot'), child: child!),
        home: PartnerHub(backend: b, role: 'owner'),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-240, 0),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Menu & Item Status'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add Bhaji'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add to catalog'));
    await t.pumpAndSettle();
    expect(find.text('Enter a bhaji name.'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Aloo Jeera');
    await t.enterText(find.byType(TextField).last, 'Potatoes with cumin');
    await t.pumpAndSettle();
    await t.tap(find.text('Add to catalog'));
    await t.pumpAndSettle();
    expect(b.saved, 'Aloo Jeera');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
