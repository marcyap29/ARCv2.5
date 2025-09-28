import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/journal_entry_state.dart';
import '../../state/feature_flags.dart';
import '../../telemetry/analytics.dart';
import '../../services/lumara/lumara_inline_api.dart';
import '../../services/ocr/ocr_service.dart';
import '../../services/journal_session_cache.dart';
import '../../arc/core/keyword_extraction_cubit.dart';
import '../../arc/core/journal_capture_cubit.dart';
import '../../arc/core/journal_repository.dart';
import '../../arc/core/widgets/keyword_analysis_view.dart';
import 'widgets/lumara_fab.dart';
import 'widgets/lumara_suggestion_sheet.dart';
import 'widgets/inline_reflection_block.dart';

/// Main journal screen with integrated LUMARA companion and OCR scanning
class JournalScreen extends StatefulWidget {
  final String? selectedEmotion;
  final String? selectedReason;
  
  const JournalScreen({
    super.key,
    this.selectedEmotion,
    this.selectedReason,
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final JournalEntryState _entryState = JournalEntryState();
  final Analytics _analytics = Analytics();
  late final LumaraInlineApi _lumaraApi;
  late final OcrService _ocrService;

  @override
  void initState() {
    super.initState();
    _lumaraApi = LumaraInlineApi(_analytics);
    _ocrService = StubOcrService(_analytics); // TODO: Use platform-specific implementation
    _analytics.logJournalEvent('opened');
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    setState(() {
      _entryState.text = text;
    });
  }

  void _onLumaraFabTapped() {
    _analytics.logLumaraEvent('fab_tapped');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LumaraSuggestionSheet(
        onSelect: _onLumaraIntentSelected,
      ),
    );
  }

  Future<void> _onLumaraIntentSelected(LumaraIntent intent) async {
    _analytics.logLumaraEvent('suggestion_selected', data: {
      'intent': intent.name,
    });

    try {
      final reflection = await _lumaraApi.generatePromptedReflection(
        entryText: _entryState.text,
        intent: intent.name,
        phase: _entryState.phase,
      );

      final block = InlineBlock(
        type: 'inline_reflection',
        intent: intent.name,
        content: reflection,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.addReflection(block);
      });

      _analytics.logLumaraEvent('inline_reflection_inserted', data: {
        'intent': intent.name,
        'phase': _entryState.phase,
      });

      // Scroll to show the new reflection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          try {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } catch (e) {
            // Handle scroll animation errors gracefully
          }
        }
      });
    } catch (e) {
      _analytics.log('lumara_error', {'error': e.toString()});
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate reflection: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onScanPage() async {
    if (!FeatureFlags.scanPage) return;

    _analytics.logScanEvent('started');
    
    // TODO: Implement camera scanning flow
    // For MVP, simulate scanning
    await _simulateScanning();
  }

  Future<void> _simulateScanning() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Scanning page...'),
          ],
        ),
      ),
    );

    try {
      // Simulate OCR processing
      final mockImageFile = await _createMockImageFile();
      final extractedText = await _ocrService.extractText(mockImageFile);
      
      // Create scan attachment
      final attachment = ScanAttachment(
        type: 'ocr_text',
        text: extractedText,
        sourceImageId: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _entryState.addAttachment(attachment);
      });

      _analytics.logScanEvent('completed', data: {
        'text_length': extractedText.length,
      });

      // Show preview dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showScanPreview(extractedText);
      }
    } catch (e) {
      _analytics.log('scan_error', {'error': e.toString()});
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<File> _createMockImageFile() async {
    // Create a mock file for testing
    // In real implementation, this would be the captured image
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/mock_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes([]); // Empty file for mock
    return file;
  }

  void _showScanPreview(String extractedText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanned Text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(extractedText),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _insertTextIntoEntry(extractedText);
                  },
                  child: const Text('Insert into entry'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _insertTextIntoEntry(String text) {
    final currentText = _textController.text;
    final cursorPosition = _textController.selection.baseOffset;
    
    final newText = currentText.substring(0, cursorPosition) + 
                   '\n\n$text' + 
                   currentText.substring(cursorPosition);
    
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: cursorPosition + text.length + 2,
    );
    
    _onTextChanged(newText);
  }

  void _onContinue() {
    _analytics.logJournalEvent('continue_pressed', data: {
      'text_length': _entryState.text.length,
      'reflection_count': _entryState.blocks.length,
    });
    
    // Navigate to keyword analysis
    Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => JournalCaptureCubit(context.read<JournalRepository>()),
            ),
            BlocProvider(
              create: (context) => KeywordExtractionCubit()..initialize(),
            ),
          ],
          child: KeywordAnalysisView(
            content: _entryState.text,
            mood: widget.selectedEmotion ?? 'Other',
            initialEmotion: widget.selectedEmotion,
            initialReason: widget.selectedReason,
          ),
        ),
      ),
    ).then((result) {
      // Handle save result - if saved successfully, go back to home
      if (result != null && result['save'] == true) {
        // Clear the session cache since entry was saved
        JournalSessionCache.clearSession();
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Write what is true right now'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.home),
            tooltip: 'Home',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true, // Ensure safe area at bottom for navigation
        child: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Text input area
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Bottom padding for FAB and nav
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Main text field
                      TextField(
                        controller: _textController,
                        onChanged: _onTextChanged,
                        maxLines: null,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind right now?',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 16),
                      
                      // Inline reflection blocks
                      ..._entryState.blocks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final block = entry.value;
                        return InlineReflectionBlock(
                          content: block.content,
                          intent: block.intent,
                          phase: block.phase,
                          onRegenerate: () => _onRegenerateReflection(index),
                          onSoften: () => _onSoftenReflection(index),
                          onMoreDepth: () => _onMoreDepthReflection(index),
                          onContinueWithLumara: _onContinueWithLumara,
                        );
                      }),
                      
                      // Scan attachments
                      ..._entryState.attachments.map((attachment) => _buildScanAttachment(attachment)),
                    ],
                  ),
                ),
              ),
              
              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Add media button
                    IconButton(
                      onPressed: () {
                        // TODO: Implement media picker
                        _analytics.logJournalEvent('media_button_pressed');
                      },
                      icon: const Icon(Icons.add_photo_alternate),
                      tooltip: 'Add Media',
                    ),
                    
                    // Scan page button
                    if (FeatureFlags.scanPage)
                      IconButton(
                        onPressed: _onScanPage,
                        icon: const Icon(Icons.document_scanner),
                        tooltip: 'Scan Page',
                      ),
                    
                    const Spacer(),
                    
                    // Reflect with LUMARA button (secondary)
                    if (_entryState.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: _onLumaraFabTapped,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Reflect with LUMARA'),
                      ),
                    
                    const SizedBox(width: 8),
                    
                    // Continue button (primary)
                    ElevatedButton(
                      onPressed: _entryState.text.isNotEmpty ? _onContinue : null,
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // LUMARA floating action button
          if (FeatureFlags.inlineLumara)
            Positioned(
              right: 16,
              bottom: 100, // Above the bottom action bar
              child: LumaraFab(
                nudge: _entryState.showLumaraNudge,
                reducedMotion: reducedMotion,
                onTap: _onLumaraFabTapped,
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildScanAttachment(ScanAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Scanned Text',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            attachment.text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _insertTextIntoEntry(attachment.text),
                child: const Text('Insert into entry'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _entryState.attachments.remove(attachment);
                  });
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onRegenerateReflection(int index) async {
    final block = _entryState.blocks[index];
    try {
      final newReflection = await _lumaraApi.generatePromptedReflection(
        entryText: _entryState.text,
        intent: block.intent,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: newReflection,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
        );
      });
    } catch (e) {
      _analytics.log('lumara_regenerate_error', {'error': e.toString()});
    }
  }

  Future<void> _onSoftenReflection(int index) async {
    final block = _entryState.blocks[index];
    try {
      final softerReflection = await _lumaraApi.generateSofterReflection(
        entryText: _entryState.text,
        intent: block.intent,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: softerReflection,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
        );
      });
    } catch (e) {
      _analytics.log('lumara_soften_error', {'error': e.toString()});
    }
  }

  Future<void> _onMoreDepthReflection(int index) async {
    final block = _entryState.blocks[index];
    try {
      final deeperReflection = await _lumaraApi.generateDeeperReflection(
        entryText: _entryState.text,
        intent: block.intent,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: deeperReflection,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
        );
      });
    } catch (e) {
      _analytics.log('lumara_depth_error', {'error': e.toString()});
    }
  }

  void _onContinueWithLumara() {
    _analytics.logLumaraEvent('continue_with_lumara_opened_chat');
    
    // TODO: Navigate to full LUMARA chat screen
    // This would open the existing LUMARA assistant screen
    Navigator.of(context).pushNamed('/lumara-chat', arguments: {
      'seed': _entryState.text,
      'phase': _entryState.phase,
    });
  }
}
