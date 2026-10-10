import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/auth_screens.dart';

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 300));
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
  await t.pump();
  final b = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await t.runAsync(() async {
    final im = await b.toImage(pixelRatio: 2);
    final d = await im.toByteData(format: ui.ImageByteFormat.png);
    Directory('/tmp/gshots').createSync(recursive: true);
    await File('/tmp/gshots/$name.png').writeAsBytes(d!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/Jakarta-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Jakarta-600.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Jakarta-700.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('four screens flow: any 10 digits and any 4 digit code', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: GAuthFlow(home: (_) => const Scaffold(body: Text('HOME'))),
        ),
      ),
    );
    await shot(t, '1_splash');
    expect(find.textContaining('emo'), findsNothing);
    await t.tap(find.text('Get Started'));
    await t.pumpAndSettle();
    await shot(t, '2_onboarding');
    await t.tap(find.text('Continue with Mobile'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '9876543210');
    await t.pump();
    await shot(t, '3_login');
    await t.tap(find.text('Get OTP'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('+91 9876543210', findRichText: true),
      findsOneWidget,
    );
    await t.enterText(find.byType(TextField), '4829');
    await t.pump();
    await shot(t, '4_otp');
    await t.tap(find.text('Verify & Proceed'));
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('short number or code keeps the button disabled', (t) async {
    await t.pumpWidget(MaterialApp(home: GLogin(onOtp: (_) {})));
    await t.enterText(find.byType(TextField), '98765');
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
