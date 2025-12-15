import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/arc/chat/widgets/attribution_display_widget.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/shared/widgets/lumara_action_menu.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import 'package:my_app/arc/chat/voice/audio_io.dart';
import 'package:my_app/shared/ui/settings/voiceover_preference_service.dart';

/// Inline reflection block that appears within journal entries
class InlineReflectionBlock extends StatefulWidget {
  final String content;
  final String intent; // ideas | think | perspective | next | analyze
  final String? phase; // e.g., "Recovery"
  final bool isLoading; // Whether LUMARA is currently generating insights
  final String? loadingMessage; // Optional loading message
  final VoidCallback onRegenerate;
  final VoidCallback onSoften;
  final VoidCallback onMoreDepth;
  final VoidCallback onContinueWithLumara;
  final VoidCallback onContinueThought;
  final VoidCallback onDelete;
  final List<AttributionTrace>? attributionTraces; // Memory attribution traces
  final String? blockId; // Unique ID for favorites tracking

  const InlineReflectionBlock({
    super.key,
    required this.content,
    required this.intent,
    this.phase,
    this.isLoading = false,
    this.loadingMessage,
    required this.onRegenerate,
    required this.onSoften,
    required this.onMoreDepth,
    required this.onContinueWithLumara,
    required this.onContinueThought,
    required this.onDelete,
    this.attributionTraces,
    this.blockId,
  });

  @override
  State<InlineReflectionBlock> createState() => _InlineReflectionBlockState();
}

class _InlineReflectionBlockState extends State<InlineReflectionBlock> with SingleTickerProviderStateMixin {
  AudioIO? _audioIO;
  bool _showActions = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAudioIO();
  }
  
  Future<void> _initializeAudioIO() async {
    try {
      _audioIO = AudioIO();
      await _audioIO!.initializeTTS();

      // Auto-speak content if Voice Responses is enabled - delay to ensure widget is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        await _speakContentIfEnabled();
      });
    } catch (e) {
      debugPrint('Error initializing AudioIO: $e');
    }
  }

  /// Check if reflection has web sources
  bool _hasWebSource() {
    if (widget.attributionTraces == null || widget.attributionTraces!.isEmpty) {
      return false;
    }
    
    // Check if any trace mentions web or external source
    for (final trace in widget.attributionTraces!) {
      final nodeRef = trace.nodeRef.toLowerCase();
      if (nodeRef.contains('web') || 
          nodeRef.contains('external') || 
          nodeRef.contains('search') ||
          trace.relation.toLowerCase().contains('web')) {
        return true;
      }
    }
    
    return false;
  }

  Future<void> _speakContent() async {
    try {
      if (_audioIO != null && widget.content.isNotEmpty) {
        // Clean text for speech (remove markdown, etc.)
        final cleanText = _cleanTextForSpeech(widget.content);
        if (cleanText.isNotEmpty) {
          await _audioIO!.speak(cleanText);
        }
      }
    } catch (e) {
      debugPrint('Error speaking content: $e');
    }
  }

  /// Speak content if Voice Responses setting is enabled
  Future<void> _speakContentIfEnabled() async {
    try {
      debugPrint('InlineReflectionBlock: Checking voice responses setting...');
      final voiceoverEnabled = await VoiceoverPreferenceService.instance.isVoiceoverEnabled();
      debugPrint('InlineReflectionBlock: Voice responses enabled: $voiceoverEnabled');
      debugPrint('InlineReflectionBlock: AudioIO available: ${_audioIO != null}');
      debugPrint('InlineReflectionBlock: Content available: ${widget.content.isNotEmpty}');

      if (voiceoverEnabled && _audioIO != null && widget.content.isNotEmpty) {
        // Clean text for speech (remove markdown, etc.)
        final cleanText = _cleanTextForSpeech(widget.content);
        debugPrint('InlineReflectionBlock: Clean text length: ${cleanText.length}');
        if (cleanText.isNotEmpty) {
          debugPrint('InlineReflectionBlock: Starting to speak LUMARA reflection...');
          await _audioIO!.speak(cleanText);
          debugPrint('InlineReflectionBlock: Speech completed');
        }
      } else {
        debugPrint('InlineReflectionBlock: Not speaking - voiceoverEnabled: $voiceoverEnabled, audioIO: ${_audioIO != null}, content: ${widget.content.isNotEmpty}');
      }
    } catch (e) {
      debugPrint('Error speaking content automatically: $e');
    }
  }

  String _cleanTextForSpeech(String text) {
    // Remove markdown formatting
    String cleaned = text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1') // Code
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // Links
        .replaceAll(RegExp(r'#{1,6}\s+'), '') // Headers
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Multiple newlines
        .trim();
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Remove card styling - make transparent and minimal (Rosebud style)
    final bg = Colors.transparent; 
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      // Minimal container without border or shadow
      decoration: BoxDecoration(
        color: bg,
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6), // Remove horizontal padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reflection content or loading indicator
              if (widget.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'LUMARA is thinking...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                // Reflection content (Blue color for LUMARA, distinct from user text)
                ..._buildParagraphs(widget.content, theme),
                
                // Web source indicator
                if (_hasWebSource()) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'External Information Used',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Attribution display (if available)
                if (widget.attributionTraces != null && widget.attributionTraces!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      return AttributionDisplayWidget(
                        traces: widget.attributionTraces!,
                        responseId: widget.blockId ?? 'journal_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                  ),
                ],
                
                // Minimal Action Row (Rosebud Style: Play, Share, Menu)
                if (!widget.isLoading && widget.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Speak (Play icon)
                      IconButton(
                        icon: Icon(Icons.play_arrow_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _speakContent(),
                        tooltip: 'Speak',
                      ),
                      const SizedBox(width: 8),
                      // Share (Replace Copy with Share)
                      IconButton(
                        icon: Icon(Icons.ios_share, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () {
                          // For now, copy to clipboard as requested functionality, but with share icon
                          Clipboard.setData(ClipboardData(text: widget.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('LUMARA response copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Copy',
                      ),
                      const SizedBox(width: 8),
                      // Favorite
                      FutureBuilder<bool>(
                        future: widget.blockId != null
                            ? FavoritesService.instance.isFavorite(widget.blockId!)
                            : Future.value(false),
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              size: 18,
                              color: isFavorite
                                  ? Colors.amber
                                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: widget.blockId != null
                                ? () => _toggleFavorite(context)
                                : null,
                            tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Delete (Moved to be just after Star)
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: widget.onDelete,
                        tooltip: 'Delete',
                      ),
                      const Spacer(),
                      // Toggle Action Menu
                      IconButton(
                        icon: Icon(
                          _showActions ? Icons.expand_less : Icons.tune,
                          size: 18,
                          color: _showActions 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () {
                          setState(() {
                            _showActions = !_showActions;
                          });
                        },
                        tooltip: 'More Actions',
                      ),
                    ],
                  ),
                  
                  // Expandable Action Row (Drops down below)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _showActions 
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                LumaraActionButton(
                                  label: 'Regenerate',
                                  icon: Icons.refresh,
                                  onPressed: widget.isLoading ? () {} : widget.onRegenerate,
                                ),
                                const SizedBox(width: 8),
                                LumaraActionButton(
                                  label: 'Soften tone',
                                  icon: Icons.favorite_outline,
                                  onPressed: widget.isLoading ? () {} : widget.onSoften,
                                ),
                                const SizedBox(width: 8),
                                LumaraActionButton(
                                  label: 'More depth',
                                  icon: Icons.insights,
                                  onPressed: widget.isLoading ? () {} : widget.onMoreDepth,
                                ),
                                const SizedBox(width: 8),
                                LumaraActionButton(
                                  label: 'Continue thought',
                                  icon: Icons.play_arrow,
                                  onPressed: widget.isLoading ? () {} : widget.onContinueThought,
                                ),
                                const SizedBox(width: 8),
                                LumaraActionButton(
                                  label: 'Explore LUMARA conversation options',
                                  icon: Icons.chat,
                                  onPressed: widget.isLoading ? () {} : widget.onContinueWithLumara,
                                  isPrimary: true,
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  ),
                ],
            ],
            ],
          ),
        ),
    );
  }

  /// Build paragraphs from content text with improved mobile readability
  /// For in-journal: min 10 words/sentence, min 2 sentences/paragraph, max 4 sentences/paragraph
  List<Widget> _buildParagraphs(String content, ThemeData theme) {
    if (content.trim().isEmpty) {
      return [const SizedBox.shrink()];
    }

    // Split by double newlines first (explicit paragraphs)
    List<String> paragraphs = content.split('\n\n');

    // Clean up paragraphs - remove single newlines within paragraphs
    paragraphs = paragraphs.map((p) => p.replaceAll('\n', ' ').trim()).toList();

    // If no double newlines, try splitting by single newlines
    if (paragraphs.length == 1 && content.contains('\n')) {
      paragraphs = content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }

    // If still single paragraph, apply in-journal formatting rules
    if (paragraphs.length == 1) {
      paragraphs = _formatInJournalParagraphs(content);
    }

    // Filter out empty paragraphs and build widgets with improved spacing
    final widgets = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 16 : 0),
            child: SelectableText(
              paragraph,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: 16, // Rosebud style: clear, readable text
                color: const Color(0xFF7C3AED), // Purple text for LUMARA (same as regular journal mode)
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }
    }

    return widgets.isEmpty ? [
      SelectableText(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          fontSize: 16,
          color: const Color(0xFF7C3AED), // Purple text for LUMARA (same as regular journal mode)
          fontWeight: FontWeight.w400,
        ),
      )
    ] : widgets;
  }

  /// Format content into paragraphs using in-journal rules:
  /// - Fixed: 2 sentences per paragraph
  List<String> _formatInJournalParagraphs(String content) {
    final sentences = _extractSentences(content);

    if (sentences.length < 2) {
      // If less than 2 sentences, return as single paragraph
      return [content];
    }

    final paragraphs = <String>[];

    // Group every 2 sentences together
    for (int i = 0; i < sentences.length; i += 2) {
      String paragraphText = sentences[i];

      // Add second sentence if available
      if (i + 1 < sentences.length) {
        paragraphText += ' ' + sentences[i + 1];
      }

      paragraphs.add(paragraphText.trim());
    }

    return paragraphs;
  }

  /// Extract sentences that meet minimum word requirements
  List<String> _extractValidSentences(String text, {required int minWords}) {
    final allSentences = _extractSentences(text);
    final validSentences = <String>[];

    for (final sentence in allSentences) {
      final wordCount = sentence.trim().split(RegExp(r'\s+')).length;
      if (wordCount >= minWords) {
        validSentences.add(sentence);
      } else {
        // If sentence is too short, try to combine with previous sentence
        if (validSentences.isNotEmpty) {
          final lastSentence = validSentences.removeLast();
          final combined = '$lastSentence $sentence';
          validSentences.add(combined);
        } else {
          // Keep short sentence as is if it's the first one
          validSentences.add(sentence);
        }
      }
    }

    return validSentences;
  }

  /// Fallback to simple 2-sentence grouping for edge cases
  List<String> _fallbackToSimpleGrouping(String content) {
    final sentences = _extractSentences(content);

    if (sentences.length >= 2) {
      final paragraphs = <String>[];

      // Group every 2 sentences together (previous behavior)
      for (int i = 0; i < sentences.length; i += 2) {
        String paragraphText = sentences[i];

        // Add second sentence if available
        if (i + 1 < sentences.length) {
          paragraphText += ' ' + sentences[i + 1];
        }

        paragraphs.add(paragraphText.trim());
      }

      return paragraphs;
    }

    return [content];
  }

  /// Extract sentences from text using improved sentence boundary detection
  List<String> _extractSentences(String text) {
    if (text.trim().isEmpty) return [];

    final sentences = <String>[];

    // Enhanced sentence pattern that handles:
    // - Standard endings: . ! ?
    // - Quotes and parentheses: "Hello." or (end).
    // - Abbreviations: handles common abbreviations like "Dr.", "etc.", "i.e."
    final sentencePattern = RegExp(
      r'(?<![A-Z][a-z]\.)\s*([^.!?]*[.!?]+(?:\s*["\)]*)?)\s*(?=[A-Z]|$)',
      multiLine: true,
    );

    final matches = sentencePattern.allMatches(text);

    if (matches.isEmpty) {
      // Fallback: if no clear sentence boundaries, return the whole text
      return [text.trim()];
    }

    for (final match in matches) {
      final sentence = match.group(1)?.trim();
      if (sentence != null && sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    // If we didn't capture everything, add remaining text
    final totalCaptured = matches.fold<int>(0, (sum, match) => sum + (match.group(0)?.length ?? 0));
    if (totalCaptured < text.length * 0.8) {
      // Fallback to simpler splitting if complex regex missed too much
      return _simpleSentenceSplit(text);
    }

    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }

  /// Simple sentence splitting as fallback
  List<String> _simpleSentenceSplit(String text) {
    // Split by sentence endings followed by whitespace and capital letter
    final parts = text.split(RegExp(r'([.!?])\s+(?=[A-Z])'));
    final sentences = <String>[];

    for (int i = 0; i < parts.length; i += 2) {
      String sentence = parts[i];
      if (i + 1 < parts.length) {
        sentence += parts[i + 1]; // Add the punctuation back
      }
      sentence = sentence.trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    return sentences.isNotEmpty ? sentences : [text.trim()];
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    if (widget.blockId == null) return;

    try {
      await FavoritesService.instance.initialize();
      final isFavorite = await FavoritesService.instance.isFavorite(widget.blockId!);

      if (isFavorite) {
        // Remove from favorites
        await FavoritesService.instance.removeFavoriteBySourceId(widget.blockId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from Favorites'),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {}); // Refresh UI
        }
      } else {
        // Add to favorites
        final atCapacity = await FavoritesService.instance.isCategoryAtCapacity('answer');
        if (atCapacity) {
          _showCapacityPopup(context);
          return;
        }

        final favorite = LumaraFavorite.fromMessage(
          content: widget.content,
          sourceId: widget.blockId!,
          sourceType: 'journal',
          metadata: {
            'phase': widget.phase,
            'intent': widget.intent,
          },
        );

        final added = await FavoritesService.instance.addFavorite(favorite);
        if (added && mounted) {
          // Always show snackbar with Manage link
          final isFirstTime = !await FavoritesService.instance.hasShownFirstTimeSnackbar();
          if (isFirstTime) {
            await FavoritesService.instance.markFirstTimeSnackbarShown();
          }
          _showFavoriteAddedSnackbar(context);
          setState(() {}); // Refresh UI
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  void _showCapacityPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorites Full'),
        content: const Text(
          'You have reached the maximum of 25 favorites. Please remove some favorites before adding new ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesManagementView(),
                ),
              );
            },
            child: const Text('Manage Favorites'),
          ),
        ],
      ),
    );
  }

  void _showFavoriteAddedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Added to Favorites',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'LUMARA will now adapt its style based on your favorites. Tap to manage them.',
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Manage',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FavoritesManagementView(),
              ),
            );
          },
        ),
      ),
    );
  }
}
