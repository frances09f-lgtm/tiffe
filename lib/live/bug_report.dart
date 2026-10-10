import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keep in step with pubspec.yaml (a test checks this).
const appVersion = '1.0.23+23';

/// Removes emails and phone numbers from text before it leaves the phone.
String scrub(String s) => s
    .replaceAll(
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'),
      '[email]',
    )
    .replaceAll(RegExp(r'\+?\d[\d\s\-]{8,}\d'), '[number]');

String _cut(String s, int n) => s.length <= n ? s : s.substring(0, n);

/// Small in-memory ring buffer of recent app events and errors.
class BugLog {
  static final List<String> _lines = [];
  static String screen = 'unknown';
  static const max = 50;

  static void add(String line) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    _lines.add(_cut('$t ${scrub(line)}', 300));
    if (_lines.length > max) _lines.removeAt(0);
  }

  static List<String> get lines => List.unmodifiable(_lines);
  @visibleForTesting
  static void clear() => _lines.clear();

  /// Call once at start-up so Flutter and platform errors land in the log.
  static void install() {
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      add('FlutterError: ${d.exceptionAsString()}');
      old?.call(d);
    };
    final oldPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, s) {
      add('Error: $e');
      return oldPlatform?.call(e, s) ?? false;
    };
  }
}

String newReportId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// A duplicate report_id means the report already arrived.
bool _isDuplicate(Object e) => e is PostgrestException && e.code == '23505';

class BugReports {
  static const queueKey = 'bug_report_queue';

  static Map<String, dynamic> build({
    required String comment,
    String? role,
    String? userId,
  }) => {
    'report_id': newReportId(),
    'app': 'tiffe',
    'app_version': appVersion,
    'device': _cut(
      scrub('${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
      120,
    ),
    'screen': BugLog.screen,
    'role': role,
    'comment': _cut(scrub(comment.trim()), 1000),
    'logs': BugLog.lines.join('\n'),
  };

  /// Sends the report. If it cannot be delivered it is kept on the phone and
  /// retried later. Returns true when delivered now.
  static Future<bool> send(
    SupabaseClient client,
    SharedPreferences prefs,
    Map<String, dynamic> report,
  ) async {
    try {
      try {
        await client.from('bug_reports').insert(report);
      } catch (e) {
        if (!_isDuplicate(e)) rethrow;
      }
      await flush(client, prefs);
      return true;
    } catch (e) {
      BugLog.add('Report not sent: ${e.runtimeType}');
      final q = prefs.getStringList(queueKey) ?? [];
      q.add(jsonEncode(report));
      await prefs.setStringList(
        queueKey,
        q.length > 20 ? q.sublist(q.length - 20) : q,
      );
      return false;
    }
  }

  /// Retries reports saved on the phone. Stops at the first failure.
  static Future<void> flush(
    SupabaseClient client,
    SharedPreferences prefs,
  ) async {
    final q = prefs.getStringList(queueKey) ?? [];
    if (q.isEmpty) return;
    final left = List<String>.from(q);
    for (final item in q) {
      try {
        try {
          await client
              .from('bug_reports')
              .insert(jsonDecode(item) as Map<String, dynamic>);
        } catch (e) {
          if (!_isDuplicate(e)) rethrow;
        }
        left.remove(item);
      } catch (_) {
        break;
      }
    }
    await prefs.setStringList(queueKey, left);
  }
}
