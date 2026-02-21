import 'dart:async';

import 'package:my_app/prism/models/health_consent.dart';
import 'package:my_app/prism/models/health_summary.dart';
import 'package:my_app/prism/repositories/health_repository_wiring.dart';
import 'package:my_app/prism/services/health_consent_service.dart';
import 'package:my_app/prism/services/health_service.dart';

class HealthPreviewProvider {
  static final HealthPreviewProvider instance = HealthPreviewProvider._();
  final HealthConsentService _consent = HealthConsentService();
  late final AppHealthRepository _repo;

  HealthPreviewProvider._() {
    _repo = AppHealthRepository.create(
      healthService: HealthService(),
      consentService: _consent,
      pollInterval: const Duration(minutes: 15),
    );
  }

  Future<void> setConsent(HealthConsent consent) => _consent.set(consent);

  Future<HealthSummary?> getTodaySummary() async {
    final now = DateTime.now();
    return _repo.fetchDailySummary(day: DateTime(now.year, now.month, now.day));
  }

  Stream<HealthSummary> watchToday() => _repo.watchToday();
}


