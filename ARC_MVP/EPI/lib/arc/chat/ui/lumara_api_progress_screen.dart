/// LUMARA API Progress Screen
///
/// Shown when a chat query triggers an API-backed flow (research, writing).
/// Same visual as voice mode (sigil in "thinking" state, pulsing/glow) with
/// a single accent color; status text from the API call (e.g. research steps).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/voice/ui/voice_sigil.dart';
import 'package:my_app/models/phase_models.dart';

class LumaraApiProgressScreen extends StatelessWidget {
  const LumaraApiProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LumaraAssistantCubit, LumaraAssistantState>(
      listenWhen: (prev, curr) {
        if (prev is LumaraAssistantLoaded && curr is LumaraAssistantLoaded) {
          return prev.isProcessing && !curr.isProcessing;
        }
        return false;
      },
      listener: (context, state) {
        if (state is LumaraAssistantLoaded && !state.isProcessing) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final steps = state is LumaraAssistantLoaded
            ? state.processingSteps
            : <String>[];
        final primaryText = steps.isNotEmpty
            ? steps.last
            : 'Connecting…';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VoiceSigil(
                      state: VoiceSigilState.thinking,
                      currentPhase: PhaseLabel.discovery,
                      colorOverride: kSigilSingleColor,
                      audioLevel: 0.0,
                      onTap: () {},
                      size: 200,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              primaryText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (steps.length > 1) ...[
                              const SizedBox(height: 8),
                              ...steps.sublist(0, steps.length - 1).map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        s,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[400],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
