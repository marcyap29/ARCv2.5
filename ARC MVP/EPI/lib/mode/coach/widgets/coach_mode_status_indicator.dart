import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../coach_mode_cubit.dart';
import '../coach_mode_state.dart';

class CoachModeStatusIndicator extends StatelessWidget {
  const CoachModeStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoachModeCubit, CoachModeState>(
      builder: (context, state) {
        // Handle all possible states more robustly
        if (state is! CoachModeEnabled) {
          return const SizedBox.shrink();
        }
        
        if (!state.enabled) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(left: 4, top: 8, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.blue.shade300,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'COACH MODE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (state.pendingShareCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${state.pendingShareCount}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
