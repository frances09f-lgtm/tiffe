import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'partner_hub_test.dart' as hub;

void main() {
  testWidgets('All Orders transition action has readable orange fill', (
    t,
  ) async {
    await hub.open(t, 390);
    await t.tap(find.text('All Orders'));
    await t.pumpAndSettle();
    final finder = find.ancestor(
      of: find.text('Mark Preparing'),
      matching: find.byType(FilledButton),
    );
    expect(finder, findsOneWidget);
    final button = t.widget<FilledButton>(finder);
    final background = button.style!.backgroundColor!.resolve({})!;
    final foreground = button.style!.foregroundColor!.resolve({})!;
    expect(background, const Color(0xFFFC8019));
    expect(foreground, const Color(0xFF121212));
    final light = background.computeLuminance();
    final dark = foreground.computeLuminance();
    expect((light + 0.05) / (dark + 0.05), greaterThan(4.5));
    expect(t.takeException(), isNull);
  });
}
