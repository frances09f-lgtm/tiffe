import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/ui/gemini/auth_screens.dart' show GColors;
import 'package:tiffe/ui/gemini/track_screen.dart';
import 'package:tiffe/ui/tracking_map.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TrackingMap.animateDemo = false;
  GTrack.animate = false;
  setUp(() => GColors.dark = false);
  await testMain();
}
