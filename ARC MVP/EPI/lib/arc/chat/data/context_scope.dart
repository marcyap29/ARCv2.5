import 'package:equatable/equatable.dart';

/// Defines what data LUMARA can access
class LumaraScope extends Equatable {
  final bool journal;
  final bool phase;
  final bool arcforms;
  final bool voice;
  final bool media;
  final bool drafts;
  final bool chats;

  const LumaraScope({
    this.journal = true,
    this.phase = true,
    this.arcforms = true,
    this.voice = true,
    this.media = true,
    this.drafts = true,
    this.chats = true,
  });

  /// Default scope with all options enabled
  static const LumaraScope defaultScope = LumaraScope(
    journal: true,
    phase: true,
    arcforms: true,
    voice: true,
    media: true,
    drafts: true,
    chats: true,
  );

  LumaraScope copyWith({
    bool? journal,
    bool? phase,
    bool? arcforms,
    bool? voice,
    bool? media,
    bool? drafts,
    bool? chats,
  }) {
    return LumaraScope(
      journal: journal ?? this.journal,
      phase: phase ?? this.phase,
      arcforms: arcforms ?? this.arcforms,
      voice: voice ?? this.voice,
      media: media ?? this.media,
      drafts: drafts ?? this.drafts,
      chats: chats ?? this.chats,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'journal': journal,
      'phase': phase,
      'arcforms': arcforms,
      'voice': voice,
      'media': media,
      'drafts': drafts,
      'chats': chats,
    };
  }

  factory LumaraScope.fromJson(Map<String, dynamic> json) {
    return LumaraScope(
      journal: json['journal'] as bool? ?? true,
      phase: json['phase'] as bool? ?? true,
      arcforms: json['arcforms'] as bool? ?? true,
      voice: json['voice'] as bool? ?? true,
      media: json['media'] as bool? ?? true,
      drafts: json['drafts'] as bool? ?? true,
      chats: json['chats'] as bool? ?? true,
    );
  }

  /// Check if any scope is enabled
  bool get hasAnyEnabled => journal || phase || arcforms || voice || media || drafts || chats;

  /// Get enabled scopes as a list
  List<String> get enabledScopes {
    final scopes = <String>[];
    if (journal) scopes.add('Journal');
    if (phase) scopes.add('Phase');
    if (arcforms) scopes.add('Arcforms');
    if (voice) scopes.add('Voice');
    if (media) scopes.add('Media');
    if (drafts) scopes.add('Drafts');
    if (chats) scopes.add('Chats');
    return scopes;
  }

  /// Check if a specific scope is enabled
  bool hasScope(String scope) {
    switch (scope.toLowerCase()) {
      case 'journal':
        return journal;
      case 'phase':
        return phase;
      case 'arcforms':
        return arcforms;
      case 'voice':
        return voice;
      case 'media':
        return media;
      case 'drafts':
        return drafts;
      case 'chats':
        return chats;
      default:
        return false;
    }
  }

  @override
  List<Object?> get props => [journal, phase, arcforms, voice, media, drafts, chats];
}