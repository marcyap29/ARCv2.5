import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../coach_mode_cubit.dart';
import '../coach_mode_state.dart';
import '../coach_keyword_listener.dart';
import '../ui/coach_mode_drawer.dart';

class CoachKeywordSuggestion extends StatefulWidget {
  final String text;
  final String? contextId;

  const CoachKeywordSuggestion({
    super.key,
    required this.text,
    this.contextId,
  });

  @override
  State<CoachKeywordSuggestion> createState() => _CoachKeywordSuggestionState();
}

class _CoachKeywordSuggestionState extends State<CoachKeywordSuggestion> {
  final CoachKeywordListener _keywordListener = CoachKeywordListener();

  @override
  void initState() {
    super.initState();
    _analyzeText();
  }

  @override
  void didUpdateWidget(CoachKeywordSuggestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _analyzeText();
    }
  }

  @override
  void dispose() {
    _keywordListener.dispose();
    super.dispose();
  }

  void _analyzeText() {
    if (widget.text.isEmpty) {
      return;
    }

    _keywordListener.analyzeText(widget.text, contextId: widget.contextId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoachModeCubit, CoachModeState>(
      builder: (context, state) {
        if (state is! CoachModeEnabled || !state.enabled) {
          return const SizedBox.shrink();
        }

        if (state.suggestionCooldown) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<bool>(
          stream: _keywordListener.suggestionStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!) {
              return const SizedBox.shrink();
            }

            return _buildSuggestionChip();
          },
        );
      },
    );
  }

  Widget _buildSuggestionChip() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Coaching tools available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openCoachMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Open'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _dismissSuggestion,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Dismiss',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCoachMode() {
    // Mark suggestion as shown to prevent showing again
    context.read<CoachModeCubit>().markSuggestionShown();
    
    // Open the coach mode drawer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const CoachModeDrawer(),
      ),
    );
  }

  void _dismissSuggestion() {
    // Mark suggestion as shown to prevent showing again
    context.read<CoachModeCubit>().markSuggestionShown();
  }
}
