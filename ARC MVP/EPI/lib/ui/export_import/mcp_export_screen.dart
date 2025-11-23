import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/mira/store/arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/mira/store/mcp/export/mcp_pack_export_service.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:intl/intl.dart';

/// MCP Export Screen - Create MCP Package (.mcpkg)
class McpExportScreen extends StatefulWidget {
  final String? initialFormat; // 'arcx' or 'zip' - optional format pre-selection
  
  const McpExportScreen({super.key, this.initialFormat});

  @override
  State<McpExportScreen> createState() => _McpExportScreenState();
}

class _McpExportScreenState extends State<McpExportScreen> {
  bool _isExporting = false;
  String _exportFormat = 'arcx'; // 'arcx' or 'zip'
  int _entryCount = 0;
  int _photoCount = 0;
  int _chatCount = 0;
  int _favoritesCount = 0;
  
  // Always using ARCX secure format (per spec - .zip option removed)
  
  // Chat export settings - always include archived chats
  bool _includeArchivedChats = true;
  
  // Multi-select for entries
  bool _useMultiSelect = false;
  Set<String> _selectedEntryIds = {};
  List<JournalEntry> _allEntries = [];
  
  // Password-based encryption (only for .arcx format)
  bool _usePasswordEncryption = false;
  String? _exportPassword;
  
  // ARCX V2 export options
  ARCXExportStrategy _exportStrategy = ARCXExportStrategy.together; // Export strategy
  
  // Date range filtering
  String _dateRangeSelection = 'all'; // 'all', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    // Set initial format if provided
    if (widget.initialFormat != null) {
      _exportFormat = widget.initialFormat!;
    }
    _loadJournalStats();
  }

  Future<void> _loadJournalStats() async {
    try {
      final journalRepo = context.read<JournalRepository>();
      final entries = await journalRepo.getAllJournalEntries();
      _allEntries = entries;
      
      int photoCount = 0;
      for (final entry in entries) {
        photoCount += entry.media.where((m) => m.type == MediaType.image).length;
      }

      // Load chat count
      int chatCount = 0;
      try {
        final chatRepo = ChatRepoImpl.instance;
        await chatRepo.initialize();
        final allChats = await chatRepo.listAll(includeArchived: true);
        chatCount = allChats.length;
      } catch (e) {
        print('Error loading chat count: $e');
      }

      // Load favorites count
      int favoritesCount = 0;
      try {
        final favoritesService = FavoritesService.instance;
        await favoritesService.initialize();
        favoritesCount = await favoritesService.getCount();
      } catch (e) {
        print('Error loading favorites count: $e');
      }

      setState(() {
        _entryCount = entries.length;
        _photoCount = photoCount;
        _chatCount = chatCount;
        _favoritesCount = favoritesCount;
      });
    } catch (e) {
      print('Error loading journal stats: $e');
    }
  }

  Future<void> _exportMcpPackage() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Get journal entries (either selected or all)
      final journalRepo = context.read<JournalRepository>();
      List<JournalEntry> entries;
      
      if (_useMultiSelect && _selectedEntryIds.isNotEmpty) {
        // Export only selected entries
        final allEntries = await journalRepo.getAllJournalEntries();
        entries = allEntries.where((e) => _selectedEntryIds.contains(e.id)).toList();
        
        if (entries.isEmpty) {
          _showErrorDialog('No entries selected for export');
          return;
        }
      } else {
        // Export all entries
        entries = await journalRepo.getAllJournalEntries();

      if (entries.isEmpty) {
        _showErrorDialog('No entries to export');
        return;
        }
      }

      // Create progress notifier
      final progressNotifier = ValueNotifier<String>('Preparing export...');
      
      // Show progress dialog
      _showProgressDialog(progressNotifier);

      // Always use ARCX secure format (per spec - .zip option removed)
      if (_exportFormat == 'arcx') {
        // Secure .arcx export
        final outputDir = await getApplicationDocumentsDirectory();
        final exportsDir = Directory(path.join(outputDir.path, 'Exports'));
        if (!await exportsDir.exists()) {
          await exportsDir.create(recursive: true);
        }

        // Calculate date range based on selection (for entries, chats, and media)
        DateTime? startDate;
        DateTime? endDate;
        
        switch (_dateRangeSelection) {
          case 'custom':
            startDate = _customStartDate;
            if (_customEndDate != null) {
              // Set end date to end of day to include all entries/media on that day
              endDate = DateTime(
                _customEndDate!.year, 
                _customEndDate!.month, 
                _customEndDate!.day, 
                23, 59, 59, 999
              );
            }
            break;
          case 'all':
          default:
            // No date filtering
            break;
        }
        
        // Filter entries by date range if specified
        List<JournalEntry> filteredEntries = entries;
        if (startDate != null || endDate != null) {
          filteredEntries = entries.where((entry) {
            if (startDate != null && entry.createdAt.isBefore(startDate)) return false;
            if (endDate != null && entry.createdAt.isAfter(endDate)) return false;
            return true;
          }).toList();
        }
        
        // Collect media items - filter by date range if custom date range is set
        // This ensures media within the date range is included regardless of entry selection
        final photoMedia = <MediaItem>[];
        final mediaMap = <String, MediaItem>{};
        
        if (startDate != null || endDate != null) {
          // When custom date range is set, load all entries and filter media by date range
          try {
            final allEntries = await journalRepo.getAllJournalEntries();
            for (final entry in allEntries) {
              // Check if entry is within date range
              if (startDate != null && entry.createdAt.isBefore(startDate)) continue;
              if (endDate != null && entry.createdAt.isAfter(endDate)) continue;
              
              // Include media from entries within date range
              for (final mediaItem in entry.media.where((m) => m.type == MediaType.image)) {
                mediaMap[mediaItem.id] = mediaItem;
              }
            }
          } catch (e) {
            print('Warning: Could not load all entries for media filtering: $e');
          }
        } else {
          // When "All Entries" is selected (no date range), collect media from selected/filtered entries
          for (final entry in filteredEntries) {
            for (final mediaItem in entry.media.where((m) => m.type == MediaType.image)) {
              mediaMap[mediaItem.id] = mediaItem;
            }
          }
        }
        
        photoMedia.addAll(mediaMap.values);

        // Use ARCX Export Service V2 (new specification)
        final chatRepo = ChatRepoImpl.instance;
        try {
          await chatRepo.initialize();
        } catch (e) {
          print('Warning: Could not initialize ChatRepo: $e');
        }
        
        // Initialize PhaseRegimeService for export
        PhaseRegimeService? phaseRegimeService;
        try {
          final analyticsService = AnalyticsService();
          final rivetSweepService = RivetSweepService(analyticsService);
          phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
          await phaseRegimeService.initialize();
          print('ARCX Export: PhaseRegimeService initialized');
        } catch (e) {
          print('Warning: Could not initialize PhaseRegimeService: $e');
          // Continue export without phase regimes
        }
        
        final arcxExportV2 = ARCXExportServiceV2(
          journalRepo: journalRepo,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );
        
        // Build selection from filtered entries
        final entryIds = filteredEntries.map((e) => e.id).toList();
        final mediaIds = photoMedia.map((m) => m.id).toList();
        
        // Get chat thread IDs - filter by date range selection and archived setting
        final chatThreadIds = <String>[];
        try {
          final allChats = await chatRepo.listAll(includeArchived: _includeArchivedChats);
          
          // Apply date range filtering to chats if date range is specified
          for (final chat in allChats) {
            // Skip if outside date range
            if (startDate != null && chat.createdAt.isBefore(startDate)) continue;
            if (endDate != null && chat.createdAt.isAfter(endDate)) continue;
            
            chatThreadIds.add(chat.id);
          }
          
          print('ARCX Export: Including ${chatThreadIds.length} chats (archived: $_includeArchivedChats, date range: ${startDate != null || endDate != null ? "filtered" : "all"})');
        } catch (e) {
          print('Warning: Could not load chats for export: $e');
        }
        
          final result = await arcxExportV2.export(
          selection: ARCXExportSelection(
            entryIds: entryIds,
            chatThreadIds: chatThreadIds,
            mediaIds: mediaIds,
            startDate: startDate,
            endDate: endDate,
          ),
          options: ARCXExportOptions(
            strategy: _exportStrategy,
            encrypt: true,
            compression: 'auto',
            dedupeMedia: true,
            includeChecksums: true,
            startDate: startDate,
            endDate: endDate,
          ),
          outputDir: exportsDir,
          password: _usePasswordEncryption ? _exportPassword : null,
          onProgress: (message) {
            if (mounted) {
              progressNotifier.value = message;
            }
          },
        );

        // Hide progress dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (result.success) {
          // Update archive size with actual file size
          if (result.arcxPath != null) {
            // File size update removed
          }
          _showArcSuccessDialogV2(result);
        } else {
          _showErrorDialog(result.error ?? 'ARCX export failed');
        }
      } else if (_exportFormat == 'zip') {
        // Standard ZIP export using McpPackExportService
        
        // Calculate date range based on selection
        DateTime? startDate;
        DateTime? endDate;
        
        switch (_dateRangeSelection) {
          case 'custom':
            startDate = _customStartDate;
            if (_customEndDate != null) {
              // Set end date to end of day
              endDate = DateTime(
                _customEndDate!.year, 
                _customEndDate!.month, 
                _customEndDate!.day, 
                23, 59, 59, 999
              );
            }
            break;
          case 'all':
          default:
            break;
        }
        
        // Filter entries by date range
        List<JournalEntry> filteredEntries = entries;
        if (startDate != null || endDate != null) {
          filteredEntries = entries.where((entry) {
            if (startDate != null && entry.createdAt.isBefore(startDate)) return false;
            if (endDate != null && entry.createdAt.isAfter(endDate)) return false;
            return true;
          }).toList();
        }
        
        // Prepare output path
        final outputDir = await getApplicationDocumentsDirectory();
        final exportsDir = Directory(path.join(outputDir.path, 'Exports'));
        if (!await exportsDir.exists()) {
          await exportsDir.create(recursive: true);
        }
        
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
        final outputPath = path.join(exportsDir.path, 'export_$timestamp.zip');
        
        // Prepare chat dates filter if date range is used
        Set<String>? chatDatesFilter;
        if (startDate != null || endDate != null) {
          chatDatesFilter = {};
          // Add all dates in range to the filter set
          // This is a bit simplistic but works for McpPackExportService which expects a Set of date strings
          final start = startDate ?? DateTime(2000);
          final end = endDate ?? DateTime.now();
          
          for (var d = start; d.isBefore(end) || d.isAtSameMomentAs(end); d = d.add(const Duration(days: 1))) {
            final dateKey = '${d.year.toString().padLeft(4, '0')}-'
                          '${d.month.toString().padLeft(2, '0')}-'
                          '${d.day.toString().padLeft(2, '0')}';
            chatDatesFilter.add(dateKey);
          }
        }
        
        // Initialize ChatRepo
        final chatRepo = ChatRepoImpl.instance;
        try {
          await chatRepo.initialize();
        } catch (e) {
          print('Warning: Could not initialize ChatRepo: $e');
        }
        
        // Initialize PhaseRegimeService for export
        PhaseRegimeService? phaseRegimeService;
        try {
          final analyticsService = AnalyticsService();
          final rivetSweepService = RivetSweepService(analyticsService);
          phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
          await phaseRegimeService.initialize();
          print('McpPackExportService: PhaseRegimeService initialized');
        } catch (e) {
          print('Warning: Could not initialize PhaseRegimeService: $e');
        }

        final mcpPackService = McpPackExportService(
          bundleId: 'export_$timestamp',
          outputPath: outputPath,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );
        
        // Pass progress updates
        // McpPackExportService doesn't support callback, so we just show "Exporting..."
        
        final result = await mcpPackService.exportJournal(
          entries: filteredEntries,
          includePhotos: true,
          reducePhotoSize: false,
          includeChats: true,
          includeArchivedChats: _includeArchivedChats,
          chatDatesFilter: chatDatesFilter,
        );
        
        if (result.success) {
          // Show success dialog with result
          // Use similar dialog style but customized for ZIP
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Export Complete'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Successfully exported ${result.totalEntries} entries, ${result.totalChatSessions} chats, and ${result.totalPhotos} media items.'),
                  const SizedBox(height: 16),
                  Text(
                    'Location: ${path.basename(outputPath)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _shareMcpPackage(outputPath);
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        } else {
          _showErrorDialog(result.error ?? 'ZIP export failed');
        }
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide progress dialog
      }
      _showErrorDialog('Export failed: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showProgressDialog(ValueNotifier<String> progressNotifier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: progressNotifier,
        builder: (context, message, child) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Creating Secure Archive...',
                  style: heading3Style(context),
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: bodyStyle(context),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareMcpPackage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showErrorDialog('Export file not found');
        return;
      }

      // Store messenger reference before async operation
      final messenger = mounted ? ScaffoldMessenger.of(context) : null;
      
      // Get share position origin for iPad support
      // On iPad, share sheet requires a non-zero position origin
      Rect? sharePositionOrigin;
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        // Use center of screen as share position origin (required for iPad)
        sharePositionOrigin = Rect.fromLTWH(
          screenSize.width / 2,
          screenSize.height / 2,
          1,
          1,
        );
      }
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'MCP Package - $_entryCount entries, $_photoCount photos',
        subject: 'Journal Export - ${path.basename(filePath)}',
        sharePositionOrigin: sharePositionOrigin,
      );
      
      // Show confirmation after successful share (only if still mounted)
      if (mounted && messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Archive saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to share file: $e');
    }
  }

  void _showArcSuccessDialogV2(ARCXExportResultV2 result) async {
    // Show success dialog for V2 export
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully exported ${result.entriesExported} entries, ${result.chatsExported} chats, and ${result.mediaExported} media items.'),
            const SizedBox(height: 16),
            if (result.arcxPath != null)
              Text(
                'Location: ${path.basename(result.arcxPath!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (result.arcxPath != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareMcpPackage(result.arcxPath!);
              },
              child: const Text('Share'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bodyStyle(context)),
          Text(value, style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    bool showError = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Set Password', style: heading2Style(context)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a password to create a portable archive that works on any device.',
                style: bodyStyle(context),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter a strong password',
                ),
                onChanged: (_) {
                  if (showError) {
                    setState(() => showError = false);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter the password',
                  errorText: showError ? 'Passwords do not match' : null,
                ),
                onChanged: (_) {
                  if (showError) {
                    setState(() => showError = false);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  setState(() => showError = true);
                  return;
                }
                
                if (controller.text != confirmController.text) {
                  setState(() => showError = true);
                  return;
                }
                
                this.setState(() {
                  _exportPassword = controller.text;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
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
            Expanded(
              child: Text('Export Failed', style: heading2Style(context)),
            ),
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description

            // Redaction settings (ARCX format only)
            if (_exportFormat == 'arcx') ...[
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
                        const Icon(Icons.security, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Security & Privacy Settings',
                            style: heading3Style(context).copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  // Password encryption temporarily disabled - causes hangs with large files
                  // _buildOptionTile(
                  //   title: 'Use password encryption',
                  //   subtitle: 'Create portable archives that work on any device (requires password)',
                  //   value: _usePasswordEncryption,
                  //   onChanged: (value) {
                  //     setState(() {
                  //       _usePasswordEncryption = value;
                  //       if (value && _exportPassword == null) {
                  //         _showPasswordDialog();
                  //       }
                  //     });
                  //   },
                  // ),
                    if (_usePasswordEncryption && _exportPassword != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Password set',
                                  style: bodyStyle(context),
                                ),
                              ),
                              TextButton(
                                onPressed: _showPasswordDialog,
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Advanced Export Options (Date Range) - Available for both formats
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
                    'Advanced Export Options',
                    style: heading3Style(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date Range',
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDateRangeSelector(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Options
            Text(
              'Export Options',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Multi-select option
            _buildOptionTile(
              title: 'Select specific entries',
              subtitle: 'Choose which entries to export (default: all entries)',
              value: _useMultiSelect,
              onChanged: (value) {
                setState(() {
                  _useMultiSelect = value;
                  if (!value) {
                    _selectedEntryIds.clear(); // Clear selection when disabled
                  }
                });
              },
            ),

            // Entry selection list (shown when multi-select is enabled)
            if (_useMultiSelect) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Entries (${_selectedEntryIds.length}/${_allEntries.length})',
                          style: heading3Style(context),
                        ),
                        if (_selectedEntryIds.length > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedEntryIds.clear();
                              });
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _allEntries.length,
                        itemBuilder: (context, index) {
                          final entry = _allEntries[index];
                          final isSelected = _selectedEntryIds.contains(entry.id);
                          final dateStr = '${entry.createdAt.month}/${entry.createdAt.day}/${entry.createdAt.year}';
                          final preview = entry.content.length > 50 
                              ? '${entry.content.substring(0, 50)}...' 
                              : entry.content;
                          
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedEntryIds.add(entry.id);
                                } else {
                                  _selectedEntryIds.remove(entry.id);
                                }
                              });
                            },
                            title: Text(
                              dateStr,
                              style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              preview,
                              style: bodyStyle(context).copyWith(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Summary
            Text(
              'Export Summary',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Entries:', 
                    _useMultiSelect && _selectedEntryIds.isNotEmpty
                        ? '${_selectedEntryIds.length} selected'
                        : '$_entryCount (all)',
                  ),
                  _buildSummaryRow('Photos:', '$_photoCount'),
                  _buildSummaryRow('Chats:', '$_chatCount'),
                  _buildSummaryRow('LUMARA Favorites:', '$_favoritesCount'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Export button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isExporting ? null : _exportMcpPackage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _exportFormat == 'zip' ? Colors.blue : kcAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isExporting
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
                          Text('Creating Package...'),
                        ],
                      )
                    : Text(
                        _exportFormat == 'arcx' ? 'Create Secure Archive (.arcx)' : 'Create Zip File (.zip)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        title: Text(title, style: heading3Style(context)),
        subtitle: Text(subtitle, style: bodyStyle(context)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: kcAccentColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }


  Widget _buildDateRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Text('All entries', style: bodyStyle(context)),
            value: 'all',
            groupValue: _dateRangeSelection,
            onChanged: (value) {
              setState(() {
                _dateRangeSelection = value!;
              });
            },
            activeColor: kcAccentColor,
          ),
          RadioListTile<String>(
            title: Text('Custom date range', style: bodyStyle(context)),
            value: 'custom',
            groupValue: _dateRangeSelection,
            onChanged: (value) {
              setState(() {
                _dateRangeSelection = value!;
              });
            },
            activeColor: kcAccentColor,
          ),
          if (_dateRangeSelection == 'custom') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Start Date', style: bodyStyle(context).copyWith(fontSize: 14)),
                    subtitle: Text(
                      _customStartDate != null
                          ? DateFormat('yyyy-MM-dd').format(_customStartDate!)
                          : 'Not set',
                      style: bodyStyle(context).copyWith(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _customStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _customStartDate = date;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text('End Date', style: bodyStyle(context).copyWith(fontSize: 14)),
                    subtitle: Text(
                      _customEndDate != null
                          ? DateFormat('yyyy-MM-dd').format(_customEndDate!)
                          : 'Not set',
                      style: bodyStyle(context).copyWith(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _customEndDate ?? DateTime.now(),
                        firstDate: _customStartDate ?? DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _customEndDate = date;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}
