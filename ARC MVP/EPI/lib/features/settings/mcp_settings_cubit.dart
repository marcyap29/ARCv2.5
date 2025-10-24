import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../prism/mcp/import/mcp_import_service.dart';
import '../../prism/mcp/models/mcp_schemas.dart';
import '../../arc/core/journal_repository.dart';
import '../../services/phase_regime_service.dart';
import 'package:my_app/models/journal_entry_model.dart' as model;
import '../../mira/mira_service.dart';
import '../../../mira/core/schema.dart';
import '../../../mira/core/ids.dart';
import '../../data/models/media_item.dart';

/// State for MCP settings operations
class McpSettingsState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final McpStorageProfile selectedProfile;
  final bool isExporting;
  final bool isImporting;
  final double progress;
  final String? currentOperation;

  const McpSettingsState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.selectedProfile = McpStorageProfile.hiFidelity,
    this.isExporting = false,
    this.isImporting = false,
    this.progress = 0.0,
    this.currentOperation,
  });

  McpSettingsState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    McpStorageProfile? selectedProfile,
    bool? isExporting,
    bool? isImporting,
    double? progress,
    String? currentOperation,
  }) {
    return McpSettingsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      selectedProfile: selectedProfile ?? this.selectedProfile,
      isExporting: isExporting ?? this.isExporting,
      isImporting: isImporting ?? this.isImporting,
      progress: progress ?? this.progress,
      currentOperation: currentOperation,
    );
  }
}

/// Cubit for managing MCP export and import operations
class McpSettingsCubit extends Cubit<McpSettingsState> {
  final JournalRepository _journalRepository;
  final PhaseRegimeService _phaseRegimeService;
  McpImportService? _importService;

  McpSettingsCubit({
    required JournalRepository journalRepository,
    required PhaseRegimeService phaseRegimeService,
  }) : _journalRepository = journalRepository,
       _phaseRegimeService = phaseRegimeService,
       super(const McpSettingsState());


  /// Refresh timeline after data changes
  void _refreshTimeline() {
    // This will be called from the UI layer where we have access to TimelineCubit
    // For now, we'll emit an event that the UI can listen to
    print('DEBUG: MCP import completed - timeline should refresh');
  }


  /// Export journal data to MCP format using MIRA system
  Future<Directory?> exportToMcp({
    required Directory outputDir,
    McpExportScope scope = McpExportScope.all,
    bool emitSuccessMessage = false,
  }) async {

    emit(state.copyWith(
      isLoading: true,
      isExporting: true,
      error: null,
      successMessage: null,
      currentOperation: 'Preparing export...',
      progress: 0.0,
    ));

    try {
      // Get all journal entries
      final journalEntries = _journalRepository.getAllJournalEntries();

      // Debug logging
      print('🔍 MCP Export Debug: Found ${journalEntries.length} journal entries');
      for (int i = 0; i < journalEntries.length && i < 3; i++) {
        final entry = journalEntries[i];
        print('🔍 Entry $i: id=${entry.id}, content length=${entry.content.length}, keywords=${entry.keywords.length}');
        print('🔍 Entry $i SAGE: ${entry.sageAnnotation != null ? "present" : "null"}');
      }

      emit(state.copyWith(
        currentOperation: 'Processing ${journalEntries.length} journal entries...',
        progress: 0.2,
      ));

      // Initialize MIRA service if needed
      final miraService = MiraService.instance;

      // Ensure MIRA is initialized with journal repository
      try {
        await miraService.initialize(journalRepo: _journalRepository);
      } catch (e) {
        // MIRA might already be initialized, continue
        print('⚠️ MIRA initialization warning: $e');
      }

      emit(state.copyWith(
        currentOperation: 'Populating semantic memory...',
        progress: 0.4,
      ));

      // Convert and populate MIRA with journal entries
      await _populateMiraWithJournalEntries(miraService, journalEntries);

      emit(state.copyWith(
        currentOperation: 'Generating MCP bundle...',
        progress: 0.7,
      ));

      // Export using MIRA's enhanced MCP export system
      print('🔍 Starting MCP export to: ${outputDir.path}');
      final resultDir = await miraService.exportToMcp(
        outputDir: outputDir,
        storageProfile: _getStorageProfileString(McpStorageProfile.hiFidelity),
        includeEvents: false,
      );
      print('🔍 MCP export completed, result dir: ${resultDir.path}');

      // After export, verify the nodes.jsonl file contains media
      await _verifyExportMedia(resultDir);

      emit(state.copyWith(
        currentOperation: 'Export completed',
        progress: 1.0,
      ));


      // Always end loading states; optionally emit a success snackbar
      if (emitSuccessMessage) {
        emit(state.copyWith(
          isLoading: false,
          isExporting: false,
          successMessage: 'MCP export completed successfully!\n'
              'Output: ${resultDir.path}\n'
              'Entries: ${journalEntries.length} journal entries exported',
          progress: 1.0,
          currentOperation: null,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          isExporting: false,
          progress: 1.0,
          currentOperation: null,
        ));
      }
      return resultDir;
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isExporting: false,
        error: 'Export error: $e',
        progress: 0.0,
        currentOperation: null,
      ));
      return null;
    }
  }

  /// Import MCP bundle
  Future<void> importFromMcp({
    required Directory bundleDir,
    McpImportOptions options = const McpImportOptions(),
  }) async {
    // Initialize import service with journal repository and phase regime service
    _importService ??= McpImportService(
      journalRepo: _journalRepository,
      phaseRegimeService: _phaseRegimeService,
    );

    emit(state.copyWith(
      isLoading: true,
      isImporting: true,
      error: null,
      successMessage: null,
      currentOperation: 'Validating MCP bundle...',
      progress: 0.0,
    ));

    try {
      emit(state.copyWith(
        currentOperation: 'Importing MCP bundle...',
        progress: 0.3,
      ));

      // Import MCP bundle
      final result = await _importService!.importBundle(bundleDir, options);

      if (result.success) {
        // Trigger timeline refresh after successful import
        _refreshTimeline();

      emit(state.copyWith(
          isLoading: false,
          isImporting: false,
          successMessage: 'MCP import completed successfully!\n'
              'Imported: ${result.counts['nodes'] ?? 0} nodes, '
              '${result.counts['edges'] ?? 0} edges\n'
              'Processing time: ${result.processingTime.inMilliseconds}ms',
        progress: 1.0,
          currentOperation: null,
        ));
      } else {
        // Enhanced error reporting with specific details
        String detailedError = result.message;
        if (result.errors.isNotEmpty) {
          detailedError += '\n\nDetails:\n${result.errors.take(3).join('\n')}';
          if (result.errors.length > 3) {
            detailedError += '\n... and ${result.errors.length - 3} more errors';
          }
        }
        if (result.warnings.isNotEmpty) {
          detailedError += '\n\nWarnings:\n${result.warnings.take(2).join('\n')}';
        }

      emit(state.copyWith(
        isLoading: false,
        isImporting: false,
          error: detailedError,
          progress: 0.0,
          currentOperation: null,
        ));
      }
    } catch (e) {
      // Enhanced exception handling with specific messaging
      String errorMessage = 'Import error: $e';

      // Provide specific guidance for common issues
      if (e.toString().contains('manifest.json not found')) {
        errorMessage = 'Import failed: ZIP file does not contain a valid MCP bundle.\n\n'
            'Expected structure:\n'
            '• manifest.json\n'
            '• nodes.jsonl\n'
            '• edges.jsonl\n\n'
            'Please ensure you\'re importing a properly exported MCP bundle.';
      } else if (e.toString().contains('schema_version')) {
        errorMessage = 'Import failed: Bundle was created with an incompatible version.\n\n'
            'Try re-exporting your data with the current version of the app.';
      } else if (e.toString().contains('Invalid JSON')) {
        errorMessage = 'Import failed: Bundle contains corrupted data.\n\n'
            'The manifest.json file is not valid JSON. Please re-export your data.';
      }
      
      emit(state.copyWith(
        isLoading: false,
        isImporting: false,
        error: errorMessage,
        progress: 0.0,
        currentOperation: null,
      ));
    }
  }

  /// Clear error message
  void clearError() {
    emit(state.copyWith(error: null));
  }

  /// Clear success message
  void clearSuccessMessage() {
    emit(state.copyWith(successMessage: null));
  }

  /// Reset state
  void reset() {
    emit(const McpSettingsState());
  }

  /// Populate MIRA repository with journal entries
  Future<void> _populateMiraWithJournalEntries(MiraService miraService, List<model.JournalEntry> entries) async {
    final repo = miraService.repo;

    print('🔍 MIRA Population: Processing ${entries.length} entries');

    for (final entry in entries) {
      // Convert journal entry to MIRA node
      final miraNode = _convertToMiraNode(entry);
      print('🔍 Created MIRA node: ${miraNode.id}, type=${miraNode.type}, content length=${miraNode.data['text']?.toString().length ?? 0}');
      await repo.upsertNode(miraNode);

      // Create keyword nodes and edges
      for (final keyword in entry.keywords) {
        final keywordNode = MiraNode.keyword(
          text: keyword,
          timestamp: entry.createdAt,
        );
        await repo.upsertNode(keywordNode);

        // Create mentions edge
        final edge = MiraEdge.mentions(
          src: miraNode.id,
          dst: keywordNode.id,
          timestamp: entry.createdAt,
        );
        await repo.upsertEdge(edge);
      }

      // Create phase node and edge if phase info exists
      if (entry.metadata != null && entry.metadata!['phase'] != null) {
        final phase = entry.metadata!['phase'].toString();
        final phaseNode = MiraNode.phase(
          text: phase,
          timestamp: entry.createdAt,
          metadata: {'source': 'journal_entry'},
        );
        await repo.upsertNode(phaseNode);

        final phaseEdge = MiraEdge.taggedAs(
          src: miraNode.id,
          dst: phaseNode.id,
          timestamp: entry.createdAt,
        );
        await repo.upsertEdge(phaseEdge);
      }
    }
  }

  /// Convert journal entry model to MIRA node
  MiraNode _convertToMiraNode(model.JournalEntry entry) {
    // Extract SAGE narrative from sageAnnotation field
    final sageAnnotation = entry.sageAnnotation;
    
    // DEBUG: Log media items for troubleshooting
    print('🔍 MCP Settings: Converting entry ${entry.id} with ${entry.media.length} media items');
    if (entry.media.isNotEmpty) {
      for (int i = 0; i < entry.media.length; i++) {
        final media = entry.media[i];
        print('🔍 Media $i: id=${media.id}, uri=${media.uri}, type=${media.type.name}');
        print('🔍 Media $i details: duration=${media.duration?.inSeconds}s, size=${media.sizeBytes} bytes');
        print('🔍 Media $i analysis: ${media.analysisData?.keys}');
      }
    } else {
      print('🔍 MCP Settings: Entry ${entry.id} has NO media items');
    }

    final miraNode = MiraNode.entry(
      id: deterministicEntryId(entry.content, entry.createdAt),
      narrative: entry.content,
      keywords: entry.keywords,
      timestamp: entry.createdAt,
      metadata: {
        'text': entry.content,
        'journal': {'text': entry.content},
        'narrative': {
          'situation': sageAnnotation?.situation ?? '',
          'action': sageAnnotation?.action ?? '',
          'growth': sageAnnotation?.growth ?? '',
          'essence': sageAnnotation?.essence ?? '',
        },
        'phase': entry.metadata?['phase'],
        'phase_hint': entry.metadata?['phase_hint'],
        'keywords': entry.keywords,
        'emotions': {
          'emotion': entry.emotion,
          'emotionReason': entry.emotionReason,
          'mood': entry.mood,
        },
        'original_entry_id': entry.id,
        'sage_confidence': sageAnnotation?.confidence,
        // Add media items with comprehensive metadata for all media types
        'media': entry.media.map((m) => {
          'id': m.id,
          'uri': m.uri,
          'type': m.type.name,
          'created_at': m.createdAt.toIso8601String(),
          'alt_text': m.altText,
          'ocr_text': m.ocrText,
          'transcript': m.transcript,
          'duration': m.duration?.inSeconds,
          'size_bytes': m.sizeBytes,
          'analysis_data': m.analysisData,
          // Future-proofing: Additional metadata based on media type
          'media_metadata': _getMediaTypeMetadata(m),
        }).toList(),
        ...?entry.metadata,
      },
    );

    // DEBUG: Log MIRA node metadata to verify media inclusion
    print('🔍 MCP Settings: MIRA node created for entry ${entry.id}');
    print('🔍 MIRA node metadata keys: ${miraNode.metadata.keys}');
    if (miraNode.metadata.containsKey('media')) {
      final mediaArray = miraNode.metadata['media'] as List;
      print('🔍 MIRA node has ${mediaArray.length} media items in metadata');
      for (int i = 0; i < mediaArray.length; i++) {
        final media = mediaArray[i] as Map<String, dynamic>;
        print('🔍 MIRA Media $i: ${media['type']} - ${media['uri']}');
      }
    } else {
      print('❌ MIRA node MISSING media field in metadata!');
    }

    return miraNode;
  }

  /// Convert storage profile enum to string
  String _getStorageProfileString(McpStorageProfile profile) {
    switch (profile) {
      case McpStorageProfile.minimal:
        return 'minimal';
      case McpStorageProfile.spaceSaver:
        return 'space_saver';
      case McpStorageProfile.balanced:
        return 'balanced';
      case McpStorageProfile.hiFidelity:
        return 'hi_fidelity';
    }
  }

  /// Get media-type-specific metadata for future-proofing
  Map<String, dynamic> _getMediaTypeMetadata(MediaItem media) {
    final baseMetadata = <String, dynamic>{
      'format': _getFileFormat(media.uri),
      'has_analysis': media.analysisData != null,
    };

    switch (media.type) {
      case MediaType.image:
        return {
          ...baseMetadata,
          'storage_location': 'photo_gallery',
          'accessibility': media.altText != null,
          'ocr_available': media.ocrText != null,
        };

      case MediaType.video:
        final duration = media.duration?.inSeconds ?? 0;
        final screenshotInterval = _getVideoScreenshotInterval(duration);
        return {
          ...baseMetadata,
          'storage_location': 'photo_gallery',
          'duration_seconds': duration,
          'screenshot_strategy': {
            'interval_seconds': screenshotInterval,
            'estimated_screenshots': duration > 0 ? (duration / screenshotInterval).ceil() : 0,
          },
          'transcription_available': media.transcript != null,
        };

      case MediaType.audio:
        return {
          ...baseMetadata,
          'storage_location': 'files_folder',
          'duration_seconds': media.duration?.inSeconds,
          'transcription_available': media.transcript != null,
          'transcript_length': media.transcript?.length ?? 0,
        };

      case MediaType.file:
        final format = _getFileFormat(media.uri).toLowerCase();
        if (format == 'pdf') {
          return {
            ...baseMetadata,
            'storage_location': 'files_folder',
            'document_type': 'pdf',
            'ocr_available': media.ocrText != null,
            'text_extraction': media.ocrText != null,
          };
        } else if (['doc', 'docx'].contains(format)) {
          return {
            ...baseMetadata,
            'storage_location': 'files_folder',
            'document_type': 'word',
            'text_extraction': media.ocrText != null,
            'word_count': _getWordCount(media.ocrText),
          };
        } else {
          return {
            ...baseMetadata,
            'storage_location': 'files_folder',
            'document_type': 'generic',
          };
        }
    }
  }

  /// Get file format from URI
  String _getFileFormat(String uri) {
    final extension = uri.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'mp4':
        return 'mp4';
      case 'mov':
        return 'mov';
      case 'mp3':
        return 'mp3';
      case 'wav':
        return 'wav';
      case 'm4a':
        return 'm4a';
      case 'pdf':
        return 'pdf';
      case 'doc':
        return 'doc';
      case 'docx':
        return 'docx';
      default:
        return extension;
    }
  }

  /// Get video screenshot interval based on duration
  int _getVideoScreenshotInterval(int durationSeconds) {
    if (durationSeconds <= 30) return 5;
    if (durationSeconds <= 60) return 10;
    if (durationSeconds <= 120) return 20;
    if (durationSeconds <= 300) return 30;
    return 60;
  }

  /// Get word count from text
  int _getWordCount(String? text) {
    if (text == null || text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  /// Verify that the exported nodes.jsonl file contains media data
  Future<void> _verifyExportMedia(Directory exportDir) async {
    try {
      final nodesFile = File(path.join(exportDir.path, 'nodes.jsonl'));
      if (await nodesFile.exists()) {
        final lines = await nodesFile.readAsLines();
        int entriesWithMedia = 0;
        int totalMediaItems = 0;
        
        for (final line in lines) {
          final node = jsonDecode(line);
          if (node['type'] == 'journal_entry' && node.containsKey('media')) {
            entriesWithMedia++;
            final media = node['media'] as List;
            totalMediaItems += media.length;
            
            // Check first media item for ph:// URI
            if (media.isNotEmpty) {
              final firstMedia = media[0] as Map<String, dynamic>;
              print('🔍 Export Verification: Entry ${node['id']} has ${media.length} media items');
              print('🔍   First media URI: ${firstMedia['uri']}');
            }
          }
        }
        
        print('✅ Export Verification: $entriesWithMedia entries with $totalMediaItems total media items');
      } else {
        print('⚠️ Export verification failed: nodes.jsonl file not found');
      }
    } catch (e) {
      print('⚠️ Export verification failed: $e');
    }
  }
}
