import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keep in step with pubspec.yaml (a test checks this).
const appVersion = '1.0.38+38';

/// Removes emails and phone numbers from text before it leaves the phone.
String scrub(String s) => s
    .replaceAll(
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'),
      '[email]',
    )
    .replaceAll(RegExp(r'\+?\d[\d\s\-]{8,}\d'), '[number]');

String _cut(String s, int n) => s.length <= n ? s : s.substring(0, n);

/// Only the type name of an error is logged, never its message, so tokens,
/// URLs, addresses and order content cannot leak. Unknown types become 'Other'.
const _knownErrors = {
  'FormatException',
  'StateError',
  'ArgumentError',
  'RangeError',
  'TypeError',
  'NoSuchMethodError',
  'AssertionError',
  'TimeoutException',
  'SocketException',
  'HttpException',
  'HandshakeException',
  'PostgrestException',
  'AuthException',
  'AuthApiException',
  'ClientException',
  'FileSystemException',
  'PlatformException',
  'MissingPluginException',
  'UnsupportedError',
  'UnimplementedError',
  'ConcurrentModificationError',
  'OutOfMemoryError',
};
String errorKind(Object e) {
  final t = e.runtimeType.toString();
  return _knownErrors.contains(t) ? t : 'Other';
}

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
      add('FlutterError: ${errorKind(d.exception)}');
      old?.call(d);
    };
    final oldPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, s) {
      add('Error: ${errorKind(e)}');
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

  static const maxQueue = 20;
  static const maxAge = Duration(days: 7);
  static const timeout = Duration(seconds: 10);

  static Future<void> _insert(
    SupabaseClient client,
    Map<String, dynamic> report,
  ) async {
    try {
      await client.from('bug_reports').insert(report).timeout(timeout);
    } catch (e) {
      if (!_isDuplicate(e)) rethrow;
    }
  }

  static List<Map<String, dynamic>> _load(SharedPreferences prefs) {
    final out = <Map<String, dynamic>>[];
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    for (final raw in prefs.getStringList(queueKey) ?? <String>[]) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        if ((m['t'] as int) >= cutoff) out.add(m); // expired items are dropped
      } catch (_) {}
    }
    return out;
  }

  static Future<void> _save(
    SharedPreferences prefs,
    List<Map<String, dynamic>> q,
  ) => prefs.setStringList(queueKey, q.map(jsonEncode).toList());

  /// Delivers the report. If offline it is kept on the phone for up to 7 days
  /// (max 20). When that list is full the new report is NOT stored and the
  /// result says so; older reports are never silently dropped.
  static Future<ReportResult> send(
    SupabaseClient client,
    SharedPreferences prefs,
    Map<String, dynamic> report,
  ) async {
    try {
      await _insert(client, report);
      await flush(client, prefs);
      return ReportResult.sent;
    } catch (e) {
      BugLog.add('Report not sent: ${errorKind(e)}');
      final q = _load(prefs);
      if (q.length >= maxQueue) return ReportResult.full;
      q.add({'t': DateTime.now().millisecondsSinceEpoch, 'r': report});
      await _save(prefs, q);
      return ReportResult.queued;
    }
  }

  /// Retries reports saved on the phone, oldest first. Stops at the first
  /// failure. Called when the app opens and before each new report.
  static Future<void> flush(
    SupabaseClient client,
    SharedPreferences prefs,
  ) async {
    final q = _load(prefs);
    if (q.isEmpty) {
      await _save(prefs, q);
      return;
    }
    final left = List<Map<String, dynamic>>.from(q);
    for (final item in q) {
      try {
        await _insert(client, Map<String, dynamic>.from(item['r'] as Map));
        left.remove(item);
      } catch (_) {
        break;
      }
    }
    await _save(prefs, left);
  }
}

enum ReportResult { sent, queued, full }
