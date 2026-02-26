// lib/shared/ui/onboarding/widgets/personality_setup_screen.dart
// Personality setup: 7 questions that generate LUMARA baseline config

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';

class PersonalitySetupScreen extends StatefulWidget {
  const PersonalitySetupScreen({super.key});

  @override
  State<PersonalitySetupScreen> createState() => _PersonalitySetupScreenState();
}

class _PersonalitySetupScreenState extends State<PersonalitySetupScreen> {
  final Map<String, String> _choices = {};
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  static const List<({String key, String question, List<String> options})> _choiceQuestions = [
    (key: 'tone', question: 'How should I talk to you?', options: [
      'Casual and direct',
      'Warm and encouraging',
      'Professional and precise',
      'Adapt to my mood',
    ]),
    (key: 'disagreement', question: 'When you disagree or think I\'m wrong?', options: [
      'Call me out directly',
      'Gently offer another perspective',
      'Only if I ask',
      'Never, just support me',
    ]),
    (key: 'responseLength', question: 'How much do you say at once?', options: [
      'Short and punchy',
      'Balanced',
      'Detailed and thorough',
    ]),
    (key: 'emotionalSupport', question: 'When I\'m struggling, what do I need most?', options: [
      'Help me think it through',
      'Practical next steps',
      'Just to be heard first',
      'Push me to keep going',
    ]),
    (key: 'avoid', question: 'What annoys you most in an AI?', options: [
      'Sycophantic praise',
      'Wishy-washy non-answers',
      'Unsolicited advice',
      'Over-explaining obvious things',
    ]),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildAnswers() {
    final map = <String, dynamic>{
      'tone': _choices['tone'] ?? '',
      'disagreement': _choices['disagreement'] ?? '',
      'responseLength': _choices['responseLength'] ?? '',
      'emotionalSupport': _choices['emotionalSupport'] ?? '',
      'avoid': _choices['avoid'] ?? '',
      'userName': _nameController.text.trim(),
      'userNotes': _notesController.text.trim(),
    };
    return map;
  }

  bool get _canSubmit {
    for (final q in _choiceQuestions) {
      if ((_choices[q.key] ?? '').isEmpty) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    await context.read<ArcOnboardingCubit>().completePersonalityAndOnboarding(_buildAnswers());
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kcPrimaryColor.withOpacity(0.2),
                Colors.black,
              ],
            ),
          ),
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'How we\'ll work together',
                  style: heading2Style(context).copyWith(color: Colors.white),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'A few quick choices so I match how you like to work.',
                        style: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._choiceQuestions.map((q) => _buildChoiceSection(context, q)),
                      const SizedBox(height: 20),
                      Text(
                        'What should I call you?',
                        style: heading3Style(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: bodyStyle(context).copyWith(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Your name or nickname',
                          hintStyle: bodyStyle(context).copyWith(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Anything else about how you want to work together?',
                        style: heading3Style(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        style: bodyStyle(context).copyWith(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Optional',
                          hintStyle: bodyStyle(context).copyWith(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_canSubmit && !_isSubmitting) ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kcPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Get started'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceSection(
    BuildContext context,
    ({String key, String question, List<String> options}) q,
  ) {
    final selected = _choices[q.key] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.question,
            style: heading3Style(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: q.options.map((option) {
              final isSelected = selected == option;
              return ChoiceChip(
                label: Text(
                  option,
                  style: bodyStyle(context).copyWith(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 14,
                  ),
                ),
                selected: isSelected,
                onSelected: (v) {
                  setState(() {
                    if (v) _choices[q.key] = option;
                  });
                },
                backgroundColor: Colors.white.withOpacity(0.06),
                selectedColor: kcPrimaryColor,
                side: BorderSide(
                  color: isSelected ? kcPrimaryColor : Colors.white.withOpacity(0.2),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
