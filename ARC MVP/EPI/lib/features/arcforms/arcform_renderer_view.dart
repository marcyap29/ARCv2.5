import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/arcforms/arcform_renderer_cubit.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/widgets/arcform_layout.dart';
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
