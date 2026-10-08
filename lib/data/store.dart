import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tiffin.dart';

class TiffeStore extends ChangeNotifier {
  final SharedPreferences prefs;
  String name = '', phone = '', address = '', area = 'Kothrud';
  Plan plan = Plan.none;
  bool onboarded = false;
  final Map<String, List<String>> selections = {};
  List<String> usual = ['batata', 'matki'];
  TiffeStore(this.prefs) {
    try {
      final raw = prefs.getString('tiffe.v1');
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      name = d['name'] ?? '';
      phone = d['phone'] ?? '';
      address = d['address'] ?? '';
      area = d['area'] ?? 'Kothrud';
      onboarded = d['onboarded'] == true;
      plan = Plan.values.firstWhere(
        (p) => p.name == d['plan'],
        orElse: () => Plan.none,
      );
      for (final e
          in (d['selections'] as Map<String, dynamic>? ?? {}).entries) {
        selections[e.key] = List<String>.from(e.value);
      }
      usual = List<String>.from(d['usual'] ?? ['batata', 'matki']);
    } catch (_) {
      /* Corrupt local preview state falls back safely. */
    }
  }
  List<String> selected(DateTime date, int tiffin) =>
      List.of(selections['${Pricing.dateKey(date)}:$tiffin'] ?? []);
  Future<void> saveSelection(
    DateTime date,
    int tiffin,
    List<String> ids,
  ) async {
    selections['${Pricing.dateKey(date)}:$tiffin'] = ids
        .where((id) => menu.any((b) => b.id == id && b.available))
        .toList();
    await save();
  }

  Future<void> save() async {
    await prefs.setString(
      'tiffe.v1',
      jsonEncode({
        'name': name,
        'phone': phone,
        'address': address,
        'area': area,
        'plan': plan.name,
        'onboarded': onboarded,
        'selections': selections,
        'usual': usual,
      }),
    );
    notifyListeners();
  }
}
