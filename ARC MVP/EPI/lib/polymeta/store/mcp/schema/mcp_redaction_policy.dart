class McpRedactionPolicy {
  final String timestampPrecision; // 'full' | 'date_only'
  final bool quantizeVitals; // bucket vitals
  const McpRedactionPolicy({this.timestampPrecision = 'full', this.quantizeVitals = false});

  DateTime clampTimestamp(DateTime t) {
    if (timestampPrecision == 'date_only') {
      return DateTime.utc(t.year, t.month, t.day);
    }
    return t.toUtc();
  }

  double? quantizeHr(double? v) {
    if (!quantizeVitals || v == null) return v;
    // 10 bpm buckets
    final bucket = (v / 10).floor() * 10;
    return bucket.toDouble();
  }

  double? quantizeHrv(double? v) {
    if (!quantizeVitals || v == null) return v;
    // coarse buckets: <30, 30-60, >60
    if (v < 30) return 20;
    if (v < 60) return 45;
    return 70;
  }
}


