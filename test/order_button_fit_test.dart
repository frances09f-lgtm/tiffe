import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'partner_hub_test.dart' as hub;

void main() {
  testWidgets('All Orders Verify payment label stays on one line', (t) async {
    await hub.open(t, 390);
    await t.ensureVisible(find.text('All Orders'));
    await t.tap(find.text('All Orders'));
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(390, 3000);
    await t.pumpAndSettle();
    final finder = find.text('Verify payment');
    expect(finder, findsWidgets);
    final text = t.widget<Text>(finder.first);
    expect(text.maxLines, 1);
    expect(text.softWrap, false);
    final style = DefaultTextStyle.of(t.element(finder.first)).style;
    final fontSize = text.style?.fontSize ?? style.fontSize ?? 14;
    expect(t.getSize(finder.first).height, lessThan(fontSize * 2));
    expect(t.takeException(), isNull);
  });
}
