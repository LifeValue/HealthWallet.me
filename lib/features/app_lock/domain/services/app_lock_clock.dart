import 'package:injectable/injectable.dart';

/// Wall clock for the app lock, injected so tests can move time forward.
@injectable
class AppLockClock {
  const AppLockClock();

  DateTime now() => DateTime.now();
}
