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

import 'live_ui_test.dart' show capture;

class OrderBackend extends TiffeBackend {
  OrderBackend()
    : super(
        SupabaseClient(
          'https://example.invalid',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  String? placedDate;
  List<List<String>>? placedTiffins;
  String? placedKey;
  @override
  String? get userId => '00000000-0000-0000-0000-000000000001';
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value([
    {'id': 'aaaaaaaa-0000-4000-8000-000000000001', 'name': 'Batata Bhaji', 'description': '', 'available': true, 'sort_order': 1},
    {'id': 'aaaaaaaa-0000-4000-8000-000000000002', 'name': 'Matki Usal', 'description': '', 'available': true, 'sort_order': 2},
    {'id': 'aaaaaaaa-0000-4000-8000-000000000003', 'name': 'Vatana', 'description': '', 'available': true, 'sort_order': 3},
  ]);
  @override
  Future<Map<String, dynamic>?> currentSettings() async => {
    'id': true,
    'one_time_price_paise': 8000,
    'one_time_delivery_paise': 2000,
    'extra_bhaji_paise': 1000,
    'cutoff_time': '09:00:00',
    'delivery_time': '20:00:00',
    'areas': ['Kothrud', 'Baner'],
  };
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value([]);
  @override
  Stream<List<Map<String, dynamic>>> subscriptions() => Stream.value([]);
  @override
  Future<Map<String, dynamic>?> profile() async => {
    'name': 'Test',
    'phone': '9999999999',
    'address': '1 Road',
    'area': 'Kothrud',
  };
  @override
  Future<String> placeOrder({
    required String date,
    required List<List<String>> tiffins,
    required String idempotencyKey,
    String instructions = '',
    String? subscriptionId,
  }) async {
    placedDate = date;
    placedTiffins = tiffins;
    placedKey = idempotencyKey;
    return 'order-1';
  }
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
  testWidgets('customer order flow validates and places with idempotency key', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = TiffeStore(await SharedPreferences.getInstance());
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    final b = OrderBackend();
    await t.pumpWidget(
      RepaintBoundary(
        child: TiffeApp(store: s, startScreen: LiveWorkspace(backend: b, store: s)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Order a tiffin'), findsOneWidget);
    await t.tap(find.text('Order a tiffin'));
    await t.pumpAndSettle();
    expect(find.text('Place order'), findsOneWidget);
    // Underfilled tiffin is rejected before any network call.
    await t.tap(find.widgetWithText(FilterChip, 'Batata Bhaji'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Place order'));
    await t.tap(find.text('Place order'));
    await t.pumpAndSettle();
    expect(find.text('Pick 2 to 8 bhajis for each tiffin.'), findsOneWidget);
    expect(b.placedKey, isNull);
    // Two bhajis: total ₹100, one call, one idempotency key.
    await t.tap(find.widgetWithText(FilterChip, 'Matki Usal'));
    await t.pumpAndSettle();
    expect(find.textContaining('Total: ₹100'), findsOneWidget);
    await capture(t, 'order-sheet-two-bhajis');
    await t.ensureVisible(find.text('Place order'));
    await t.tap(find.text('Place order'));
    await t.pumpAndSettle();
    expect(b.placedKey, isNotNull);
    expect(b.placedTiffins!.single, hasLength(2));
    expect(b.placedDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(find.text('Order placed - the kitchen has it.'), findsOneWidget);
    // Three bhajis would price the third at +₹10: reopen and check preview.
    await t.tap(find.text('Menu').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Order a tiffin'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilterChip, 'Batata Bhaji'));
    await t.tap(find.widgetWithText(FilterChip, 'Matki Usal'));
    await t.tap(find.widgetWithText(FilterChip, 'Vatana'));
    await t.pumpAndSettle();
    expect(find.textContaining('Total: ₹110'), findsOneWidget);
  });
}
