// lib/mira/memory/domain_scoping_service.dart
// Domain scoping service for EPI memory system
// Implements separate "memory buckets" with controlled cross-domain synthesis

import 'enhanced_memory_schema.dart';

/// Service for managing scoped memory domains and controlled access
class DomainScopingService {
  /// Domain access policies
  final Map<MemoryDomain, DomainPolicy> _domainPolicies = {};

  /// Cross-domain synthesis rules
  final Map<String, CrossDomainRule> _crossDomainRules = {};

  /// Domain isolation settings
  final Map<String, DomainIsolationSettings> _isolationSettings = {};

  DomainScopingService() {
    _initializeDefaultPolicies();
  }

  /// Initialize default domain policies
  void _initializeDefaultPolicies() {
    // Personal domain - high privacy, limited sharing
    _domainPolicies[MemoryDomain.personal] = const DomainPolicy(
      domain: MemoryDomain.personal,
      accessLevel: AccessLevel.strict,
      allowCrossDomainSynthesis: false,
      requiresExplicitConsent: true,
      retentionPeriod: Duration(days: 365 * 5), // 5 years
      encryptionRequired: true,
    );

    // Work domain - moderate privacy, professional context
    _domainPolicies[MemoryDomain.work] = const DomainPolicy(
      domain: MemoryDomain.work,
      accessLevel: AccessLevel.moderate,
      allowCrossDomainSynthesis: true,
      requiresExplicitConsent: false,
      retentionPeriod: Duration(days: 365 * 3), // 3 years
      encryptionRequired: false,
    );

    // Health domain - maximum privacy
    _domainPolicies[MemoryDomain.health] = const DomainPolicy(
      domain: MemoryDomain.health,
      accessLevel: AccessLevel.maximum,
      allowCrossDomainSynthesis: false,
      requiresExplicitConsent: true,
      retentionPeriod: Duration(days: 365 * 7), // 7 years
      encryptionRequired: true,
    );

    // Creative domain - open sharing, inspiration focus
    _domainPolicies[MemoryDomain.creative] = const DomainPolicy(
      domain: MemoryDomain.creative,
      accessLevel: AccessLevel.open,
      allowCrossDomainSynthesis: true,
      requiresExplicitConsent: false,
      retentionPeriod: Duration(days: 365 * 10), // 10 years
      encryptionRequired: false,
    );

    // Learning domain - knowledge building
    _domainPolicies[MemoryDomain.learning] = const DomainPolicy(
      domain: MemoryDomain.learning,
      accessLevel: AccessLevel.moderate,
      allowCrossDomainSynthesis: true,
      requiresExplicitConsent: false,
      retentionPeriod: Duration(days: 365 * 10), // 10 years
      encryptionRequired: false,
    );

    // Relationships domain - high privacy
    _domainPolicies[MemoryDomain.relationships] = const DomainPolicy(
      domain: MemoryDomain.relationships,
      accessLevel: AccessLevel.strict,
      allowCrossDomainSynthesis: false,
      requiresExplicitConsent: true,
      retentionPeriod: Duration(days: 365 * 5), // 5 years
      encryptionRequired: true,
    );

    // Finance domain - maximum security
    _domainPolicies[MemoryDomain.finance] = const DomainPolicy(
      domain: MemoryDomain.finance,
      accessLevel: AccessLevel.maximum,
      allowCrossDomainSynthesis: false,
      requiresExplicitConsent: true,
      retentionPeriod: Duration(days: 365 * 7), // 7 years
      encryptionRequired: true,
    );

    // Spiritual domain - personal, respectful handling
    _domainPolicies[MemoryDomain.spiritual] = const DomainPolicy(
      domain: MemoryDomain.spiritual,
      accessLevel: AccessLevel.strict,
      allowCrossDomainSynthesis: false,
      requiresExplicitConsent: true,
      retentionPeriod: Duration(days: 365 * 10), // 10 years
      encryptionRequired: true,
    );

    // Meta domain - system level, moderate access
    _domainPolicies[MemoryDomain.meta] = const DomainPolicy(
      domain: MemoryDomain.meta,
      accessLevel: AccessLevel.moderate,
      allowCrossDomainSynthesis: true,
      requiresExplicitConsent: false,
      retentionPeriod: Duration(days: 365 * 2), // 2 years
      encryptionRequired: false,
    );
  }

  /// Check if access to domain is allowed for given context
  bool isAccessAllowed({
    required MemoryDomain domain,
    required AccessContext context,
    bool requiresCrossDomainSynthesis = false,
  }) {
    final policy = _domainPolicies[domain];
    if (policy == null) return false;

    // Check basic access level
    if (!_checkAccessLevel(policy.accessLevel, context)) {
      return false;
    }

    // Check cross-domain synthesis permission
    if (requiresCrossDomainSynthesis && !policy.allowCrossDomainSynthesis) {
      return false;
    }

    // Check explicit consent requirement
    if (policy.requiresExplicitConsent && !context.hasExplicitConsent) {
      return false;
    }

    return true;
  }

  /// Filter memory nodes by domain access permissions
  List<EnhancedMiraNode> filterByDomainAccess({
    required List<EnhancedMiraNode> nodes,
    required AccessContext context,
    List<MemoryDomain>? allowedDomains,
    bool enableCrossDomainSynthesis = false,
  }) {
    return nodes.where((node) {
      // Check if domain is in allowed list
      if (allowedDomains != null && !allowedDomains.contains(node.domain)) {
        return false;
      }

      // Check domain access permissions
      return isAccessAllowed(
        domain: node.domain,
        context: context,
        requiresCrossDomainSynthesis: enableCrossDomainSynthesis,
      );
    }).toList();
  }

  /// Retrieve memories scoped to specific domains
  Future<List<EnhancedMiraNode>> retrieveScopedMemories({
    required List<MemoryDomain> domains,
    required AccessContext context,
    String? query,
    int? limit,
    DateTime? after,
    DateTime? before,
  }) async {
    // This would integrate with the actual MIRA repository
    // For now, returning empty list as placeholder
    final List<EnhancedMiraNode> allNodes = []; // TODO: Get from MIRA repo

    var filteredNodes = filterByDomainAccess(
      nodes: allNodes,
      context: context,
      allowedDomains: domains,
    );

    // Apply temporal filters
    if (after != null) {
      filteredNodes = filteredNodes.where((n) => n.createdAt.isAfter(after)).toList();
    }
    if (before != null) {
      filteredNodes = filteredNodes.where((n) => n.createdAt.isBefore(before)).toList();
    }

    // Apply query filter if provided
    if (query != null && query.isNotEmpty) {
      filteredNodes = filteredNodes.where((n) =>
        n.narrative.toLowerCase().contains(query.toLowerCase()) ||
        n.keywords.any((k) => k.toLowerCase().contains(query.toLowerCase()))
      ).toList();
    }

    // Apply limit
    if (limit != null && filteredNodes.length > limit) {
      filteredNodes = filteredNodes.take(limit).toList();
    }

    return filteredNodes;
  }

  /// Create cross-domain synthesis request
  Future<CrossDomainSynthesisResult> requestCrossDomainSynthesis({
    required List<MemoryDomain> sourceDomains,
    required String synthesisGoal,
    required AccessContext context,
    bool requiresUserConsent = true,
  }) async {
    // Check if cross-domain synthesis is allowed for all source domains
    for (final domain in sourceDomains) {
      final policy = _domainPolicies[domain];
      if (policy == null || !policy.allowCrossDomainSynthesis) {
        return CrossDomainSynthesisResult.denied(
          reason: 'Cross-domain synthesis not allowed for domain: ${domain.name}',
          domain: domain,
        );
      }
    }

    // Check if user consent is required and provided
    if (requiresUserConsent && !context.hasExplicitConsent) {
      return CrossDomainSynthesisResult.consentRequired(
        domains: sourceDomains,
        goal: synthesisGoal,
      );
    }

    // TODO: Implement actual synthesis logic
    return CrossDomainSynthesisResult.success(
      synthesizedNodes: [],
      sourceDomains: sourceDomains,
      goal: synthesisGoal,
    );
  }

  /// Set domain isolation rules
  void setDomainIsolation({
    required MemoryDomain domain,
    required List<MemoryDomain> isolatedFrom,
    String? reason,
  }) {
    _isolationSettings['${domain.name}_isolation'] = DomainIsolationSettings(
      domain: domain,
      isolatedFrom: isolatedFrom,
      reason: reason,
      timestamp: DateTime.now().toUtc(),
    );
  }

  /// Check if two domains can interact
  bool canDomainsInteract(MemoryDomain domainA, MemoryDomain domainB) {
    final isolationA = _isolationSettings['${domainA.name}_isolation'];
    final isolationB = _isolationSettings['${domainB.name}_isolation'];

    if (isolationA != null && isolationA.isolatedFrom.contains(domainB)) {
      return false;
    }
    if (isolationB != null && isolationB.isolatedFrom.contains(domainA)) {
      return false;
    }

    return true;
  }

  /// Get domain statistics
  Map<String, dynamic> getDomainStatistics() {
    final stats = <String, dynamic>{};

    for (final domain in MemoryDomain.values) {
      final policy = _domainPolicies[domain];
      stats[domain.name] = {
        'access_level': policy?.accessLevel.name,
        'cross_domain_synthesis': policy?.allowCrossDomainSynthesis,
        'requires_consent': policy?.requiresExplicitConsent,
        'encryption_required': policy?.encryptionRequired,
        'retention_days': policy?.retentionPeriod.inDays,
      };
    }

    return {
      'domain_policies': stats,
      'isolation_rules': _isolationSettings.length,
      'cross_domain_rules': _crossDomainRules.length,
    };
  }

  /// Export domain configuration for backup/migration
  Map<String, dynamic> exportDomainConfiguration() {
    return {
      'export_timestamp': DateTime.now().toUtc().toIso8601String(),
      'domain_policies': _domainPolicies.map((domain, policy) =>
          MapEntry(domain.name, policy.toJson())),
      'cross_domain_rules': _crossDomainRules.map((id, rule) =>
          MapEntry(id, rule.toJson())),
      'isolation_settings': _isolationSettings.map((id, settings) =>
          MapEntry(id, settings.toJson())),
      'schema_version': 'domain_config.v1',
    };
  }

  /// Check access level against context
  bool _checkAccessLevel(AccessLevel required, AccessContext context) {
    switch (required) {
      case AccessLevel.open:
        return true;
      case AccessLevel.moderate:
        return context.isAuthenticated;
      case AccessLevel.strict:
        return context.isAuthenticated && context.hasElevatedPrivileges;
      case AccessLevel.maximum:
        return context.isAuthenticated &&
               context.hasElevatedPrivileges &&
               context.hasRecentAuthentication;
    }
  }
}

/// Domain access policy configuration
class DomainPolicy {
  final MemoryDomain domain;
  final AccessLevel accessLevel;
  final bool allowCrossDomainSynthesis;
  final bool requiresExplicitConsent;
  final Duration retentionPeriod;
  final bool encryptionRequired;

  const DomainPolicy({
    required this.domain,
    required this.accessLevel,
    required this.allowCrossDomainSynthesis,
    required this.requiresExplicitConsent,
    required this.retentionPeriod,
    required this.encryptionRequired,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain.name,
    'access_level': accessLevel.name,
    'allow_cross_domain_synthesis': allowCrossDomainSynthesis,
    'requires_explicit_consent': requiresExplicitConsent,
    'retention_period_days': retentionPeriod.inDays,
    'encryption_required': encryptionRequired,
  };

  factory DomainPolicy.fromJson(Map<String, dynamic> json) {
    return DomainPolicy(
      domain: MemoryDomain.values.firstWhere((d) => d.name == json['domain']),
      accessLevel: AccessLevel.values.firstWhere((a) => a.name == json['access_level']),
      allowCrossDomainSynthesis: json['allow_cross_domain_synthesis'],
      requiresExplicitConsent: json['requires_explicit_consent'],
      retentionPeriod: Duration(days: json['retention_period_days']),
      encryptionRequired: json['encryption_required'],
    );
  }
}

/// Access levels for memory domains
enum AccessLevel {
  open,      // Anyone can access
  moderate,  // Requires authentication
  strict,    // Requires elevated privileges
  maximum,   // Requires recent authentication + elevated privileges
}

/// Access context for permission checking
class AccessContext {
  final bool isAuthenticated;
  final bool hasElevatedPrivileges;
  final bool hasRecentAuthentication;
  final bool hasExplicitConsent;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic> metadata;

  const AccessContext({
    required this.isAuthenticated,
    this.hasElevatedPrivileges = false,
    this.hasRecentAuthentication = false,
    this.hasExplicitConsent = false,
    this.userId,
    this.sessionId,
    this.metadata = const {},
  });

  factory AccessContext.authenticated({
    required String userId,
    String? sessionId,
    bool hasElevatedPrivileges = false,
    bool hasRecentAuthentication = false,
    bool hasExplicitConsent = false,
  }) {
    return AccessContext(
      isAuthenticated: true,
      hasElevatedPrivileges: hasElevatedPrivileges,
      hasRecentAuthentication: hasRecentAuthentication,
      hasExplicitConsent: hasExplicitConsent,
      userId: userId,
      sessionId: sessionId,
    );
  }

  factory AccessContext.unauthenticated() {
    return const AccessContext(isAuthenticated: false);
  }
}

/// Cross-domain synthesis rule
class CrossDomainRule {
  final String id;
  final List<MemoryDomain> sourceDomains;
  final List<MemoryDomain> targetDomains;
  final SynthesisType synthesisType;
  final bool requiresConsent;
  final Map<String, dynamic> conditions;

  const CrossDomainRule({
    required this.id,
    required this.sourceDomains,
    required this.targetDomains,
    required this.synthesisType,
    this.requiresConsent = true,
    this.conditions = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_domains': sourceDomains.map((d) => d.name).toList(),
    'target_domains': targetDomains.map((d) => d.name).toList(),
    'synthesis_type': synthesisType.name,
    'requires_consent': requiresConsent,
    'conditions': conditions,
  };

  factory CrossDomainRule.fromJson(Map<String, dynamic> json) {
    return CrossDomainRule(
      id: json['id'],
      sourceDomains: (json['source_domains'] as List<dynamic>)
          .map((d) => MemoryDomain.values.firstWhere((domain) => domain.name == d))
          .toList(),
      targetDomains: (json['target_domains'] as List<dynamic>)
          .map((d) => MemoryDomain.values.firstWhere((domain) => domain.name == d))
          .toList(),
      synthesisType: SynthesisType.values.firstWhere((s) => s.name == json['synthesis_type']),
      requiresConsent: json['requires_consent'],
      conditions: Map<String, dynamic>.from(json['conditions']),
    );
  }
}

/// Types of cross-domain synthesis
enum SynthesisType {
  thematic,     // Find thematic connections
  temporal,     // Find temporal patterns
  emotional,    // Find emotional patterns
  causal,       // Find causal relationships
  inspiration,  // Creative inspiration
}

/// Domain isolation settings
class DomainIsolationSettings {
  final MemoryDomain domain;
  final List<MemoryDomain> isolatedFrom;
  final String? reason;
  final DateTime timestamp;

  const DomainIsolationSettings({
    required this.domain,
    required this.isolatedFrom,
    this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain.name,
    'isolated_from': isolatedFrom.map((d) => d.name).toList(),
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DomainIsolationSettings.fromJson(Map<String, dynamic> json) {
    return DomainIsolationSettings(
      domain: MemoryDomain.values.firstWhere((d) => d.name == json['domain']),
      isolatedFrom: (json['isolated_from'] as List<dynamic>)
          .map((d) => MemoryDomain.values.firstWhere((domain) => domain.name == d))
          .toList(),
      reason: json['reason'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Result of cross-domain synthesis request
class CrossDomainSynthesisResult {
  final bool success;
  final List<EnhancedMiraNode> synthesizedNodes;
  final List<MemoryDomain> sourceDomains;
  final String goal;
  final String? errorReason;
  final MemoryDomain? errorDomain;
  final bool requiresConsent;

  const CrossDomainSynthesisResult({
    required this.success,
    this.synthesizedNodes = const [],
    this.sourceDomains = const [],
    this.goal = '',
    this.errorReason,
    this.errorDomain,
    this.requiresConsent = false,
  });

  factory CrossDomainSynthesisResult.success({
    required List<EnhancedMiraNode> synthesizedNodes,
    required List<MemoryDomain> sourceDomains,
    required String goal,
  }) {
    return CrossDomainSynthesisResult(
      success: true,
      synthesizedNodes: synthesizedNodes,
      sourceDomains: sourceDomains,
      goal: goal,
    );
  }

  factory CrossDomainSynthesisResult.denied({
    required String reason,
    MemoryDomain? domain,
  }) {
    return CrossDomainSynthesisResult(
      success: false,
      errorReason: reason,
      errorDomain: domain,
    );
  }

  factory CrossDomainSynthesisResult.consentRequired({
    required List<MemoryDomain> domains,
    required String goal,
  }) {
    return CrossDomainSynthesisResult(
      success: false,
      sourceDomains: domains,
      goal: goal,
      requiresConsent: true,
      errorReason: 'User consent required for cross-domain synthesis',
    );
  }
}