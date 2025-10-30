import 'dart:async';

import 'package:my_app/prism/models/health_consent.dart';
import 'package:my_app/prism/models/health_summary.dart';
import 'package:my_app/prism/repositories/health_repository.dart';
import 'package:my_app/prism/services/health_consent_service.dart';
import 'package:my_app/prism/services/health_service.dart';

class AppHealthRepository extends HealthRepositoryImpl {
  final HealthService _healthService;
  final HealthConsentService _consentService;
  Timer? _timer;

  AppHealthRepository._internal({
    required HealthService healthService,
    required HealthConsentService consentService,
  })  : _healthService = healthService,
        _consentService = consentService,
        super(
          provider: (_) async => null,
          isAuthorized: () async => false,
          requestAuthorization: (_) async => false,
        ) {
    // Wire the abstract behaviors to concrete implementations
    // ignore: invalid_use_of_visible_for_testing_member
    // Recreate with functional bindings
  }

  static AppHealthRepository create({
    required HealthService healthService,
    required HealthConsentService consentService,
    Duration pollInterval = const Duration(minutes: 15),
  }) {
    final repo = AppHealthRepository._internal(
      healthService: healthService,
      consentService: consentService,
    );

    // Replace provider/auth functions by monkey-patching via closures on the instance
    // This relies on the base class fields being effectively used through methods.
    repo._bind(pollInterval: pollInterval);
    return repo;
  }

  void _bind({required Duration pollInterval}) {
    // Start polling today summary if consent allows
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) async {
      final c = _consentService.current;
      if (!c.readHealth) return;
      final authed = await _healthService.hasPermissions();
      if (!authed) return;
      final today = DateTime.now();
      final summary = await _healthService.fetchDailySummary(
        day: DateTime(today.year, today.month, today.day),
        canShowInChat: c.referenceInChat,
        canShowValues: c.showNumericValues,
      );
      if (summary != null) {
        pushToday(summary);
      }
    });
  }

  // Override abstract methods through composition
  @override
  Future<HealthSummary?> fetchDailySummary({required DateTime day}) async {
    final c = _consentService.current;
    if (!c.readHealth) return null;
    final authed = await _healthService.hasPermissions();
    if (!authed) return null;
    return _healthService.fetchDailySummary(
      day: day,
      canShowInChat: c.referenceInChat,
      canShowValues: c.showNumericValues,
    );
  }

  @override
  Future<bool> isAuthorized() async {
    final c = _consentService.current;
    if (!c.readHealth) return false;
    return _healthService.hasPermissions();
  }

  @override
  Future<bool> requestAuthorization({required HealthScopes scopes}) async {
    // Update consent first
    final current = _consentService.current;
    await _consentService.set(
      current.copyWith(
        readHealth: scopes.readHealth,
        referenceInChat: scopes.referenceInChat,
        showNumericValues: scopes.showNumericValues,
        notifications: scopes.notifications,
        retention: scopes.showNumericValues
            ? HealthRetention.full
            : HealthRetention.trendsOnly,
      ),
    );
    if (!scopes.readHealth) return false;
    return _healthService.requestAuthorization();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}


