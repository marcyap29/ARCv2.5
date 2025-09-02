import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/widgets/geometry_selector.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class PhaseRecommendationDialog extends StatefulWidget {
  final String recommendedPhase;
  final String rationale;
  final List<String> keywords;
  final Function(String phase, ArcformGeometry? overrideGeometry) onConfirm;
  final VoidCallback onCancel;

  const PhaseRecommendationDialog({
    super.key,
    required this.recommendedPhase,
    required this.rationale,
    required this.keywords,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PhaseRecommendationDialog> createState() => _PhaseRecommendationDialogState();
}

class _PhaseRecommendationDialogState extends State<PhaseRecommendationDialog> {
  bool _showGeometrySelector = false;
  late ArcformGeometry _selectedGeometry;
  bool _isAutoGeometry = true;

  @override
  void initState() {
    super.initState();
    // Set default geometry based on recommended phase
    _selectedGeometry = UserPhaseService.getGeometryForPhase(widget.recommendedPhase);
  }

  void _onReshapePressed() {
    setState(() {
      _showGeometrySelector = true;
    });
  }

  void _onGeometryChanged(ArcformGeometry geometry) {
    setState(() {
      _selectedGeometry = geometry;
      _isAutoGeometry = false;
    });
  }

  void _onToggleAuto() {
    setState(() {
      _isAutoGeometry = !_isAutoGeometry;
      if (_isAutoGeometry) {
        _selectedGeometry = UserPhaseService.getGeometryForPhase(widget.recommendedPhase);
      }
      _showGeometrySelector = !_isAutoGeometry;
    });
  }

  void _onConfirm() {
    final overrideGeometry = _isAutoGeometry ? null : _selectedGeometry;
    widget.onConfirm(widget.recommendedPhase, overrideGeometry);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDialogWidth = screenWidth * 0.9; // 90% of screen width
    
    return Dialog(
      backgroundColor: kcBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth > 380 ? 380 : maxDialogWidth,
          maxHeight: 700,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: kcPrimaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phase Detected',
                        style: heading1Style(context),
                      ),
                      Text(
                        'ARC recommends your current phase',
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, color: kcSecondaryTextColor),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Recommended Phase Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kcPrimaryColor.withOpacity(0.1),
                    kcPrimaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getPhaseIcon(widget.recommendedPhase),
                        color: kcPrimaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.recommendedPhase,
                        style: heading1Style(context).copyWith(
                          color: kcPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    UserPhaseService.getPhaseDescription(widget.recommendedPhase),
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kcSurfaceAltColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: kcAccentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.rationale,
                            style: captionStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Geometry Selection Section
            if (!_showGeometrySelector) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kcPrimaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedGeometry.name,
                                style: heading3Style(context).copyWith(
                                  color: kcPrimaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedGeometry.description,
                                style: captionStyle(context).copyWith(
                                  color: kcSecondaryTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _onReshapePressed,
                          style: TextButton.styleFrom(
                            foregroundColor: kcAccentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Edit', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Show Geometry Selector
              Flexible(
                child: SingleChildScrollView(
                  child: GeometrySelector(
                    currentGeometry: _selectedGeometry,
                    isAutoDetected: _isAutoGeometry,
                    onGeometryChanged: _onGeometryChanged,
                    onToggleAuto: _onToggleAuto,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
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
                    onPressed: _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Arcform',
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
        return Icons.open_in_full;
      case 'transition':
        return Icons.trending_up;
      case 'consolidation':
        return Icons.integration_instructions;
      case 'recovery':
        return Icons.healing;
      case 'breakthrough':
        return Icons.flash_on;
      default:
        return Icons.psychology;
    }
  }
}