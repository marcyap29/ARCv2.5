import 'package:flutter/material.dart';

/// Persona options for LUMARA
enum LumaraPersona {
  companion,
  strategist,
  therapist,
  challenger,
}

/// Persona selector widget for chat
class PersonaSelectorWidget extends StatelessWidget {
  final LumaraPersona selectedPersona;
  final Function(LumaraPersona) onPersonaChanged;

  const PersonaSelectorWidget({
    super.key,
    required this.selectedPersona,
    required this.onPersonaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: DropdownButton<LumaraPersona>(
              value: selectedPersona,
              underline: const SizedBox.shrink(),
              icon: Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              isExpanded: true, // Prevent overflow issues
              items: [
                DropdownMenuItem(
                  value: LumaraPersona.companion,
                  child: Text('Companion'),
                ),
                DropdownMenuItem(
                  value: LumaraPersona.strategist,
                  child: Text('Strategist'),
                ),
                DropdownMenuItem(
                  value: LumaraPersona.therapist,
                  child: Text('Therapist'),
                ),
                DropdownMenuItem(
                  value: LumaraPersona.challenger,
                  child: Text('Challenger'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onPersonaChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Convert persona to conversation mode (for API)
  static String personaToConversationMode(LumaraPersona persona) {
    switch (persona) {
      case LumaraPersona.companion:
        return 'companion';
      case LumaraPersona.strategist:
        return 'strategist';
      case LumaraPersona.therapist:
        return 'therapist';
      case LumaraPersona.challenger:
        return 'challenger';
    }
  }
}

