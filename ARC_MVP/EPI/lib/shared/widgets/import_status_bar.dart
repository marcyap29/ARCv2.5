import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:my_app/shared/app_colors.dart';

/// Mini status bar shown below the app bar when an import is running.
/// Pushes main content (LUMARA / Phase / Conversation) down; disappears when import completes.
/// Copy and layout make clear the app is not locked — user can keep using it.
class ImportStatusBar extends StatelessWidget {
  const ImportStatusBar({super.key});

  /// Height tuned so message + subtitle + progress bar fit without overflow (was 52, overflowed by 7px).
  static const double _height = 60;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImportProgressCubit, ImportProgressState>(
      buildWhen: (a, b) => a.isActive != b.isActive || a.message != b.message || a.fraction != b.fraction,
      builder: (context, state) {
        if (!state.isActive) return const SizedBox.shrink();
        final hasFraction = state.fraction > 0 && state.fraction <= 1;
        return Material(
          color: kcSurfaceColor,
          elevation: 0,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.cloud_download_outlined, size: 20, color: kcPrimaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.message,
                          style: const TextStyle(
                            color: kcPrimaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You can keep using the app',
                          style: TextStyle(
                            color: kcSecondaryTextColor.withOpacity(0.9),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: hasFraction ? state.fraction : null,
                            backgroundColor: kcSurfaceAltColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasFraction
                        ? '${(state.fraction * 100).round()}%'
                        : '0%',
                    style: const TextStyle(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
