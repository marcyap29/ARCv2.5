// lib/arc/phase/share/phase_share_composition_screen.dart
// UI screen for composing phase transition shares

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../models/phase_models.dart';
import '../../../services/phase_regime_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/rivet_sweep_service.dart';
import 'phase_share_models.dart';
import 'phase_share_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class PhaseShareCompositionScreen extends StatefulWidget {
  final PhaseLabel phaseName;
  final DateTime transitionDate;
  final String? initialCaption;

  const PhaseShareCompositionScreen({
    super.key,
    required this.phaseName,
    required this.transitionDate,
    this.initialCaption,
  });

  @override
  State<PhaseShareCompositionScreen> createState() => _PhaseShareCompositionScreenState();
}

class _PhaseShareCompositionScreenState extends State<PhaseShareCompositionScreen> {
  final PhaseShareService _shareService = PhaseShareService.instance;
  final TextEditingController _captionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _includeDuration = false;
  bool _includePhaseCount = false;
  bool _includeTimeline = true;
  SharePlatform _selectedPlatform = SharePlatform.instagram;
  bool _isGenerating = false;
  bool _isSharing = false;
  Uint8List? _generatedImage;
  PhaseShare? _currentShare;
  List<PhaseTimelineData> _timelineData = [];
  int? _phaseCount;
  Duration? _previousPhaseDuration;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _captionController.text = widget.initialCaption ?? '';
    _loadShareData();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadShareData() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Load timeline data
      final timeline = await _shareService.getTimelineData(
        phaseRegimeService: phaseRegimeService,
        currentDate: widget.transitionDate,
      );

      // Load phase count
      final count = await _shareService.getPhaseCount(
        phaseRegimeService: phaseRegimeService,
        phase: widget.phaseName,
      );

      // Load previous phase duration
      final duration = await _shareService.getPreviousPhaseDuration(
        phaseRegimeService: phaseRegimeService,
        transitionDate: widget.transitionDate,
      );

      if (mounted) {
        setState(() {
          _timelineData = timeline;
          _phaseCount = count;
          _previousPhaseDuration = duration;
        });
      }
    } catch (e) {
      debugPrint('Error loading share data: $e');
    }
  }

  Future<void> _generateImage() async {
    if (_captionController.text.trim().length < 10) {
      setState(() {
        _validationError = 'Caption must be at least 10 characters';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _validationError = null;
    });

    try {
      final share = PhaseShare(
        phaseId: 'phase_${widget.transitionDate.millisecondsSinceEpoch}',
        phaseName: widget.phaseName,
        transitionDate: widget.transitionDate,
        userCaption: _captionController.text.trim(),
        includeDuration: _includeDuration,
        includePhaseCount: _includePhaseCount,
        includeTimeline: _includeTimeline,
        timelineData: _includeTimeline ? _timelineData : [],
        phaseCount: _phaseCount,
        previousPhaseDuration: _previousPhaseDuration,
      );

      // Validate share
      final validation = _shareService.validateShare(share);
      if (!validation.isValid) {
        setState(() {
          _validationError = validation.errorMessage;
          _isGenerating = false;
        });
        return;
      }

      // Generate image
      final imageBytes = await _shareService.generateShareImage(share, _selectedPlatform);

      if (mounted) {
        setState(() {
          _generatedImage = imageBytes;
          _currentShare = share.copyWith(imageBytes: imageBytes, platform: _selectedPlatform);
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Error generating image: $e';
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null || _currentShare == null) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      // Save image to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/phase_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_generatedImage!);

      // Share using native share sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _currentShare!.userCaption,
      );

      // Mark as shared
      await _shareService.markAsShared();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phase transition shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Error sharing: $e';
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kcPrimaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Share Phase Transition',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview section
              if (_generatedImage != null) ...[
                _buildPreviewSection(),
                const SizedBox(height: 24),
              ],

              // Caption input
              _buildCaptionSection(),
              const SizedBox(height: 24),

              // Optional toggles
              _buildOptionsSection(),
              const SizedBox(height: 24),

              // Platform selector
              _buildPlatformSection(),
              const SizedBox(height: 24),

              // Validation error
              if (_validationError != null)
                _buildErrorSection(_validationError!),

              const SizedBox(height: 24),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
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
            'Preview',
            style: heading3Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_generatedImage != null)
            Image.memory(
              _generatedImage!,
              fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }

  Widget _buildCaptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Caption *',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Write your own reflection on this phase transition (10-500 characters)',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _captionController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Share your thoughts on entering this phase...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
          style: bodyStyle(context),
          validator: (value) {
            if (value == null || value.trim().length < 10) {
              return 'Caption must be at least 10 characters';
            }
            if (value.trim().length > 500) {
              return 'Caption must be less than 500 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${_captionController.text.length}/500',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optional Information',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(
            'Include Timeline',
            style: bodyStyle(context),
          ),
          subtitle: Text(
            'Show last 6 months of phase transitions',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 12,
            ),
          ),
          value: _includeTimeline,
          onChanged: (value) => setState(() => _includeTimeline = value),
        ),
        if (_previousPhaseDuration != null)
          SwitchListTile(
            title: Text(
              'Include Duration',
              style: bodyStyle(context),
            ),
            subtitle: Text(
              'Show time spent in previous phase',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
            value: _includeDuration,
            onChanged: (value) => setState(() => _includeDuration = value),
          ),
        if (_phaseCount != null)
          SwitchListTile(
            title: Text(
              'Include Phase Count',
              style: bodyStyle(context),
            ),
            subtitle: Text(
              'Show which instance of this phase (e.g., "My 3rd Discovery phase")',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
            value: _includePhaseCount,
            onChanged: (value) => setState(() => _includePhaseCount = value),
          ),
      ],
    );
  }

  Widget _buildPlatformSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: SharePlatform.values.map((platform) {
            final isSelected = _selectedPlatform == platform;
            return ChoiceChip(
              label: Text(_getPlatformName(platform)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPlatform = platform);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildErrorSection(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: bodyStyle(context).copyWith(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isGenerating ? null : _generateImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: kcAccentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Generate Image',
                    style: heading3Style(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        if (_generatedImage != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSharing ? null : _shareImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Share',
                          style: heading3Style(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  String _getPlatformName(SharePlatform platform) {
    switch (platform) {
      case SharePlatform.instagram:
        return 'Instagram';
      case SharePlatform.linkedin:
        return 'LinkedIn';
      case SharePlatform.twitter:
        return 'Twitter/X';
      case SharePlatform.generic:
        return 'Generic';
    }
  }
}

