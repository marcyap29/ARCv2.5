import 'package:my_app/services/adaptive/user_cadence_detector.dart';
import 'package:my_app/services/sentinel/sentinel_config.dart';
import 'rivet_config.dart';

/// Adaptive configuration for RIVET and Sentinel
class AdaptiveConfig {
  final SentinelConfig sentinel;
  final RivetConfig rivet;

  AdaptiveConfig({
    required this.sentinel,
    required this.rivet,
  });

  /// Create config for user type
  factory AdaptiveConfig.forUserType(UserType type) {
    switch (type) {
      case UserType.powerUser:
        return AdaptiveConfig._powerUser();
      case UserType.frequent:
        return AdaptiveConfig._frequent();
      case UserType.weekly:
        return AdaptiveConfig._weekly();
      case UserType.sporadic:
        return AdaptiveConfig._sporadic();
      case UserType.insufficientData:
        return AdaptiveConfig._default();
    }
  }

  factory AdaptiveConfig._powerUser() {
    return AdaptiveConfig(
      sentinel: SentinelConfig.powerUser(),
      rivet: RivetConfig.powerUser(),
    );
  }

  factory AdaptiveConfig._frequent() {
    return AdaptiveConfig(
      sentinel: SentinelConfig.frequent(),
      rivet: RivetConfig.frequent(),
    );
  }

  factory AdaptiveConfig._weekly() {
    return AdaptiveConfig(
      sentinel: SentinelConfig.weekly(),
      rivet: RivetConfig.weekly(),
    );
  }

  factory AdaptiveConfig._sporadic() {
    return AdaptiveConfig(
      sentinel: SentinelConfig.sporadic(),
      rivet: RivetConfig.sporadic(),
    );
  }

  factory AdaptiveConfig._default() {
    // Default to weekly (most forgiving) for new users
    return AdaptiveConfig._weekly();
  }
}

