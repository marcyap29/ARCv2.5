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
import '../../core/mcp/import/mcp_pack_import_service.dart' show McpPackImportService, McpImportResult;
import '../../core/mcp/import/enhanced_mcp_import_service.dart';
import '../../core/mcp/import/mcp_import_service.dart' show McpImportOptions;
import '../../lumara/chat/chat_repo_impl.dart';
import '../../utils/file_utils.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import '../../arcx/ui/arcx_import_progress_screen.dart';
import '../../arcx/services/arcx_import_service_v2.dart';
import '../../arcx/services/arcx_import_service.dart';

/// MCP Import Screen - Restore from MCP Package (.zip) or Secure Archive (.arcx)
class McpImportScreen extends StatefulWidget {
  const McpImportScreen({super.key});

  @override
  State<McpImportScreen> createState() => _McpImportScreenState();
}

class _McpImportScreenState extends State<McpImportScreen> {
  bool _isImporting = false;
  String? _selectedPath;
  List<String> _selectedPaths = [];
  String? _detectedFormat;
  bool _isSeparatedPackage = false;
  Map<String, String> _detectedGroups = {}; // groupType -> filePath

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
        // Single .arcx import - navigate to progress screen
        final arcxFile = File(_selectedPath!);
        if (!await arcxFile.exists()) {
          _showErrorDialog('ARCX file not found');
          setState(() => _isImporting = false);
          return;
        }

        // Find manifest file (sibling to .arcx)
        final manifestPath = _selectedPath!.replaceAll('.arcx', '.manifest.json');
        final manifestFile = File(manifestPath);
        String? actualManifestPath;
        
        if (await manifestFile.exists()) {
          actualManifestPath = manifestPath;
        }

        // Navigate to ARCX import progress screen
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ARCXImportProgressScreen(
              arcxPath: _selectedPath!,
              manifestPath: actualManifestPath,
            ),
          ),
        ).then((_) {
          // Refresh timeline after import completes
          context.read<TimelineCubit>().reloadAllEntries();
          setState(() => _isImporting = false);
        });
      } else {
        // Legacy MCP (.zip) import
        final journalRepo = context.read<JournalRepository>();
        final importService = McpPackImportService(journalRepo: journalRepo);

        // Show progress dialog
        _showProgressDialog();

        // Import basic journal data
        final importResult = await importService.importFromPath(_selectedPath!);

        // Hide progress dialog
        Navigator.of(context).pop();

        if (importResult.success) {
          // Also import chats if nodes.jsonl exists (Enhanced MCP format)
          int chatSessionsImported = 0;
          int chatMessagesImported = 0;
          
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
                // Get chat repo - use singleton base repo
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
            print('⚠️ MCP Import: Failed to import chats: $e');
            // Don't fail the entire import if chat import fails
          }
          
          // Refresh timeline to show imported entries
          context.read<TimelineCubit>().reloadAllEntries();
          _showSuccessDialog(importResult, chatSessionsImported: chatSessionsImported, chatMessagesImported: chatMessagesImported);
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
    final journalRepo = context.read<JournalRepository>();
    final chatRepo = ChatRepoImpl.instance;
    await chatRepo.initialize();
    
    final importService = ARCXImportServiceV2(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
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
            onProgress: (message) {
              print('ARCX Import ($groupType): $message');
            },
          );
          
          if (result.success) {
            totalEntries += result.entriesImported;
            totalChats += result.chatsImported;
            totalMedia += result.mediaImported;
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
      }
      
      // Refresh timeline
      context.read<TimelineCubit>().reloadAllEntries();
      
      // Show success dialog
      _showSeparatedImportSuccessDialog(
        entriesImported: totalEntries,
        chatsImported: totalChats,
        mediaImported: totalMedia,
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
    
    final importService = ARCXImportServiceV2(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
    );
    
    int totalEntries = 0;
    int totalChats = 0;
    int totalMedia = 0;
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
            onProgress: (message) {
              print('ARCX Import: $message');
            },
          );
          
          if (result.success) {
            totalEntries += result.entriesImported;
            totalChats += result.chatsImported;
            totalMedia += result.mediaImported;
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
      }
      
      // Refresh timeline
      context.read<TimelineCubit>().reloadAllEntries();
      
      // Show success dialog
      _showSeparatedImportSuccessDialog(
        entriesImported: totalEntries,
        chatsImported: totalChats,
        mediaImported: totalMedia,
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
    required List<String> warnings,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Import Complete', style: heading2Style(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully imported separated packages!',
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Entries imported:', '$entriesImported'),
            _buildSummaryRow('Chats imported:', '$chatsImported'),
            _buildSummaryRow('Media imported:', '$mediaImported'),
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('Done'),
          ),
        ],
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

  void _showSuccessDialog(McpImportResult result, {int chatSessionsImported = 0, int chatMessagesImported = 0}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Import Complete', style: heading2Style(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your data has been successfully restored!',
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Entries restored:', '${result.totalEntries}'),
            _buildSummaryRow('Photos restored:', '${result.totalPhotos}'),
            if (chatSessionsImported > 0 || chatMessagesImported > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow('Chats imported:', '$chatSessionsImported sessions, $chatMessagesImported messages'),
            ] else ...[
              const SizedBox(height: 8),
              _buildSummaryRow('Chats imported:', '0'),
            ],
            _buildSummaryRow('Missing/corrupted:', '0'),
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bodyStyle(context)),
          Text(value, style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
