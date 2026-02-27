// lib/mira/policy/policy_engine.dart
// MIRA Policy Engine for Privacy and Access Control
// Implements domain-based access control and consent management

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../core/schema_v2.dart';

/// Purpose for memory access
enum Purpose {
  retrieval,        // General memory retrieval
  export,          // Memory export
  analysis,        // AI analysis
  sharing,         // Sharing with other agents
  backup,          // Backup operations
  migration,       // Data migration
  debugging,       // Debug and development
  research,        // Research and analytics
}

/// Policy decision result
class PolicyDecision {
  final bool allowed;
  final String reason;
  final List<String> conditions;
  final Map<String, dynamic> metadata;

  const PolicyDecision({
    required this.allowed,
    required this.reason,
    this.conditions = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'allowed': allowed,
    'reason': reason,
    'conditions': conditions,
    'metadata': metadata,
  };
}

/// Consent log entry
class ConsentLogEntry {
  final String id;                    // ULID
  final String actor;                 // Who requested access
  final String purpose;               // Why access was requested
  final String resource;              // What was accessed
  final bool granted;                 // Whether access was granted
  final String reason;                // Reason for decision
  final DateTime timestamp;           // When this happened
  final Map<String, dynamic> context; // Additional context

  const ConsentLogEntry({
    required this.id,
    required this.actor,
    required this.purpose,
    required this.resource,
    required this.granted,
    required this.reason,
    required this.timestamp,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor': actor,
    'purpose': purpose,
    'resource': resource,
    'granted': granted,
    'reason': reason,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'context': context,
  };

  factory ConsentLogEntry.fromJson(Map<String, dynamic> json) => ConsentLogEntry(
    id: json['id'] as String,
    actor: json['actor'] as String,
    purpose: json['purpose'] as String,
    resource: json['resource'] as String,
    granted: json['granted'] as bool,
    reason: json['reason'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    context: Map<String, dynamic>.from(json['context'] ?? {}),
  );
}

/// Policy rule
class PolicyRule {
  final String id;
  final String name;
  final String description;
  final List<MemoryDomain> domains;
  final List<PrivacyLevel> maxPrivacyLevels;
  final List<Purpose> allowedPurposes;
  final List<String> allowedActors;
  final Map<String, dynamic> conditions;
  final bool enabled;

  const PolicyRule({
    required this.id,
    required this.name,
    required this.description,
    required this.domains,
    required this.maxPrivacyLevels,
    required this.allowedPurposes,
    required this.allowedActors,
    this.conditions = const {},
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'domains': domains.map((d) => d.name).toList(),
    'max_privacy_levels': maxPrivacyLevels.map((p) => p.name).toList(),
    'allowed_purposes': allowedPurposes.map((p) => p.name).toList(),
    'allowed_actors': allowedActors,
    'conditions': conditions,
    'enabled': enabled,
  };

  factory PolicyRule.fromJson(Map<String, dynamic> json) => PolicyRule(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    domains: (json['domains'] as List<dynamic>)
        .map((d) => MemoryDomain.values.firstWhere((e) => e.name == d))
        .toList(),
    maxPrivacyLevels: (json['max_privacy_levels'] as List<dynamic>)
        .map((p) => PrivacyLevel.values.firstWhere((e) => e.name == p))
        .toList(),
    allowedPurposes: (json['allowed_purposes'] as List<dynamic>)
        .map((p) => Purpose.values.firstWhere((e) => e.name == p))
        .toList(),
    allowedActors: List<String>.from(json['allowed_actors'] ?? []),
    conditions: Map<String, dynamic>.from(json['conditions'] ?? {}),
    enabled: json['enabled'] as bool? ?? true,
  );
}

/// Policy engine for MIRA memory access control
class PolicyEngine {
  final List<PolicyRule> _rules;
  final List<ConsentLogEntry> _consentLog;
  final Map<String, dynamic> _userPreferences;

  PolicyEngine({
    List<PolicyRule>? rules,
    List<ConsentLogEntry>? consentLog,
    Map<String, dynamic>? userPreferences,
  }) : _rules = rules ?? _getDefaultRules(),
       _consentLog = consentLog ?? [],
       _userPreferences = userPreferences ?? {};

  /// Get default policy rules
  static List<PolicyRule> _getDefaultRules() => [
    // Personal domain - high privacy
    const PolicyRule(
      id: 'personal_high_privacy',
      name: 'Personal High Privacy',
      description: 'Personal memories with high privacy protection',
      domains: [MemoryDomain.personal],
      maxPrivacyLevels: [PrivacyLevel.personal, PrivacyLevel.private],
      allowedPurposes: [Purpose.retrieval, Purpose.analysis],
      allowedActors: ['user', 'system'],
    ),
    
    // Work domain - moderate privacy
    const PolicyRule(
      id: 'work_moderate_privacy',
      name: 'Work Moderate Privacy',
      description: 'Work memories with moderate privacy protection',
      domains: [MemoryDomain.work],
      maxPrivacyLevels: [PrivacyLevel.public, PrivacyLevel.personal],
      allowedPurposes: [Purpose.retrieval, Purpose.analysis, Purpose.sharing],
      allowedActors: ['user', 'system', 'work_agent'],
    ),
    
    // Health domain - maximum privacy
    const PolicyRule(
      id: 'health_maximum_privacy',
      name: 'Health Maximum Privacy',
      description: 'Health memories with maximum privacy protection',
      domains: [MemoryDomain.health],
      maxPrivacyLevels: [PrivacyLevel.private, PrivacyLevel.sensitive],
      allowedPurposes: [Purpose.retrieval],
      allowedActors: ['user'],
    ),
    
    // Creative domain - open sharing
    const PolicyRule(
      id: 'creative_open_sharing',
      name: 'Creative Open Sharing',
      description: 'Creative memories for open sharing',
      domains: [MemoryDomain.creative],
      maxPrivacyLevels: [PrivacyLevel.public, PrivacyLevel.personal],
      allowedPurposes: [Purpose.retrieval, Purpose.analysis, Purpose.sharing, Purpose.export],
      allowedActors: ['user', 'system', 'creative_agent'],
    ),
    
    // Finance domain - maximum security
    const PolicyRule(
      id: 'finance_maximum_security',
      name: 'Finance Maximum Security',
      description: 'Finance memories with maximum security',
      domains: [MemoryDomain.finance],
      maxPrivacyLevels: [PrivacyLevel.sensitive, PrivacyLevel.confidential],
      allowedPurposes: [Purpose.retrieval],
      allowedActors: ['user'],
    ),
  ];

  /// Check if access is allowed
  PolicyDecision checkAccess({
    required MemoryDomain domain,
    required PrivacyLevel privacyLevel,
    required String actor,
    required Purpose purpose,
    Map<String, dynamic>? context,
  }) {
    // Find applicable rules
    final applicableRules = _rules.where((rule) => 
      rule.enabled &&
      rule.domains.contains(domain) &&
      rule.maxPrivacyLevels.contains(privacyLevel) &&
      rule.allowedActors.contains(actor) &&
      rule.allowedPurposes.contains(purpose)
    ).toList();

    if (applicableRules.isEmpty) {
      _logConsent(actor, purpose, '${domain.name}:${privacyLevel.name}', false, 
          'No applicable policy rule found');
      return PolicyDecision(
        allowed: false,
        reason: 'No applicable policy rule found for domain ${domain.name}, privacy ${privacyLevel.name}, actor $actor, purpose ${purpose.name}',
        conditions: ['no_matching_rule'],
      );
    }

    // Check conditions for each rule
    for (final rule in applicableRules) {
      if (_checkRuleConditions(rule, context)) {
        _logConsent(actor, purpose, '${domain.name}:${privacyLevel.name}', true, 
            'Policy rule ${rule.name} allows access');
        return PolicyDecision(
          allowed: true,
          reason: 'Policy rule ${rule.name} allows access',
          conditions: ['rule_matched'],
          metadata: {'rule_id': rule.id, 'rule_name': rule.name},
        );
      }
    }

    _logConsent(actor, purpose, '${domain.name}:${privacyLevel.name}', false, 
        'No rule conditions satisfied');
    return const PolicyDecision(
      allowed: false,
      reason: 'No rule conditions satisfied',
      conditions: ['conditions_not_met'],
    );
  }

  /// Check rule conditions
  bool _checkRuleConditions(PolicyRule rule, Map<String, dynamic>? context) {
    if (rule.conditions.isEmpty) return true;

    final contextMap = context ?? {};
    
    for (final condition in rule.conditions.entries) {
      final key = condition.key;
      final expectedValue = condition.value;
      final actualValue = contextMap[key];

      if (actualValue != expectedValue) {
        return false;
      }
    }

    return true;
  }

  /// Log consent decision
  void _logConsent(String actor, Purpose purpose, String resource, bool granted, String reason) {
    final entry = ConsentLogEntry(
      id: _generateId(),
      actor: actor,
      purpose: purpose.name,
      resource: resource,
      granted: granted,
      reason: reason,
      timestamp: DateTime.now().toUtc(),
      context: {
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'user_preferences': _userPreferences,
      },
    );

    _consentLog.add(entry);
  }

  /// Generate unique ID for consent log
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    final bytes = Uint8List.fromList([
      (timestamp >> 24) & 0xFF,
      (timestamp >> 16) & 0xFF,
      (timestamp >> 8) & 0xFF,
      timestamp & 0xFF,
      (random >> 8) & 0xFF,
      random & 0xFF,
    ]);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }

  /// Get consent log
  List<ConsentLogEntry> getConsentLog() => List.unmodifiable(_consentLog);

  /// Get consent log for specific actor
  List<ConsentLogEntry> getConsentLogForActor(String actor) =>
      _consentLog.where((entry) => entry.actor == actor).toList();

  /// Get consent log for specific purpose
  List<ConsentLogEntry> getConsentLogForPurpose(Purpose purpose) =>
      _consentLog.where((entry) => entry.purpose == purpose.name).toList();

  /// Add policy rule
  void addRule(PolicyRule rule) {
    _rules.add(rule);
  }

  /// Remove policy rule
  void removeRule(String ruleId) {
    _rules.removeWhere((rule) => rule.id == ruleId);
  }

  /// Update policy rule
  void updateRule(PolicyRule updatedRule) {
    final index = _rules.indexWhere((rule) => rule.id == updatedRule.id);
    if (index != -1) {
      _rules[index] = updatedRule;
    }
  }

  /// Get all policy rules
  List<PolicyRule> getRules() => List.unmodifiable(_rules);

  /// Export policy configuration
  Map<String, dynamic> exportPolicy() => {
    'version': '1.0.0',
    'rules': _rules.map((rule) => rule.toJson()).toList(),
    'user_preferences': _userPreferences,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
  };

  /// Import policy configuration
  void importPolicy(Map<String, dynamic> config) {
    final rules = (config['rules'] as List<dynamic>? ?? [])
        .map((rule) => PolicyRule.fromJson(rule as Map<String, dynamic>))
        .toList();
    
    _rules.clear();
    _rules.addAll(rules);
    
    _userPreferences.clear();
    _userPreferences.addAll(Map<String, dynamic>.from(config['user_preferences'] ?? {}));
  }

  /// Check if PII should be redacted for export
  bool shouldRedactPII({
    required PrivacyLevel privacyLevel,
    required bool hasPII,
    bool userOverride = false,
  }) {
    if (userOverride) return false;
    if (!hasPII) return false;
    
    // Redact PII for sensitive and confidential privacy levels
    return privacyLevel == PrivacyLevel.sensitive || 
           privacyLevel == PrivacyLevel.confidential;
  }

  /// Get safe export configuration
  Map<String, dynamic> getSafeExportConfig({
    required List<MemoryDomain> domains,
    required PrivacyLevel maxPrivacyLevel,
    bool userOverride = false,
  }) => {
    'domains': domains.map((d) => d.name).toList(),
    'max_privacy_level': maxPrivacyLevel.name,
    'redact_pii': true,
    'user_override': userOverride,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
  };
}
