import 'dart:async';
import 'dart:io';
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

class EmptyBackend extends TiffeBackend {
  EmptyBackend()
    : super(
        SupabaseClient(
          'https://example.invalid',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  String? get userId => '00000000-0000-0000-0000-000000000001';
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value([]);
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value([]);
  @override
  Stream<List<Map<String, dynamic>>> subscriptions() => Stream.value([]);
  @override
  Future<Map<String, dynamic>?> profile() async => {
    'name': 'Test customer',
    'phone': '9999999999',
    'area': 'Baner',
    'address': 'Test address',
  };
}

Future<void> capture(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  final b = t.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await t.runAsync(() async {
    final image = await b.toImage(pixelRatio: 2);
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
    final font = FontLoader('TiffeSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('live scaffold has true empty states and login', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = TiffeStore(await SharedPreferences.getInstance())
      ..darkMode = true;
    t.view.physicalSize = const Size(430, 932);
    t.view.devicePixelRatio = 1;
    final b = EmptyBackend();
    await t.pumpWidget(
      RepaintBoundary(
        child: TiffeApp(
          store: s,
          startScreen: SignIn(backend: b),
        ),
      ),
    );
    await capture(t, 'live-customer-signin');
    await t.tap(find.text('New to Tiffe? Create account'));
    await t.pumpAndSettle();
    await capture(t, 'live-create-account');
    await t.pumpWidget(
      RepaintBoundary(
        child: TiffeApp(
          store: s,
          startScreen: LiveWorkspace(backend: b, store: s),
        ),
      ),
    );
    await capture(t, 'live-menu-empty');
    await t.tap(find.text('Orders').last);
    await t.pumpAndSettle();
    expect(find.textContaining('No orders yet'), findsOneWidget);
    expect(find.text('Delivered'), findsNothing);
    await capture(t, 'live-orders-empty');
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await t.tap(find.text('My Tiffin Subscription'));
    await t.pumpAndSettle();
    await t.pumpAndSettle();
    expect(find.text('No active subscription'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    await capture(t, 'live-plan-empty');
    await t.pumpWidget(
      RepaintBoundary(
        child: TiffeApp(
          store: s,
          startScreen: SignIn(backend: b, admin: true),
        ),
      ),
    );
    await capture(t, 'live-admin-signin');
    await t.pumpWidget(const SizedBox());
  });
}
