import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'a11y_flags.dart';

class AccessibilityDebugPanel extends StatelessWidget {
  const AccessibilityDebugPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    
    final a11y = context.watch<A11yCubit>().state;
    
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Accessibility (Debug)', 
              style: TextStyle(fontWeight: FontWeight.bold)
            ),
            SwitchListTile(
              title: const Text('Larger Text (1.2x)'), 
              value: a11y.largerText,
              onChanged: context.read<A11yCubit>().setLargerText,
            ),
            SwitchListTile(
              title: const Text('High Contrast'), 
              value: a11y.highContrast,
              onChanged: context.read<A11yCubit>().setHighContrast,
            ),
            SwitchListTile(
              title: const Text('Reduced Motion'), 
              value: a11y.reducedMotion,
              onChanged: context.read<A11yCubit>().setReducedMotion,
            ),
          ],
        ),
      ),
    );
  }
}
