enum HealthRetention { none, trendsOnly, full }

class HealthConsent {
  final bool readHealth;
  final bool referenceInChat;
  final bool showNumericValues;
  final bool notifications;
  final HealthRetention retention;

  const HealthConsent({
    required this.readHealth,
    required this.referenceInChat,
    required this.showNumericValues,
    required this.notifications,
    required this.retention,
  });

  HealthConsent copyWith({
    bool? readHealth,
    bool? referenceInChat,
    bool? showNumericValues,
    bool? notifications,
    HealthRetention? retention,
  }) => HealthConsent(
        readHealth: readHealth ?? this.readHealth,
        referenceInChat: referenceInChat ?? this.referenceInChat,
        showNumericValues: showNumericValues ?? this.showNumericValues,
        notifications: notifications ?? this.notifications,
        retention: retention ?? this.retention,
      );

  static const disabled = HealthConsent(
    readHealth: false,
    referenceInChat: false,
    showNumericValues: false,
    notifications: false,
    retention: HealthRetention.none,
  );
}


