import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../ui/gemini/auth_screens.dart';
import '../ui/gemini/toast.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bug_report.dart';

/// Public, key-free update check. Asks GitHub for the newest Tiffe release
/// tag (v plus build number) and compares it with this app's build number.
const latestReleaseApi =
    'https://api.github.com/repos/frances09f-lgtm/tiffe/releases/latest';

/// Opens the tester's Firebase App Distribution page for Tiffe.
const updatePage =
    'https://appdistribution.firebase.google.com/testerapps/1:509368336413:android:281dab933ae0c01e0a46f4';

int get currentBuild => int.tryParse(appVersion.split('+').last) ?? 0;

/// Returns the newer build number, or null when up to date / unknown.
typedef FetchLatest = Future<int?> Function();

Future<int?> fetchLatestBuild() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client
        .getUrl(Uri.parse(latestReleaseApi))
        .timeout(const Duration(seconds: 8));
    req.headers.set('Accept', 'application/vnd.github+json');
    req.headers.set('User-Agent', 'com.ambi.tiffe');
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map;
    final tag = json['tag_name'] as String?;
    UpdateCheck.latestNote = _firstNote(json['body'] as String?);
    final m = RegExp(r'^v(\d+)$').firstMatch(tag ?? '');
    return m == null ? null : int.parse(m.group(1)!);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// First readable line of the release notes, without markdown marks.
String? _firstNote(String? body) {
  for (final raw in (body ?? '').split('\n')) {
    final l = raw
        .replaceAll(RegExp(r'[#*`>_]'), '')
        .replaceFirst(RegExp(r'^\s*-\s*'), '')
        .trim();
    if (l.isNotEmpty) return l.length > 160 ? '${l.substring(0, 157)}...' : l;
  }
  return null;
}

class UpdateCheck {
  static const knownKey = 'update_known_build';

  /// Newer build known to exist, or null. Drives the Home banner.
  static final ValueNotifier<int?> available = ValueNotifier<int?>(null);
  static String? latestNote;

  /// Restores the banner from the last check so it stays until updated.
  static void restore(SharedPreferences prefs) {
    final known = prefs.getInt(knownKey) ?? 0;
    available.value = known > currentBuild ? known : null;
  }

  static const snoozeKey = 'update_snooze';
  static const checkedKey = 'update_checked_at';
  static const every = Duration(hours: 6);
  static const snooze = Duration(hours: 12);
  static Future<void> Function(Uri) opener = (u) async {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  };

  /// Shows "New version available" at most once per 6 hours, and not again
  /// for 12 hours after the user taps Later.
  static Future<void> run(
    BuildContext context,
    SharedPreferences prefs, {
    FetchLatest fetch = fetchLatestBuild,
    bool manual = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(checkedKey) ?? 0;
    final snoozed = prefs.getInt(snoozeKey) ?? 0;
    // Automatic checks respect the 6h gap and the Later snooze; the Check
    // for updates button always asks and always answers.
    if (!manual && (now - last < every.inMilliseconds || now < snoozed)) return;
    await prefs.setInt(checkedKey, now);
    final latest = await fetch();
    if (latest != null) {
      await prefs.setInt(knownKey, latest);
      available.value = latest > currentBuild ? latest : null;
    }
    if (!context.mounted) return;
    if (latest == null || latest <= currentBuild) {
      if (manual) {
        gToast(
          context,
          latest == null
              ? 'Could not check for updates. Please try again later.'
              : 'You are up to date (v$currentBuild).',
        );
      }
      return;
    }
    final note = latestNote;
    final update = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'New version available',
          style: gText(18, w: FontWeight.w800, c: GColors.green),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiffe v$latest is ready.',
              style: gText(14, w: FontWeight.w600, c: GColors.charcoal),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note, style: gText(13, c: GColors.grey, height: 1.4)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(
              'Later',
              style: gText(14, w: FontWeight.w700, c: GColors.grey),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GColors.saffron,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              'Update',
              style: gText(14, w: FontWeight.w700, c: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (update == true) {
      await opener(Uri.parse(updatePage));
    } else {
      await prefs.setInt(snoozeKey, now + snooze.inMilliseconds);
    }
  }
}
