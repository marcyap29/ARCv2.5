// lib/arc/arcform/share/arcform_share_sheet.dart
// Reusable share panel widget for Arcform sharing

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'arcform_share_models.dart';
import 'lumara_share_service.dart';
import 'package:my_app/services/analytics_service.dart';

/// Reusable share panel for Arcform sharing
class ArcformShareSheet extends StatefulWidget {
  final ArcformSharePayload initialPayload;
  final String fromView; // "arcform_view", "timeline_card", "reveal_screen"
  final Widget? arcformPreview; // Optional preview widget to capture as image

  const ArcformShareSheet({
    super.key,
    required this.initialPayload,
    required this.fromView,
    this.arcformPreview,
  });

  @override
  State<ArcformShareSheet> createState() => _ArcformShareSheetState();
}

class _ArcformShareSheetState extends State<ArcformShareSheet> {
  late ArcformSharePayload _payload;
  final LumaraShareService _shareService = LumaraShareService();
  bool _isLoadingMetadata = false;
  bool _isSharing = false;
  final TextEditingController _captionController = TextEditingController();
  String? _selectedCaptionType;

  @override
  void initState() {
    super.initState();
    _payload = widget.initialPayload;
    _captionController.text = _payload.userCaption ?? '';

    // Load LUMARA metadata if not already present
    if (_needsMetadata()) {
      _loadMetadata();
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool _needsMetadata() {
    // For quiet mode, no metadata needed
    if (_payload.shareMode == ArcShareMode.quiet) {
      return false;
    }
    // For reflective/signal modes, check if template exists
    return _payload.systemCaptionTemplate == null;
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      final metadata = await _shareService.generateShareMetadata(
        shareMode: _payload.shareMode,
        arcformId: _payload.arcformId,
        phase: _payload.phase,
        keywords: _payload.keywords,
        platform: _payload.platform,
      );

      setState(() {
        _payload = metadata;
        _isLoadingMetadata = false;
      });
    } catch (e) {
      print('ArcformShareSheet: Error loading metadata: $e');
      setState(() {
        _isLoadingMetadata = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar and close button row
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 8),
              child: Row(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kcSecondaryTextColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: kcPrimaryTextColor),
                    onPressed: () {
                      AnalyticsService.trackEvent('arc_share_canceled');
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Title with extra top padding to avoid notch
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 20),
              child: Text(
                'Share Arcform',
                style: heading3Style(context),
              ),
            ),

            // Content (legacy component - consider using ArcformShareCompositionScreen instead)
            _buildContent(),
          ],
        ),
      ),
    );
  }

  // Legacy mode selection removed - use ArcformShareCompositionScreen instead

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: kcPrimaryColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: heading4Style(context)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: supportingTextStyle(context)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kcSecondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingMetadata) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      );
    }

    // For quiet mode, show minimal UI
    if (_payload.shareMode == ArcShareMode.quiet) {
      return _buildQuietShareContent();
    } else {
      // For reflective/signal modes, show caption editor
      return _buildSocialShareContent();
    }
  }

  Widget _buildQuietShareContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quiet Share',
              style: sectionHeaderStyle(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Share the Arcform image without any caption.',
              style: supportingTextStyle(context),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleSocialShare,
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }

  // Legacy direct share removed - use ArcformShareCompositionScreen instead

  Widget _buildSocialShareContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview image
            if (widget.arcformPreview != null) ...[
              Text(
                'Preview',
                style: sectionHeaderStyle(context),
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kcBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kcBorderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.arcformPreview,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Platform selection
            Text(
              'Platform',
              style: sectionHeaderStyle(context),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SocialPlatform.instagramStory,
                SocialPlatform.instagramFeed,
                SocialPlatform.linkedinFeed,
              ].map((platform) {
                final isSelected = _payload.platform == platform;
                return ChoiceChip(
                  label: Text(_getPlatformName(platform)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _payload = _payload.copyWith(platform: platform);
                      });
                      _loadMetadata(); // Reload metadata for new platform
                    }
                  },
                  selectedColor: kcPrimaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : kcPrimaryTextColor,
                  ),
                );
              }).toList(),
            ),

            // User caption input
            const SizedBox(height: 24),
            Text(
              'Your caption',
              style: sectionHeaderStyle(context),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: bodyStyle(context),
              decoration: InputDecoration(
                hintText: 'Write your caption...',
                hintStyle: supportingTextStyle(context),
                filled: true,
                fillColor: kcSurfaceAltColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kcBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kcBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kcPrimaryColor),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _payload = _payload.copyWith(userCaption: value.isEmpty ? null : value);
                });
              },
            ),

            // System caption options
            if (_hasSystemCaptions()) ...[
              const SizedBox(height: 20),
              Text(
                'Suggested captions',
                style: sectionHeaderStyle(context),
              ),
              const SizedBox(height: 8),
              if (_payload.systemCaptionTemplate != null) ...[
                _buildCaptionOption('Template', _payload.systemCaptionTemplate!),
              ],
            ],

            // Footer opt-in
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _payload.footerOptIn,
                  onChanged: (value) {
                    setState(() {
                      _payload = _payload.copyWith(footerOptIn: value ?? true);
                    });
                  },
                  activeColor: kcPrimaryColor,
                ),
                Expanded(
                  child: Text(
                    'Include "About ARC" footer',
                    style: bodyStyle(context),
                  ),
                ),
              ],
            ),

            // Share button
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSharing ? null : () => _handleSocialShare(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSharing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Share', style: buttonStyle(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionOption(String type, String caption) {
    final isSelected = _selectedCaptionType == type.toLowerCase();
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCaptionType = type.toLowerCase();
          _captionController.text = caption;
          _payload = _payload.copyWith(userCaption: caption);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kcPrimaryColor.withOpacity(0.2) : kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kcPrimaryColor : kcBorderColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: captionStyle(context).copyWith(
                      color: isSelected ? kcPrimaryColor : kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: bodyStyle(context),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: kcPrimaryColor),
          ],
        ),
      ),
    );
  }

  bool _hasSystemCaptions() {
    return _payload.systemCaptionTemplate != null;
  }

  // Legacy direct share removed - use ArcformShareCompositionScreen instead
  Future<void> _handleDirectShare() async {
    // This method is deprecated - use ArcformShareCompositionScreen
    _handleSocialShare();
    // Validate privacy rules
    if (!_shareService.validatePrivacyRules(_payload)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message contains content that cannot be shared. Please revise.'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSharing = true;
    });

    // Log analytics
    AnalyticsService.trackEvent('arc_share_opened', properties: {
      'mode': 'direct',
      'from_view': widget.fromView,
    });

    // TODO: Implement in-app direct share logic
    // For now, use system share sheet
    final message = _payload.getFinalMessage();
    await Share.share(message);

    AnalyticsService.trackEvent('arc_share_completed', properties: {
      'mode': 'direct',
      'arcform_phase': _payload.phase,
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSocialShare() async {
    // Validate privacy rules
    if (!_shareService.validatePrivacyRules(_payload)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caption contains content that cannot be shared. Please revise.'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSharing = true;
    });

    // Log analytics
    AnalyticsService.trackEvent('arc_share_opened', properties: {
      'mode': 'social',
      'from_view': widget.fromView,
      'platform': _payload.platform ?? 'unknown',
    });

    try {
      // Build caption with optional footer
      var caption = _payload.getFinalMessage();
      if (_payload.footerOptIn) {
        caption += '\n\nAbout ARC: A personal growth journaling app';
      }

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

      // Capture image if preview widget provided
      XFile? imageFile;
      if (widget.arcformPreview != null) {
        imageFile = await _captureArcformImage();
      }

      // Share via system share sheet
      if (imageFile != null) {
        await Share.shareXFiles(
          [imageFile],
          text: caption,
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        // For text-only sharing, use Share.share (doesn't require sharePositionOrigin)
        await Share.share(caption);
      }

      AnalyticsService.trackEvent('arc_share_completed', properties: {
        'mode': 'social',
        'platform': _payload.platform ?? 'unknown',
        'arcform_phase': _payload.phase,
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('ArcformShareSheet: Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _exportImage() async {
    if (widget.arcformPreview == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No preview available for export')),
        );
      }
      return;
    }

    AnalyticsService.trackEvent('arc_share_opened', properties: {
      'mode': 'export',
      'from_view': widget.fromView,
    });

    try {
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

      final imageFile = await _captureArcformImage();
      if (imageFile != null) {
        await Share.shareXFiles(
          [imageFile],
          sharePositionOrigin: sharePositionOrigin,
        );
        AnalyticsService.trackEvent('arc_share_completed', properties: {
          'mode': 'export',
          'arcform_phase': _payload.phase,
        });
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('ArcformShareSheet: Error exporting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  Future<XFile?> _captureArcformImage() async {
    try {
      // This is a simplified implementation
      // In a real scenario, you'd use a RenderRepaintBoundary to capture the widget
      // For now, return null and let the share work without image
      return null;
    } catch (e) {
      print('ArcformShareSheet: Error capturing image: $e');
      return null;
    }
  }

  String _getPlatformName(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagramStory:
        return 'Instagram Story';
      case SocialPlatform.instagramFeed:
        return 'Instagram Feed';
      case SocialPlatform.linkedinFeed:
        return 'LinkedIn';
      case SocialPlatform.linkedinCarousel:
        return 'LinkedIn Carousel';
    }
  }
}

/// Show the Arcform share sheet
Future<void> showArcformShareSheet({
  required BuildContext context,
  required ArcformSharePayload payload,
  required String fromView,
  Widget? arcformPreview,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ArcformShareSheet(
      initialPayload: payload,
      fromView: fromView,
      arcformPreview: arcformPreview,
    ),
  );
}

