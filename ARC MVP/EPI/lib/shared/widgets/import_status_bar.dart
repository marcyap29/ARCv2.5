import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:my_app/shared/app_colors.dart';

/// Mini status bar shown below the app bar when an import is running.
/// Pushes main content (LUMARA / Phase / Conversation) down; disappears when import completes.
class ImportStatusBar extends StatelessWidget {
  const ImportStatusBar({super.key});

  static const double _height = 40;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImportProgressCubit, ImportProgressState>(
      buildWhen: (a, b) => a.isActive != b.isActive || a.message != b.message || a.fraction != b.fraction,
      builder: (context, state) {
        if (!state.isActive) return const SizedBox.shrink();
        return Material(
          color: kcSurfaceColor,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.cloud_download, size: 18, color: kcPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.message,
                          style: TextStyle(
                            color: kcPrimaryTextColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        LinearProgressIndicator(
                          value: state.fraction > 0 ? state.fraction : null,
                          backgroundColor: kcSurfaceAltColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(state.fraction * 100).round()}%',
                    style: TextStyle(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
