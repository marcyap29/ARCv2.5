class PrivacySettings {
  final bool removePii;
  final String timestampPrecision; // 'full' | 'date_only'
  final bool quantizeVitals;
  const PrivacySettings({
    this.removePii = false,
    this.timestampPrecision = 'full',
    this.quantizeVitals = false,
  });
}


