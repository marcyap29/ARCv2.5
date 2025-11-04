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
import '../../utils/file_utils.dart';
import '../../arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/lumara/chat/chat_repo_impl.dart';
import 'package:intl/intl.dart';

/// MCP Export Screen - Create MCP Package (.mcpkg)
class McpExportScreen extends StatefulWidget {
  const McpExportScreen({super.key});

  @override
  State<McpExportScreen> createState() => _McpExportScreenState();
}

class _McpExportScreenState extends State<McpExportScreen> {
  bool _isExporting = false;
  int _entryCount = 0;
  int _photoCount = 0;
  String _estimatedSize = 'Calculating...';
  
  // Always using ARCX secure format (per spec - .zip option removed)
  
  // Chat export settings
  bool _includeArchivedChats = false;
  
  // Multi-select for entries
  bool _useMultiSelect = false;
  Set<String> _selectedEntryIds = {};
  List<JournalEntry> _allEntries = [];
  
  // ARCX redaction settings (only visible when secure format is selected)
  bool _includePhotoLabels = false;
  bool _dateOnlyTimestamps = false;
  bool _removePii = false; // New: user-controlled PII removal (default Off)
  
  // Password-based encryption (only for .arcx format)
  bool _usePasswordEncryption = false;
  String? _exportPassword;
  
  // ARCX V2 export options
  ARCXExportStrategy _exportStrategy = ARCXExportStrategy.together; // Export strategy
  int _mediaPackTargetSizeMB = 200; // Target size for media packs in MB
  
  // Date range filtering
  String _dateRangeSelection = 'all'; // 'all', 'last6months', 'lastyear', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
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

      setState(() {
        _entryCount = entries.length;
        _photoCount = photoCount;
        _estimatedSize = _calculateEstimatedSize(entries);
      });
    } catch (e) {
      print('Error loading journal stats: $e');
    }
  }

  String _calculateEstimatedSize(List<JournalEntry> entries) {
    // Rough estimation: 1KB per entry + 500KB per photo
    final estimatedBytes = (_entryCount * 1024) + (_photoCount * 500 * 1024);
    return FileUtils.formatFileSize(estimatedBytes);
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
      
      // Extract dates from selected entries for filtering associated data
      final selectedDates = <String>{};
      for (final entry in entries) {
        final date = '${entry.createdAt.year.toString().padLeft(4, '0')}-'
                     '${entry.createdAt.month.toString().padLeft(2, '0')}-'
                     '${entry.createdAt.day.toString().padLeft(2, '0')}';
        selectedDates.add(date);
      }

      // Create progress notifier
      final progressNotifier = ValueNotifier<String>('Preparing export...');
      
      // Show progress dialog
      _showProgressDialog(progressNotifier);

      // Always use ARCX secure format (per spec - .zip option removed)
      {
        // Secure .arcx export
        final outputDir = await getApplicationDocumentsDirectory();
        final exportsDir = Directory(path.join(outputDir.path, 'Exports'));
        if (!await exportsDir.exists()) {
          await exportsDir.create(recursive: true);
        }

        // Collect photo media items from journal entries (always included)
        final photoMedia = <MediaItem>[];
        for (final entry in entries) {
          photoMedia.addAll(entry.media.where((m) => m.type == MediaType.image));
        }

        // Use ARCX Export Service V2 (new specification)
        final chatRepo = ChatRepoImpl.instance;
        try {
          await chatRepo.initialize();
        } catch (e) {
          print('Warning: Could not initialize ChatRepo: $e');
        }
        
        final arcxExportV2 = ARCXExportServiceV2(
          journalRepo: journalRepo,
          chatRepo: chatRepo,
        );
        
        // Build selection from entries
        final entryIds = entries.map((e) => e.id).toList();
        final mediaIds = photoMedia.map((m) => m.id).toList();
        
        // Get chat thread IDs (always included, filtered by date range)
        final chatThreadIds = <String>[];
        final allChats = await chatRepo.listAll(includeArchived: _includeArchivedChats);
        // Filter chats by selected dates if dates are available
        if (selectedDates.isNotEmpty) {
          for (final chat in allChats) {
            final chatDate = '${chat.createdAt.year.toString().padLeft(4, '0')}-'
                           '${chat.createdAt.month.toString().padLeft(2, '0')}-'
                           '${chat.createdAt.day.toString().padLeft(2, '0')}';
            if (selectedDates.contains(chatDate)) {
              chatThreadIds.add(chat.id);
            }
          }
        } else {
          chatThreadIds.addAll(allChats.map((c) => c.id));
        }
        
        // Calculate date range based on selection
        DateTime? startDate;
        DateTime? endDate;
        final now = DateTime.now();
        
        switch (_dateRangeSelection) {
          case 'last6months':
            startDate = DateTime(now.year, now.month - 6, now.day);
            break;
          case 'lastyear':
            startDate = DateTime(now.year - 1, now.month, now.day);
            break;
          case 'custom':
            startDate = _customStartDate;
            endDate = _customEndDate;
            break;
          case 'all':
          default:
            // No date filtering
            break;
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
            mediaPackTargetSizeMB: _mediaPackTargetSizeMB,
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
          _showArcSuccessDialogV2(result);
        } else {
          _showErrorDialog(result.error ?? 'ARCX export failed');
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
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'MCP Package - $_entryCount entries, $_photoCount photos',
        subject: 'Journal Export - ${path.basename(filePath)}',
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

  Widget _buildFilePath(String label, String path) {
    // Extract just the filename for display
    final filename = path.split('/').last;
    // Truncate if too long (keep first 30 and last 10 chars with ellipsis)
    final truncatedFilename = filename.length > 40 
        ? '${filename.substring(0, 30)}...${filename.substring(filename.length - 10)}' 
        : filename;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              truncatedFilename,
              style: bodyStyle(context).copyWith(
                fontFamily: 'monospace',
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        title: Text(
          'Create MCP Package',
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
                    'Choose your export format: Legacy MCP (.zip) for compatibility, or Secure Archive (.arcx) with AES-256 encryption.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can re-import either format at any time to restore your data.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Export format - ARCX is now the only format (per spec)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Archive (.arcx)',
                          style: heading3Style(context).copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Encrypted with AES-256-GCM and Ed25519 signing',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Redaction settings (ARCX format only)
            ...[
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
                    const SizedBox(height: 12),
                    _buildOptionTile(
                      title: 'Remove PII',
                      subtitle: 'Strip names, emails, device IDs, IPs, locations from JSON',
                      value: _removePii,
                      onChanged: (value) {
                        setState(() {
                          _removePii = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      title: 'Include photo labels',
                      subtitle: 'Include AI-generated photo descriptions (may contain sensitive info)',
                      value: _includePhotoLabels,
                      onChanged: (value) {
                        setState(() {
                          _includePhotoLabels = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      title: 'Date-only timestamps',
                      subtitle: 'Reduce timestamp precision to date only (e.g., 2024-01-15 instead of full datetime)',
                      value: _dateOnlyTimestamps,
                      onChanged: (value) {
                        setState(() {
                          _dateOnlyTimestamps = value;
                        });
                      },
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
              
              // ARCX V2 Advanced Options
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
                    const SizedBox(height: 12),
                    Text(
                      'Export Strategy',
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStrategySelector(),
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
                    const SizedBox(height: 16),
                    Text(
                      'Media pack target size: ${_mediaPackTargetSizeMB} MB',
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _mediaPackTargetSizeMB.toDouble(),
                      min: 50,
                      max: 500,
                      divisions: 9, // 50, 100, 150, ..., 500
                      label: '${_mediaPackTargetSizeMB} MB',
                      onChanged: (value) {
                        setState(() {
                          _mediaPackTargetSizeMB = value.round();
                        });
                      },
                    ),
                    Text(
                      'Media will be split into packs of approximately ${_mediaPackTargetSizeMB} MB each',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Options
            Text(
              'Export Options',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Include archived chats option
            _buildOptionTile(
              title: 'Include archived chats',
              subtitle: 'Export archived chat sessions as well',
              value: _includeArchivedChats,
              onChanged: (value) {
                setState(() {
                  _includeArchivedChats = value;
                });
              },
            ),

            // Multi-select option
            const SizedBox(height: 8),
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
                  _buildSummaryRow('Chats:', 'Will be included'),
                  _buildSummaryRow('Estimated size:', _estimatedSize),
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
                  backgroundColor: kcAccentColor,
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
                    : const Text(
                        'Create Secure Archive (.arcx)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildStrategySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          RadioListTile<ARCXExportStrategy>(
            title: Text('All together', style: bodyStyle(context)),
            subtitle: Text('Single archive with all entries, chats, and media', style: bodyStyle(context).copyWith(fontSize: 12)),
            value: ARCXExportStrategy.together,
            groupValue: _exportStrategy,
            onChanged: (value) {
              setState(() {
                _exportStrategy = value!;
              });
            },
            activeColor: kcAccentColor,
          ),
          RadioListTile<ARCXExportStrategy>(
            title: Text('Separate groups (3 archives)', style: bodyStyle(context)),
            subtitle: Text('Entries, Chats, and Media as separate packages', style: bodyStyle(context).copyWith(fontSize: 12)),
            value: ARCXExportStrategy.separateGroups,
            groupValue: _exportStrategy,
            onChanged: (value) {
              setState(() {
                _exportStrategy = value!;
              });
            },
            activeColor: kcAccentColor,
          ),
          RadioListTile<ARCXExportStrategy>(
            title: Text('Entries+Chats together, Media separate (2 archives)', style: bodyStyle(context)),
            subtitle: Text('Compressed entries/chats archive + uncompressed media archive', style: bodyStyle(context).copyWith(fontSize: 12)),
            value: ARCXExportStrategy.entriesChatsTogetherMediaSeparate,
            groupValue: _exportStrategy,
            onChanged: (value) {
              setState(() {
                _exportStrategy = value!;
              });
            },
            activeColor: kcAccentColor,
          ),
        ],
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
            title: Text('Last 6 months', style: bodyStyle(context)),
            value: 'last6months',
            groupValue: _dateRangeSelection,
            onChanged: (value) {
              setState(() {
                _dateRangeSelection = value!;
              });
            },
            activeColor: kcAccentColor,
          ),
          RadioListTile<String>(
            title: Text('Last year', style: bodyStyle(context)),
            value: 'lastyear',
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
