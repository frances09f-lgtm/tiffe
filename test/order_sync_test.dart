import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/live/order_sync.dart';

OrderRows rows(String id) => [
  {'id': id},
];

class FeedFixture {
  final live = StreamController<OrderRows>.broadcast(sync: true);
  final refresh = StreamController<void>.broadcast(sync: true);
  final pending = <Completer<OrderRows>>[];
  final received = <OrderRows>[];
  final errors = <Object>[];
  late final StreamSubscription<OrderRows> sub;
  FeedFixture({Duration interval = const Duration(seconds: 5)}) {
    sub = syncedOrders(
      live: live.stream,
      read: () {
        final c = Completer<OrderRows>();
        pending.add(c);
        return c.future;
      },
      refresh: refresh.stream,
      interval: interval,
    ).listen(received.add, onError: errors.add);
  }
  Future<void> close() async {
    await sub.cancel();
    await live.close();
    await refresh.close();
  }
}

void main() {
  testWidgets('initial authenticated snapshot does not depend on realtime', (
    t,
  ) async {
    final f = FeedFixture();
    expect(f.pending.length, 1);
    f.pending[0].complete(rows('placed'));
    await t.pump();
    expect(f.received, [rows('placed')]);
    await t.runAsync(f.close);
  });
  testWidgets(
    'realtime order is emitted without waiting for the poll interval',
    (t) async {
      final f = FeedFixture();
      f.live.add(rows('realtime'));
      await t.pump();
      expect(f.received, [rows('realtime')]);
      await t.runAsync(f.close);
    },
  );
  testWidgets('missing realtime order is recovered on the five second tick', (
    t,
  ) async {
    final f = FeedFixture();
    f.pending[0].complete([]);
    await t.pump();
    await t.pump(const Duration(seconds: 5));
    expect(f.pending.length, 2);
    f.pending[1].complete(rows('new'));
    await t.pump();
    expect(f.received.last, rows('new'));
    await t.runAsync(f.close);
  });
  testWidgets('slow reads never overlap or build a periodic backlog', (
    t,
  ) async {
    final f = FeedFixture();
    await t.pump(const Duration(seconds: 20));
    expect(f.pending.length, 1);
    f.pending[0].complete([]);
    await t.pump();
    expect(f.pending.length, 1);
    await t.pump(const Duration(seconds: 5));
    expect(f.pending.length, 2);
    await t.runAsync(f.close);
  });
  testWidgets('older poll cannot replace a newer realtime snapshot', (t) async {
    final f = FeedFixture();
    f.live.add(rows('new'));
    await t.pump();
    f.pending[0].complete(rows('old'));
    await t.pump();
    expect(f.received, [rows('new')]);
    await t.runAsync(f.close);
  });
  testWidgets('older poll error cannot override recovered realtime data', (
    t,
  ) async {
    final f = FeedFixture();
    f.live.add(rows('new'));
    f.pending[0].completeError(StateError('old error'));
    await t.pump();
    expect(f.errors, isEmpty);
    expect(f.received.last, rows('new'));
    await t.runAsync(f.close);
  });
  testWidgets(
    'explicit refresh is immediate and coalesces behind a slow read',
    (t) async {
      final f = FeedFixture();
      for (var i = 0; i < 5; i++) {
        f.refresh.add(null);
      }
      expect(f.pending.length, 1);
      f.pending[0].complete([]);
      await t.pump();
      expect(f.pending.length, 2);
      f.pending[1].complete(rows('fresh'));
      await t.pump();
      expect(f.received.last, rows('fresh'));
      f.refresh.add(null);
      expect(f.pending.length, 3);
      await t.runAsync(f.close);
    },
  );
  testWidgets(
    'failure is surfaced and identical recovered data clears stale warning',
    (t) async {
      final f = FeedFixture();
      f.pending[0].complete(rows('same'));
      await t.pump();
      f.refresh.add(null);
      f.pending[1].completeError(StateError('offline'));
      await t.pump();
      expect(f.errors.length, 1);
      f.refresh.add(null);
      f.pending[2].complete(rows('same'));
      await t.pump();
      expect(f.received, [rows('same'), rows('same')]);
      await t.runAsync(f.close);
    },
  );
  testWidgets('unchanged healthy snapshots are deduplicated', (t) async {
    final f = FeedFixture();
    f.pending[0].complete(rows('same'));
    await t.pump();
    f.refresh.add(null);
    f.pending[1].complete(rows('same'));
    await t.pump();
    f.live.add(rows('same'));
    await t.pump();
    expect(f.received.length, 1);
    await t.runAsync(f.close);
  });
  testWidgets('polling survives realtime errors and a closed realtime stream', (
    t,
  ) async {
    final f = FeedFixture();
    f.live.addError(StateError('socket failed'));
    await t.runAsync(f.live.close);
    f.pending[0].complete(rows('initial'));
    await t.pump();
    expect(f.errors.length, 1);
    await t.pump(const Duration(seconds: 5));
    f.pending[1].complete(rows('new'));
    await t.pump();
    expect(f.received.last, rows('new'));
    await t.runAsync(f.sub.cancel);
    await t.runAsync(f.refresh.close);
  });
  testWidgets('customer interval can remain fifteen seconds', (t) async {
    final f = FeedFixture(interval: const Duration(seconds: 15));
    f.pending[0].complete([]);
    await t.pump();
    await t.pump(const Duration(seconds: 5));
    expect(f.pending.length, 1);
    await t.pump(const Duration(seconds: 10));
    expect(f.pending.length, 2);
    await t.runAsync(f.close);
  });
  testWidgets('cancel removes timers, subscriptions and late completions', (
    t,
  ) async {
    final f = FeedFixture();
    f.refresh.add(null);
    await t.runAsync(f.sub.cancel);
    expect(f.live.hasListener, false);
    expect(f.refresh.hasListener, false);
    f.pending[0].complete(rows('late'));
    await t.pump(const Duration(seconds: 20));
    expect(f.received, isEmpty);
    expect(f.pending.length, 1);
    await t.runAsync(f.live.close);
    await t.runAsync(f.refresh.close);
  });
}
