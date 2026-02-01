// lib/shared/ui/onboarding/onboarding_complete_screen.dart
// Completion screen showing quiz result and inaugural entry

import 'package:flutter/material.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/internal/echo/phase/quiz_models.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  final JournalEntry entry;
  final UserProfile profile;
  /// Preview of CHRONICLE monthly synthesis (first few lines) when available
  final String? lumaraSynthesisPreview;

  const OnboardingCompleteScreen({
    super.key,
    required this.entry,
    required this.profile,
    this.lumaraSynthesisPreview,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success icon
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Welcome to LUMARA',
                style: heading1Style(context).copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Explanation
              Text(
                'I\'ve created your inaugural journal entry and established a baseline understanding of where you are right now.',
                style: bodyStyle(context).copyWith(
                  color: Colors.grey[300],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Entry preview card
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article,
                            color: kcPrimaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Inaugural Entry',
                            style: heading3Style(context).copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.content.split('\n').length} lines, ${entry.content.split(' ').length} words',
                        style: bodyStyle(context).copyWith(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getPreview(entry.content),
                        style: bodyStyle(context).copyWith(
                          color: Colors.grey[200],
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              if (lumaraSynthesisPreview != null && lumaraSynthesisPreview!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.white.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: kcPrimaryColor.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LUMARA\'s Initial Understanding',
                          style: heading3Style(context).copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lumaraSynthesisPreview!,
                          style: bodyStyle(context).copyWith(
                            color: Colors.grey[200],
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // What's captured
              Card(
                color: kcPrimaryColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LUMARA now knows:',
                        style: heading3Style(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildKnowsItem('Your current phase: ${_phaseDisplay(profile.currentPhase)}', context),
                      _buildKnowsItem('Primary focus: ${_themesDisplay(profile.dominantThemes)}', context),
                      _buildKnowsItem('Emotional state: ${_emotionalDisplay(profile.emotionalState)}', context),
                      _buildKnowsItem('How you approach challenges', context),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // CTA buttons
              ElevatedButton(
                onPressed: () => _viewEntry(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Read Your Entry',
                  style: buttonStyle(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _startJournaling(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start Journaling',
                  style: buttonStyle(context).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildKnowsItem(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: bodyStyle(context).copyWith(
                color: Colors.grey[200],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPreview(String content) {
    // Get first paragraph after title
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (final line in lines) {
      if (!line.startsWith('#') && !line.startsWith('*') && !line.startsWith('---')) {
        return line;
      }
    }
    return content.substring(0, content.length > 200 ? 200 : content.length);
  }
  
  String _phaseDisplay(String? phase) {
    if (phase == null) return 'Unknown';
    return phase[0].toUpperCase() + phase.substring(1);
  }
  
  String _themesDisplay(List<String> themes) {
    if (themes.isEmpty) return 'Various areas';
    if (themes.length == 1) return themes[0];
    return themes.take(2).join(', ') + (themes.length > 2 ? ', +more' : '');
  }
  
  String _emotionalDisplay(String? state) {
    final map = {
      'struggling': 'Struggling',
      'uncertain': 'Uncertain',
      'stable': 'Stable',
      'hopeful': 'Hopeful',
      'energized': 'Energized',
      'mixed': 'Mixed',
      'numb': 'Disconnected',
    };
    return map[state] ?? 'Processing';
  }
  
  void _viewEntry(BuildContext context) {
    // TODO: Navigate to journal entry view
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entry view coming soon'),
        backgroundColor: kcPrimaryColor,
      ),
    );
  }
  
  void _startJournaling(BuildContext context) {
    // Navigate to home/main screen
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }
}
