import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/mode/first_responder/fr_settings_cubit.dart';
import 'package:my_app/mode/first_responder/fr_settings.dart';

class FRStatusIndicator extends StatelessWidget {
  const FRStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FRSettingsCubit, FRSettings>(
      builder: (context, state) {
        print('DEBUG: FRStatusIndicator - state.isEnabled: ${state.isEnabled}');
        print('DEBUG: FRStatusIndicator - state: $state');
        if (state.isEnabled) {
          return Container(
            margin: const EdgeInsets.only(left: 2, top: 8, right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.shade300,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'FR MODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
