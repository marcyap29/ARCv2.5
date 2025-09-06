import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/settings/settings_cubit.dart';
import 'package:my_app/features/settings/widgets/personalization_option.dart';
import 'package:my_app/features/settings/widgets/tone_selector.dart';
import 'package:my_app/features/settings/widgets/rhythm_picker.dart';
import 'package:my_app/features/settings/widgets/text_scale_slider.dart';

class PersonalizationView extends StatelessWidget {
  const PersonalizationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Personalization',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Tone Selection
              PersonalizationOption(
                title: 'Journaling Tone',
                subtitle: 'Choose the emotional atmosphere for your journaling experience',
                icon: Icons.palette,
                child: ToneSelector(
                  selectedTone: state.selectedTone,
                  onToneChanged: (tone) {
                    context.read<SettingsCubit>().setTone(tone);
                  },
                ),
              ),

              // Rhythm Selection
              PersonalizationOption(
                title: 'Journaling Rhythm',
                subtitle: 'Set your preferred journaling frequency and pattern',
                icon: Icons.schedule,
                child: RhythmPicker(
                  selectedRhythm: state.selectedRhythm,
                  onRhythmChanged: (rhythm) {
                    context.read<SettingsCubit>().setRhythm(rhythm);
                  },
                ),
              ),

              // Text Size
              PersonalizationOption(
                title: 'Text Size',
                subtitle: 'Adjust text size for better readability',
                icon: Icons.text_fields,
                child: TextScaleSlider(
                  textScaleFactor: state.textScaleFactor,
                  onScaleChanged: (scale) {
                    context.read<SettingsCubit>().setTextScaleFactor(scale);
                  },
                ),
              ),

              // Color Accessibility
              PersonalizationOption(
                title: 'Color Accessibility',
                subtitle: 'Enhanced color contrast for better visibility',
                icon: Icons.visibility,
                child: SwitchListTile(
                  title: const Text(
                    'Enable Color Accessibility',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'High contrast colors and better visibility',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: state.colorAccessibilityEnabled,
                  onChanged: (value) {
                    context.read<SettingsCubit>().toggleColorAccessibility();
                  },
                  activeThumbColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              // High Contrast Mode
              PersonalizationOption(
                title: 'High Contrast Mode',
                subtitle: 'Maximum contrast for better readability',
                icon: Icons.contrast,
                child: SwitchListTile(
                  title: const Text(
                    'Enable High Contrast',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Maximum contrast for better visibility',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: state.highContrastMode,
                  onChanged: (value) {
                    context.read<SettingsCubit>().toggleHighContrast();
                  },
                  activeThumbColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              // Intro Audio Toggle
              PersonalizationOption(
                title: 'Intro Music',
                subtitle: 'Ethereal ambient music during welcome and onboarding',
                icon: Icons.music_note,
                child: SwitchListTile(
                  title: const Text(
                    'Enable Intro Music',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Play ambient music during welcome and onboarding',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: !state.introAudioMuted,
                  onChanged: (value) {
                    context.read<SettingsCubit>().toggleIntroAudio();
                  },
                  activeThumbColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              // Preview Section
              if (state.selectedTone != 'calm' || 
                  state.selectedRhythm != 'daily' || 
                  state.textScaleFactor != 1.0 ||
                  state.colorAccessibilityEnabled ||
                  state.highContrastMode ||
                  state.introAudioMuted) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Settings Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tone: ${state.selectedTone}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Rhythm: ${state.selectedRhythm}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Text Size: ${(state.textScaleFactor * 100).round()}%',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Color Accessibility: ${state.colorAccessibilityEnabled ? "On" : "Off"}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'High Contrast: ${state.highContrastMode ? "On" : "Off"}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Intro Music: ${state.introAudioMuted ? "Off" : "On"}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
