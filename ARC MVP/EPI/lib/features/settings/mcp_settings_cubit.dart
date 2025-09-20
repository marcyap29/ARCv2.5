import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../mcp/export/mcp_export_service.dart';
import '../../mcp/import/mcp_import_service.dart';
import '../../mcp/models/mcp_schemas.dart';
import '../../repositories/journal_repository.dart';
import '../../models/journal_entry_model.dart' as model;

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
  McpExportService? _exportService;
  McpImportService? _importService;

  McpSettingsCubit({
    required JournalRepository journalRepository,
  }) : _journalRepository = journalRepository,
       super(const McpSettingsState());

  /// Initialize MCP services
  void _initializeServices() {
    _exportService = McpExportService(
      storageProfile: state.selectedProfile,
      notes: 'EPI ARC MVP Export - ${DateTime.now().toIso8601String()}',
    );
    _importService = McpImportService();
  }

  /// Set storage profile for export
  void setStorageProfile(McpStorageProfile profile) {
    emit(state.copyWith(selectedProfile: profile));
    _initializeServices();
  }

  /// Export journal data to MCP format
  Future<McpExportResult?> exportToMcp({
    required Directory outputDir,
    McpExportScope scope = McpExportScope.all,
    bool emitSuccessMessage = false,
  }) async {
    if (_exportService == null) {
      _initializeServices();
    }

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
      
      emit(state.copyWith(
        currentOperation: 'Processing ${journalEntries.length} journal entries...',
        progress: 0.2,
      ));

      // Convert JournalEntry models to MCP format
      final mcpJournalEntries = journalEntries.map((entry) => _convertToMcpJournalEntry(entry)).toList();
      
      // Export to MCP format
      final result = await _exportService!.exportToMcp(
        outputDir: outputDir,
        scope: scope,
        journalEntries: mcpJournalEntries,
      );

      if (result.success) {
        // Always end loading states; optionally emit a success snackbar
        if (emitSuccessMessage) {
          emit(state.copyWith(
            isLoading: false,
            isExporting: false,
            successMessage: 'MCP export completed successfully!\n'
                'Bundle ID: ${result.bundleId}\n'
                'Output: ${result.outputDir.path}\n'
                    'Files: ${result.ndjsonFiles?.length ?? 0}',
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
        return result;
      } else {
        emit(state.copyWith(
          isLoading: false,
          isExporting: false,
          error: 'Export failed: ${result.error}',
          progress: 0.0,
          currentOperation: null,
        ));
        return null;
      }
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
    _importService ??= McpImportService();

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

  /// Convert JournalEntry model to MCP JournalEntry format
  JournalEntry _convertToMcpJournalEntry(model.JournalEntry entry) {
    // Create MCP JournalEntry object
    return JournalEntry(
      id: entry.id,
      content: entry.content,
      createdAt: entry.createdAt,
      tags: entry.keywords.toSet(),
      userId: 'default_user', // TODO: Get actual user ID
      metadata: entry.metadata ?? {},
    );
  }
}
