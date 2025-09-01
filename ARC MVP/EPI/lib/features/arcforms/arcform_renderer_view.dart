import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/arcforms/arcform_renderer_cubit.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/widgets/arcform_layout.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';
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
          return ArcformLayout(
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
          );
        }

        return const Center(child: Text('Unknown state'));
      },
    );
  }
}
