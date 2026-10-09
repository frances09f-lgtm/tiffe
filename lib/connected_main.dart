import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'ui/app.dart';
import 'live/backend.dart';
import 'live/live_app.dart';

/// Connected build: never falls back to demo auth/orders when offline.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  Widget build(BuildContext context) => backend != null
      ? LiveGate(store: widget.store, backend: backend)
      : Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Logo(size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Tiffe could not connect. No order has been placed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : retry,
                    child: Text(busy ? 'Connecting...' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
}
