// lib/lumara/profile/lumara_preferences_screen.dart
// Phase 6: "How should LUMARA work with you?" — onboarding or standalone from Settings.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'lumara_preferences_model.dart';

const String _keyLumaraPrefsSkipped = 'lumara_prefs_skipped';

class LumaraPreferencesScreen extends StatefulWidget {
  const LumaraPreferencesScreen({
    super.key,
    this.standaloneMode = false,
    this.onSaveAndComplete,
    this.onSkip,
  });

  /// When true (e.g. opened from Settings), show Save + Back only. Otherwise Show Continue + Skip.
  final bool standaloneMode;
  final VoidCallback? onSaveAndComplete;
  final VoidCallback? onSkip;

  @override
  State<LumaraPreferencesScreen> createState() => _LumaraPreferencesScreenState();
}

class _LumaraPreferencesScreenState extends State<LumaraPreferencesScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _communicationStyle = 'balanced';
  String _challengeStyle = 'gentle';
  String _tone = 'casual';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await LumaraPreferencesStore.instance.load();
    if (mounted) {
      setState(() {
        _nameController.text = prefs.preferredName;
        _communicationStyle = prefs.communicationStyle;
        _challengeStyle = prefs.challengeStyle;
        _tone = prefs.tone;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndAdvance() async {
    setState(() => _saving = true);
    final prefs = LumaraPreferences(
      preferredName: _nameController.text.trim(),
      communicationStyle: _communicationStyle,
      challengeStyle: _challengeStyle,
      tone: _tone,
    );
    await LumaraPreferencesStore.instance.save(prefs);
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.standaloneMode) {
      widget.onSaveAndComplete?.call();
    } else {
      context.read<ArcOnboardingCubit>().advanceAfterLumaraPrefs();
    }
  }

  void _skip() async {
    if (widget.standaloneMode) {
      widget.onSkip?.call();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLumaraPrefsSkipped, true);
    if (!mounted) return;
    context.read<ArcOnboardingCubit>().advanceAfterLumaraPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.standaloneMode
          ? AppBar(
              title: const Text('LUMARA Preferences'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'How should LUMARA work with you?',
                      style: heading1Style(context).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can change these anytime in Settings → LUMARA',
                      style: bodyStyle(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'What should LUMARA call you?',
                        hintText: 'Your name or nickname',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel(context, 'Communication style'),
                    const SizedBox(height: 8),
                    _chips(context, ['Short & punchy', 'Balanced', 'Long & detailed'],
                        ['short', 'balanced', 'long'], _communicationStyle, (v) => setState(() => _communicationStyle = v)),
                    const SizedBox(height: 20),
                    _sectionLabel(context, 'How should LUMARA challenge you?'),
                    const SizedBox(height: 8),
                    _chips(context, ['Call me out directly', 'Gentle nudges', 'Just support me'],
                        ['direct', 'gentle', 'support'], _challengeStyle, (v) => setState(() => _challengeStyle = v)),
                    const SizedBox(height: 20),
                    _sectionLabel(context, 'Tone'),
                    const SizedBox(height: 8),
                    _chips(context, ['Casual', 'Professional'], ['casual', 'professional'], _tone, (v) => setState(() => _tone = v)),
                    const SizedBox(height: 32),
                    if (_saving)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saveAndAdvance,
                          style: FilledButton.styleFrom(
                            backgroundColor: kcPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(widget.standaloneMode ? 'Save' : 'Continue'),
                        ),
                      ),
                      if (!widget.standaloneMode || widget.onSkip != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _skip,
                          child: Text(
                            widget.standaloneMode ? 'Back' : 'Skip',
                            style: bodyStyle(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _chips(BuildContext context, List<String> labels, List<String> values, String selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) {
        final isSelected = values[i] == selected;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: isSelected,
          onSelected: (_) => onSelect(values[i]),
          selectedColor: kcPrimaryColor.withOpacity(0.3),
        );
      }),
    );
  }
}
