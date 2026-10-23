import 'dart:async';

/// Completes on a local mutation event or a server acknowledgement. A late
/// server rejection is reported separately, after the caller has navigated away.
Future<void> waitForLocalWrite({
  required Stream<bool> pendingWrites,
  required Future<void> Function() write,
  required void Function() onAcknowledged,
  required void Function(Object error) onLateError,
}) async {
  final result = Completer<void>();
  final subscription = pendingWrites.listen((pending) {
    if (pending && !result.isCompleted) result.complete();
  }, onError: (Object _) {});
  try {
    unawaited(
      write().then(
        (_) {
          onAcknowledged();
          if (!result.isCompleted) result.complete();
        },
        onError: (Object error, StackTrace stack) {
          onAcknowledged();
          if (!result.isCompleted) {
            result.completeError(error, stack);
          } else {
            onLateError(error);
          }
        },
      ),
    );
    await result.future;
  } finally {
    await subscription.cancel();
  }
}
