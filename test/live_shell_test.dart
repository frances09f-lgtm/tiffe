import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/live/live_app.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/ui/gemini/home_screen.dart';

import 'live_content_test.dart' show ContentBackend;

Future<void> shot(WidgetTester t, String name) async {
  final b = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await t.runAsync(() async {
    final im = await b.toImage(pixelRatio: 1);
    final d = await im.toByteData(format: ui.ImageByteFormat.png);
    Directory('/tmp/lshots').createSync(recursive: true);
    await File('/tmp/lshots/$name.png').writeAsBytes(d!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final f in {
      'Inter': ['Inter-400', 'Inter-600', 'Inter-700'],
      'PlusJakartaSans': ['Jakarta-400', 'Jakarta-600', 'Jakarta-700'],
    }.entries) {
      final l = FontLoader(f.key);
      for (final n in f.value) {
        l.addFont(rootBundle.load('assets/fonts/$n.ttf'));
      }
      await l.load();
    }
  });

  for (final w in [390.0, 320.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('customer shell has no overflow at ${w}px x$scale', (
        t,
      ) async {
        t.view.physicalSize = Size(w, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = TiffeStore(await SharedPreferences.getInstance());
        await t.pumpWidget(
          RepaintBoundary(
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(w, 800),
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
          ),
        );
        await t.runAsync(() async {
          final ctx = t.element(find.byType(LiveWorkspace));
          for (final f in Directory(
            'assets/food',
          ).listSync().whereType<File>()) {
            await precacheImage(AssetImage(f.path), ctx);
          }
        });
        await t.pumpAndSettle();
        await shot(t, 'home_${w.toInt()}_$scale');
        expect(find.text('Pause Tomorrow'), findsNothing);
        for (final tab in ['Menu', 'Orders', 'Profile']) {
          await t.tap(
            find.descendant(
              of: find.byType(GBottomNav),
              matching: find.text(tab),
            ),
          );
          await t.pumpAndSettle();
          if (tab == 'Menu') {
            await t.tap(find.text('Batata Bhaji'));
            await t.tap(find.text('Matki Usal'));
            await t.ensureVisible(find.text('Vatana'));
            await t.pumpAndSettle();
            await t.tap(find.text('Vatana'));
            await t.pumpAndSettle();
            expect(find.textContaining('3 selected + 1 extra'), findsOneWidget);
            expect(find.text('+₹10 for extras'), findsOneWidget);
          }
          await shot(t, '${tab.toLowerCase()}_${w.toInt()}_$scale');
          if (tab == 'Profile') {
            await t.tap(find.text('Help & Support'));
            await t.pumpAndSettle();
            expect(find.text('Check for updates'), findsOneWidget);
            expect(find.text('Report a problem'), findsOneWidget);
            await shot(t, 'help_${w.toInt()}_$scale');
          }
        }
        expect(t.takeException(), isNull);
      });
    }
  }

  for (final w in [390.0, 320.0]) {
    testWidgets('intro and email login render at ${w}px x1.3', (t) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = TiffeStore(await SharedPreferences.getInstance());
      await t.pumpWidget(
        RepaintBoundary(
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(w, 800),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: TiffeApp(
              store: store,
              startScreen: SignIn(backend: ContentBackend(), showIntro: true),
            ),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      await shot(t, 'splash_${w.toInt()}');
      await t.tap(find.byType(FilledButton).first);
      await t.pumpAndSettle();
      await shot(t, 'onboard_${w.toInt()}');
      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();
      await shot(t, 'login_${w.toInt()}');
      expect(find.text('Sign in'), findsOneWidget);
      await t.tap(find.text('New to Tiffe? Create account'));
      await t.pumpAndSettle();
      expect(find.text('Create account'), findsWidgets);
      await shot(t, 'register_${w.toInt()}');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('home and orders with a plan and orders at 320px x1.3', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    String d(int k) {
      final x = now.add(Duration(days: k));
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }

    final b = DataBackend()
      ..orderRows = [
        for (final e in [
          ['11111111-aaaa', d(0), 'Out for Delivery', 2],
          ['22222222-bbbb', d(-1), 'Delivered', 1],
        ])
          {
            'id': e[0],
            'delivery_date': e[1],
            'quantity': e[3],
            'status': e[2],
            'total_paise': 12000,
            'payment_status': 'verified',
            'eta_at': null,
            'created_at': '2026-10-10T09:42:00Z',
            'subscription_id': null,
          },
      ];
    await t.pumpWidget(
      RepaintBoundary(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: TiffeApp(
            store: store,
            startScreen: LiveWorkspace(backend: b, store: store),
          ),
        ),
      ),
    );
    await t.runAsync(() async {
      final ctx = t.element(find.byType(LiveWorkspace));
      for (final f in Directory('assets/food').listSync().whereType<File>()) {
        await precacheImage(AssetImage(f.path), ctx);
      }
    });
    await t.pumpAndSettle();
    await shot(t, 'home_data');
    expect(find.text('Double Tiffe'), findsOneWidget);
    expect(find.text('Out for Delivery'), findsWidgets);
    await t.tap(
      find.descendant(
        of: find.byType(GBottomNav),
        matching: find.text('Orders'),
      ),
    );
    await t.pumpAndSettle();
    await shot(t, 'orders_data');
    await t.tap(find.text('Track Details').first);
    await t.pumpAndSettle();
    await shot(t, 'track_data');
    expect(t.takeException(), isNull);
  });

  testWidgets('sub pages and order sheet render', (t) async {
    t.view.physicalSize = const Size(360, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    await t.pumpWidget(
      RepaintBoundary(
        child: TiffeApp(
          store: store,
          startScreen: LiveWorkspace(backend: DataBackend(), store: store),
        ),
      ),
    );
    await t.runAsync(() async {
      final ctx = t.element(find.byType(LiveWorkspace));
      for (final f in Directory('assets/food').listSync().whereType<File>()) {
        await precacheImage(AssetImage(f.path), ctx);
      }
    });
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(GBottomNav),
        matching: find.text('Profile'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Edit Profile'));
    await t.pumpAndSettle();
    await shot(t, 'edit_profile');
    await t.tap(find.byIcon(Icons.arrow_back).first);
    await t.pumpAndSettle();
    await t.tap(find.text('My Tiffin Subscription'));
    await t.pumpAndSettle();
    await shot(t, 'sub_page');
    await t.tap(find.byIcon(Icons.arrow_back).first);
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(of: find.byType(GBottomNav), matching: find.text('Menu')),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Batata Bhaji'));
    await t.tap(find.text('Matki Usal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Order'));
    await t.pumpAndSettle();
    await shot(t, 'order_sheet');
    expect(t.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('tracking page contrast dark=$dark', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = TiffeStore(await SharedPreferences.getInstance())
        ..darkMode = dark;
      final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30),
      );
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final b = DataBackend()
        ..orderRows = [
          {
            'id': 'cccccccc-1',
            'delivery_date': day,
            'quantity': 1,
            'status': 'Out for Delivery',
            'total_paise': 10000,
            'payment_status': 'verified',
            'eta_at': null,
            'subscription_id': null,
          },
        ];
      await t.pumpWidget(
        RepaintBoundary(
          child: TiffeApp(
            store: store,
            startScreen: LiveWorkspace(backend: b, store: store),
          ),
        ),
      );
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
      await shot(t, 'track_${dark ? 'dark' : 'light'}');
      await t.tap(find.text('Live Map Tracking'));
      await t.pumpAndSettle();
      expect(find.text('Live Delivery Tracking'), findsOneWidget);
      expect(find.text('Arriving'), findsNothing);
      expect(find.textContaining('(preview)'), findsNothing);
      expect(find.textContaining('simulated preview'), findsWidgets);
      await shot(t, 'live_${dark ? 'dark' : 'light'}');
      await t.tap(find.byIcon(Icons.arrow_back).first);
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.arrow_back).first);
      await t.pumpAndSettle();
      final nav = t.element(find.byType(LiveWorkspace));
      gToast(nav, 'Profile updated successfully!');
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await shot(t, 'toast_${dark ? 'dark' : 'light'}');
      expect(t.takeException(), isNull);
    });
  }
}

class DataBackend extends ContentBackend {
  @override
  Future<List<Map<String, dynamic>>> orderItems(List<String> ids) async => [
    for (final id in ids) ...[
      {'order_id': id, 'tiffin': 1, 'item_name': 'Batata Bhaji'},
      {'order_id': id, 'tiffin': 1, 'item_name': 'Matki Usal'},
    ],
  ];
  @override
  Stream<List<Map<String, dynamic>>> subscriptions() => Stream.value([
    {
      'id': 'sub-1',
      'customer_id': 'fixture-customer',
      'plan': 'double',
      'starts_on': '2020-01-01',
      'ends_on': '2099-01-31',
      'verified': true,
    },
  ]);
}
