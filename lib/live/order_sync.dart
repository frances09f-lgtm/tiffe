import 'dart:async';
import 'dart:convert';

typedef OrderRows = List<Map<String, dynamic>>;

/// Realtime is the fast path; authenticated snapshots recover missed events.
/// One read at a time, with generation guards against stale poll completions.
Stream<OrderRows> syncedOrders({
  required Stream<OrderRows> live,
  required Future<OrderRows> Function() read,
  required Stream<void> refresh,
  required Duration interval,
}) {
  late StreamController<OrderRows> out;
  StreamSubscription<OrderRows>? liveSub;
  StreamSubscription<void>? refreshSub;
  Timer? timer;
  bool cancelled = false, reading = false, queuedRefresh = false;
  bool hadError = false;
  int generation = 0;
  String? last;

  void emit(OrderRows rows) {
    if (cancelled) return;
    final key = jsonEncode(rows);
    if (key == last && !hadError) return;
    last = key;
    hadError = false;
    out.add(rows);
  }

  void report(Object error, StackTrace stack) {
    if (cancelled) return;
    hadError = true;
    out.addError(error, stack);
  }

  Future<void> poll({bool explicit = false}) async {
    if (cancelled) return;
    if (reading) {
      // A manual/foreground refresh deserves a new read after an older read;
      // periodic ticks merely skip, so a slow connection cannot build a queue.
      if (explicit) queuedRefresh = true;
      return;
    }
    reading = true;
    final started = generation;
    try {
      final rows = await read();
      if (!cancelled && started == generation) emit(rows);
    } catch (e, s) {
      if (!cancelled && started == generation) report(e, s);
    } finally {
      reading = false;
      if (queuedRefresh && !cancelled) {
        queuedRefresh = false;
        unawaited(poll());
      }
    }
  }

  out = StreamController<OrderRows>(
    onListen: () {
      liveSub = live.listen((rows) {
        generation++;
        emit(rows);
      }, onError: (Object e, StackTrace s) => report(e, s));
      refreshSub = refresh.listen((_) => unawaited(poll(explicit: true)));
      unawaited(poll());
      timer = Timer.periodic(interval, (_) => unawaited(poll()));
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      timer?.cancel();
      await liveSub?.cancel();
      await refreshSub?.cancel();
    },
  );
  return out.stream;
}
