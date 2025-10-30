import 'package:flutter/material.dart';
import 'package:my_app/arc/ui/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class GeometrySelector extends StatefulWidget {
  final ArcformGeometry currentGeometry;
  final bool isAutoDetected;
  final Function(ArcformGeometry) onGeometryChanged;
  final VoidCallback? onToggleAuto;

  const GeometrySelector({
    super.key,
    required this.currentGeometry,
    required this.isAutoDetected,
    required this.onGeometryChanged,
    this.onToggleAuto,
  });

  @override
  State<GeometrySelector> createState() => _GeometrySelectorState();
}

class _GeometrySelectorState extends State<GeometrySelector>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isAutoDetected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isAutoDetected 
              ? kcPrimaryColor.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with auto/manual toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Select Phase',
                  style: heading3Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Compact toggle button only
              if (widget.onToggleAuto != null)
                TextButton(
                  onPressed: widget.onToggleAuto,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.isAutoDetected ? kcAccentColor : kcPrimaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    widget.isAutoDetected ? 'Manual' : 'Auto',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Current geometry display
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isAutoDetected ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kcPrimaryColor.withOpacity(0.1),
                        kcPrimaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kcPrimaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getGeometryIcon(widget.currentGeometry),
                        color: kcPrimaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getPhaseName(widget.currentGeometry),
                              style: heading3Style(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.currentGeometry.description,
                              style: captionStyle(context).copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Phase selection grid (only shown when manual mode)
          if (!widget.isAutoDetected) ...[
            Text(
              'Choose phase:',
              style: captionStyle(context).copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _buildGeometryGrid(),
          ],

          // Auto-detection explanation
          if (widget.isAutoDetected) ...[
            const SizedBox(height: 8),
            Text(
              'Auto-detected from your content',
              style: captionStyle(context).copyWith(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeometryGrid() {
    const geometries = ArcformGeometry.values;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: geometries.length,
      itemBuilder: (context, index) {
        final geometry = geometries[index];
        final isSelected = geometry == widget.currentGeometry;
        
        return GestureDetector(
          onTap: () => widget.onGeometryChanged(geometry),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? kcPrimaryColor.withOpacity(0.2)
                  : kcSurfaceAltColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? kcPrimaryColor
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getGeometryIcon(geometry),
                  color: isSelected ? kcPrimaryColor : Colors.white.withOpacity(0.7),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  _getPhaseName(geometry),
                  style: captionStyle(context).copyWith(
                    color: isSelected ? kcPrimaryColor : Colors.white.withOpacity(0.9),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getGeometryIcon(ArcformGeometry geometry) {
    switch (geometry) {
      case ArcformGeometry.spiral:
        return Icons.rotate_right;
      case ArcformGeometry.flower:
        return Icons.local_florist;
      case ArcformGeometry.branch:
        return Icons.account_tree;
      case ArcformGeometry.weave:
        return Icons.grid_4x4;
      case ArcformGeometry.glowCore:
        return Icons.radio_button_checked;
      case ArcformGeometry.fractal:
        return Icons.pattern;
    }
  }

  String _getPhaseName(ArcformGeometry geometry) {
    switch (geometry) {
      case ArcformGeometry.spiral:
        return 'Discovery';
      case ArcformGeometry.flower:
        return 'Expansion';
      case ArcformGeometry.branch:
        return 'Transition';
      case ArcformGeometry.weave:
        return 'Consolidation';
      case ArcformGeometry.glowCore:
        return 'Recovery';
      case ArcformGeometry.fractal:
        return 'Breakthrough';
    }
  }
}



