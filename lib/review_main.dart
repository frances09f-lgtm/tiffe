import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'ui/app.dart';
import 'live/backend.dart';
import 'live/live_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TiffeStore(await SharedPreferences.getInstance());
  final client = await BackendConfig.initialize();
  runApp(
    TiffeApp(
      store: store,
      startScreen: LiveGate(
        store: store,
        backend: client == null ? null : TiffeBackend(client),
        admin: true,
      ),
    ),
  );
}
