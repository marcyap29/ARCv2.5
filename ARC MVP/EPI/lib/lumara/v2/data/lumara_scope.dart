// lib/lumara/v2/data/lumara_scope.dart
// Simplified scope system for LUMARA v2.0

import 'package:equatable/equatable.dart';

/// Simplified scope system for LUMARA v2.0
class LumaraScope extends Equatable {
  final bool journal;
  final bool drafts;
  final bool chats;
  final bool media;
  final bool phase;
  
  const LumaraScope({
    this.journal = true,
    this.drafts = true,
    this.chats = true,
    this.media = true,
    this.phase = true,
  });
  
  /// Default scope with all access enabled
  static const LumaraScope all = LumaraScope();
  
  /// Minimal scope with only journal access
  static const LumaraScope journalOnly = LumaraScope(
    journal: true,
    drafts: false,
    chats: false,
    media: false,
    phase: false,
  );
  
  /// Scope for reflection (journal + phase)
  static const LumaraScope reflection = LumaraScope(
    journal: true,
    drafts: false,
    chats: false,
    media: false,
    phase: true,
  );
  
  /// Scope for comprehensive analysis (all sources)
  static const LumaraScope comprehensive = LumaraScope();
  
  LumaraScope copyWith({
    bool? journal,
    bool? drafts,
    bool? chats,
    bool? media,
    bool? phase,
  }) {
    return LumaraScope(
      journal: journal ?? this.journal,
      drafts: drafts ?? this.drafts,
      chats: chats ?? this.chats,
      media: media ?? this.media,
      phase: phase ?? this.phase,
    );
  }
  
  /// Get enabled sources as a list
  List<String> get enabledSources {
    final sources = <String>[];
    if (journal) sources.add('journal');
    if (drafts) sources.add('drafts');
    if (chats) sources.add('chats');
    if (media) sources.add('media');
    return sources;
  }
  
  /// Check if any scope is enabled
  bool get hasAnyEnabled => journal || drafts || chats || media || phase;
  
  /// Check if specific scope is enabled
  bool hasScope(String scope) {
    switch (scope.toLowerCase()) {
      case 'journal':
        return journal;
      case 'drafts':
        return drafts;
      case 'chats':
        return chats;
      case 'media':
        return media;
      case 'phase':
        return phase;
      default:
        return false;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'journal': journal,
      'drafts': drafts,
      'chats': chats,
      'media': media,
      'phase': phase,
    };
  }
  
  factory LumaraScope.fromJson(Map<String, dynamic> json) {
    return LumaraScope(
      journal: json['journal'] as bool? ?? true,
      drafts: json['drafts'] as bool? ?? true,
      chats: json['chats'] as bool? ?? true,
      media: json['media'] as bool? ?? true,
      phase: json['phase'] as bool? ?? true,
    );
  }
  
  @override
  List<Object?> get props => [journal, drafts, chats, media, phase];
  
  @override
  String toString() {
    return 'LumaraScope(journal: $journal, drafts: $drafts, chats: $chats, media: $media, phase: $phase)';
  }
}
