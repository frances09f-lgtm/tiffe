import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/menu_screen.dart';

void main() {
  testWidgets('an unavailable bhaji is greyed out and cannot be picked', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: GMenu(
          categories: const ['Today’s Menu'],
          items: const [
            [
              GMenuItem('Vatana', 'Peas', '', '', 'assets/food/batata.jpg'),
              GMenuItem(
                'Cabbage Bhaji',
                'Cabbage',
                '',
                '',
                'assets/food/aloo.jpg',
                unavailable: true,
              ),
              GMenuItem('Aloo Bhaji', 'Potato', '', '', 'assets/food/aloo.jpg'),
            ],
          ],
          showWeekly: false,
          maxPick: 8,
          initialSelected: const [1],
        ),
      ),
    );
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
    await t.tap(find.text('Unavailable'));
    await t.pump();
    expect(find.text('0 selected'), findsOneWidget);
    await t.tap(find.text('Select').first);
    await t.pump();
    expect(find.text('1 selected'), findsOneWidget);
  });
}
