import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
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
  final String? initialFormat; // 'arcx', 'zip', or 'txt' - optional format pre-selection
  
  const McpExportScreen({super.key, this.initialFormat});

  @override
  State<McpExportScreen> createState() => _McpExportScreenState();
}

class _McpExportScreenState extends State<McpExportScreen> {
  bool _isExporting = false;
  String _exportFormat = 'arcx'; // 'arcx', 'zip', or 'txt'
  int _entryCount = 0;
  int _photoCount = 0;
  int _chatCount = 0;
  int _favoritesCount = 0;
  
  // Always using ARCX secure format (per spec - .zip option removed)
  
  // Chat export settings - always include archived chats
  final bool _includeArchivedChats = true;
  
  // Multi-select for entries
  bool _useMultiSelect = false;
  final Set<String> _selectedEntryIds = {};
  List<JournalEntry> _allEntries = [];
  
  // Password-based encryption (only for .arcx format)
  bool _usePasswordEncryption = false;
  String? _exportPassword;
  
  // ARCX V2 export options
  final ARCXExportStrategy _exportStrategy = ARCXExportStrategy.together; // Export strategy
  
  // Date range filtering
  String _dateRangeSelection = 'all'; // 'all', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Media pack target size (MB)
  int _mediaPackTargetSizeMB = 200;

  @override
  void initState() {
    super.initState();
    // Set initial format if provided
    if (widget.initialFormat != null) {
      _exportFormat = widget.initialFormat!;
    }
    // Reset export state to ensure clean initialization
    _resetExportState();
    _loadJournalStats();
  }

  @override
  void dispose() {
    // Clean up state when leaving the screen
    _resetExportState();
    super.dispose();
  }

  /// Resets all export state to default values
  void _resetExportState() {
    _useMultiSelect = false;
    _selectedEntryIds.clear();
    _dateRangeSelection = 'all';
    _customStartDate = null;
    _customEndDate = null;
    _usePasswordEncryption = false;
    _exportPassword = null;
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

    // Validate custom date range: require both start and end when "Custom date range" is selected
    if (_dateRangeSelection == 'custom') {
      if (_customStartDate == null || _customEndDate == null) {
        _showErrorDialog(
          'Please set both Start Date and End Date for the custom date range, or switch to "All entries".',
        );
        return;
      }
      if (_customStartDate!.isAfter(_customEndDate!)) {
        _showErrorDialog('Start date must be on or before end date.');
        return;
      }
    }

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
          setState(() => _isExporting = false);
          _showErrorDialog('No entries to export');
          return;
        }
      }

      // Create progress notifier
      final progressNotifier = ValueNotifier<String>('Preparing export...');
      
      // Show progress dialog
      _showProgressDialog(progressNotifier);

      // .txt export: plain text files, one per entry (date-filtered)
      if (_exportFormat == 'txt') {
        DateTime? startDate;
        DateTime? endDate;
        switch (_dateRangeSelection) {
          case 'custom':
            startDate = _customStartDate;
            if (_customEndDate != null) {
              endDate = DateTime(
                _customEndDate!.year,
                _customEndDate!.month,
                _customEndDate!.day,
                23,
                59,
                59,
                999,
              );
            }
            break;
          case 'all':
          default:
            break;
        }
        List<JournalEntry> filteredEntries = entries;
        if (startDate != null || endDate != null) {
          filteredEntries = entries.where((entry) {
            if (startDate != null && entry.createdAt.isBefore(startDate)) return false;
            if (endDate != null && entry.createdAt.isAfter(endDate)) return false;
            return true;
          }).toList();
        }
        if (filteredEntries.isEmpty) {
          if (mounted) Navigator.of(context).pop();
          setState(() => _isExporting = false);
          _showErrorDialog('No entries in the selected range.');
          return;
        }
        progressNotifier.value = 'Writing .txt files...';
        final outputDir = await getApplicationDocumentsDirectory();
        final exportDir = Directory(path.join(outputDir.path, 'Exports', 'txt_${DateTime.now().millisecondsSinceEpoch}'));
        await exportDir.create(recursive: true);
        String safeName(String s) => s.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
        final files = <XFile>[];
        for (var i = 0; i < filteredEntries.length; i++) {
          final e = filteredEntries[i];
          final name = e.title.isEmpty ? 'entry_$i' : safeName(e.title);
          final file = File(path.join(exportDir.path, '$name.txt'));
          await file.writeAsString(e.content, encoding: utf8);
          files.add(XFile(file.path));
        }
        if (mounted) Navigator.of(context).pop();
        setState(() => _isExporting = false);
        if (files.isEmpty) return;
        await Share.shareXFiles(
          files,
          text: files.length == 1 ? 'Exported as .txt' : 'Exported ${files.length} entries as .txt',
        );
        if (mounted) {
          _showSuccessDialog('Exported ${files.length} ${files.length == 1 ? 'entry' : 'entries'} as .txt');
        }
        return;
      }

      // ARCX for secure format or when password is set (ZIP + password => .arcx for compatibility)
      if (_exportFormat == 'arcx' || (_exportFormat == 'zip' && _usePasswordEncryption)) {
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
            mediaPackTargetSizeMB: _mediaPackTargetSizeMB,
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
        
        print('📦 ZIP Export: Starting export with ${entries.length} total entries');
        print('📦 ZIP Export: Date range selection: $_dateRangeSelection');
        
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
            print('📦 ZIP Export: Custom date range - Start: $startDate, End: $endDate');
            break;
          case 'all':
          default:
            print('📦 ZIP Export: Exporting all entries (no date filter)');
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
        
        // Validate we have entries to export
        if (filteredEntries.isEmpty) {
          Navigator.of(context).pop(); // Close progress dialog
          setState(() => _isExporting = false);
          _showErrorDialog('No entries found to export. Please check your date range selection.');
          return;
        }
        
        print('📦 ZIP Export: Exporting ${filteredEntries.length} entries (from ${entries.length} total)');
        
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
          mediaPackTargetSizeMB: _mediaPackTargetSizeMB,
        );
        
        if (result.success) {
          // Close progress dialog first
          Navigator.of(context).pop();
          
          
          // Show success dialog with result
          // Use similar dialog style but customized for ZIP
          showDialog(
            context: context,
            barrierDismissible: false,
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
                  onPressed: () {
                    // Reset export state after successful export
                    _resetExportState();
                    setState(() {});
                    Navigator.of(context).pop(); // Close success dialog
                    Navigator.of(context).pop(); // Navigate back to MCP Management screen
                  },
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close success dialog
                    Navigator.of(context).pop(); // Navigate back to MCP Management screen
                    // Share after navigation completes
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _shareMcpPackage(outputPath);
                    });
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        } else {
          Navigator.of(context).pop(); // Close progress dialog
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
      barrierColor: Colors.black54,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: progressNotifier,
        builder: (context, message, child) {
          return AlertDialog(
            backgroundColor: kcSurfaceColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Creating Secure Archive...',
                  style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: bodyStyle(context).copyWith(color: kcPrimaryTextColor),
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
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Archive saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
            onPressed: () {
              // Reset export state after successful export
              _resetExportState();
              setState(() {});
              Navigator.of(context).pop();
            },
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

  String _buildSummaryLine() {
    final n = _useMultiSelect && _selectedEntryIds.isNotEmpty
        ? _selectedEntryIds.length
        : _entryCount;
    if (_exportFormat == 'txt') return '$n ${n == 1 ? 'entry' : 'entries'}';
    final parts = ['$n entries', '$_photoCount photos'];
    if (_chatCount > 0) parts.add('$_chatCount chats');
    if (_favoritesCount > 0) parts.add('$_favoritesCount favorites');
    return parts.join(' · ');
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
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Export Failed',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: bodyStyle(context).copyWith(color: kcPrimaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: bodyStyle(context).copyWith(color: kcAccentColor)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Export complete',
                style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: bodyStyle(context).copyWith(color: kcPrimaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: bodyStyle(context).copyWith(color: kcAccentColor)),
          ),
        ],
      ),
    );
  }

  /// Trigger Google Drive upload if enabled

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

            // Security: only for ARCX/ZIP
            if (_exportFormat == 'arcx' || _exportFormat == 'zip') ...[
              _buildOptionTile(
                title: 'Encrypt with password',
                subtitle: _exportFormat == 'zip'
                    ? 'Save as .arcx; restore with password on any device'
                    : 'Restore on any device with password',
                value: _usePasswordEncryption,
                onChanged: (value) {
                  setState(() {
                    _usePasswordEncryption = value;
                    if (!value) {
                      _exportPassword = null;
                    } else if (_exportPassword == null) {
                      _showPasswordDialog();
                    }
                  });
                },
              ),
              if (_usePasswordEncryption && _exportPassword != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Password set', style: bodyStyle(context).copyWith(fontSize: 13)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _showPasswordDialog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Single options card: date range, choose entries, media pack (ARCX only)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date range',
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDateRangeSelector(),
                  const SizedBox(height: 16),
                  _buildOptionTile(
                    title: 'Choose specific entries',
                    subtitle: _useMultiSelect
                        ? '${_selectedEntryIds.length} selected'
                        : 'Export all entries in range',
                    value: _useMultiSelect,
                    onChanged: (value) {
                      setState(() {
                        _useMultiSelect = value;
                        if (!value) _resetExportState();
                      });
                    },
                  ),
                  if (_exportFormat == 'arcx') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Media pack size',
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _mediaPackTargetSizeMB.toDouble(),
                            min: 50,
                            max: 500,
                            divisions: 9,
                            label: '$_mediaPackTargetSizeMB MB',
                            onChanged: (value) {
                              setState(() => _mediaPackTargetSizeMB = value.round());
                            },
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '$_mediaPackTargetSizeMB MB',
                            style: bodyStyle(context).copyWith(fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (_useMultiSelect) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                constraints: const BoxConstraints(maxHeight: 220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedEntryIds.length} of ${_allEntries.length} selected',
                          style: bodyStyle(context).copyWith(fontSize: 13),
                        ),
                        if (_selectedEntryIds.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _selectedEntryIds.clear()),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _allEntries.length,
                        itemBuilder: (context, index) {
                          final entry = _allEntries[index];
                          final isSelected = _selectedEntryIds.contains(entry.id);
                          final dateStr = DateFormat.yMMMd().format(entry.createdAt);
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
                              style: bodyStyle(context).copyWith(fontSize: 13),
                            ),
                            subtitle: Text(
                              entry.title.isEmpty
                                  ? (entry.content.length > 40 ? '${entry.content.substring(0, 40)}...' : entry.content)
                                  : entry.title,
                              style: bodyStyle(context).copyWith(fontSize: 12, color: kcSecondaryTextColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // One-line summary
            Text(
              _buildSummaryLine(),
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),

            const SizedBox(height: 20),

            // Export button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isExporting ? null : _exportMcpPackage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _exportFormat == 'zip'
                      ? Colors.blue
                      : _exportFormat == 'txt'
                          ? Colors.teal
                          : kcAccentColor,
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
                        _exportFormat == 'txt'
                            ? 'Create Text Files (.txt)'
                            : _exportFormat == 'arcx'
                                ? 'Create Secure Archive (.arcx)'
                                : 'Create Zip File (.zip)',
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
    return ListTile(
      title: Text(title, style: bodyStyle(context).copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: bodyStyle(context).copyWith(fontSize: 12, color: kcSecondaryTextColor)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: kcAccentColor,
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }


  Widget _buildDateRangeSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RadioListTile<String>(
          title: Text('All entries', style: bodyStyle(context).copyWith(fontSize: 14)),
          value: 'all',
          groupValue: _dateRangeSelection,
          onChanged: (value) {
            setState(() => _dateRangeSelection = value!);
          },
          activeColor: kcAccentColor,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<String>(
          title: Text('Custom range', style: bodyStyle(context).copyWith(fontSize: 14)),
          value: 'custom',
          groupValue: _dateRangeSelection,
          onChanged: (value) {
            setState(() => _dateRangeSelection = value!);
          },
          activeColor: kcAccentColor,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (_dateRangeSelection == 'custom') ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _customStartDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _customStartDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _customStartDate != null
                        ? DateFormat.yMMMd().format(_customStartDate!)
                        : 'Start',
                    style: bodyStyle(context).copyWith(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kcPrimaryTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _customEndDate ?? _customStartDate ?? DateTime.now(),
                      firstDate: _customStartDate ?? DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _customEndDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _customEndDate != null
                        ? DateFormat.yMMMd().format(_customEndDate!)
                        : 'End',
                    style: bodyStyle(context).copyWith(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kcPrimaryTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

}
