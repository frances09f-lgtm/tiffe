import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/connected_main.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/ui/customer_style.dart';
import 'package:tiffe/live/live_app.dart';

import 'live_content_test.dart' show ContentBackend;

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.runAsync(() async {
    final context = t.element(find.byType(Scaffold).first);
    await precacheImage(const AssetImage('assets/food/hero.jpg'), context);
    await precacheImage(
      const AssetImage('assets/brand/tiffe-logo.png'),
      context,
    );
  });
  await t.pump(const Duration(milliseconds: 100));
  final b = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await t.runAsync(() async {
    final image = await b.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('screenshots').create(recursive: true);
    await File('screenshots/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final f in ['Inter', 'PlusJakartaSans']) {
      final p = f == 'Inter' ? 'Inter' : 'Jakarta';
      await (FontLoader(f)
            ..addFont(rootBundle.load('assets/fonts/$p-400.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$p-700.ttf')))
          .load();
    }
    await (FontLoader('TiffeSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('entry visual states and honest offline retry', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    Future<void> show(Widget child) async {
      await t.pumpWidget(
        RepaintBoundary(
          child: TiffeApp(
            store: store,
            startScreen: CustomerStyle(child: child),
          ),
        ),
      );
      await t.pump();
    }

    await show(const CustomerSplash());
    await shot(t, 'v19-splash');
    var continued = false;
    await show(CustomerWelcome(onContinue: () => continued = true));
    await shot(t, 'v19-welcome');
    await t.scrollUntilVisible(
      find.text('Get started'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'v19-welcome-lower');
    await t.ensureVisible(find.text('Get started'));
    await t.pumpAndSettle();
    await t.tap(find.text('Get started'));
    expect(continued, true);
    await show(SignIn(backend: ContentBackend()));
    await shot(t, 'v19-email-login');
    expect(find.text('Mobile number'), findsNothing);
    await t.tap(find.text('New to Tiffe? Create account'));
    await t.pump();
    await shot(t, 'v19-email-registration');
    var retried = false;
    await show(CustomerOffline(busy: false, onRetry: () => retried = true));
    await shot(t, 'v19-offline');
    await t.tap(find.text('Retry'));
    expect(retried, true);
    expect(find.textContaining('arrive on time'), findsNothing);
    await show(
      Scaffold(
        body: OrderSheet(
          backend: ContentBackend(),
          cfg: ContentBackend().fixture['settings'],
          menuRows: (ContentBackend().fixture['menu'] as List)
              .cast<Map<String, dynamic>>(),
          initialBhajis: [
            for (final m in (ContentBackend().fixture['menu'] as List).take(2))
              (m as Map)['id'] as String,
          ],
        ),
      ),
    );
    await shot(t, 'v19-order-review');
    await t.drag(find.byType(ListView), const Offset(0, -550));
    await t.pump();
    await shot(t, 'v19-order-review-bill');
    await t.ensureVisible(find.text('Add a second tiffin'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add a second tiffin'));
    await t.pumpAndSettle();
    // The Menu page opens to pick the second tiffin's bhajis.
    final names = [
      for (final m in (ContentBackend().fixture['menu'] as List).take(2))
        (m as Map)['name'] as String,
    ];
    for (final n in names) {
      await t.tap(find.text(n));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Order'));
    await t.pumpAndSettle();
    expect(find.text('₹180'), findsWidgets);
    expect(find.text('Total Payable'), findsOneWidget);
    expect(find.text('Delivery Charge'), findsOneWidget);
    expect(find.text('₹20'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'connected launch transitions from splash to genuine offline screen',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = TiffeStore(await SharedPreferences.getInstance());
      await t.pumpWidget(
        TiffeApp(
          store: store,
          startScreen: ConnectedStart(store: store, backend: null),
        ),
      );
      expect(find.text('Tiffe'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1100));
      await t.pump();
      expect(find.text('Kitchen signal lost'), findsOneWidget);
      expect(find.textContaining('Place Order'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
}
