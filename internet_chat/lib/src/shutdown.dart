import 'dart:async';
import 'dart:io';

/// Completes on Ctrl-C (SIGINT) or, outside Windows, on SIGTERM, which is
/// what `docker stop` sends.
Future<void> shutdownSignal() {
  final done = Completer<void>();
  void finish(ProcessSignal _) {
    if (!done.isCompleted) done.complete();
  }

  ProcessSignal.sigint.watch().listen(finish);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(finish);
  }
  return done.future;
}
