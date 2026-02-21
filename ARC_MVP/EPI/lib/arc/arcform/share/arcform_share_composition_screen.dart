// lib/arc/arcform/share/arcform_share_composition_screen.dart
// Composition screen for Arcform sharing with new modes

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'arcform_share_models.dart';
import 'arcform_share_caption_templates.dart';
import 'arcform_share_image_generator.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/render/arcform_renderer_3d.dart';

class ArcformShareCompositionScreen extends StatefulWidget {
  final String phase;
  final List<String> keywords;
  final String arcformId;
  final Widget? arcformPreview; // Arcform 3D widget to capture
  final GlobalKey? repaintBoundaryKey; // For capturing Arcform image
  final Uint8List? preCapturedImage; // Pre-captured Arcform image bytes
  final DateTime? transitionDate;
  final Arcform3DData? arcformData; // Arcform data for re-capturing with label settings

  const ArcformShareCompositionScreen({
    super.key,
    required this.phase,
    required this.keywords,
    this.arcformId = 'current',
    this.arcformPreview,
    this.repaintBoundaryKey,
    this.preCapturedImage,
    this.transitionDate,
    this.arcformData,
  });

  @override
  State<ArcformShareCompositionScreen> createState() => _ArcformShareCompositionScreenState();
}

class _ArcformShareCompositionScreenState extends State<ArcformShareCompositionScreen> {
  final TextEditingController _captionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _arcformRepaintBoundaryKey = GlobalKey(); // For capturing Arcform if needed

  ArcShareMode _selectedMode = ArcShareMode.quiet;
  SocialPlatform _selectedPlatform = SocialPlatform.instagramStory;
  bool _includeDuration = false;
  bool _includePhaseCount = false;
  bool _includeDateRange = true;
  bool _showLabels = false; // Hide labels by default for privacy on public networks
  bool _isGenerating = false;
  bool _isSharing = false;
  Uint8List? _generatedImage;
  ArcformSharePayload? _currentPayload;
  String? _validationError;
  String? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _loadTemplates() {
    // Load default template for current mode
    _updateTemplate();
  }

  void _updateTemplate() {
    final template = ArcformShareCaptionTemplates.getDefaultTemplate(
      _selectedMode,
      widget.phase,
    );
    if (template != null && _captionController.text.isEmpty) {
      _captionController.text = template;
      _selectedTemplate = template;
    }
  }

  Future<void> _generateImage() async {
    if (_selectedMode != ArcShareMode.quiet && !_isCaptionValid()) {
      setState(() {
        _validationError = 'Caption must be 10-200 characters for ${_selectedMode.name} mode';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _validationError = null;
    });

    try {
      // If we have arcform data and need to re-capture with label settings, do that
      Uint8List? arcformImage;
      if (widget.arcformData != null) {
        // Re-capture with current label setting
        arcformImage = await _captureArcformWithSettings(widget.arcformData!);
      }
      
      // Otherwise, use pre-captured image if available
      if (arcformImage == null) {
        arcformImage = widget.preCapturedImage;
      }
      
      // Try capturing from provided repaintBoundaryKey first
      if (arcformImage == null && widget.repaintBoundaryKey != null) {
        arcformImage = await _captureArcformImageFromKey(widget.repaintBoundaryKey!);
      }
      
      // If still null, try capturing from our own RepaintBoundary (if arcformPreview is rendered)
      if (arcformImage == null && _arcformRepaintBoundaryKey.currentContext != null) {
        arcformImage = await _captureArcformImageFromKey(_arcformRepaintBoundaryKey);
      }

      if (arcformImage == null) {
        setState(() {
          _validationError = 'Failed to capture Phase image. Please ensure the Phase visualization is visible and try again.';
          _isGenerating = false;
        });
        return;
      }

      // Build payload
      final payload = ArcformSharePayload(
        shareMode: _selectedMode,
        arcformId: widget.arcformId,
        phase: widget.phase,
        keywords: widget.keywords,
        platform: _selectedPlatform,
        userCaption: _selectedMode != ArcShareMode.quiet ? _captionController.text.trim() : null,
        systemCaptionTemplate: _selectedTemplate,
        includeDuration: _includeDuration,
        includePhaseCount: _includePhaseCount,
        includeDateRange: _includeDateRange,
        transitionDate: widget.transitionDate ?? DateTime.now(),
      );

      // Generate platform-specific composite image
      final compositeImage = await ArcformShareImageGenerator.generateArcformImage(
        arcformImageBytes: arcformImage,
        payload: payload,
        platform: _selectedPlatform,
      );

      if (compositeImage != null) {
        setState(() {
          _generatedImage = compositeImage;
          _currentPayload = payload.copyWith(imageBytes: compositeImage);
          _isGenerating = false;
        });
      } else {
        setState(() {
          _validationError = 'Failed to generate composite image';
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

  /// Capture Arcform with current label settings
  Future<Uint8List?> _captureArcformWithSettings(Arcform3DData arcformData) async {
    final captureKey = GlobalKey();
    final captureWidget = RepaintBoundary(
      key: captureKey,
      child: Arcform3D(
        nodes: arcformData.nodes,
        edges: arcformData.edges,
        phase: arcformData.phase,
        skin: arcformData.skin,
        showNebula: true,
        enableLabels: _showLabels, // Use toggle setting
        initialZoom: 1.6,
      ),
    );
    
    // Build the capture widget offscreen
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000, // Position offscreen
        top: -10000,
        child: SizedBox(
          width: 400,
          height: 400,
          child: captureWidget,
        ),
      ),
    );
    overlay.insert(overlayEntry);
    
    // Wait for widget to render
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Capture the image
    Uint8List? imageBytes;
    try {
      final captureContext = captureKey.currentContext;
      if (captureContext != null) {
        final RenderRepaintBoundary? boundary = 
            captureContext.findRenderObject() as RenderRepaintBoundary?;
        
        if (boundary != null) {
          final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          imageBytes = byteData?.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('Error capturing Arcform with settings: $e');
    } finally {
      // Remove the overlay entry
      overlayEntry.remove();
    }
    
    return imageBytes;
  }

  Future<Uint8List?> _captureArcformImageFromKey(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context == null) return null;
      
      final RenderRepaintBoundary? boundary = 
          context.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) return null;
      
      // Capture at high resolution
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      
      // Convert to PNG bytes
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose(); // Clean up
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing Arcform from key: $e');
      return null;
    }
  }

  Size _getPlatformSize(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagramStory:
        return const Size(1080, 1920);
      case SocialPlatform.instagramFeed:
        return const Size(1080, 1080);
      case SocialPlatform.linkedinFeed:
        return const Size(1200, 627);
      case SocialPlatform.linkedinCarousel:
        return const Size(1080, 1080);
    }
  }

  bool _isCaptionValid() {
    if (_selectedMode == ArcShareMode.quiet) return true;
    final text = _captionController.text.trim();
    return text.length >= 10 && text.length <= 200;
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null || _currentPayload == null) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      // Save image to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/arcform_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_generatedImage!);

      // Build caption
      final caption = _currentPayload!.getFinalMessage();
      final finalCaption = _currentPayload!.footerOptIn && caption.isNotEmpty
          ? '$caption\n\nCreated with ARC'
          : caption.isNotEmpty
              ? caption
              : 'Created with ARC';

      // Share using native share sheet
      // Get share position origin for iPad/iOS support
      Rect? sharePositionOrigin;
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        sharePositionOrigin = Rect.fromLTWH(
          screenSize.width / 2,
          screenSize.height / 2,
          1,
          1,
        );
      }
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: finalCaption,
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phase shared successfully!'),
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
          'Share Phase',
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
              // Share mode selection
              _buildModeSection(),
              const SizedBox(height: 24),

              // Platform selection
              _buildPlatformSection(),
              const SizedBox(height: 24),

              // Caption (if not quiet mode)
              if (_selectedMode != ArcShareMode.quiet) ...[
                _buildCaptionSection(),
                const SizedBox(height: 24),
              ],

              // Optional metrics
              _buildMetricsSection(),
              const SizedBox(height: 24),

              // Arcform preview (if provided, render it so it can be captured)
              if (widget.arcformPreview != null && _generatedImage == null) ...[
                _buildArcformPreviewSection(),
                const SizedBox(height: 24),
              ],

              // Generated image preview
              if (_generatedImage != null) ...[
                _buildPreviewSection(),
                const SizedBox(height: 24),
              ],

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

  Widget _buildModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share Mode',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...ArcShareMode.values.map((mode) {
          final isSelected = _selectedMode == mode;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedMode = mode;
                  _updateTemplate();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kcAccentColor.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? kcAccentColor
                        : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? kcAccentColor : Colors.grey,
                          width: 2,
                        ),
                        color: isSelected ? kcAccentColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getModeTitle(mode),
                            style: heading3Style(context).copyWith(
                              color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getModeDescription(mode),
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
            ),
          );
        }),
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
          children: SocialPlatform.values.map((platform) {
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

  Widget _buildCaptionSection() {
    final templates = _selectedMode == ArcShareMode.reflective
        ? ArcformShareCaptionTemplates.getReflectiveTemplates(widget.phase)
        : ArcformShareCaptionTemplates.getSignalTemplates(phaseName: widget.phase);

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
          'Write your reflection (10-200 characters)',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        // Template suggestions
        if (templates.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templates.take(3).map((template) {
              return ActionChip(
                label: Text(template, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _captionController.text = template;
                    _selectedTemplate = template;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _captionController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Share your thoughts...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
          style: bodyStyle(context),
          validator: (value) {
            if (_selectedMode != ArcShareMode.quiet) {
              if (value == null || value.trim().length < 10) {
                return 'Caption must be at least 10 characters';
              }
              if (value.trim().length > 200) {
                return 'Caption must be less than 200 characters';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${_captionController.text.length}/200',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsSection() {
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
          title: Text('Include Date Range', style: bodyStyle(context)),
          value: _includeDateRange,
          onChanged: (value) => setState(() => _includeDateRange = value),
        ),
        SwitchListTile(
          title: Text('Include Duration', style: bodyStyle(context)),
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
        SwitchListTile(
          title: Text('Include Phase Count', style: bodyStyle(context)),
          subtitle: Text(
            'Show which instance of this phase',
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

  Widget _buildArcformPreviewSection() {
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
            'Phase Preview',
            style: heading3Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            width: double.infinity,
            child: RepaintBoundary(
              key: _arcformRepaintBoundaryKey,
              child: widget.arcformPreview!,
            ),
          ),
        ],
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

  String _getModeTitle(ArcShareMode mode) {
    switch (mode) {
      case ArcShareMode.quiet:
        return 'Quiet Share';
      case ArcShareMode.reflective:
        return 'Reflective Share';
      case ArcShareMode.signal:
        return 'Signal Share';
    }
  }

  String _getModeDescription(ArcShareMode mode) {
    switch (mode) {
      case ArcShareMode.quiet:
        return 'Mysterious artifact, minimal context';
      case ArcShareMode.reflective:
        return 'Personal insight + growth narrative';
      case ArcShareMode.signal:
        return 'Professional growth + process intelligence';
    }
  }

  String _getPlatformName(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagramStory:
        return 'Instagram Story';
      case SocialPlatform.instagramFeed:
        return 'Instagram Feed';
      case SocialPlatform.linkedinFeed:
        return 'LinkedIn Feed';
      case SocialPlatform.linkedinCarousel:
        return 'LinkedIn Carousel';
    }
  }
}

