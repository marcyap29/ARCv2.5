import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/polymeta/memory/enhanced_memory_schema.dart';
import 'package:my_app/arc/chat/widgets/attribution_display_widget.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import 'package:my_app/arc/chat/voice/audio_io.dart';

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

class _InlineReflectionBlockState extends State<InlineReflectionBlock> {
  AudioIO? _audioIO;
  
  @override
  void initState() {
    super.initState();
    _initializeAudioIO();
  }
  
  Future<void> _initializeAudioIO() async {
    try {
      _audioIO = AudioIO();
      await _audioIO!.initializeTTS();
    } catch (e) {
      debugPrint('Error initializing AudioIO: $e');
    }
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
    final bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final borderColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(width: 3, color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with LUMARA icon and phase
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LUMARA',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (widget.phase != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.phase!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Reflection content or loading indicator with progress meter
              // Unified with in-chat LUMARA loading indicator UI/UX
              if (widget.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                      const SizedBox(height: 12),
                      // Progress meter
                      LinearProgressIndicator(
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                )
              else ...[
                // Reflection content (different color to distinguish from user text)
                // Split content into paragraphs for better readability
                ..._buildParagraphs(widget.content, theme),
                
                // Attribution display (if available)
                if (widget.attributionTraces != null && widget.attributionTraces!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      print('InlineReflectionBlock: Rendering AttributionDisplayWidget with ${widget.attributionTraces!.length} traces');
                      return AttributionDisplayWidget(
                        traces: widget.attributionTraces!,
                        responseId: widget.blockId ?? 'journal_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                  ),
                ] else if (widget.attributionTraces != null) ...[
                  // Debug: Show why attributions aren't showing
                  Builder(
                    builder: (context) {
                      print('InlineReflectionBlock: Attribution traces is null or empty (null: ${widget.attributionTraces == null}, empty: ${widget.attributionTraces?.isEmpty ?? true})');
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                
                // Copy, star, and delete buttons (lower left - unified with in-chat UX)
                if (!widget.isLoading && widget.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
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
                      IconButton(
                        icon: Icon(Icons.volume_up, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _speakContent(),
                        tooltip: 'Speak',
                      ),
                      FutureBuilder<bool>(
                        future: widget.blockId != null
                            ? FavoritesService.instance.isFavorite(widget.blockId!)
                            : Future.value(false),
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              size: 16,
                              color: isFavorite
                                  ? Colors.amber
                                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: widget.blockId != null
                                ? () => _toggleFavorite(context)
                                : null,
                            tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onDelete,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _ActionButton(
                      label: 'Regenerate',
                      icon: Icons.refresh,
                      onPressed: widget.isLoading ? () {} : widget.onRegenerate,
                    ),
                    _ActionButton(
                      label: 'Soften tone',
                      icon: Icons.favorite_outline,
                      onPressed: widget.isLoading ? () {} : widget.onSoften,
                    ),
                    _ActionButton(
                      label: 'More depth',
                      icon: Icons.insights,
                      onPressed: widget.isLoading ? () {} : widget.onMoreDepth,
                    ),
                    _ActionButton(
                      label: 'Continue thought',
                      icon: Icons.play_arrow,
                      onPressed: widget.isLoading ? () {} : widget.onContinueThought,
                    ),
                    _ActionButton(
                      label: 'Explore LUMARA conversation options',
                      icon: Icons.chat,
                      onPressed: widget.isLoading ? () {} : widget.onContinueWithLumara,
                      isPrimary: true,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }

  /// Build paragraphs from content text with improved mobile readability
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
    
    // If still single paragraph, try splitting by sentence endings for better readability
    if (paragraphs.length == 1) {
      // Split by periods/exclamation/question marks followed by space and capital letter
      // This creates natural paragraph breaks for long responses
      final sentencePattern = RegExp(r'([.!?])\s+([A-Z])');
      final matches = sentencePattern.allMatches(content);
      
      if (matches.length >= 2) {
        paragraphs = [];
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            final sentence = content.substring(lastIndex, match.start + 1).trim();
            if (sentence.isNotEmpty) {
              paragraphs.add(sentence);
            }
            lastIndex = match.start + 1;
          }
        }
        if (lastIndex < content.length) {
          final remaining = content.substring(lastIndex).trim();
          if (remaining.isNotEmpty) {
            paragraphs.add(remaining);
          }
        }
      }
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
                height: 1.6, // Increased line height for better mobile readability
                fontSize: 15, // Slightly larger font for mobile
                color: theme.colorScheme.secondary,
                fontStyle: FontStyle.italic,
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
          fontSize: 15,
          color: theme.colorScheme.secondary,
          fontStyle: FontStyle.italic,
        ),
      )
    ] : widgets;
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
        final atCapacity = await FavoritesService.instance.isAtCapacity();
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

/// Action button for inline reflection block
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: isPrimary 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPrimary 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(44, 32), // Accessibility minimum
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
