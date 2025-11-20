import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/arcforms/arcform_renderer_cubit.dart';
import 'package:my_app/arc/ui/arcforms/arcform_renderer_state.dart';
import 'package:my_app/arc/ui/arcforms/arcform_renderer_view.dart';
import 'package:my_app/arc/arcform/render/arcform_renderer_3d.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Compact preview widget showing current phase Arcform visualization
/// Displays above timeline icons in the Timeline view
class CurrentPhaseArcformPreview extends StatefulWidget {
  const CurrentPhaseArcformPreview({super.key});

  @override
  State<CurrentPhaseArcformPreview> createState() => _CurrentPhaseArcformPreviewState();
}

class _CurrentPhaseArcformPreviewState extends State<CurrentPhaseArcformPreview> {
  @override
  void initState() {
    super.initState();
    // Initialize the cubit if not already provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ArcformRendererCubit>();
      if (cubit.state is ArcformRendererInitial) {
        cubit.initialize();
      }
    });
  }

  /// Convert 2D Node/Edge from cubit state to 3D Arcform data
  Arcform3DData? _convertTo3DData(ArcformRendererLoaded state) {
    try {
      // Extract keywords from nodes
      final keywords = state.nodes.map((node) => node.label).toList();
      
      if (keywords.isEmpty) {
        return null;
      }

      // Create skin for this phase
      final skin = ArcformSkin.forUser('user', 'current_phase_${state.currentPhase}');

      // Generate 3D layout using layouts_3d
      final nodes = layout3D(
        keywords: keywords,
        phase: state.currentPhase,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: 0.6 + (kw.length / 30.0)},
        keywordValences: {for (var kw in keywords) kw: 0.0},
      );

      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: state.currentPhase,
        maxEdgesPerNode: 4,
        maxDistance: 1.4,
      );

      return Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: state.currentPhase,
        skin: skin,
        title: '${state.currentPhase} Constellation',
        content: 'Current phase Arcform visualization',
        createdAt: DateTime.now(),
        id: 'current_phase_${state.currentPhase}',
      );
    } catch (e) {
      print('Error converting to 3D data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArcformRendererCubit, ArcformRendererState>(
      builder: (context, state) {
        if (state is ArcformRendererLoading) {
          return Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kcSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kcBorderColor.withOpacity(0.2)),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is ArcformRendererLoaded) {
          final arcformData = _convertTo3DData(state);
          
          if (arcformData == null) {
            return Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kcSurfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kcBorderColor.withOpacity(0.2)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      color: kcSecondaryTextColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Arcform data available',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () {
              // Navigate to full Arcform view
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider<ArcformRendererCubit>.value(
                    value: context.read<ArcformRendererCubit>(),
                    child: const ArcformRendererView(),
                  ),
                ),
              );
            },
            child: Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kcSurfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with phase name and expand icon
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: kcPrimaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current Phase: ${state.currentPhase}',
                            style: heading3Style(context).copyWith(
                              color: kcPrimaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_full,
                          size: 18,
                          color: kcSecondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  // Arcform preview
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Arcform3D(
                          nodes: arcformData.nodes,
                          edges: arcformData.edges,
                          phase: arcformData.phase,
                          skin: arcformData.skin,
                          showNebula: true,
                          enableLabels: false,
                          initialZoom: 2.0, // Compact zoom level
                        ),
                      ),
                    ),
                  ),
                  // Phase elements info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        _buildInfoChip(
                          Icons.circle,
                          '${arcformData.nodes.length} Nodes',
                          context,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.link,
                          '${arcformData.edges.length} Edges',
                          context,
                        ),
                        const Spacer(),
                        Text(
                          'Tap to expand',
                          style: captionStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is ArcformRendererError) {
          return Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kcSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kcBorderColor.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: kcSecondaryTextColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to load Arcform',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Initial state - show loading
        return Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kcSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kcBorderColor.withOpacity(0.2)),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: kcPrimaryColor,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: captionStyle(context).copyWith(
            color: kcPrimaryTextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

