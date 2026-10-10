import 'dart:async';

import 'package:tiffe/ui/tracking_map.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TrackingMap.animateDemo = false;
  await testMain();
}
