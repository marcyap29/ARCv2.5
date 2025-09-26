import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:convert';
import '../../prism/mcp/import/mcp_import_service.dart';
import '../../prism/mcp/models/mcp_schemas.dart';
import '../../prism/mcp/export/mcp_export_service.dart';
import '../../prism/mcp/bundle/journal_bundle_writer.dart';
import '../../repositories/journal_repository.dart';
import '../../arc/models/journal_entry_model.dart' as model;
import '../../mira/mira_service.dart';
import '../../mira/core/schema.dart';
import '../../mira/core/ids.dart';

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
    this.selectedProfile = McpStorageProfile.balanced,
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
  McpImportService? _importService;

  McpSettingsCubit({
    required JournalRepository journalRepository,
  }) : _journalRepository = journalRepository,
       super(const McpSettingsState());

  /// Initialize MCP services
  void _initializeServices() {
    _importService = McpImportService(journalRepo: _journalRepository);
  }

  /// Set storage profile for export
  void setStorageProfile(McpStorageProfile profile) {
    emit(state.copyWith(selectedProfile: profile));
    _initializeServices();
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
      final journalRepo = JournalRepository();

      // Ensure MIRA is initialized with journal repository
      try {
        await miraService.initialize(journalRepo: journalRepo);
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
        storageProfile: _getStorageProfileString(state.selectedProfile),
        includeEvents: false,
      );
      print('🔍 MCP export completed, result dir: ${resultDir.path}');

      emit(state.copyWith(
        currentOperation: 'Export completed',
        progress: 1.0,
      ));

      // Read the actual counts from the generated files
      final manifestFile = File('${resultDir.path}/manifest.json');
      Map<String, dynamic> manifest = {};
      if (await manifestFile.exists()) {
        final manifestContent = await manifestFile.readAsString();
        manifest = jsonDecode(manifestContent);
      }

      final counts = manifest['counts'] as Map<String, dynamic>? ?? {};
      
      // Create result object
      final result = McpExportResult(
        success: true,
        bundleId: manifest['bundle_id']?.toString() ?? 'epi_export_${DateTime.now().millisecondsSinceEpoch}',
        outputDir: resultDir,
        manifestFile: manifestFile,
        ndjsonFiles: {
          'nodes': File('${resultDir.path}/nodes.jsonl'),
          'edges': File('${resultDir.path}/edges.jsonl'),
          'pointers': File('${resultDir.path}/pointers.jsonl'),
          'embeddings': File('${resultDir.path}/embeddings.jsonl'),
        },
        counts: McpCounts(
          nodes: counts['nodes'] ?? 0,
          edges: counts['edges'] ?? 0,
          pointers: counts['pointers'] ?? 0,
          embeddings: counts['embeddings'] ?? 0,
        ),
      );

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
    // Initialize import service with journal repository
    _importService ??= McpImportService(journalRepo: JournalRepository());

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

    return MiraNode.entry(
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
        ...?entry.metadata,
      },
    );
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
}
