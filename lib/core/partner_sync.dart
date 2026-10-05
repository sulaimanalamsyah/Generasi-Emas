import 'package:flutter/foundation.dart';

/// Lightweight notifier to synchronize partner status across tabs and widgets
/// without full app rebuilds or heavy state management boilerplate.
class PartnerSync {
  PartnerSync._();

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// Trigger a sync event so that any active or keep-alive pages reload partner status.
  static void notify() {
    notifier.value++;
  }
}
