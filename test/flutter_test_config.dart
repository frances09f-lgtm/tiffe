import 'dart:async';

import 'package:tiffe/ui/gemini/track_screen.dart';
import 'package:tiffe/ui/tracking_map.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TrackingMap.animateDemo = false;
  GTrack.animate = false;
  await testMain();
}
