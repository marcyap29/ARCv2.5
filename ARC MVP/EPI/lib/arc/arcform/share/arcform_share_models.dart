// lib/arc/arcform/share/arcform_share_models.dart
// Data models for Arcform sharing system

import 'package:equatable/equatable.dart';

/// Sharing mode: direct (in-app user to user) or social (external platforms)
enum ArcShareMode {
  direct,
  social,
}

/// Social platform options
enum SocialPlatform {
  instagram,
  x,
  tiktok,
  linkedin,
}

/// Unified data model for Arcform share payloads
/// This is the single source of truth for sharing state
class ArcformSharePayload extends Equatable {
  final ArcShareMode shareMode;
  final String arcformId; // "current" or specific snapshot id
  final String phase; // ATLAS phase name
  final List<String> keywords; // 5-10 Arcform keywords
  final String? platform; // "instagram", "x", "tiktok", "linkedin" (social only)
  final String? systemMessage; // for direct share
  final String? userMessage; // user authored text for direct share
  final String? systemCaptionShort;
  final String? systemCaptionReflective;
  final String? systemCaptionTechnical;
  final String? userCaption; // user authored text for social share
  final String altText; // visual description for accessibility
  final bool footerOptIn; // "About ARC" footer for social

  const ArcformSharePayload({
    required this.shareMode,
    required this.arcformId,
    required this.phase,
    required this.keywords,
    this.platform,
    this.systemMessage,
    this.userMessage,
    this.systemCaptionShort,
    this.systemCaptionReflective,
    this.systemCaptionTechnical,
    this.userCaption,
    this.altText = '',
    this.footerOptIn = true,
  });

  ArcformSharePayload copyWith({
    ArcShareMode? shareMode,
    String? arcformId,
    String? phase,
    List<String>? keywords,
    String? platform,
    String? systemMessage,
    String? userMessage,
    String? systemCaptionShort,
    String? systemCaptionReflective,
    String? systemCaptionTechnical,
    String? userCaption,
    String? altText,
    bool? footerOptIn,
  }) {
    return ArcformSharePayload(
      shareMode: shareMode ?? this.shareMode,
      arcformId: arcformId ?? this.arcformId,
      phase: phase ?? this.phase,
      keywords: keywords ?? this.keywords,
      platform: platform ?? this.platform,
      systemMessage: systemMessage ?? this.systemMessage,
      userMessage: userMessage ?? this.userMessage,
      systemCaptionShort: systemCaptionShort ?? this.systemCaptionShort,
      systemCaptionReflective: systemCaptionReflective ?? this.systemCaptionReflective,
      systemCaptionTechnical: systemCaptionTechnical ?? this.systemCaptionTechnical,
      userCaption: userCaption ?? this.userCaption,
      altText: altText ?? this.altText,
      footerOptIn: footerOptIn ?? this.footerOptIn,
    );
  }

  /// Get the final message/caption to use for sharing
  /// Prioritizes user-authored content, falls back to system suggestions
  String getFinalMessage() {
    if (shareMode == ArcShareMode.direct) {
      return userMessage ?? systemMessage ?? '';
    } else {
      // For social, use user caption if provided, otherwise use short caption
      return userCaption ?? systemCaptionShort ?? '';
    }
  }

  /// Get the selected system caption based on user preference
  String? getSelectedSystemCaption(String? preference) {
    if (preference == null) return systemCaptionShort;
    switch (preference.toLowerCase()) {
      case 'short':
        return systemCaptionShort;
      case 'reflective':
        return systemCaptionReflective;
      case 'technical':
        return systemCaptionTechnical;
      default:
        return systemCaptionShort;
    }
  }

  @override
  List<Object?> get props => [
        shareMode,
        arcformId,
        phase,
        keywords,
        platform,
        systemMessage,
        userMessage,
        systemCaptionShort,
        systemCaptionReflective,
        systemCaptionTechnical,
        userCaption,
        altText,
        footerOptIn,
      ];
}

