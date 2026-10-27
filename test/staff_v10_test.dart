import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffe/staff/partner_hub.dart';
import 'package:tiffe/staff/staff_update.dart';

import 'admin_controls_test.dart' show OwnerBackend;
import 'staff_kitchen_v9_test.dart' show istToday, order;

/// Staff 1.0.10: light mode, labelled Sync/Updates, readable handover, accept
/// step (Order placed -> Confirmed) and Remove bhaji.
class HubBackend extends OwnerBackend {
  HubBackend(this.rows, {this.menuRows = const []});
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> menuRows;
  String? accepted;
  String? archived;
  Object? archiveError;
  @override
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) =>
      Stream.value(rows);
  @override
  Stream<List<Map<String, dynamic>>> menu() => Stream.value(menuRows);
  @override
  Future<Map<String, dynamic>?> currentSettings() async => {
    'kitchen_auto_accept': false,
  };
  @override
  Future<List<Map<String, dynamic>>> deliveryStaff() async => [
    {'user_id': 'rider-1', 'name': 'Vijay'},
  ];
  @override
  Future<List<Map<String, dynamic>>> orderItems(List<String> ids) async => [
    {'order_id': 'ord-0001', 'item_name': 'Batata Bhaji'},
    {'order_id': 'ord-0002', 'item_name': 'Aloo Gobi'},
    {'order_id': 'ord-0003', 'item_name': 'Paneer Masala'},
  ];
  @override
  Future<void> acceptOrder(String id) async => accepted = id;
  @override
  Future<void> archiveMenuItem(String id) async {
    if (archiveError != null) throw archiveError!;
    archived = id;
  }
}

Map<String, dynamic> placed(String id) =>
    order(id, istToday, 'Confirmed')..['awaiting_acceptance'] = true;

List<Map<String, dynamic>> sampleOrders() => [
  placed('ord-0001'),
  // Legacy row (before the migration): no awaiting_acceptance value.
  order('ord-0002', istToday, 'Confirmed'),
  order('ord-0003', istToday, 'Preparing'),
  // Ready, payment verified, no rider: assign on the card.
  order('ord-0004', istToday, 'Packed'),
  // Ready, payment not verified: the one step that lives in All Orders.
  order('ord-0005', istToday, 'Packed', payment: 'unpaid'),
  order('ord-0006', istToday, 'Packed', rider: 'rider-1'),
];

const menuSample = [
  {
    'id': 'm-1',
    'name': 'Batata Bhaji',
    'description': 'Potato, mustard seeds',
    'available': true,
    'archived_at': null,
  },
  {
    'id': 'm-2',
    'name': 'Bhindi Fry',
    'description': 'Okra',
    'available': false,
  },
  {
    'id': 'm-3',
    'name': 'Old Bhaji',
    'description': 'Removed earlier',
    'available': false,
    'archived_at': '2026-10-20T10:00:00Z',
  },
];

Future<void> loadFonts() async {
  for (final (family, files) in [
    (
      'PlusJakartaSans',
      ['Jakarta-400.ttf', 'Jakarta-600.ttf', 'Jakarta-700.ttf'],
    ),
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']),
  ]) {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await l.load();
  }
}

Future<void> shot(WidgetTester t, String name) async {
  final dir = Platform.environment['TIFFE_SHOTS'];
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('app')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(data!.buffer.asUint8List());
  });
}

Widget app(HubBackend b, {String role = 'owner'}) => RepaintBoundary(
  key: const Key('app'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PartnerHub(backend: b, role: role),
  ),
);

/// WCAG relative-luminance contrast ratio.
double contrast(Color a, Color b) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double l(Color c) => 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  final x = l(a), y = l(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Color textColor(WidgetTester t, Finder f) {
  final rich = t.widget<RichText>(
    find.descendant(of: f, matching: find.byType(RichText)).first,
  );
  return rich.text.style!.color!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    staffDark.value = true;
  });
  tearDown(() => staffDark.value = true);

  Future<void> pumpHub(
    WidgetTester t,
    HubBackend b, {
    String role = 'owner',
  }) async {
    await loadFonts();
    t.view.physicalSize = const Size(390, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(app(b, role: role));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('sun/moon switch repaints the whole hub and is remembered', (
    t,
  ) async {
    await pumpHub(t, HubBackend(sampleOrders()));
    final title = find.text('LIVE KITCHEN PREPARATION SUMMARY (PUNE BATCHES)');
    expect(textColor(t, title), const Color(0xFFF4F4F5));
    await shot(t, 'staff-kitchen-dark');

    await t.tap(find.byTooltip('Switch to light mode'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    // The kitchen hub is built outside the theme builder; it must still
    // switch to dark ink, not keep the dark-mode white text.
    expect(textColor(t, title), const Color(0xFF18181B));
    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    // Metric numbers were hard-coded white (invisible on the light card).
    for (final v in find.text('3').evaluate()) {
      final c = (v.widget as Text).style?.color;
      if (c != null) expect(c, isNot(Colors.white));
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('staff_dark_mode'), isFalse);
    await shot(t, 'staff-kitchen-light');

    // Back to dark: dark mode stays available.
    await t.tap(find.byTooltip('Switch to dark mode'));
    await t.pump();
    expect(textColor(t, title), const Color(0xFFF4F4F5));
    expect(prefs.getBool('staff_dark_mode'), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Sync and Updates are labelled, bright and readable in both themes',
    (t) async {
      for (final dark in [false, true]) {
        SharedPreferences.setMockInitialValues({'staff_dark_mode': dark});
        staffDark.value = dark;
        await pumpHub(t, HubBackend(sampleOrders()));
        final bg = dark ? const Color(0xFF262626) : const Color(0xFFFFFFFF);
        for (final label in ['Sync', 'Updates']) {
          final f = find.widgetWithText(OutlinedButton, label);
          expect(f, findsOneWidget, reason: '$label button');
          final c = textColor(t, find.text(label));
          expect(contrast(c, bg), greaterThan(7), reason: '$label dark=$dark');
        }
        await t.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('Updates button: checking state, up-to-date and error feedback', (
    t,
  ) async {
    staffDark.value = false;
    await loadFonts();
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final gate = Completer<String>();
    var body = '';
    final checker = StaffUpdateChecker(
      fetchText: (_) => gate.isCompleted ? Future.value(body) : gate.future,
      currentVersion: () async => '1.0.10',
    );
    Widget hub() => RepaintBoundary(
      key: const Key('app'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenHub(
              d: AdminData(
                orders: sampleOrders(),
                subs: const [],
                customers: const [],
                menu: const [],
                riders: const [],
                today: istToday,
              ),
              b: HubBackend(const []),
              items: const [],
              onSync: () async {},
              updateChecker: checker,
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(hub());
    await t.pump();
    await t.tap(find.text('Updates'));
    await t.pump();
    // While the feed is being read the button says so and cannot be re-tapped.
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text('Checking for updates...'), findsOneWidget);
    body = '{"tiffe_staff":{"version":"1.0.10","notes":"n","apk":"https://example.com/a.apk"}}';
    gate.complete(body);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('You have the latest version (1.0.10).'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    await shot(t, 'staff-updates-latest');

    // A newer version opens the in-app update dialog (download + installer).
    body = '{"tiffe_staff":{"version":"1.0.11","notes":"Faster kitchen view.","apk":"https://example.com/a.apk"}}';
    await t.tap(find.text('Updates'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('1.0.11'), findsWidgets);
    expect(find.textContaining('Faster kitchen view.'), findsOneWidget);
    await shot(t, 'staff-updates-dialog-light');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Updates button reports a failed check plainly', (t) async {
    final checker = StaffUpdateChecker(
      fetchText: (_) async => throw const SocketException('offline'),
      currentVersion: () async => '1.0.10',
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenHub(
              d: AdminData(
                orders: const [],
                subs: const [],
                customers: const [],
                menu: const [],
                riders: const [],
                today: istToday,
              ),
              b: HubBackend(const []),
              items: const [],
              onSync: () async {},
              updateChecker: checker,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Updates'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Could not check for updates. Try again in a minute.'),
      findsOneWidget,
    );
  });

  testWidgets('disabled Confirm Handover text stays readable in both themes', (
    t,
  ) async {
    for (final dark in [false, true]) {
      SharedPreferences.setMockInitialValues({'staff_dark_mode': dark});
      staffDark.value = dark;
      await pumpHub(t, HubBackend(sampleOrders()));
      await shot(t, 'staff-handover-${dark ? 'dark' : 'light'}');
      final buttons = find.widgetWithText(FilledButton, 'Confirm Handover');
      expect(buttons, findsNWidgets(3));
      final disabled = t.widget<FilledButton>(buttons.first);
      expect(disabled.onPressed, isNull);
      final style = disabled.style!;
      final fg = style.foregroundColor!.resolve({WidgetState.disabled})!;
      final bg = style.backgroundColor!.resolve({WidgetState.disabled})!;
      expect(fg.a, 1.0, reason: 'no faded disabled text');
      expect(contrast(fg, bg), greaterThan(7), reason: 'dark=$dark');
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('handover hints point to the card, not All Orders, for riders', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'staff_dark_mode': false});
    staffDark.value = false;
    await pumpHub(t, HubBackend(sampleOrders()));
    expect(
      find.text('Assign a delivery partner above to enable Confirm Handover.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Verify payment in All Orders, then assign a delivery partner on this card.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('assign a rider in All Orders'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  test('handoverHint covers every case', () {
    Map<String, dynamic> o({String pay = 'verified', String? rider}) => {
      'payment_status': pay,
      'assigned_to': rider,
    };
    expect(handoverHint(o(rider: 'r'), role: 'owner', hasRiders: true), isNull);
    expect(
      handoverHint(o(), role: 'owner', hasRiders: true),
      'Assign a delivery partner above to enable Confirm Handover.',
    );
    expect(
      handoverHint(o(), role: 'owner', hasRiders: false),
      contains('Delivery Fleet'),
    );
    expect(
      handoverHint(
        o(pay: 'unpaid', rider: 'r'),
        role: 'owner',
        hasRiders: true,
      ),
      'Verify payment in All Orders to enable Confirm Handover.',
    );
    // Kitchen staff cannot open All Orders, so they are never sent there.
    final kitchen = handoverHint(
      o(pay: 'unpaid'),
      role: 'kitchen',
      hasRiders: true,
    )!;
    expect(kitchen, isNot(contains('All Orders')));
  });

  test('order placed vs confirmed works with old and new database rows', () {
    expect(awaitingAcceptance({'status': 'Confirmed'}), isFalse);
    expect(
      awaitingAcceptance({'status': 'Confirmed', 'awaiting_acceptance': null}),
      isFalse,
    );
    expect(
      awaitingAcceptance({'status': 'Confirmed', 'awaiting_acceptance': false}),
      isFalse,
    );
    expect(
      awaitingAcceptance({'status': 'Confirmed', 'awaiting_acceptance': true}),
      isTrue,
    );
    expect(awaitingAcceptance({'status': 'Placed'}), isTrue);
    // Once preparing, the flag no longer matters.
    expect(
      awaitingAcceptance({'status': 'Preparing', 'awaiting_acceptance': true}),
      isFalse,
    );
    expect(staffStatusLabel({'status': 'Placed'}), 'Order placed');
    expect(staffStatusLabel({'status': 'Preparing'}), 'Preparing');
  });

  testWidgets(
    'kitchen accepts a placed order; legacy confirmed starts preparing',
    (t) async {
      SharedPreferences.setMockInitialValues({'staff_dark_mode': false});
      staffDark.value = false;
      final b = HubBackend(sampleOrders());
      await pumpHub(t, b);
      expect(find.text('ORDER PLACED · NOT ACCEPTED'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Accept Order'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Start Preparing'),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(FilledButton, 'Accept Order'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Accept order?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Accept'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(b.accepted, 'ord-0001');
      // Legacy confirmed order: the old one-tap move to Preparing.
      await t.tap(find.widgetWithText(FilledButton, 'Start Preparing'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(b.advancedTo, 'Preparing');
      await t.pumpWidget(const SizedBox());
    },
  );

  test('accept and remove errors are plain before the database update', () {
    expect(
      acceptErrorText(
        Exception('PGRST202 Could not find the function public.accept_order'),
      ),
      contains('database update (tiffe-v56)'),
    );
    expect(
      removeBhajiErrorText(
        Exception("PGRST204 Could not find the 'archived_at' column"),
      ),
      contains('database update (tiffe-v56)'),
    );
    expect(removeBhajiErrorText(Exception('timeout')), contains('connection'));
  });

  testWidgets('All Orders shows Order placed with an Accept order action', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'staff_dark_mode': false});
    staffDark.value = false;
    final b = HubBackend(sampleOrders());
    await pumpHub(t, b);
    await t.ensureVisible(find.text('All Orders').first);
    await t.tap(find.text('All Orders').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Accept order'), findsOneWidget);
    await shot(t, 'staff-all-orders-light');
    await t.tap(find.widgetWithText(FilledButton, 'Accept order'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await t.pumpAndSettle();
    expect(b.accepted, 'ord-0001');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Remove bhaji: separate from the switch, confirmed, archived', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'staff_dark_mode': false});
    staffDark.value = false;
    final b = HubBackend(sampleOrders(), menuRows: menuSample);
    await pumpHub(t, b);
    await t.ensureVisible(find.text('Menu & Item Status').first);
    await t.tap(find.text('Menu & Item Status').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    // Archived bhaji is gone from the menu; the others keep their switch.
    expect(find.text('Old Bhaji'), findsNothing);
    expect(find.text('Batata Bhaji'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    await shot(t, 'staff-menu-remove-light');
    await t.tap(find.byKey(const Key('remove-bhaji-m-2')));
    await t.pumpAndSettle();
    expect(find.text('Remove Bhindi Fry?'), findsOneWidget);
    await shot(t, 'staff-menu-remove-confirm-light');
    // Cancel changes nothing.
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(b.archived, isNull);
    await t.tap(find.byKey(const Key('remove-bhaji-m-2')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Remove'));
    await t.pumpAndSettle();
    expect(b.archived, 'm-2');
    expect(find.text('Bhindi Fry removed from the menu.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
