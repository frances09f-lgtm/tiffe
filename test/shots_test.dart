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
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
  await t.pumpAndSettle();
  final boundary = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/shots/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}


void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final f in {'Inter': ['Inter-400','Inter-600','Inter-700'], 'PlusJakartaSans': ['Jakarta-400','Jakarta-600','Jakarta-700'], 'TiffeSans': ['Roboto-Regular','Roboto-Bold']}.entries) {
      final l = FontLoader(f.key);
      for (final n in f.value) { l.addFont(rootBundle.load('assets/fonts/$n.ttf')); }
      await l.load();
    }
    Directory('/tmp/shots').createSync(recursive: true);
  });
  testWidgets('shots', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = TiffeStore(await SharedPreferences.getInstance());
    t.view.physicalSize = const Size(390, 1900);
    t.view.devicePixelRatio = 1;
    final b = ContentBackend();
    await t.pumpWidget(RepaintBoundary(child: TiffeApp(store: s, startScreen: LiveWorkspace(backend: b, store: s))));
    await capture(t, 'home');
    for (final e in {'Menu': 'menu', 'Orders': 'orders', 'Plan': 'plan', 'Profile': 'profile'}.entries) {
      await t.tap(find.text(e.key).last);
      await t.pumpAndSettle();
      await capture(t, e.value);
    }
    await t.tap(find.text('Plan').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Subscribe to Daily Tiffe →'));
    await t.pumpAndSettle();
    await capture(t, 'review');
    await t.pumpWidget(const SizedBox());
  });
}
