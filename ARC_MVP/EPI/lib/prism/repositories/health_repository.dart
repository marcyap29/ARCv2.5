import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_app/prism/models/health_summary.dart';

class HealthScopes {
  final bool readHealth;
  final bool referenceInChat;
  final bool showNumericValues;
  final bool notifications;

  const HealthScopes({
    required this.readHealth,
    required this.referenceInChat,
    required this.showNumericValues,
    required this.notifications,
  });
}

abstract class HealthRepository {
  Future<HealthSummary?> fetchDailySummary({required DateTime day});
  Stream<HealthSummary> watchToday();
  Future<bool> isAuthorized();
  Future<bool> requestAuthorization({required HealthScopes scopes});
}

typedef HealthSummaryProvider = Future<HealthSummary?> Function(DateTime day);

class HealthRepositoryImpl implements HealthRepository {
  final HealthSummaryProvider _provider;
  final StreamController<HealthSummary> _controller = StreamController.broadcast();
  final Future<bool> Function(HealthScopes) _authRequest;
  final Future<bool> Function() _authCheck;

  HealthRepositoryImpl({
    required HealthSummaryProvider provider,
    required Future<bool> Function() isAuthorized,
    required Future<bool> Function(HealthScopes) requestAuthorization,
  })  : _provider = provider,
        _authCheck = isAuthorized,
        _authRequest = requestAuthorization;

  @override
  Future<HealthSummary?> fetchDailySummary({required DateTime day}) => _provider(day);

  @override
  Stream<HealthSummary> watchToday() => _controller.stream;

  void pushToday(HealthSummary summary) {
    if (!_controller.isClosed) _controller.add(summary);
  }

  @override
  Future<bool> isAuthorized() => _authCheck();

  @override
  Future<bool> requestAuthorization({required HealthScopes scopes}) => _authRequest(scopes);

  @mustCallSuper
  void dispose() {
    _controller.close();
  }
}


