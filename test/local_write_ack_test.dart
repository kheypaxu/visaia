import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/local_write_ack.dart';

void main() {
  test(
    'offline local confirmation finishes without a server acknowledgement',
    () async {
      final events = StreamController<bool>();
      final remote = Completer<void>();
      var acknowledged = false;
      final saved = waitForLocalWrite(
        pendingWrites: events.stream,
        write: () => remote.future,
        onAcknowledged: () => acknowledged = true,
        onLateError: (_) => fail('Unexpected rejection'),
      );
      events.add(false); // An initial cached read is not a saved write.
      events.add(true);
      await saved;
      expect(acknowledged, isFalse);
      remote.complete();
      await Future<void>.delayed(Duration.zero);
      expect(acknowledged, isTrue);
      await events.close();
    },
  );

  test(
    'online acknowledgement works even without a local snapshot event',
    () async {
      var acknowledged = false;
      await waitForLocalWrite(
        pendingWrites: const Stream<bool>.empty(),
        write: () async {},
        onAcknowledged: () => acknowledged = true,
        onLateError: (_) => fail('Unexpected rejection'),
      );
      expect(acknowledged, isTrue);
    },
  );

  test('immediate server rejection reaches the saving screen', () async {
    await expectLater(
      waitForLocalWrite(
        pendingWrites: const Stream<bool>.empty(),
        write: () => Future<void>.error(StateError('permission-denied')),
        onAcknowledged: () {},
        onLateError: (_) => fail('Should reject the save directly'),
      ),
      throwsStateError,
    );
  });

  test('a rejection after local confirmation is still reported', () async {
    final events = StreamController<bool>();
    final remote = Completer<void>();
    Object? reported;
    final saved = waitForLocalWrite(
      pendingWrites: events.stream,
      write: () => remote.future,
      onAcknowledged: () {},
      onLateError: (error) => reported = error,
    );
    events.add(true);
    await saved;
    remote.completeError(StateError('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(reported, isStateError);
    await events.close();
  });

  test('synchronous write errors propagate', () async {
    await expectLater(
      waitForLocalWrite(
        pendingWrites: const Stream<bool>.empty(),
        write: () => throw StateError('invalid payload'),
        onAcknowledged: () {},
        onLateError: (_) => fail('Unexpected late rejection'),
      ),
      throwsStateError,
    );
  });
}
