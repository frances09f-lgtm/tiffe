import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TiffeStore(await SharedPreferences.getInstance());
  runApp(TiffeApp(store: store));
}
