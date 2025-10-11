import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/data/models/media_item.dart';
import '../../../mcp/orchestrator/ios_vision_orchestrator.dart';
import '../../../state/journal_entry_state.dart';
import '../../../ui/widgets/cached_thumbnail.dart';
import '../../../services/thumbnail_cache_service.dart';

class JournalEditView extends StatefulWidget {
  final TimelineEntry entry;
  final int entryIndex;

  const JournalEditView({
    super.key,
    required this.entry,
    required this.entryIndex,
  });

  @override
  State<JournalEditView> createState() => _JournalEditViewState();
}

class _JournalEditViewState extends State<JournalEditView> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  String? _selectedMood;
  List<String> _selectedKeywords = [];
  late String _currentPhase;
  late String _currentGeometry;
  late DateTime _selectedDateTime;
  
  // Multimodal functionality
  final ImagePicker _imagePicker = ImagePicker();
  late final IOSVisionOrchestrator _ocpOrchestrator;
  final List<dynamic> _attachments = []; // Can contain ScanAttachment or PhotoAttachment
  
  // Thumbnail cache service
  final ThumbnailCacheService _thumbnailCache = ThumbnailCacheService();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.preview);
    _focusNode = FocusNode();
    
    // Initialize multimodal functionality
    _ocpOrchestrator = IOSVisionOrchestrator();
    _ocpOrchestrator.initialize();
    _thumbnailCache.initialize();
    
    // Get the actual journal entry to access metadata and timestamp
    final journalRepository = JournalRepository();
    final journalEntry = journalRepository.getJournalEntryById(widget.entry.id);
    _selectedDateTime = journalEntry?.createdAt ?? DateTime.now();
    
    // Initialize with existing data, prioritizing journal entry metadata
    _selectedMood = null; // TimelineEntry doesn't have mood, will be set by user
    _selectedKeywords = List<String>.from(widget.entry.keywords);
    
    // Check if journal entry has user-updated metadata first
    if (journalEntry?.metadata != null && journalEntry!.metadata!['updated_by_user'] == true) {
      _currentPhase = journalEntry.metadata!['phase'] as String? ?? 'Discovery';
      _currentGeometry = journalEntry.metadata!['geometry'] as String? ?? 'spiral';
      print('DEBUG: Using user-updated metadata - Phase: $_currentPhase, Geometry: $_currentGeometry');
    } else {
      // Fallback to TimelineEntry phase/geometry
      _currentPhase = widget.entry.phase ?? 'Discovery';
      _currentGeometry = widget.entry.geometry ?? 'spiral';
      print('DEBUG: Using TimelineEntry - Phase: $_currentPhase, Geometry: $_currentGeometry');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    
    // Clean up thumbnails when timeline editor is closed
    _thumbnailCache.clearAllThumbnails();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('Edit Entry', style: heading1Style(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text('Save', style: buttonStyle(context)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry date/time picker
              _buildDateTimeSection(),
              
              const SizedBox(height: 24),

              // Mood selection
              _buildMoodSection(),
              
              const SizedBox(height: 24),

              // Keywords section
              _buildKeywordsSection(),
              
              const SizedBox(height: 24),

              // Arcform section
              _buildArcformSection(),
              
              const SizedBox(height: 24),

              // Multimodal toolbar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kcSecondaryTextColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Photo gallery button
                    IconButton(
                      onPressed: _handlePhotoGallery,
                      icon: const Icon(Icons.add_photo_alternate),
                      tooltip: 'Add Photo from Gallery',
                      style: IconButton.styleFrom(
                        foregroundColor: kcPrimaryColor,
                        backgroundColor: kcPrimaryColor.withOpacity(0.1),
                      ),
                    ),
                    
                    // Camera button
                    IconButton(
                      onPressed: _handleCamera,
                      icon: const Icon(Icons.camera_alt),
                      tooltip: 'Take Photo',
                      style: IconButton.styleFrom(
                        foregroundColor: kcPrimaryColor,
                        backgroundColor: kcPrimaryColor.withOpacity(0.1),
                      ),
                    ),
                    
                    // Microphone button
                    IconButton(
                      onPressed: _handleMicrophone,
                      icon: const Icon(Icons.mic),
                      tooltip: 'Add Voice Note',
                      style: IconButton.styleFrom(
                        foregroundColor: kcPrimaryColor,
                        backgroundColor: kcPrimaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // Text editor
              Container(
                height: 200, // Fixed height to prevent overflow
                decoration: BoxDecoration(
                  color: kcSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kcSecondaryTextColor.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: bodyStyle(context),
                  decoration: InputDecoration(
                    hintText: 'Edit your journal entry...',
                    hintStyle: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  cursorColor: kcPrimaryColor,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(2),
                ),
              ),
              
              // Photo attachments display
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAttachmentsSection(),
                const SizedBox(height: 16),
              ],
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & Time',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectDateTime,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: kcPrimaryGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: kcPrimaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entry Date & Time:',
                  style: captionStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDateTime(_selectedDateTime),
                        style: heading1Style(context).copyWith(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_calendar,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSection() {
    final moods = ['happy', 'sad', 'anxious', 'calm', 'excited', 'grateful', 'confused', 'hopeful'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moods.map((mood) {
            final isSelected = _selectedMood == mood;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMood = isSelected ? null : mood;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? kcPrimaryColor 
                      : kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? kcPrimaryColor 
                        : kcSecondaryTextColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  mood,
                  style: bodyStyle(context).copyWith(
                    color: isSelected 
                        ? Colors.white 
                        : kcPrimaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKeywordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keywords',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        if (_selectedKeywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedKeywords.map((keyword) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kcPrimaryColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      keyword,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedKeywords.remove(keyword);
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: kcPrimaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          decoration: InputDecoration(
            hintText: 'Add keywords (press Enter to add)',
            hintStyle: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kcSecondaryTextColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kcPrimaryColor),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && !_selectedKeywords.contains(value.trim())) {
              setState(() {
                _selectedKeywords.add(value.trim());
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildArcformSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Arcform',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kcSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kcSecondaryTextColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              // Phase display
              Row(
                children: [
                  Icon(
                    _getPhaseIcon(_currentPhase),
                    color: _getPhaseColor(_currentPhase),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Phase: $_currentPhase',
                    style: bodyStyle(context).copyWith(
                      color: _getPhaseColor(_currentPhase),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Arcform visualization with edit capability
              GestureDetector(
                onTap: () => _showArcformEditDialog(),
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kcSurfaceAltColor,
                    border: Border.all(
                      color: kcPrimaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          _getGeometryIcon(_currentGeometry),
                          color: kcPrimaryColor,
                          size: 40,
                        ),
                      ),
                      // Edit indicator
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: kcPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Tap to edit arcform',
                style: captionStyle(context).copyWith(
                  color: kcPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Icons.explore;
      case 'expansion':
        return Icons.local_florist;
      case 'transition':
        return Icons.trending_up;
      case 'consolidation':
        return Icons.grid_view;
      case 'recovery':
        return Icons.healing;
      case 'breakthrough':
        return Icons.auto_fix_high;
      default:
        return Icons.circle;
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple  
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFF7C2D12); // Brown
      default:
        return kcSecondaryTextColor;
    }
  }

  IconData _getGeometryIcon(String? geometry) {
    switch (geometry?.toLowerCase()) {
      case 'spiral':
        return Icons.explore;
      case 'flower':
        return Icons.local_florist;
      case 'branch':
        return Icons.trending_up;
      case 'weave':
        return Icons.grid_view;
      case 'glowcore':
        return Icons.healing;
      case 'fractal':
        return Icons.auto_fix_high;
      default:
        return Icons.auto_awesome;
    }
  }

  void _showArcformEditDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _PhaseEditDialog(
          currentPhase: _currentPhase,
          currentGeometry: _currentGeometry,
          onPhaseChanged: (newPhase, newGeometry) async {
            try {
              // Show loading state
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Updating phase...'),
                  backgroundColor: kcPrimaryColor,
                  duration: Duration(seconds: 1),
                ),
              );

              // Update the entry phase in the database
              final timelineCubit = context.read<TimelineCubit>();
              await timelineCubit.updateEntryPhase(
                widget.entry.id, 
                newPhase, 
                newGeometry,
              );

              // Update local state to reflect the change immediately
              setState(() {
                _currentPhase = newPhase;
                _currentGeometry = newGeometry;
              });

              // Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Phase updated to $newPhase'),
                    backgroundColor: kcSuccessColor,
                  ),
                );
              }
            } catch (e) {
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update phase'),
                    backgroundColor: kcDangerColor,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _onSavePressed() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text before saving'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    try {
      // Show loading state
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating entry...'),
          backgroundColor: kcPrimaryColor,
          duration: Duration(seconds: 1),
        ),
      );

      // Get the repository and update the entry
      final journalRepository = JournalRepository();
      final existingEntry = journalRepository.getJournalEntryById(widget.entry.id);

      if (existingEntry == null) {
        throw Exception('Entry not found');
      }

      // Update metadata with new keywords, mood, and phase
      final updatedMetadata = Map<String, dynamic>.from(existingEntry.metadata ?? {});
      updatedMetadata['keywords'] = _selectedKeywords;
      updatedMetadata['phase'] = _currentPhase;
      updatedMetadata['geometry'] = _currentGeometry;
      if (_selectedMood != null) {
        updatedMetadata['mood'] = _selectedMood;
      }
      updatedMetadata['updated_by_user'] = true;
      updatedMetadata['last_modified'] = DateTime.now().toIso8601String();

        // Convert attachments to MediaItem objects
        final mediaItems = _attachments.map((attachment) {
          if (attachment is PhotoAttachment) {
            return MediaItem(
              id: 'photo_${attachment.timestamp}',
              uri: attachment.imagePath,
              type: MediaType.image,
              sizeBytes: null, // Could be calculated if needed
              createdAt: DateTime.fromMillisecondsSinceEpoch(attachment.timestamp),
              ocrText: attachment.analysisResult['ocr']?['fullText'] as String?,
              transcript: null,
            );
          } else if (attachment is ScanAttachment) {
            return MediaItem(
              id: 'scan_${attachment.sourceImageId}',
              uri: attachment.sourceImageId,
              type: MediaType.image,
              sizeBytes: null,
              createdAt: DateTime.now(),
              ocrText: attachment.text,
              transcript: null,
            );
          }
          return null;
        }).where((item) => item != null).cast<MediaItem>().toList();

        // Update the journal entry with new text, metadata, media, and timestamp
        final updatedEntry = existingEntry.copyWith(
          content: _textController.text.trim(),
          metadata: updatedMetadata,
          media: mediaItems,
          createdAt: _selectedDateTime,
          updatedAt: DateTime.now(),
        );

      await journalRepository.updateJournalEntry(updatedEntry);

        // Also update the timeline cubit to refresh the UI
        if (mounted) {
          final timelineCubit = context.read<TimelineCubit>();
          await timelineCubit.refreshEntries();
        }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry updated successfully'),
            backgroundColor: kcSuccessColor,
          ),
        );
      }

      Navigator.of(context).pop();
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update entry: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (entryDate == today) {
      return 'Today, ${_formatTime(dateTime)}';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${_formatTime(dateTime)}';
    } else {
      return '${_formatDate(dateTime)}, ${_formatTime(dateTime)}';
    }
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kcPrimaryColor,
              onPrimary: Colors.white,
              surface: kcSurfaceColor,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: kcPrimaryColor,
                onPrimary: Colors.white,
                surface: kcSurfaceColor,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _handlePhotoGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processPhotoWithOCP(image.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick photo: $e');
    }
  }

  Future<void> _handleCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _processPhotoWithOCP(image.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<void> _handleMicrophone() async {
    // Show placeholder for voice recording
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice recording feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _processPhotoWithOCP(String imagePath) async {
    try {
      // Show processing indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 Analyzing photo with iOS Vision AI...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Run OCP analysis
      final result = await _ocpOrchestrator.processPhoto(
        imagePath: imagePath,
        ocrEngine: 'ios_vision',
        language: 'auto',
        maxProcessingMs: 1500,
      );

      if (result['success'] == true) {
        // Create photo attachment
        final photoAttachment = PhotoAttachment(
          type: 'photo_analysis',
          imagePath: imagePath,
          analysisResult: result,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        setState(() {
          _attachments.add(photoAttachment);
        });

        // Insert analysis summary
        final summary = result['summary'] as String? ?? 'Photo analyzed';
        final ocrText = result['ocr']?['fullText'] as String? ?? '';
        
        if (ocrText.isNotEmpty) {
          _insertTextIntoEntry('📸 **Photo Analysis**\n$summary\n\n**Text Found:**\n$ocrText');
        } else {
          _insertTextIntoEntry('📸 **Photo Analysis**\n$summary');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $summary'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Unknown error');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to analyze photo: $e');
    }
  }

  void _insertTextIntoEntry(String text) {
    final currentText = _textController.text;
    final cursorPosition = _textController.selection.baseOffset;
    
    final newText = '${currentText.substring(0, cursorPosition)}\n\n$text${currentText.substring(cursorPosition)}';
    
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: cursorPosition + text.length + 2,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kcDangerColor,
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo Attachments',
          style: heading1Style(context).copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._attachments.asMap().entries.map((entry) {
          final index = entry.key;
          final attachment = entry.value;
          
          if (attachment is PhotoAttachment) {
            return _buildPhotoAttachment(attachment, index);
          } else if (attachment is ScanAttachment) {
            return _buildScanAttachment(attachment, index);
          }
          return const SizedBox.shrink();
        }).toList(),
      ],
    );
  }

  Widget _buildPhotoAttachment(PhotoAttachment attachment, int index) {
    final analysis = attachment.analysisResult;
    final summary = analysis['summary'] as String? ?? 'Photo analyzed';
    final features = analysis['features'] as Map? ?? {};
    final keypoints = features['kp'] as int? ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: kcSecondaryTextColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_camera,
                size: 16,
                color: kcPrimaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Photo Analysis',
                style: bodyStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: kcPrimaryColor.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Photo thumbnail - Clickable
          Row(
            children: [
              CachedThumbnail(
                imagePath: attachment.imagePath,
                width: 60,
                height: 60,
                borderRadius: BorderRadius.circular(6),
                onTap: () => _openPhotoInGallery(attachment.imagePath),
                showTapIndicator: true,
                placeholder: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Analysis details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: bodyStyle(context).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Features: $keypoints keypoints',
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
          
          const SizedBox(height: 8),
          Text(
            'Tap thumbnail to view photo',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryColor,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanAttachment(ScanAttachment attachment, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: kcSecondaryTextColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.document_scanner,
            size: 16,
            color: kcPrimaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Scan: ${attachment.text}',
              style: bodyStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openPhotoInGallery(String imagePath) async {
    try {
      if (Platform.isIOS) {
        // For iOS, try to open the Photos app directly
        // This will open the Photos app, though it may not navigate to the specific photo
        final photosUri = Uri.parse('photos-redirect://');
        if (await canLaunchUrl(photosUri)) {
          await launchUrl(photosUri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback: try to open the file directly
          final file = File(imagePath);
          if (await file.exists()) {
            final uri = Uri.file(imagePath);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _showPhotoInfo(imagePath);
            }
          } else {
            throw Exception('Photo file not found');
          }
        }
      } else {
        // For Android, try to open the file directly
        final uri = Uri.file(imagePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showPhotoInfo(imagePath);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open photo: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  void _showPhotoInfo(String imagePath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Photo saved: ${imagePath.split('/').last}'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Open Photos',
          onPressed: () async {
            final photosUri = Uri.parse('photos-redirect://');
            if (await canLaunchUrl(photosUri)) {
              await launchUrl(photosUri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }
}

class _PhaseEditDialog extends StatefulWidget {
  final String currentPhase;
  final String currentGeometry;
  final Function(String phase, String geometry) onPhaseChanged;

  const _PhaseEditDialog({
    required this.currentPhase,
    required this.currentGeometry,
    required this.onPhaseChanged,
  });

  @override
  State<_PhaseEditDialog> createState() => _PhaseEditDialogState();
}

class _PhaseEditDialogState extends State<_PhaseEditDialog> {
  late String _selectedPhase;
  late String _selectedGeometry;

  final Map<String, String> _phaseDescriptions = {
    'Discovery': 'Exploring new insights and beginnings',
    'Expansion': 'Expanding awareness and growth', 
    'Transition': 'Navigating transitions and choices',
    'Consolidation': 'Integrating experiences and wisdom',
    'Recovery': 'Healing and restoring balance',
    'Breakthrough': 'Breaking through to new levels',
  };

  final Map<String, String> _phaseToGeometry = {
    'Discovery': 'spiral',
    'Expansion': 'flower',
    'Transition': 'branch', 
    'Consolidation': 'weave',
    'Recovery': 'glowcore',
    'Breakthrough': 'fractal',
  };

  @override
  void initState() {
    super.initState();
    _selectedPhase = widget.currentPhase;
    _selectedGeometry = widget.currentGeometry;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kcBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Edit Phase',
              style: heading1Style(context).copyWith(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a new phase for this entry',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),

            // Phase Selection
            Expanded(
              child: ListView(
                children: _phaseDescriptions.entries.map((entry) {
                  final phase = entry.key;
                  final description = entry.value;
                  final isSelected = phase == _selectedPhase;
                  final isCurrent = phase == widget.currentPhase;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? kcPrimaryColor.withOpacity(0.2)
                          : kcSurfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? kcPrimaryColor
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(
                        _getPhaseIcon(phase),
                        color: _getPhaseColor(phase),
                        size: 24,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              phase,
                              style: heading3Style(context).copyWith(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: kcAccentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Current",
                                style: captionStyle(context).copyWith(
                                  color: kcAccentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          description,
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPhase = phase;
                          _selectedGeometry = _phaseToGeometry[phase] ?? 'spiral';
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: kcSecondaryColor.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: buttonStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPhaseChanged(_selectedPhase, _selectedGeometry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Update Phase',
                      style: buttonStyle(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Icons.explore;
      case 'expansion':
        return Icons.local_florist;
      case 'transition':
        return Icons.trending_up;
      case 'consolidation':
        return Icons.grid_view;
      case 'recovery':
        return Icons.healing;
      case 'breakthrough':
        return Icons.auto_fix_high;
      default:
        return Icons.circle;
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple  
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFF7C2D12); // Brown
      default:
        return kcSecondaryTextColor;
    }
  }
}
