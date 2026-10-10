import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/track_screen.dart';

void main() {
  testWidgets('Call button only with a real phone, fits 320px x1.3', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var called = 0;
    Widget app(VoidCallback? cb) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: GLive(
          headline: 'Arriving by 1:00 PM',
          detail: 'Your order is out for delivery.',
          map: const SizedBox(height: 40),
          onCall: cb,
        ),
      ),
    );
    await t.pumpWidget(app(null));
    expect(find.text('Call Delivery Partner'), findsNothing);
    await t.pumpWidget(app(() => called++));
    await t.tap(find.text('Call Delivery Partner'));
    expect(called, 1);
    expect(t.takeException(), isNull);
  });
}
