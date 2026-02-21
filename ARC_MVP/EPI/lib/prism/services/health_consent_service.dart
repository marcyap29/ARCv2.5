import 'dart:async';

import 'package:my_app/prism/models/health_consent.dart';

class HealthConsentService {
  HealthConsent _consent = HealthConsent.disabled;
  final StreamController<HealthConsent> _controller = StreamController.broadcast();

  HealthConsent get current => _consent;
  Stream<HealthConsent> watch() => _controller.stream;

  Future<void> set(HealthConsent consent) async {
    _consent = consent;
    if (!_controller.isClosed) _controller.add(consent);
  }

  void dispose() {
    _controller.close();
  }
}


