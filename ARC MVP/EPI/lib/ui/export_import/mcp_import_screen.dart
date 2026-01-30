import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart' show McpPackImportService, McpImportResult;
import 'package:my_app/mira/store/mcp/import/enhanced_mcp_import_service.dart';
import 'package:my_app/mira/store/mcp/import/mcp_import_service.dart' show McpImportOptions;
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import '../../utils/file_utils.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/mira/store/arcx/services/arcx_import_service_v2.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:my_app/mira/store/arcx/services/arcx_import_service.dart';
import 'package:my_app/mira/store/arcx/models/arcx_result.dart';
import 'package:my_app/shared/ui/home/home_view.dart';

/// MCP Import Screen - Restore from MCP Package (.zip) or Secure Archive (.arcx)
class McpImportScreen extends StatefulWidget {
  const McpImportScreen({super.key});

  @override
  State<McpImportScreen> createState() => _McpImportScreenState();

  /// Show ARCX import success dialog (e.g. from HomeView when background import completes).
  static void showARCXImportSuccessDialog(BuildContext context, ARCXImportResultV2 result) {
    Widget summaryRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: bodyStyle(context), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(value, style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        child: SafeArea(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Import Complete', style: heading2Style(ctx))),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your data has been successfully restored!', style: bodyStyle(ctx)),
                        const SizedBox(height: 16),
                        summaryRow('Entries restored:', result.entriesTotalInArchive != null
                            ? '${result.entriesImported} of ${result.entriesTotalInArchive}'
                                + (result.entriesFailed != null && result.entriesFailed! > 0 ? ' (${result.entriesFailed} failed)' : '')
                            : '${result.entriesImported}'),
                        summaryRow('Media restored:', '${result.mediaImported}'),
                        if (result.chatsImported > 0) summaryRow('Chat sessions:', '${result.chatsImported}'),
                        summaryRow('LUMARA Favorites:', '${result.lumaraFavoritesImported}'),
                        if (result.warnings != null && result.warnings!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Warnings:', style: bodyStyle(ctx).copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
                          ...result.warnings!.map((w) => Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Text('• $w', style: bodyStyle(ctx).copyWith(fontSize: 12, color: Colors.orange)))),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _McpImportScreenState extends State<McpImportScreen> {
  bool _isImporting = false;
  String? _selectedPath;
  List<String> _selectedPaths = [];
  String? _detectedFormat;
  bool _isSeparatedPackage = false;
  Map<String, String> _detectedGroups = {}; // groupType -> filePath

  Future<void> _continueImportFromFolder() async {
    if (_isImporting) return;
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath == null || !mounted) return;
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        _showErrorDialog('Folder does not exist');
        return;
      }
      setState(() => _isImporting = true);
      PhaseRegimeService? phaseRegimeService;
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
      } catch (_) {}
      final journalRepo = context.read<JournalRepository>();
      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      final importService = ARCXImportServiceV2(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
      final preview = await importService.getImportSetDiffPreview(folder);
      final filesToImport = preview['filesToImport'] as int? ?? 0;
      final filesAlreadyImported = preview['filesAlreadyImported'] as int? ?? 0;
      final filesInFolder = preview['filesInFolder'] as int? ?? 0;
      if (!mounted) return;
      setState(() => _isImporting = false);
      if (filesInFolder == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No .arcx files found in this folder'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (filesToImport == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All $filesAlreadyImported file(s) in this folder have already been imported.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Continue Import from Folder'),
          content: Text(
            'Found $filesInFolder .arcx file(s). $filesAlreadyImported already imported, $filesToImport to import.\n\nProceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _isImporting = true);
      _showProgressDialog();
      final continueResult = await importService.importContinueFromFolder(
        folder: folder,
        options: ARCXImportOptions(
          validateChecksums: true,
          dedupeMedia: true,
          skipExisting: true,
          resolveLinks: true,
        ),
        password: null,
        onProgress: (message, [fraction = 0.0]) {
          if (mounted) {
            // Progress dialog is already shown; could update message if needed
          }
        },
      );
      if (mounted) Navigator.of(context).pop();
      setState(() => _isImporting = false);
      if (continueResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              continueResult.filesProcessed == 0
                  ? 'Export set is up to date.'
                  : 'Imported ${continueResult.filesProcessed} file(s): '
                    '${continueResult.totalEntriesImported} entries, '
                    '${continueResult.totalChatsImported} chats, '
                    '${continueResult.totalMediaImported} media.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.read<TimelineCubit>().reloadAllEntries();
      } else {
        _showErrorDialog(
          continueResult.errors?.join('\n') ?? 'Import failed',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        Navigator.of(context).pop();
      }
      _showErrorDialog('Continue import failed: $e');
    }
  }

  Future<void> _selectMcpFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'mcpkg', 'arcx'],
        allowMultiple: true, // Allow multiple files for separated packages
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
        
        // Check if these are .arcx files (separated packages)
        final arcxFiles = files.where((p) => p.endsWith('.arcx')).toList();
        
        if (arcxFiles.isNotEmpty) {
          // Try to detect separated packages
          await _detectSeparatedPackages(arcxFiles);
        }
        
        String? format;
        if (files.any((p) => p.endsWith('.arcx'))) {
          format = 'Secure Archive (.arcx)';
          if (files.length > 1) {
            format = '${files.length} Secure Archives (.arcx) - Separated Packages';
          }
        } else if (files.any((p) => FileUtils.isMcpPackage(p))) {
          format = 'MCP Package (.zip)';
        } else {
          format = 'Unknown';
        }
        
        setState(() {
          _selectedPaths = files;
          _selectedPath = files.length == 1 ? files.first : null;
          _detectedFormat = format;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to select file: $e');
    }
  }
  
  Future<void> _detectSeparatedPackages(List<String> arcxFiles) async {
    try {
      final detectedGroups = <String, String>{};
      final exportIds = <String>[];
      final baseExportIds = <String>{}; // Base export IDs (without suffixes like -entries-chats, -media)
      
      for (final filePath in arcxFiles) {
        try {
          final file = File(filePath);
          if (!await file.exists()) continue;
          
          // Extract manifest to check scope
          final arcxZip = await file.readAsBytes();
          final zipDecoder = ZipDecoder();
          final archive = zipDecoder.decodeBytes(arcxZip);
          
          ArchiveFile? manifestFile;
          for (final f in archive) {
            if (f.name == 'manifest.json') {
              manifestFile = f;
              break;
            }
          }
          
          if (manifestFile != null) {
            final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
            final scope = manifestJson['scope'] as Map<String, dynamic>?;
            final exportId = manifestJson['export_id'] as String?;
            
            if (exportId != null) {
              exportIds.add(exportId);
              
              // Extract base export ID (remove suffixes like -entries-chats, -media, -entries, -chats)
              String baseExportId = exportId;
              if (exportId.contains('-entries-chats')) {
                baseExportId = exportId.replaceAll('-entries-chats', '');
              } else if (exportId.contains('-media')) {
                baseExportId = exportId.replaceAll('-media', '');
              } else if (exportId.contains('-entries')) {
                baseExportId = exportId.replaceAll('-entries', '');
              } else if (exportId.contains('-chats')) {
                baseExportId = exportId.replaceAll('-chats', '');
              }
              baseExportIds.add(baseExportId);
              
              // Check if this is a separated package (separate_groups flag or has suffix indicating separation)
              final isSeparated = (scope != null && scope['separate_groups'] == true) ||
                                  exportId.contains('-entries-chats') ||
                                  exportId.contains('-media') ||
                                  exportId.contains('-entries') ||
                                  exportId.contains('-chats');
              
              if (isSeparated) {
                // Determine group type from export ID suffix, scope, or file name
                final fileName = path.basename(filePath).toLowerCase();
                String groupType = 'Unknown';
                
                // Check export ID suffix first (most reliable)
                if (exportId.contains('-entries-chats')) {
                  groupType = 'Entries+Chats';
                } else if (exportId.contains('-media')) {
                  groupType = 'Media';
                } else if (exportId.contains('-entries')) {
                  groupType = 'Entries';
                } else if (exportId.contains('-chats')) {
                  groupType = 'Chats';
                } else if (scope != null) {
                  // Fall back to scope counts
                  if (scope['entries_count'] != null && (scope['entries_count'] as int) > 0) {
                    if (scope['chats_count'] != null && (scope['chats_count'] as int) > 0) {
                      groupType = 'Entries+Chats';
                    } else {
                      groupType = 'Entries';
                    }
                  } else if (scope['chats_count'] != null && (scope['chats_count'] as int) > 0) {
                    groupType = 'Chats';
                  } else if (scope['media_count'] != null && (scope['media_count'] as int) > 0) {
                    groupType = 'Media';
                  }
                }
                
                // Final fallback to file name
                if (groupType == 'Unknown') {
                  if (fileName.contains('entries') && fileName.contains('chat')) {
                    groupType = 'Entries+Chats';
                  } else if (fileName.contains('entries') || fileName.contains('entry')) {
                    groupType = 'Entries';
                  } else if (fileName.contains('chats') || fileName.contains('chat')) {
                    groupType = 'Chats';
                  } else if (fileName.contains('media')) {
                    groupType = 'Media';
                  }
                }
                
                if (groupType != 'Unknown') {
                  detectedGroups[groupType] = filePath;
                }
              }
            }
          }
        } catch (e) {
          print('Warning: Could not read manifest from $filePath: $e');
        }
      }
      
      // Check if all files share the same base exportId (they're from the same export)
      // This handles both 3-archive format (same exportId) and 2-archive format (base exportId with suffixes)
      if (baseExportIds.length == 1 && detectedGroups.length > 1) {
        setState(() {
          _isSeparatedPackage = true;
          _detectedGroups = detectedGroups;
        });
      }
    } catch (e) {
      print('Warning: Could not detect separated packages: $e');
    }
  }


  Future<void> _importMcpData() async {
    if (_isImporting || (_selectedPath == null && _selectedPaths.isEmpty)) return;

    setState(() {
      _isImporting = true;
    });

    try {
      // Check if we have separated packages
      if (_isSeparatedPackage && _detectedGroups.isNotEmpty) {
        // Import separated packages in order: Media → Entries → Chats
        await _importSeparatedPackages();
      } else if (_selectedPaths.isNotEmpty && _selectedPaths.any((p) => p.endsWith('.arcx'))) {
        // Multiple .arcx files but not detected as separated - import them all
        await _importMultipleArcFiles(_selectedPaths);
      } else if (_selectedPath != null && _selectedPath!.endsWith('.arcx')) {
        // Single .arcx import - run in background; mini status bar on HomeView shows progress
        final arcxFile = File(_selectedPath!);
        if (!await arcxFile.exists()) {
          _showErrorDialog('ARCX file not found');
          setState(() => _isImporting = false);
          return;
        }
        if (!mounted) return;
        final progressCubit = context.read<ImportProgressCubit>();
        final journalRepo = context.read<JournalRepository>();
        final arcxPath = _selectedPath!;
        setState(() => _isImporting = false);
        progressCubit.start();
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        Future(() async {
          try {
            final chatRepo = ChatRepoImpl.instance;
            await chatRepo.initialize();
            PhaseRegimeService? phaseRegimeService;
            try {
              final analyticsService = AnalyticsService();
              final rivetSweepService = RivetSweepService(analyticsService);
              phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
              await phaseRegimeService.initialize();
            } catch (_) {}
            final importService = ARCXImportServiceV2(
              journalRepo: journalRepo,
              chatRepo: chatRepo,
              phaseRegimeService: phaseRegimeService,
            );
            final result = await importService.import(
              arcxPath: arcxPath,
              options: ARCXImportOptions(
                validateChecksums: true,
                dedupeMedia: true,
                skipExisting: true,
                resolveLinks: true,
              ),
              password: null,
              onProgress: (message, [fraction = 0.0]) {
                progressCubit.update(message, fraction);
              },
            );
            if (result.success) {
              progressCubit.complete(result);
            } else {
              progressCubit.fail(result.error);
            }
          } catch (e) {
            progressCubit.fail(e.toString());
          }
        });
      } else {
        // Legacy MCP (.zip) import
        final journalRepo = context.read<JournalRepository>();
        
        // Initialize PhaseRegimeService for import
        PhaseRegimeService? phaseRegimeService;
        try {
          final analyticsService = AnalyticsService();
          final rivetSweepService = RivetSweepService(analyticsService);
          phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
          await phaseRegimeService.initialize();
          print('MCP Import: PhaseRegimeService initialized');
        } catch (e) {
          print('Warning: Could not initialize PhaseRegimeService: $e');
        }
        
        // Initialize ChatRepo for chat import
        final chatRepo = ChatRepoImpl.instance;
        await chatRepo.initialize();
        
        final importService = McpPackImportService(
          journalRepo: journalRepo,
          phaseRegimeService: phaseRegimeService,
          chatRepo: chatRepo,
        );

        // Show progress dialog
        _showProgressDialog();

        // Import basic journal data
        final importResult = await importService.importFromPath(_selectedPath!);

        // Hide progress dialog
        Navigator.of(context).pop();

        if (importResult.success) {
          // Also import chats and favorites if nodes.jsonl exists (Enhanced MCP format)
          int chatSessionsImported = 0;
          int chatMessagesImported = 0;
          int lumaraFavoritesImported = 0;
          int lumaraFavoritesTotal = 0;
          
          try {
            final tempDir = Directory.systemTemp;
            final extractedDirs = tempDir.listSync()
                .whereType<Directory>()
                .where((dir) => dir.path.contains('mcp_import_'))
                .toList();
            
            if (extractedDirs.isNotEmpty) {
              // Use the most recent extracted directory
              final bundleDir = extractedDirs.last;
              final nodesFile = File('${bundleDir.path}/nodes.jsonl');
              
              if (await nodesFile.exists()) {
                // Import favorites from nodes.jsonl
                // (McpPackImportService already imported journal entries)
                // Track count of successfully imported LUMARA favorites vs total found
                int favoritesCount = 0;
                int favoritesTotal = 0;
                try {
                  final favoritesService = FavoritesService.instance;
                  await favoritesService.initialize();
                  
                  await for (final line in nodesFile.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
                    if (line.trim().isEmpty) continue;
                    final jsonData = jsonDecode(line);
                    if (jsonData is Map<String, dynamic> && jsonData['type'] == 'lumara_favorite') {
                      favoritesTotal++; // Count all favorites found
                      try {
                        final node = McpNode.fromJson(jsonData);
                        final metadata = node.metadata ?? {};
                        final favoriteId = metadata['favorite_id'] as String? ?? 
                                          node.id.replaceFirst('lumara_favorite_', '');
                        final sourceId = metadata['source_id'] as String?;
                        final sourceType = metadata['source_type'] as String?;
                        final favoriteMetadata = metadata['metadata'] as Map<String, dynamic>? ?? {};
                        
                        final content = node.narrative?.essence ?? 
                                       node.contentSummary ?? 
                                       '';
                        
                        if (content.isNotEmpty) {
                          // Check if favorite already exists
                          bool shouldImport = true;
                          if (sourceId != null) {
                            final existing = await favoritesService.findFavoriteBySourceId(sourceId);
                            if (existing != null) {
                              shouldImport = false;
                            }
                          }
                          
                          // Check capacity
                          if (shouldImport && await favoritesService.isAtCapacity()) {
                            shouldImport = false;
                          }
                          
                          if (shouldImport) {
                            final favorite = LumaraFavorite(
                              id: favoriteId,
                              content: content,
                              timestamp: node.timestamp.toLocal(),
                              sourceId: sourceId,
                              sourceType: sourceType,
                              metadata: favoriteMetadata,
                            );
                            
                            // Only count favorites that are successfully added
                            final added = await favoritesService.addFavorite(favorite);
                            if (added) {
                              favoritesCount++;
                            }
                          }
                        }
                      } catch (e) {
                        print('⚠️ MCP Import: Failed to import favorite: $e');
                        // Continue processing other favorites even if this one fails
                      }
                    }
                  }
                } catch (e) {
                  print('⚠️ MCP Import: Failed to import favorites: $e');
                  // Continue with other imports even if favorites import fails
                }
                // Set the count of successfully imported LUMARA favorites and total found
                lumaraFavoritesImported = favoritesCount;
                lumaraFavoritesTotal = favoritesTotal;
                
                // Also import chats using enhanced service
                final baseChatRepo = ChatRepoImpl.instance;
                await baseChatRepo.initialize();
                
                final enhancedImportService = EnhancedMcpImportService(
                  chatRepo: baseChatRepo,
                );
                
                final enhancedResult = await enhancedImportService.importBundle(
                  bundleDir,
                  McpImportOptions(strictMode: false, maxErrors: 100),
                );
                
                chatSessionsImported = enhancedResult.chatSessionsImported;
                chatMessagesImported = enhancedResult.chatMessagesImported;
              }
            }
          } catch (e) {
            print('⚠️ MCP Import: Failed to import chats/favorites: $e');
            // Don't fail the entire import if chat/favorites import fails
          }
          
          // Refresh timeline to show imported entries
          context.read<TimelineCubit>().reloadAllEntries();
          _showSuccessDialog(importResult, 
            chatSessionsImported: chatSessionsImported, 
            chatMessagesImported: chatMessagesImported,
            lumaraFavoritesImported: lumaraFavoritesImported,
            lumaraFavoritesTotal: lumaraFavoritesTotal,
          );
        } else {
          _showErrorDialog(importResult.error ?? 'Import failed');
        }
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide progress dialog
      }
      _showErrorDialog('Import failed: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  /// Import separated packages in order: Media → Entries → Chats
  Future<void> _importSeparatedPackages() async {
    print('🚀 DEBUG: Starting _importSeparatedPackages method');
    final journalRepo = context.read<JournalRepository>();
    final chatRepo = ChatRepoImpl.instance;
    await chatRepo.initialize();
    
    // Initialize PhaseRegimeService for import
    PhaseRegimeService? phaseRegimeService;
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      print('ARCX Import: PhaseRegimeService initialized');
    } catch (e) {
      print('Warning: Could not initialize PhaseRegimeService: $e');
      // Continue import without phase regimes
    }
    
    final importService = ARCXImportServiceV2(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
      phaseRegimeService: phaseRegimeService,
    );
    
    // Import in order: Media → Entries → Chats (or Media → Entries+Chats for 2-archive format)
    // Determine import order based on detected groups
    final importOrder = <String>[];
    if (_detectedGroups.containsKey('Media')) {
      importOrder.add('Media');
    }
    // Handle 2-archive format (Entries+Chats together)
    if (_detectedGroups.containsKey('Entries+Chats')) {
      importOrder.add('Entries+Chats');
    } else {
      // Handle 3-archive format (separate)
      if (_detectedGroups.containsKey('Entries')) {
        importOrder.add('Entries');
      }
      if (_detectedGroups.containsKey('Chats')) {
        importOrder.add('Chats');
      }
    }
    
    int totalEntries = 0;
    int totalChats = 0;
    int totalMedia = 0;
    int totalFavorites = 0;
    final warnings = <String>[];
    
    // Show progress dialog
    final importOrderText = importOrder.join(' → ');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Importing Separated Packages...',
              style: heading3Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Importing in order: $importOrderText',
              style: bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    
    try {
      for (final groupType in importOrder) {
        final filePath = _detectedGroups[groupType];
        if (filePath == null || !await File(filePath).exists()) {
          warnings.add('$groupType package not found');
          continue;
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importing $groupType...'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        try {
          // Try V2 import service first
          final result = await importService.import(
            arcxPath: filePath,
            options: ARCXImportOptions(
              validateChecksums: true,
              dedupeMedia: true,
              skipExisting: true,
              resolveLinks: true, // Important for separated packages
            ),
            password: null, // TODO: Support password if needed
            onProgress: (message, [fraction = 0.0]) {
              print('ARCX Import ($groupType): $message');
            },
          );
          
          if (result.success) {
            totalEntries += result.entriesImported;
            totalChats += result.chatsImported;
            totalMedia += result.mediaImported;
            // Favorites are only in entries+chats archive, not in media-only archives
            if (groupType != 'Media') {
              final favoritesMap = result.lumaraFavoritesImported;
              totalFavorites += (favoritesMap['answers'] ?? 0) + (favoritesMap['chats'] ?? 0) + (favoritesMap['entries'] ?? 0);
            }
            if (result.warnings != null && result.warnings!.isNotEmpty) {
              warnings.addAll(result.warnings!);
            }
          } else {
            // V2 failed - check if it's a 1.2 format file before trying legacy
            bool isArc12 = false;
            try {
              final arcxFile = File(filePath);
              final arcxZip = await arcxFile.readAsBytes();
              final zipDecoder = ZipDecoder();
              final archive = zipDecoder.decodeBytes(arcxZip);
              
              for (final file in archive) {
                if (file.name == 'manifest.json') {
                  final manifestJson = jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>;
                  final arcxVersion = manifestJson['arcx_version'] as String?;
                  if (arcxVersion == '1.2') {
                    isArc12 = true;
                    break;
                  }
                }
              }
            } catch (_) {
              // Couldn't check version
            }
            
            if (isArc12) {
              // This is a 1.2 file, V2 should have handled it - don't try legacy
              warnings.add('Failed to import $groupType (ARCX 1.2 format): ${result.error}. This may indicate a corrupted archive or unsupported export options.');
            } else {
              // Not a 1.2 file, try legacy service
              print('ARCX Import: V2 import failed for $groupType, trying legacy: ${result.error}');
              final legacyCounts = await _tryLegacyImport(filePath, groupType, warnings);
              if (legacyCounts != null) {
                totalEntries += legacyCounts['entries'] ?? 0;
                totalChats += legacyCounts['chats'] ?? 0;
                totalMedia += legacyCounts['media'] ?? 0;
              }
            }
          }
        } catch (e) {
          // Check if it's a version format error
          final errorMsg = e.toString();
          // Only fall back to legacy if it's explicitly NOT ARCX 1.2 format
          if (errorMsg.contains('ARCX 1.2 format') || errorMsg.contains('legacy import service')) {
            // This means V2 detected an older format (not 1.2), so try legacy
            print('ARCX Import: Older format detected for $groupType, falling back to legacy service');
            final legacyCounts = await _tryLegacyImport(filePath, groupType, warnings);
            if (legacyCounts != null) {
              totalEntries += legacyCounts['entries'] ?? 0;
              totalChats += legacyCounts['chats'] ?? 0;
              totalMedia += legacyCounts['media'] ?? 0;
            }
          } else {
            // V2 failed for other reasons - don't try legacy if it's a 1.2 format file
            // Check if it's actually a 1.2 format file first
            try {
              final arcxFile = File(filePath);
              final arcxZip = await arcxFile.readAsBytes();
              final zipDecoder = ZipDecoder();
              final archive = zipDecoder.decodeBytes(arcxZip);
              
              for (final file in archive) {
                if (file.name == 'manifest.json') {
                  final manifestJson = jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>;
                  final arcxVersion = manifestJson['arcx_version'] as String?;
                  if (arcxVersion == '1.2') {
                    // This is a 1.2 file, V2 should have handled it
                    warnings.add('Failed to import $groupType (ARCX 1.2 format): $e. This may indicate a corrupted archive or unsupported export options.');
                    break;
                  }
                }
              }
            } catch (_) {
              // Couldn't check version, just report the error
              warnings.add('Failed to import $groupType: $e');
            }
          }
        }
      }
      
      // Hide progress dialog
      if (mounted) {
        Navigator.of(context).pop();
        print('🔧 DEBUG: Dismissed progress dialog');
      }

      // Refresh timeline
      context.read<TimelineCubit>().reloadAllEntries();
      print('🔄 DEBUG: Timeline refreshed');

      // Show success dialog
      print('🎯 DEBUG: Calling success dialog with entries:$totalEntries, chats:$totalChats, media:$totalMedia');
      _showSeparatedImportSuccessDialog(
        entriesImported: totalEntries,
        chatsImported: totalChats,
        mediaImported: totalMedia,
        lumaraFavoritesImported: totalFavorites,
        warnings: warnings,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide progress dialog
      }
      _showErrorDialog('Import failed: $e');
    }
  }
  
  /// Import multiple ARCX files (not necessarily separated)
  Future<void> _importMultipleArcFiles(List<String> filePaths) async {
    final journalRepo = context.read<JournalRepository>();
    final chatRepo = ChatRepoImpl.instance;
    await chatRepo.initialize();
    
    // Initialize PhaseRegimeService for import
    PhaseRegimeService? phaseRegimeService;
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      print('ARCX Import: PhaseRegimeService initialized');
    } catch (e) {
      print('Warning: Could not initialize PhaseRegimeService: $e');
      // Continue import without phase regimes
    }
    
    final importService = ARCXImportServiceV2(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
      phaseRegimeService: phaseRegimeService,
    );
    
    int totalEntries = 0;
    int totalChats = 0;
    int totalMedia = 0;
    int totalFavorites = 0;
    final warnings = <String>[];
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Importing ${filePaths.length} Archives...',
              style: heading3Style(context),
            ),
          ],
        ),
      ),
    );
    
    try {
      for (final filePath in filePaths) {
        if (!await File(filePath).exists()) {
          warnings.add('File not found: ${path.basename(filePath)}');
          continue;
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importing ${path.basename(filePath)}...'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        try {
          // Try V2 import service first
          final result = await importService.import(
            arcxPath: filePath,
            options: ARCXImportOptions(
              validateChecksums: true,
              dedupeMedia: true,
              skipExisting: true,
              resolveLinks: true,
            ),
            password: null,
            onProgress: (message, [fraction = 0.0]) {
              print('ARCX Import: $message');
            },
          );
          
          if (result.success) {
            totalEntries += result.entriesImported;
            totalChats += result.chatsImported;
            totalMedia += result.mediaImported;
            // Accumulate favorites from all archives (they're typically in entries+chats archives)
            final favoritesMap = result.lumaraFavoritesImported;
            totalFavorites += (favoritesMap['answers'] ?? 0) + (favoritesMap['chats'] ?? 0) + (favoritesMap['entries'] ?? 0);
            if (result.warnings != null && result.warnings!.isNotEmpty) {
              warnings.addAll(result.warnings!);
            }
          } else {
            // V2 failed - check if it's a 1.2 format file before trying legacy
            bool isArc12 = false;
            try {
              final arcxFile = File(filePath);
              final arcxZip = await arcxFile.readAsBytes();
              final zipDecoder = ZipDecoder();
              final archive = zipDecoder.decodeBytes(arcxZip);
              
              for (final file in archive) {
                if (file.name == 'manifest.json') {
                  final manifestJson = jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>;
                  final arcxVersion = manifestJson['arcx_version'] as String?;
                  if (arcxVersion == '1.2') {
                    isArc12 = true;
                    break;
                  }
                }
              }
            } catch (_) {
              // Couldn't check version
            }
            
            if (isArc12) {
              // This is a 1.2 file, V2 should have handled it - don't try legacy
              warnings.add('Failed to import ${path.basename(filePath)} (ARCX 1.2 format): ${result.error}. This may indicate a corrupted archive or unsupported export options.');
            } else {
              // Not a 1.2 file, try legacy service
              print('ARCX Import: V2 import failed for ${path.basename(filePath)}, trying legacy: ${result.error}');
              final legacyCounts = await _tryLegacyImport(filePath, path.basename(filePath), warnings);
              if (legacyCounts != null) {
                totalEntries += legacyCounts['entries'] ?? 0;
                totalChats += legacyCounts['chats'] ?? 0;
                totalMedia += legacyCounts['media'] ?? 0;
              }
            }
          }
        } catch (e) {
          // Check if it's a version format error
          final errorMsg = e.toString();
          // Only fall back to legacy if it's explicitly NOT ARCX 1.2 format
          if (errorMsg.contains('ARCX 1.2 format') || errorMsg.contains('legacy import service')) {
            // This means V2 detected an older format (not 1.2), so try legacy
            print('ARCX Import: Older format detected for ${path.basename(filePath)}, falling back to legacy service');
            final legacyCounts = await _tryLegacyImport(filePath, path.basename(filePath), warnings);
            if (legacyCounts != null) {
              totalEntries += legacyCounts['entries'] ?? 0;
              totalChats += legacyCounts['chats'] ?? 0;
              totalMedia += legacyCounts['media'] ?? 0;
            }
          } else {
            // V2 failed for other reasons - check if it's a 1.2 format file
            try {
              final arcxFile = File(filePath);
              final arcxZip = await arcxFile.readAsBytes();
              final zipDecoder = ZipDecoder();
              final archive = zipDecoder.decodeBytes(arcxZip);
              
              for (final file in archive) {
                if (file.name == 'manifest.json') {
                  final manifestJson = jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>;
                  final arcxVersion = manifestJson['arcx_version'] as String?;
                  if (arcxVersion == '1.2') {
                    // This is a 1.2 file, V2 should have handled it
                    warnings.add('Failed to import ${path.basename(filePath)} (ARCX 1.2 format): $e. This may indicate a corrupted archive or unsupported export options.');
                    break;
                  }
                }
              }
            } catch (_) {
              // Couldn't check version, just report the error
              warnings.add('Failed to import ${path.basename(filePath)}: $e');
            }
          }
        }
      }
      
      // Hide progress dialog
      if (mounted) {
        Navigator.of(context).pop();
        print('🔧 DEBUG: Dismissed progress dialog');
      }

      // Refresh timeline
      context.read<TimelineCubit>().reloadAllEntries();
      print('🔄 DEBUG: Timeline refreshed');

      // Show success dialog
      print('🎯 DEBUG: Calling success dialog with entries:$totalEntries, chats:$totalChats, media:$totalMedia');
      _showSeparatedImportSuccessDialog(
        entriesImported: totalEntries,
        chatsImported: totalChats,
        mediaImported: totalMedia,
        lumaraFavoritesImported: totalFavorites,
        warnings: warnings,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showErrorDialog('Import failed: $e');
    }
  }
  
  /// Try legacy import service for older ARCX formats
  /// Returns a map with counts if successful, null otherwise
  Future<Map<String, int>?> _tryLegacyImport(String filePath, String groupType, List<String> warnings) async {
    try {
      final journalRepo = context.read<JournalRepository>();
      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      
      final legacyImportService = ARCXImportService(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
      );
      
      print('ARCX Import: Attempting legacy import for $groupType');
      
      final legacyResult = await legacyImportService.importSecure(
        arcxPath: filePath,
        manifestPath: null,
        dryRun: false,
        password: null, // TODO: Support password if needed
      );
      
      if (legacyResult.success) {
        // Successfully imported with legacy service
        print('ARCX Import: Legacy service successfully imported $groupType');
        return {
          'entries': legacyResult.entriesImported ?? 0,
          'chats': legacyResult.chatSessionsImported ?? 0,
          'media': legacyResult.photosImported ?? 0,
        };
      } else {
        warnings.add('Legacy import also failed for $groupType: ${legacyResult.error}');
        return null;
      }
    } catch (e) {
      warnings.add('Legacy import error for $groupType: $e');
      return null;
    }
  }
  
  void _showSeparatedImportSuccessDialog({
    required int entriesImported,
    required int chatsImported,
    required int mediaImported,
    int lumaraFavoritesImported = 0,
    required List<String> warnings,
    int entriesTotal = 0,
    int chatsTotal = 0,
    int mediaTotal = 0,
  }) {
    // Format counts as "x/x" (successful/total), or just "x" if total is unknown or same as successful
    String formatCount(int successful, int total) {
      if (total > 0 && total != successful) {
        return '$successful/$total';
      }
      return '$successful';
    }

    // Ensure any existing dialog is dismissed first
    print('🎉 DEBUG: About to show separated import success dialog');
    Navigator.of(context).popUntil((route) => route.isFirst);
    print('🔧 DEBUG: Dismissed existing dialogs, showing success dialog');
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SafeArea(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Import Complete', style: heading2Style(context)),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Successfully imported separated packages!',
                        style: bodyStyle(context),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Entries imported:', formatCount(entriesImported, entriesTotal)),
                      _buildSummaryRow('Chats imported:', formatCount(chatsImported, chatsTotal)),
                      _buildSummaryRow('Media imported:', formatCount(mediaImported, mediaTotal)),
                      _buildSummaryRow('LUMARA Favorites imported:', '$lumaraFavoritesImported'),
                      if (warnings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Warnings:',
                                style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              ...warnings.take(5).map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $w',
                                  style: bodyStyle(context).copyWith(fontSize: 12),
                                ),
                              )),
                              if (warnings.length > 5)
                                Text(
                                  '... and ${warnings.length - 5} more',
                                  style: bodyStyle(context).copyWith(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate to main screen (HomeView)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeView()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Restoring from MCP Package...',
              style: heading3Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Validating package → Importing entries → Importing photos → Linking',
              style: bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(McpImportResult result, {
    int chatSessionsImported = 0, 
    int chatMessagesImported = 0, 
    int lumaraFavoritesImported = 0,
    int lumaraFavoritesTotal = 0,
  }) {
    // Format counts as "x/x" (successful/total), or just "x" if total is unknown or same as successful
    String formatCount(int successful, int total) {
      if (total > 0 && total != successful) {
        return '$successful/$total';
      }
      return '$successful';
    }
    
    // Ensure any existing dialog is dismissed first
    Navigator.of(context, rootNavigator: true).popUntil((route) => !route.navigator!.canPop() || route.isFirst);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SafeArea(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Import Complete', style: heading2Style(context)),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your data has been successfully restored!',
                        style: bodyStyle(context),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Entries restored:', formatCount(result.totalEntries, result.totalEntriesFound > 0 ? result.totalEntriesFound : result.totalEntries)),
                      _buildSummaryRow('Favorites imported:', formatCount(lumaraFavoritesImported, lumaraFavoritesTotal)),
                      if (chatSessionsImported > 0 || chatMessagesImported > 0) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Chats imported:', '$chatSessionsImported sessions, $chatMessagesImported messages'),
                      ] else ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Chats imported:', '0'),
                      ],
                      _buildSummaryRow('Photos restored:', formatCount(result.totalPhotos, result.totalPhotosFound > 0 ? result.totalPhotosFound : result.totalPhotos)),
                      if (result.manifest != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Package info:',
                          style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
                        ),
                        _buildSummaryRow('Format:', result.manifest!.format),
                        _buildSummaryRow('Version:', '${result.manifest!.version}'),
                        _buildSummaryRow('Type:', result.manifest!.subtype),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // Go back to previous screen
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: bodyStyle(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showARCXImportSuccessDialogV2(ARCXImportResultV2 result) {
    // Small delay to ensure navigation completes after progress screen pops
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      // Show dialog directly - the import screen should be visible now
      showDialog(
        context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SafeArea(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Import Complete', style: heading2Style(context)),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your data has been successfully restored!',
                        style: bodyStyle(context),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow(
                        'Entries restored:',
                        result.entriesTotalInArchive != null
                            ? '${result.entriesImported} of ${result.entriesTotalInArchive}'
                                + (result.entriesFailed != null && result.entriesFailed! > 0 ? ' (${result.entriesFailed} failed)' : '')
                            : '${result.entriesImported}',
                      ),
                      _buildSummaryRow('Media restored:', '${result.mediaImported}'),
                      if (result.chatsImported > 0)
                        _buildSummaryRow('Chat sessions:', '${result.chatsImported}'),
                      if (result.phaseRegimesImported > 0)
                        _buildSummaryRow('Phase regimes:', '${result.phaseRegimesImported}'),
                      if (result.rivetStatesImported > 0)
                        _buildSummaryRow('RIVET states:', '${result.rivetStatesImported}'),
                      if (result.sentinelStatesImported > 0)
                        _buildSummaryRow('Sentinel states:', '${result.sentinelStatesImported}'),
                      if (result.arcformSnapshotsImported > 0)
                        _buildSummaryRow('ArcForm snapshots:', '${result.arcformSnapshotsImported}'),
                      _buildSummaryRow('LUMARA Favorites:', '${result.lumaraFavoritesImported}'),
                      if (result.warnings != null && result.warnings!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Warnings:',
                          style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        ...result.warnings!.map((w) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Text('• $w', style: bodyStyle(context).copyWith(fontSize: 12, color: Colors.orange)),
                        )),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Package info:',
                        style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildSummaryRow('Format:', 'arcx'),
                      _buildSummaryRow('Version:', '1.2'),
                      _buildSummaryRow('Type:', 'secure'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate to main screen (HomeView)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeView()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
      );
    });
  }

  void _showARCXImportSuccessDialog(ARCXImportResult result) {
    // Small delay to ensure navigation completes after progress screen pops
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      // Show dialog directly - the import screen should be visible now
      showDialog(
        context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SafeArea(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Import Complete', style: heading2Style(context)),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your data has been successfully restored!',
                        style: bodyStyle(context),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Entries restored:', '${result.entriesImported ?? 0}'),
                      _buildSummaryRow('Photos restored:', '${result.photosImported ?? 0}'),
                      if ((result.chatSessionsImported ?? 0) > 0 || (result.chatMessagesImported ?? 0) > 0) ...[
                        _buildSummaryRow('Chat sessions:', '${result.chatSessionsImported ?? 0}'),
                        _buildSummaryRow('Chat messages:', '${result.chatMessagesImported ?? 0}'),
                      ],
                      _buildSummaryRow('Missing/corrupted:', '0'),
                      const SizedBox(height: 8),
                      Text(
                        'Package info:',
                        style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildSummaryRow('Format:', 'arcx'),
                      _buildSummaryRow('Version:', '1.1'),
                      _buildSummaryRow('Type:', 'secure'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate to main screen (HomeView)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeView()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
      );
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text('Import Failed', style: heading2Style(context)),
          ],
        ),
        content: Text(message, style: bodyStyle(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Restore from Package',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select an MCP package (.zip) or Secure Archive (.arcx) to restore your data.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Legacy .zip files import directly, while encrypted .arcx archives are decrypted with AES-256-GCM and verified with Ed25519 signatures.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can select multiple .arcx files to restore separated packages (Entries, Chats, Media). The system will automatically detect and import them in the correct order.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // File selection
            Text(
              'Select MCP Package',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Package file selection
            _buildSelectionTile(
              title: 'Select Package File(s)',
              subtitle: 'Choose .zip (MCP) or .arcx (Secure Archive) files. Select multiple .arcx files for separated packages.',
              icon: Icons.file_present,
              onTap: _selectMcpFile,
            ),
            const SizedBox(height: 8),
            // Continue import from folder (only .arcx files not yet in import set index)
            _buildSelectionTile(
              title: 'Continue Import from Folder',
              subtitle: 'Pick a folder of .arcx files. Files not yet imported are imported; already-imported files are skipped. Works with folders created before import records (existing entries/chats are skipped).',
              icon: Icons.folder_open,
              onTap: _continueImportFromFolder,
            ),

            // Selected file info
            if (_selectedPath != null || _selectedPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: $_detectedFormat',
                            style: bodyStyle(context).copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedPath != null)
                      Text(
                        path.basename(_selectedPath!),
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 14,
                        ),
                      )
                    else if (_selectedPaths.isNotEmpty)
                      ..._selectedPaths.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          path.basename(p),
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                      )),
                    if (_isSeparatedPackage && _detectedGroups.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.link, color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Separated Packages Detected',
                                  style: bodyStyle(context).copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._detectedGroups.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.key == 'Media' ? Icons.image
                                    : entry.key == 'Entries+Chats' ? Icons.library_books
                                    : entry.key == 'Entries' ? Icons.article
                                    : Icons.chat,
                                    size: 16,
                                    color: kcSecondaryTextColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${entry.key}: ${path.basename(entry.value)}',
                                      style: bodyStyle(context).copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 4),
                            Text(
                              _detectedGroups.containsKey('Entries+Chats')
                                  ? 'Will import in order: Media → Entries+Chats'
                                  : 'Will import in order: Media → Entries → Chats',
                              style: bodyStyle(context).copyWith(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: kcSecondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isImporting || (_selectedPath == null && _selectedPaths.isEmpty)) ? null : _importMcpData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isImporting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Restoring Data...'),
                        ],
                      )
                    : Text(
                        (_selectedPath == null && _selectedPaths.isEmpty)
                            ? 'Select MCP Package First'
                            : _isSeparatedPackage
                                ? 'Restore Separated Packages'
                                : 'Restore from MCP Package',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: kcAccentColor),
        title: Text(title, style: heading3Style(context)),
        subtitle: Text(subtitle, style: bodyStyle(context)),
        trailing: const Icon(Icons.arrow_forward_ios, color: kcSecondaryTextColor, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
