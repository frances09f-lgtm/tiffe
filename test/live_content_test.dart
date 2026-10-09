import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/live/backend.dart';
import 'package:tiffe/live/live_app.dart';

class ContentBackend extends TiffeBackend {
  ContentBackend()
    : super(
        SupabaseClient(
          'https://example.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final fixture = jsonDecode(
    File('test/content_fixture.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  @override
  String? get userId => 'fixture-customer';
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value(
    (fixture['menu'] as List).map((r) => Map<String, dynamic>.from(r)).toList(),
  );
  @override
  Future<Map<String, dynamic>?> currentSettings() async =>
      Map<String, dynamic>.from(fixture['settings']);
  List<Map<String, dynamic>> orderRows = [];
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value(orderRows);
  @override
  Stream<List<Map<String, dynamic>>> subscriptions() => Stream.value([]);
  @override
  Future<List<Map<String, dynamic>>> allSubscriptions() async => [];
  @override
  Future<List<Map<String, dynamic>>> customers() async => [];
  @override
  Future<Map<String, dynamic>?> profile() async => {
    'name': 'Abhijeet',
    'phone': '9999999999',
    'address': 'Saved delivery address',
    'area': 'Baner',
  };
}

Future<void> capture(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  final boundary = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('screenshots/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Directory('screenshots').create(recursive: true);
    for (final family in ['Inter', 'PlusJakartaSans']) {
      final prefix = family == 'Inter' ? 'Inter' : 'Jakarta';
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$prefix-400.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$prefix-600.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$prefix-700.ttf')))
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
  testWidgets(
    'customer tracking uses recorded status without map or invented ETA',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = TiffeStore(await SharedPreferences.getInstance());
      final backend = ContentBackend()
        ..orderRows = [
          {
            'id': 'fixture-order',
            'delivery_date': '2026-10-10',
            'quantity': 1,
            'status': 'Out for Delivery',
            'total_paise': 10000,
            'payment_status': 'verified',
            'eta_at': null,
          },
        ];
      await t.pumpWidget(
        RepaintBoundary(
          child: TiffeApp(
            store: store,
            startScreen: LiveWorkspace(backend: backend, store: store),
          ),
        ),
      );
      await t.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/brand/tiffe-logo.png'),
          t.element(find.byType(LiveWorkspace)),
        );
      });
      await t.pumpAndSettle();
      await t.tap(find.byType(NavigationDestination).at(2));
      await capture(t, 'stitch-customer-tracking');
      expect(
        find.text('The kitchen has not shared an arrival time yet.'),
        findsOneWidget,
      );
      expect(find.text('Live GPS Tracking'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final admin in [false, true]) {
    testWidgets(
      'rich ${admin ? 'admin' : 'customer'} content uses real catalogue without fake records',
      (t) async {
        t.view.physicalSize = admin
            ? const Size(1280, 900)
            : const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = TiffeStore(await SharedPreferences.getInstance());
        await t.pumpWidget(
          RepaintBoundary(
            child: TiffeApp(
              store: store,
              startScreen: LiveWorkspace(
                backend: ContentBackend(),
                store: store,
                role: admin ? 'owner' : null,
              ),
            ),
          ),
        );
        await t.runAsync(() async {
          final context = t.element(find.byType(LiveWorkspace));
          for (final file in Directory(
            'assets/food',
          ).listSync().whereType<File>()) {
            await precacheImage(AssetImage(file.path), context);
          }
          await precacheImage(
            const AssetImage('assets/brand/tiffe-logo.png'),
            context,
          );
        });
        await capture(t, admin ? 'stitch-admin-home' : 'stitch-customer-home');
        for (final entry in <String, int>{
          'Menu': 1,
          'Orders': 2,
          admin ? 'Plans' : 'Plan': 3,
          'Profile': 4,
        }.entries) {
          await t.tap(find.byType(NavigationDestination).at(entry.value));
          await t.pumpAndSettle();
          final list = find.byType(ListView).first;
          await t.drag(list, const Offset(0, 2000));
          await t.pumpAndSettle();
          await capture(
            t,
            'stitch-${admin ? 'admin' : 'customer'}-${entry.key.toLowerCase()}',
          );
          if (entry.value == 1) {
            await t.scrollUntilVisible(
              find.text('Aloo Matar'),
              500,
              scrollable: find.byType(Scrollable).first,
            );
            await t.pumpAndSettle();
            expect(find.text('Aloo Matar'), findsOneWidget);
            expect(find.text('Unavailable'), findsOneWidget);
          }
          if (entry.value == 2) {
            expect(
              find.text(admin ? 'No orders to prepare' : 'No orders yet'),
              findsOneWidget,
            );
            expect(find.text('Delivered'), findsNothing);
          }
          if (entry.value == 3) {
            expect(find.text('Daily Tiffe'), findsOneWidget);
            expect(find.text('Double Tiffe'), findsOneWidget);
            expect(find.text('₹1500 / month'), findsOneWidget);
            expect(find.text('₹3000 / month'), findsOneWidget);
          }
          await t.drag(list, const Offset(0, -1500));
          await t.pumpAndSettle();
          await capture(
            t,
            'stitch-${admin ? 'admin' : 'customer'}-${entry.key.toLowerCase()}-lower',
          );
          expect(t.takeException(), isNull);
        }
      },
    );
  }
}
