import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/domain/tiffin.dart';

void main() {
  test('two included and all extra counts correct', () {
    for (var i = 0; i <= 8; i++) {
      expect(Pricing.extras(i), i > 2 ? (i - 2) * 10 : 0);
    }
  });
  test('plan prices and quantities', () {
    expect(Pricing.monthly(Plan.daily), 1500);
    expect(Pricing.monthly(Plan.double), 3000);
    expect(Pricing.quantity(Plan.double), 2);
    expect(Pricing.oneTime, 80);
    expect(Pricing.delivery, 199);
  });
  test('Sunday sweet only active subscribers', () {
    final sunday = DateTime(2026, 10, 11);
    expect(sunday.weekday, DateTime.sunday);
    expect(Pricing.sweet(sunday, Plan.daily), true);
    expect(Pricing.sweet(sunday, Plan.double), true);
    expect(Pricing.sweet(sunday, Plan.none), false);
    expect(Pricing.sweet(sunday, Plan.daily, paused: true), false);
    expect(Pricing.sweet(DateTime(2026, 10, 12), Plan.daily), false);
  });
  test('8 unique daily bhajis', () {
    expect(menu.length, 8);
    expect(menu.map((b) => b.id).toSet().length, 8);
  });
  test('per-tiffin extras cannot offset another tiffin', () {
    expect(Pricing.extras(3) + Pricing.extras(1), 10);
  });
  test('date keys do not mix deliveries', () {
    expect(Pricing.dateKey(DateTime(2026, 10, 9)), '2026-10-09');
    expect(Pricing.dateKey(DateTime(2026, 10, 10)), '2026-10-10');
  });
}
