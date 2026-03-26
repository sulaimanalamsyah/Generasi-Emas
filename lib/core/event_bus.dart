import 'dart:async';

class EventBus {
  EventBus._();
  static final EventBus I = EventBus._();

  // ----- CHANNEL: refresh badge pasien -----
  final _patientsRefreshCtl = StreamController<void>.broadcast();

  void triggerPatientsRefresh() => _patientsRefreshCtl.add(null);

  StreamSubscription onPatientsRefresh(void Function() fn) =>
      _patientsRefreshCtl.stream.listen((_) => fn());
}
