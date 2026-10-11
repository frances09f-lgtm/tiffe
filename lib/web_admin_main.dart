import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'live/backend.dart';
import 'live/live_app.dart';
import 'ui/app.dart';
import 'web_admin/admin_site.dart';

/// Admin website entry. Staff sign in with the existing staff login; only an
/// account with a staff role reaches the dashboard.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TiffeStore(await SharedPreferences.getInstance());
  final client = await BackendConfig.initialize();
  runApp(
    TiffeApp(
      store: store,
      startScreen: client == null
          ? const Scaffold(body: Center(child: Text('Unable to connect.')))
          : AdminGate(backend: TiffeBackend(client)),
    ),
  );
}

class AdminGate extends StatelessWidget {
  final TiffeBackend backend;
  const AdminGate({super.key, required this.backend});
  @override
  Widget build(BuildContext c) => StreamBuilder(
    stream: backend.authChanges,
    builder: (c, _) {
      if (backend.userId == null) {
        return SignIn(backend: backend, admin: true, showIntro: false);
      }
      return FutureBuilder<String?>(
        future: backend.role(),
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (s.data != 'owner') {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This site is for the Tiffe owner.'),
                    TextButton(
                      onPressed: backend.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          }
          return AdminSite(backend: backend);
        },
      );
    },
  );
}
