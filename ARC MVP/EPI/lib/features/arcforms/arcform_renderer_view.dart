import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/arcforms/arcform_renderer_cubit.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/widgets/arcform_layout.dart';
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

class ArcformRendererViewContent extends StatelessWidget {
  const ArcformRendererViewContent({super.key});

  Widget _buildPhaseIndicator(BuildContext context, String currentPhase, GeometryPattern geometry) {
    final description = UserPhaseService.getPhaseDescription(currentPhase);
    final phaseColor = _getPhaseColor(geometry);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
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
            child: Column(
              children: [
                // Phase indicator header
                _buildPhaseIndicator(context, state.currentPhase, state.selectedGeometry),
                // Main Arcform layout
                Expanded(
                  child: ArcformLayout(
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
          );
        }

        return const Center(child: Text('Unknown state'));
      },
    );
  }
}
