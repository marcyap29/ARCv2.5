import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/arcforms/arcform_renderer_cubit.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/widgets/arcform_layout.dart';
import 'package:my_app/features/arcforms/widgets/simple_3d_arcform.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class ArcformRendererView extends StatelessWidget {
  const ArcformRendererView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ArcformRendererCubit()..initialize(),
      child: const ArcformRendererViewContent(),
    );
  }
}

class ArcformRendererViewContent extends StatefulWidget {
  const ArcformRendererViewContent({super.key});

  @override
  State<ArcformRendererViewContent> createState() => _ArcformRendererViewContentState();
}

class _ArcformRendererViewContentState extends State<ArcformRendererViewContent> {
  bool _is3DMode = true; // Default to 3D mode to show off the new feature

  ArcformGeometry _convertToArcformGeometry(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return ArcformGeometry.spiral;
      case GeometryPattern.flower:
        return ArcformGeometry.flower;
      case GeometryPattern.branch:
        return ArcformGeometry.branch;
      case GeometryPattern.weave:
        return ArcformGeometry.weave;
      case GeometryPattern.glowCore:
        return ArcformGeometry.glowCore;
      case GeometryPattern.fractal:
        return ArcformGeometry.fractal;
    }
  }

  GeometryPattern _convertFromArcformGeometry(ArcformGeometry geometry) {
    switch (geometry) {
      case ArcformGeometry.spiral:
        return GeometryPattern.spiral;
      case ArcformGeometry.flower:
        return GeometryPattern.flower;
      case ArcformGeometry.branch:
        return GeometryPattern.branch;
      case ArcformGeometry.weave:
        return GeometryPattern.weave;
      case ArcformGeometry.glowCore:
        return GeometryPattern.glowCore;
      case ArcformGeometry.fractal:
        return GeometryPattern.fractal;
    }
  }



  Widget _buildPhaseIndicatorWithChangeButton(BuildContext context, String currentPhase, GeometryPattern geometry) {
    final description = UserPhaseService.getPhaseDescription(currentPhase);
    final phaseColor = _getPhaseColor(geometry);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            phaseColor.withOpacity(0.1),
            phaseColor.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: phaseColor.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: phaseColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'CURRENT PHASE',
                  style: captionStyle(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              // Phase change button
              GestureDetector(
                onTap: () => _showPhaseChangeDialog(context, currentPhase),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kcSurfaceAltColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: phaseColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        color: phaseColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Change',
                        style: captionStyle(context).copyWith(
                          color: phaseColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _getPhaseIcon(geometry),
                color: phaseColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            currentPhase.toUpperCase(),
            style: heading1Style(context).copyWith(
              color: phaseColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: bodyStyle(context).copyWith(
              color: phaseColor.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPhaseColor(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return const Color(0xFF4F46E5); // Discovery - Blue
      case GeometryPattern.flower:
        return const Color(0xFF7C3AED); // Expansion - Purple  
      case GeometryPattern.branch:
        return const Color(0xFF059669); // Transition - Green
      case GeometryPattern.weave:
        return const Color(0xFFD97706); // Consolidation - Orange
      case GeometryPattern.glowCore:
        return const Color(0xFFDC2626); // Recovery - Red
      case GeometryPattern.fractal:
        return const Color(0xFF7C2D12); // Breakthrough - Brown
    }
  }

  IconData _getPhaseIcon(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return Icons.explore; // Discovery
      case GeometryPattern.flower:
        return Icons.local_florist; // Expansion
      case GeometryPattern.branch:
        return Icons.account_tree; // Transition
      case GeometryPattern.weave:
        return Icons.grid_view; // Consolidation
      case GeometryPattern.glowCore:
        return Icons.healing; // Recovery
      case GeometryPattern.fractal:
        return Icons.auto_fix_high; // Breakthrough
    }
  }

  void _showKeywordDialog(BuildContext context, String keyword) {
    final emotionalService = EmotionalValenceService();
    final emotionalColor = emotionalService.getEmotionalColor(keyword);
    final temperature = emotionalService.getTemperatureDescription(keyword);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kcSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: emotionalColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: emotionalColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  keyword,
                  style: heading1Style(context).copyWith(
                    color: emotionalColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: emotionalColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    temperature,
                    style: captionStyle(context).copyWith(
                      color: emotionalColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: buttonStyle(context).copyWith(
                  color: kcPrimaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPhaseChangeDialog(BuildContext context, String currentPhase) {
    final phases = ['Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kcSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Change Phase',
            style: heading1Style(context).copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current phase: $currentPhase',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a new phase:',
                style: bodyStyle(context).copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ...phases.map((phase) => ListTile(
                title: Text(
                  phase,
                  style: bodyStyle(context).copyWith(
                    color: phase == currentPhase ? kcPrimaryColor : Colors.white,
                    fontWeight: phase == currentPhase ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                leading: Icon(
                  _getPhaseIcon(_phaseToGeometryPattern(phase)),
                  color: phase == currentPhase ? kcPrimaryColor : kcSecondaryTextColor,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmPhaseChange(context, currentPhase, phase);
                },
              )).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: buttonStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmPhaseChange(BuildContext context, String currentPhase, String newPhase) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kcSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirm Phase Change',
            style: heading1Style(context).copyWith(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to change your phase from $currentPhase to $newPhase?',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This will update your current phase and may affect your Arcform visualization.',
                style: captionStyle(context).copyWith(
                  color: kcSecondaryTextColor.withOpacity(0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: buttonStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changePhase(newPhase);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Change Phase',
                style: buttonStyle(context).copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _changePhase(String newPhase) {
    // Update the phase in the cubit
    final cubit = context.read<ArcformRendererCubit>();
    final newGeometry = _phaseToGeometryPattern(newPhase);
    cubit.changeGeometry(newGeometry);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phase changed to $newPhase'),
        backgroundColor: kcPrimaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  GeometryPattern _phaseToGeometryPattern(String phase) {
    switch (phase) {
      case 'Discovery':
        return GeometryPattern.spiral;
      case 'Expansion':
        return GeometryPattern.flower;
      case 'Transition':
        return GeometryPattern.branch;
      case 'Consolidation':
        return GeometryPattern.weave;
      case 'Recovery':
        return GeometryPattern.glowCore;
      case 'Breakthrough':
        return GeometryPattern.fractal;
      default:
        return GeometryPattern.spiral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArcformRendererCubit, ArcformRendererState>(
      builder: (context, state) {
        if (state is ArcformRendererInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ArcformRendererLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ArcformRendererError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading Arcform',
                  style: heading2Style(context),
                ),
                const SizedBox(height: 10),
                Text(
                  state.message,
                  style: bodyStyle(context),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    context.read<ArcformRendererCubit>().initialize();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                  ),
                  child: Text('Retry', style: buttonStyle(context)),
                ),
              ],
            ),
          );
        }

        if (state is ArcformRendererLoaded) {
          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Phase indicator header with change button
                    _buildPhaseIndicatorWithChangeButton(context, state.currentPhase, state.selectedGeometry),
                    // Main Arcform layout - switch between 2D and 3D
                    Expanded(
                      child: _is3DMode
                          ? Simple3DArcform(
                              nodes: state.nodes,
                              edges: state.edges,
                              onNodeMoved: (nodeId, x, y) {
                                context
                                    .read<ArcformRendererCubit>()
                                    .updateNodePosition(nodeId, x, y);
                              },
                              onNodeTapped: (keyword) {
                                _showKeywordDialog(context, keyword);
                              },
                              selectedGeometry: _convertToArcformGeometry(state.selectedGeometry),
                              onGeometryChanged: (geometry) {
                                context.read<ArcformRendererCubit>().changeGeometry(
                                  _convertFromArcformGeometry(geometry)
                                );
                              },
                            )
                          : ArcformLayout(
                              nodes: state.nodes,
                              edges: state.edges,
                              onNodeMoved: (nodeId, x, y) {
                                context
                                    .read<ArcformRendererCubit>()
                                    .updateNodePosition(nodeId, x, y);
                              },
                              onNodeTapped: (keyword) {
                                _showKeywordDialog(context, keyword);
                              },
                              selectedGeometry: state.selectedGeometry,
                              currentPhase: state.currentPhase,
                              onGeometryChanged: (geometry) {
                                context.read<ArcformRendererCubit>().changeGeometry(geometry);
                              },
                            ),
                    ),
                  ],
                ),
                // 3D Toggle button
                Positioned(
                  bottom: 30,
                  left: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      setState(() {
                        _is3DMode = !_is3DMode;
                      });
                    },
                    backgroundColor: _is3DMode ? kcPrimaryColor : kcSurfaceAltColor,
                    child: Icon(
                      _is3DMode ? Icons.view_in_ar : Icons.view_in_ar_outlined,
                      color: _is3DMode ? Colors.white : kcSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return const Center(child: Text('Unknown state'));
      },
    );
  }
}
