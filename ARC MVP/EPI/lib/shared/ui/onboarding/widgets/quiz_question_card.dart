// lib/shared/ui/onboarding/widgets/quiz_question_card.dart
// Individual question display component for PhaseQuizV2

import 'package:flutter/material.dart';
import 'package:my_app/arc/internal/echo/phase/quiz_models.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class QuizQuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final QuizAnswer? currentAnswer;
  final Function(QuizAnswer) onAnswerChanged;
  
  const QuizQuestionCard({
    super.key,
    required this.question,
    required this.onAnswerChanged,
    this.currentAnswer,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question text
          Text(
            question.text,
            style: heading1Style(context).copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          if (question.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              question.subtitle!,
              style: bodyStyle(context).copyWith(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Options
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final option = question.options[index];
                final isSelected = currentAnswer?.selectedOptions.contains(option.value) ?? false;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOptionCard(
                    context,
                    option,
                    isSelected,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionCard(BuildContext context, QuizOption option, bool isSelected) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? kcPrimaryColor.withOpacity(0.15)
          : Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? kcPrimaryColor
              : Colors.white.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectOption(option),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(
                question.multiSelect
                    ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                    : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                color: isSelected ? kcPrimaryColor : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: bodyStyle(context).copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    if (_hasContext(option))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _getContext(option),
                          style: bodyStyle(context).copyWith(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasContext(QuizOption option) {
    return option.value == 'numb' || option.value == 'mixed';
  }

  String _getContext(QuizOption option) {
    const contexts = {
      'numb': 'Like observing from the outside',
      'mixed': 'Intense highs and lows',
    };
    return contexts[option.value] ?? '';
  }
  
  void _selectOption(QuizOption option) {
    if (question.multiSelect) {
      // Multi-select logic
      final currentSelections = currentAnswer?.selectedOptions ?? [];
      List<String> newSelections;
      
      if (currentSelections.contains(option.value)) {
        // Deselect
        newSelections = currentSelections.where((v) => v != option.value).toList();
      } else {
        // Select (if under max)
        if (currentSelections.length < (question.maxSelections ?? 999)) {
          newSelections = [...currentSelections, option.value];
        } else {
          // Already at max, ignore
          return;
        }
      }
      
      onAnswerChanged(QuizAnswer(newSelections));
    } else {
      // Single select
      onAnswerChanged(QuizAnswer([option.value]));
    }
  }
}
