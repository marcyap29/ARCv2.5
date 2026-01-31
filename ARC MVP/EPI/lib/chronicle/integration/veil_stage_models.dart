import '../models/chronicle_aggregation.dart';

/// VEIL cycle stages (subset relevant to CHRONICLE)
/// 
/// CHRONICLE synthesis implements the VEIL narrative integration cycle:
/// - VERBALIZE: Happens at journal entry creation (Layer 0)
/// - EXAMINE: Monthly synthesis (Layer 1)
/// - INTEGRATE: Yearly synthesis (Layer 2)
/// - LINK: Multi-year synthesis (Layer 3)
enum VeilStage {
  verbalize,  // Not implemented by CHRONICLE (happens at journal entry)
  examine,    // Layer 1: Monthly synthesis
  integrate,  // Layer 2: Yearly synthesis
  link,       // Layer 3: Multi-year synthesis
}

extension VeilStageExtension on VeilStage {
  String get displayName {
    switch (this) {
      case VeilStage.verbalize:
        return 'Verbalize';
      case VeilStage.examine:
        return 'Examine';
      case VeilStage.integrate:
        return 'Integrate';
      case VeilStage.link:
        return 'Link';
    }
  }
  
  String get description {
    switch (this) {
      case VeilStage.verbalize:
        return 'Immediate capture of lived experience';
      case VeilStage.examine:
        return 'Pattern recognition across recent entries';
      case VeilStage.integrate:
        return 'Synthesis into coherent narrative';
      case VeilStage.link:
        return 'Cross-temporal biographical connections';
    }
  }
  
  /// Get the CHRONICLE layer that implements this VEIL stage
  String get chronicleLayer {
    switch (this) {
      case VeilStage.verbalize:
        return 'layer0';
      case VeilStage.examine:
        return 'monthly';
      case VeilStage.integrate:
        return 'yearly';
      case VeilStage.link:
        return 'multiyear';
    }
  }
}

/// Result from executing VEIL cycle stages
class VeilCycleResult {
  final String userId;
  final String tier;
  final List<VeilStage> stagesExecuted = [];
  final Map<String, dynamic> details = {};
  bool success = false;
  String? error;
  
  VeilCycleResult({
    required this.userId,
    required this.tier,
  });
  
  /// Get summary of executed stages
  String getSummary() {
    if (!success) {
      return 'VEIL cycle failed: $error';
    }
    
    if (stagesExecuted.isEmpty) {
      return 'No VEIL stages executed (tier may not support synthesis)';
    }
    
    final stageNames = stagesExecuted.map((s) => s.displayName).join(', ');
    return 'VEIL stages executed: $stageNames';
  }
}

/// Result from a single VEIL stage
class StageResult {
  final VeilStage stage;
  final String period;
  final String summary;
  final ChronicleAggregation? aggregation;
  
  // Stage-specific data
  final List<String>? themes;
  final List<String>? chapters;
  final List<String>? metaPatterns;
  
  StageResult({
    required this.stage,
    required this.period,
    required this.summary,
    this.aggregation,
    this.themes,
    this.chapters,
    this.metaPatterns,
  });
}

/// Status of VEIL cycle for a user
class VeilCycleStatus {
  final DateTime? lastExamine;
  final String? examineSummary;
  
  final DateTime? lastIntegrate;
  final String? integrateSummary;
  
  final DateTime? lastLink;
  final String? linkSummary;
  
  final DateTime? nextCycle;
  
  VeilCycleStatus({
    this.lastExamine,
    this.examineSummary,
    this.lastIntegrate,
    this.integrateSummary,
    this.lastLink,
    this.linkSummary,
    this.nextCycle,
  });
}
