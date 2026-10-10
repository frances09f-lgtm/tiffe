import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'ui/app.dart';
import 'ui/customer_style.dart';

import 'dart:async';

import 'live/backend.dart';
import 'live/bug_report.dart';
import 'live/live_app.dart';

/// Connected build: never falls back to demo auth/orders when offline.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BugLog.install();
  final store = TiffeStore(await SharedPreferences.getInstance());
  TiffeBackend? backend;
  try {
    final client = await BackendConfig.initialize();
    if (client != null) backend = TiffeBackend(client);
  } catch (_) {
    // The retry screen below retains local preferences but makes no success claim.
  }
  runApp(
    TiffeApp(
      store: store,
      startScreen: ConnectedStart(store: store, backend: backend),
    ),
  );
}

class ConnectedStart extends StatefulWidget {
  final TiffeStore store;
  final TiffeBackend? backend;
  const ConnectedStart({super.key, required this.store, this.backend});
  @override
  State<ConnectedStart> createState() => _ConnectedStartState();
}

class _ConnectedStartState extends State<ConnectedStart> {
  late TiffeBackend? backend = widget.backend;
  bool busy = false;
  bool starting = true;
  bool welcome = false;
  Timer? splashTimer;
  @override
  void initState() {
    super.initState();
    welcome =
        widget.backend?.userId == null &&
        widget.store.prefs.getBool('tiffe.connected.welcomeSeen') != true;
    splashTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => starting = false);
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    super.dispose();
  }

  Future<void> continueToLogin() async {
    await widget.store.prefs.setBool('tiffe.connected.welcomeSeen', true);
    if (mounted) setState(() => welcome = false);
  }

  Future<void> retry() async {
    setState(() => busy = true);
    try {
      final client = await BackendConfig.initialize();
      if (mounted && client != null) {
        setState(() => backend = TiffeBackend(client));
      }
    } catch (_) {}
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => CustomerStyle(
    child: starting
        ? const CustomerSplash()
        : backend == null
        ? CustomerOffline(busy: busy, onRetry: retry)
        : welcome && backend?.userId == null
        ? CustomerWelcome(onContinue: continueToLogin)
        : LiveGate(store: widget.store, backend: backend),
  );
}
