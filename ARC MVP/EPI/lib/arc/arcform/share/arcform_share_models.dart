// lib/arc/arcform/share/arcform_share_models.dart
// Data models for Arcform sharing system
// Implements "Identity Signaling Through Artifact" framework

import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Sharing mode: identity signaling through artifact
enum ArcShareMode {
  quiet,      // Mysterious artifact, minimal context
  reflective, // Personal insight + growth narrative
  signal,     // Professional growth + process intelligence
}

/// Social platform options (Tier 1 focus: Instagram + LinkedIn)
enum SocialPlatform {
  instagramStory,  // 1080x1920 (9:16) - Priority 1
  instagramFeed,   // 1080x1080 (1:1) - Priority 2
  linkedinFeed,     // 1200x627 (landscape) - Priority 3
  linkedinCarousel, // 1080x1080 (future)
}

/// Unified data model for Arcform share payloads
/// This is the single source of truth for sharing state
/// Implements "Identity Signaling Through Artifact" framework
class ArcformSharePayload extends Equatable {
  final ArcShareMode shareMode; // quiet, reflective, or signal
  final String arcformId; // "current" or specific snapshot id
  final String phase; // ATLAS phase name
  final List<String> keywords; // 5-10 Arcform keywords
  final SocialPlatform? platform; // Platform-specific format
  final String? userCaption; // User-authored caption (required for reflective/signal)
  final String? systemCaptionTemplate; // Suggested template based on mode
  final String altText; // visual description for accessibility
  final bool footerOptIn; // "About ARC" footer for social
  
  // Optional metrics (user-controlled)
  final bool includeDuration; // Show phase duration
  final bool includePhaseCount; // Show "3rd Discovery phase"
  final bool includeDateRange; // Show start/end dates
  
  // Generated assets
  final Uint8List? imageBytes; // Generated Arcform image
  
  // Timeline data for visualization
  final List<PhaseTimelineData>? timelineData; // Last 6 months
  
  // Phase metadata
  final DateTime? transitionDate;
  final int? phaseCount; // e.g., "3rd Discovery phase"
  final Duration? previousPhaseDuration;

  const ArcformSharePayload({
    required this.shareMode,
    required this.arcformId,
    required this.phase,
    required this.keywords,
    this.platform,
    this.userCaption,
    this.systemCaptionTemplate,
    this.altText = '',
    this.footerOptIn = true,
    this.includeDuration = false,
    this.includePhaseCount = false,
    this.includeDateRange = true,
    this.imageBytes,
    this.timelineData,
    this.transitionDate,
    this.phaseCount,
    this.previousPhaseDuration,
  });

  ArcformSharePayload copyWith({
    ArcShareMode? shareMode,
    String? arcformId,
    String? phase,
    List<String>? keywords,
    SocialPlatform? platform,
    String? userCaption,
    String? systemCaptionTemplate,
    String? altText,
    bool? footerOptIn,
    bool? includeDuration,
    bool? includePhaseCount,
    bool? includeDateRange,
    Uint8List? imageBytes,
    List<PhaseTimelineData>? timelineData,
    DateTime? transitionDate,
    int? phaseCount,
    Duration? previousPhaseDuration,
  }) {
    return ArcformSharePayload(
      shareMode: shareMode ?? this.shareMode,
      arcformId: arcformId ?? this.arcformId,
      phase: phase ?? this.phase,
      keywords: keywords ?? this.keywords,
      platform: platform ?? this.platform,
      userCaption: userCaption ?? this.userCaption,
      systemCaptionTemplate: systemCaptionTemplate ?? this.systemCaptionTemplate,
      altText: altText ?? this.altText,
      footerOptIn: footerOptIn ?? this.footerOptIn,
      includeDuration: includeDuration ?? this.includeDuration,
      includePhaseCount: includePhaseCount ?? this.includePhaseCount,
      includeDateRange: includeDateRange ?? this.includeDateRange,
      imageBytes: imageBytes ?? this.imageBytes,
      timelineData: timelineData ?? this.timelineData,
      transitionDate: transitionDate ?? this.transitionDate,
      phaseCount: phaseCount ?? this.phaseCount,
      previousPhaseDuration: previousPhaseDuration ?? this.previousPhaseDuration,
    );
  }

  /// Get the final message/caption to use for sharing
  /// For quiet mode: returns empty string (no caption)
  /// For reflective/signal: returns user caption or template
  String getFinalMessage() {
    if (shareMode == ArcShareMode.quiet) {
      return ''; // Quiet mode has no caption
    }
    return userCaption ?? systemCaptionTemplate ?? '';
  }

  /// Check if caption is required for current mode
  bool get requiresCaption => shareMode != ArcShareMode.quiet;

  /// Check if caption is valid (required length for reflective/signal)
  bool get isCaptionValid {
    if (!requiresCaption) return true;
    if (userCaption == null || userCaption!.isEmpty) return false;
    return userCaption!.trim().length >= 10 && userCaption!.trim().length <= 200;
  }

  @override
  List<Object?> get props => [
        shareMode,
        arcformId,
        phase,
        keywords,
        platform,
        userCaption,
        systemCaptionTemplate,
        altText,
        footerOptIn,
        includeDuration,
        includePhaseCount,
        includeDateRange,
        imageBytes,
        timelineData,
        transitionDate,
        phaseCount,
        previousPhaseDuration,
      ];
}

/// Phase timeline data for visualization
class PhaseTimelineData {
  final String phaseName;
  final DateTime start;
  final DateTime? end;
  final Color color;

  PhaseTimelineData({
    required this.phaseName,
    required this.start,
    this.end,
    required this.color,
  });

  Duration get duration => (end ?? DateTime.now()).difference(start);
  bool get isOngoing => end == null;
}
