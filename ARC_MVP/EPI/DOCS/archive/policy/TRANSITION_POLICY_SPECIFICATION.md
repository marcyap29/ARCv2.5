# Transition Policy Specification

**Version:** 1.0  
**Date:** January 12, 2025  
**Status:** Production Ready ✅

## Overview

The Transition Policy is a unified decision system that coordinates ATLAS (phase inference), RIVET (advancement gating), and SENTINEL (risk gating) to determine when users should advance to the next phase in their personal development journey.

## Architecture

### Core Components

1. **TransitionPolicy** - Main decision engine
2. **TransitionPolicyConfig** - Configuration parameters
3. **TransitionOutcome** - Decision result with telemetry
4. **TransitionIntegrationService** - Integration with journal flow
5. **TransitionPolicyValidator** - Configuration validation

### Data Flow

```
Journal Entry → ATLAS → RIVET → SENTINEL → Policy Decision → Phase Change/Block
     ↓              ↓        ↓         ↓            ↓
Phase Scores → ALIGN/TRACE → Risk → Decision → Notification
```

## Decision Logic

### Prerequisites for Phase Promotion

All of the following conditions must be met for a phase change to be approved:

#### 1. ATLAS Conditions
- **Margin Threshold**: New phase score must exceed current by ≥ `atlasMargin` (default: 0.62)
- **Hysteresis**: Must not be blocked by hysteresis (prevents oscillation)
- **Cooldown**: Must not be in cooldown period (default: 7 days)

#### 2. RIVET Conditions
- **ALIGN Threshold**: ALIGN score ≥ `rivetAlign` (default: 0.60)
- **TRACE Threshold**: TRACE score ≥ `rivetTrace` (default: 0.60)
- **Sustainment**: Must meet thresholds for `sustainW` consecutive entries (default: 2)
- **Independence**: Must have independent evidence in sustainment window
- **Novelty Cap**: Novelty score ≤ `noveltyCap` (default: 0.20)

#### 3. SENTINEL Conditions
- **Risk Threshold**: Risk score ≤ `riskThreshold` (default: 0.30)
- **Risk Band**: Risk level ≤ Moderate
- **Pattern Severity**: Pattern severity ≤ `riskThreshold`
- **Sustainment**: Risk must be sustained (not escalating)

### Decision Outcomes

#### TransitionDecision.promote
- All conditions satisfied
- Phase change approved
- User notified of advancement

#### TransitionDecision.hold
- One or more conditions not met
- Phase change blocked
- Specific blocking reasons provided

## Configuration

### Production Configuration (Default)
```dart
TransitionPolicyConfig.production = TransitionPolicyConfig(
  atlasMargin: 0.62,        // 62% margin required
  atlasHysteresis: 0.08,    // 8% hysteresis gap
  rivetAlign: 0.60,         // 60% ALIGN threshold
  rivetTrace: 0.60,         // 60% TRACE threshold
  sustainW: 2,              // 2-entry sustainment
  sustainGrace: 1,          // 1-entry grace period
  noveltyCap: 0.20,         // 20% novelty cap
  independenceBoost: 1.2,   // 20% independence boost
  riskThreshold: 0.30,      // 30% risk threshold
  riskDecayRate: 0.10,      // 10% decay per day
  cooldown: Duration(days: 7),     // 7-day cooldown
  riskWindow: Duration(days: 14),  // 14-day risk window
);
```

### Conservative Configuration
```dart
TransitionPolicyConfig.conservative = TransitionPolicyConfig(
  atlasMargin: 0.65,        // Higher margin
  rivetAlign: 0.65,         // Higher thresholds
  rivetTrace: 0.65,
  sustainW: 3,              // Longer sustainment
  riskThreshold: 0.20,      // Lower risk tolerance
);
```

### Aggressive Configuration
```dart
TransitionPolicyConfig.aggressive = TransitionPolicyConfig(
  atlasMargin: 0.58,        // Lower margin
  rivetAlign: 0.55,         // Lower thresholds
  rivetTrace: 0.55,
  sustainW: 1,              // Shorter sustainment
  riskThreshold: 0.40,      // Higher risk tolerance
);
```

## Integration

### Journal Capture Flow

```dart
// 1. Create integration service
final integrationService = await TransitionIntegrationServiceFactory.createProduction(
  userProfile: userProfile,
  analytics: analyticsService,
  notifications: notificationService,
);

// 2. Process journal entry
final result = await integrationService.processJournalEntry(
  journalEntryId: entryId,
  emotion: emotion,
  reason: reason,
  text: text,
  selectedKeywords: keywords,
  predictedPhase: predictedPhase,
  confirmedPhase: confirmedPhase,
);

// 3. Handle result
if (result.phaseChanged) {
  // Phase advanced - notify user
  showPhaseChangeNotification(result.newPhase!);
} else {
  // Phase blocked - show feedback
  showPhaseBlockedFeedback(result.reason);
}
```

### Telemetry

Every decision includes comprehensive telemetry:

```dart
{
  "timestamp": "2025-01-12T10:30:00Z",
  "config": { /* configuration parameters */ },
  "atlas": { /* ATLAS state and scores */ },
  "rivet": { /* RIVET state and metrics */ },
  "sentinel": { /* SENTINEL analysis */ },
  "decision": "promote|hold",
  "all_conditions_met": true|false,
  "blocking_reasons": ["reason1", "reason2"],
  "adjusted_risk_score": 0.25
}
```

## Risk Management

### Risk Decay
Risk scores decay over time to prevent stale risk from blocking advancement:

```
adjusted_risk = risk_score * exp(-decay_rate * days_since_analysis)
```

### Risk Thresholds
- **Low Risk** (≤ 0.2): No restrictions
- **Moderate Risk** (0.2-0.3): Caution advised
- **Elevated Risk** (0.3-0.5): Advancement blocked
- **High Risk** (> 0.5): Immediate attention required

## Testing

### Unit Tests
Comprehensive test suite covering:
- All decision paths
- Edge cases and boundary conditions
- Configuration validation
- Risk decay calculations
- Telemetry completeness

### Integration Tests
End-to-end testing with:
- Mock journal entries
- Simulated ATLAS/RIVET/SENTINEL responses
- Policy decision validation
- Notification delivery

## Monitoring

### Analytics Events
- `transition_policy_evaluation` - Every policy decision
- `phase_change_executed` - Successful phase advancement
- `phase_change_blocked` - Blocked phase change
- `transition_policy_error` - Policy processing errors

### Key Metrics
- Decision accuracy
- Phase advancement rate
- Blocking reason frequency
- Risk score distribution
- Processing time

## Troubleshooting

### Common Issues

#### Phase Changes Blocked
1. Check ATLAS margin and hysteresis
2. Verify RIVET thresholds and sustainment
3. Review SENTINEL risk analysis
4. Confirm cooldown status

#### High Risk Scores
1. Review recent journal entries
2. Check for concerning patterns
3. Consider risk decay timing
4. Validate SENTINEL configuration

#### Configuration Issues
1. Use `TransitionPolicyValidator.validateConfig()`
2. Check production safety with `isProductionSafe()`
3. Verify threshold ranges (0.0-1.0)
4. Test with different configurations

### Debug Mode
Enable detailed logging by setting:
```dart
TransitionPolicyConfig(
  // ... other config
  debugMode: true, // Enable detailed telemetry
);
```

## Future Enhancements

### Planned Features
- Machine learning-based threshold optimization
- User-specific configuration adaptation
- Advanced risk pattern detection
- Multi-phase transition support
- A/B testing framework

### Configuration Management
- Dynamic configuration updates
- A/B testing support
- User preference integration
- Performance monitoring

## API Reference

### TransitionPolicy
```dart
class TransitionPolicy {
  Future<TransitionOutcome> decide({
    required AtlasSnapshot atlas,
    required RivetSnapshot rivet,
    required SentinelSnapshot sentinel,
    required bool cooldownActive,
  });
}
```

### TransitionIntegrationService
```dart
class TransitionIntegrationService {
  Future<TransitionProcessingResult> processJournalEntry({
    required String journalEntryId,
    required String emotion,
    required String reason,
    required String text,
    required List<String> selectedKeywords,
    required String predictedPhase,
    required String confirmedPhase,
  });
}
```

### Factory Methods
```dart
// Create production service
TransitionIntegrationServiceFactory.createProduction()

// Create custom service
TransitionIntegrationServiceFactory.createCustom(config)

// Create policy instances
TransitionPolicyFactory.createProduction()
TransitionPolicyFactory.createConservative()
TransitionPolicyFactory.createAggressive()
TransitionPolicyFactory.createCustom(config)
```

## Conclusion

The Transition Policy provides a robust, unified decision system that balances user advancement with risk management. Through careful configuration and comprehensive monitoring, it ensures safe and appropriate phase transitions while maintaining user engagement and development progress.

For implementation details, see the source code in `lib/policy/transition_policy.dart` and `lib/policy/transition_integration_service.dart`.
