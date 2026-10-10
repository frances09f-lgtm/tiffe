import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';

import 'live_content_test.dart';

void main() {
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('calendar cells do not overflow at ${width}px x$scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = TiffeStore(await SharedPreferences.getInstance());
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1800),
              textScaler: TextScaler.linear(scale),
            ),
            child: TiffeApp(
              store: store,
              startScreen: LiveWorkspace(
                backend: ContentBackend(),
                store: store,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Orders').last);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
}
