import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'ui/app.dart';
import 'live/backend.dart';
import 'staff/staff_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TiffeStore(await SharedPreferences.getInstance());
  final client = await BackendConfig.initialize();
  runApp(
    TiffeApp(
      store: store,
      startScreen: client == null
          ? const Scaffold(
              body: Center(child: Text('Backend configuration required.')),
            )
          : StaffGate(backend: TiffeBackend(client)),
    ),
  );
}
