import '../models/vital_metrics.dart';

class HealthConnectBridgeAndroidMock {
  bool enabled = true;

  Future<List<VitalSample>> fetchMock({
    required DateTime from,
    required DateTime to,
  }) async {
    final List<VitalSample> out = [];
    var cursor = from.toUtc();
    while (cursor.isBefore(to)) {
      out.add(VitalSample(metric: 'heart_rate', start: cursor, end: cursor, value: 62));
      out.add(VitalSample(metric: 'steps', start: cursor, end: cursor, value: 120));
      out.add(VitalSample(metric: 'hrv', start: cursor, end: cursor, value: 48));
      cursor = cursor.add(const Duration(hours: 1));
    }
    return out;
  }
}


