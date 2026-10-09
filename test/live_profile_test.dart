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

class FakeBackend extends TiffeBackend {
  FakeBackend()
    : super(
        SupabaseClient(
          'https://example.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  Map<String, dynamic>? row;
  bool fail = false;
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value([]);
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value([]);
  @override
  Stream<List<Map<String, dynamic>>> subscriptions() => Stream.value([]);
  @override
  Future<Map<String, dynamic>?> currentSettings() async => {
    'areas': ['Kothrud', 'Baner'],
  };
  @override
  Future<Map<String, dynamic>?> profile() async {
    if (fail) throw Exception('offline');
    return row;
  }

  @override
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String address,
    required String area,
  }) async {
    row = {'name': name, 'phone': phone, 'address': address, 'area': area};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Directory('screenshots').create(recursive: true);
    await (FontLoader('TiffeSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('missing and partial profiles need onboarding', () {
    expect(isCompleteProfile(null), false);
    expect(isCompleteProfile({'name': 'A'}), false);
    expect(
      isCompleteProfile({
        'name': 'A',
        'phone': '9999999999',
        'address': 'Test',
        'area': 'Baner',
      }),
      true,
    );
  });
  testWidgets('new customer sees profile first, saves and reaches home', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    final backend = FakeBackend();
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: TiffeApp(
          store: store,
          startScreen: LiveWorkspace(backend: backend, store: store),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('test-artifacts').create(recursive: true);
      await File('test-artifacts/tiffe-v16-onboarding.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    await t.enterText(find.byType(TextField).at(0), 'Test customer');
    await t.enterText(find.byType(TextField).at(1), '9999999999');
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Baner').last);
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField).at(2),
      'Test building, test street',
    );
    t.testTextInput.hide();
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Save & continue'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Save & continue'));
    await t.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    await t.tap(find.text('Profile'));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('test-artifacts').create(recursive: true);
      await File('test-artifacts/tiffe-v16-profile.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    expect(t.takeException(), isNull);
  });
  testWidgets('profile read error shows retry instead of endless loading', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = TiffeStore(await SharedPreferences.getInstance());
    await t.pumpWidget(
      TiffeApp(
        store: store,
        startScreen: LiveWorkspace(
          backend: FakeBackend()..fail = true,
          store: store,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
