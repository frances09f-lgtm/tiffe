import 'package:flutter/material.dart';

import 'auth_screens.dart';

/// App-wide message bar: dark green rounded bar floating just above the
/// bottom navigation, orange icon on the left, close X on the right.
void gToast(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  final isError =
      error ||
      RegExp(
        r'^(Could not|Couldn.t|No |Choose|Selection|Enter|Please|Failed|Unable)',
      ).hasMatch(message);
  m.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GColors.green,
      elevation: 2,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: GColors.saffron,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: gText(
                14,
                w: FontWeight.w500,
                c: Colors.white,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: m.hideCurrentSnackBar,
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ],
      ),
    ),
  );
}
