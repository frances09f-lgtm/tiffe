import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffe/data/store.dart';
import 'package:tiffe/ui/app.dart';
import 'package:tiffe/live/backend.dart';
import 'package:tiffe/live/live_app.dart';

class OwnerBackend extends TiffeBackend {
  OwnerBackend()
    : super(
        SupabaseClient(
          'https://example.invalid',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  String? verifiedOrder;
  String? assignedOrder;
  String? assignedRider;
  String? advancedTo;
  DateTime? advancedEta;
  @override
  String? get userId => 'owner-1';
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value([]);
  @override
  Future<Map<String, dynamic>?> currentSettings() async => null;
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value([
        {
          'id': 'order-1',
          'delivery_date': '2026-10-10',
          'quantity': 1,
          'status': 'Packed',
          'total_paise': 10000,
          'payment_status': 'unpaid',
          'assigned_to': null,
          'eta_at': null,
        },
      ]);
  @override
  Future<Map<String, dynamic>?> profile() async => null;
  @override
  Future<void> verifyPayment(String orderId) async => verifiedOrder = orderId;
  @override
  Future<List<Map<String, dynamic>>> deliveryStaff() async => [
    {'user_id': 'rider-0000-1111'},
  ];
  @override
  Future<void> assignRider(String orderId, String riderId) async {
    assignedOrder = orderId;
    assignedRider = riderId;
  }
  @override
  Future<void> advance(String id, String status, {DateTime? eta}) async {
    advancedTo = status;
    advancedEta = eta;
  }
  @override
  Future<List<Map<String, dynamic>>> allSubscriptions() async => subs;
  @override
  Future<List<Map<String, dynamic>>> customers() async => [
    {'id': 'cust-1', 'name': 'Asha', 'phone': '9898989898', 'area': 'Baner'},
  ];
  @override
  Future<void> saveSubscription({
    required String customerId,
    required String plan,
    required String startsOn,
    required String endsOn,
    required bool verified,
  }) async {
    savedSub = {
      'customer_id': customerId,
      'plan': plan,
      'starts_on': startsOn,
      'ends_on': endsOn,
      'verified': verified,
    };
    subs.add(savedSub!);
  }
  List<Map<String, dynamic>> subs = [];
  Map<String, dynamic>? savedSub;
}

void main() {
  testWidgets('owner can verify payment, assign rider, dispatch with ETA', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = TiffeStore(await SharedPreferences.getInstance());
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    final b = OwnerBackend();
    await t.pumpWidget(
      TiffeApp(
        store: s,
        startScreen: LiveWorkspace(backend: b, store: s, role: 'owner'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Orders').last);
    await t.pumpAndSettle();
    expect(find.text('Verify payment'), findsOneWidget);
    expect(find.text('Assign rider'), findsOneWidget);
    expect(find.text('Dispatch needs verified payment and a rider.'), findsOneWidget);

    await t.tap(find.text('Verify payment'));
    await t.pumpAndSettle();
    expect(find.textContaining('Rs 100.0 was received'), findsOneWidget);
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(b.verifiedOrder, 'order-1');

    await t.tap(find.text('Assign rider'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rider rider-00'));
    await t.pumpAndSettle();
    await t.tap(find.text('Assign'));
    await t.pumpAndSettle();
    expect(b.assignedOrder, 'order-1');
    expect(b.assignedRider, 'rider-0000-1111');

    // Owner dispatch offers an ETA field.
    await t.tap(find.text('Mark Out for Delivery'));
    await t.pumpAndSettle();
    expect(find.text('Arrives in (minutes, optional)'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '25');
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    expect(b.advancedTo, 'Out for Delivery');
    expect(b.advancedEta, isNotNull);
  });

  testWidgets('owner adds a verified subscription for a customer', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = TiffeStore(await SharedPreferences.getInstance());
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    final b = OwnerBackend();
    await t.pumpWidget(
      TiffeApp(
        store: s,
        startScreen: LiveWorkspace(backend: b, store: s, role: 'owner'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Plans').last);
    await t.pumpAndSettle();
    expect(find.text('No subscriptions yet'), findsOneWidget);
    await t.tap(find.text('Add subscription'));
    await t.pumpAndSettle();
    await t.tap(find.text('Customer'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Asha').last);
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Starts on (YYYY-MM-DD)'),
      '2026-10-10',
    );
    await t.enterText(
      find.widgetWithText(TextField, 'Ends on (YYYY-MM-DD)'),
      '2026-11-09',
    );
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(b.savedSub, isNotNull);
    expect(b.savedSub!['plan'], 'daily');
    expect(b.savedSub!['verified'], true);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.textContaining('2026-10-10 to 2026-11-09'), findsOneWidget);
    expect(find.text('Payment verified'), findsOneWidget);
  });
}
