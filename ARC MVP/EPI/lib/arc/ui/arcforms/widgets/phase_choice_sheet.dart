import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/i18n/copy.dart';

class PhaseChoiceSheet extends StatefulWidget {
  final String currentPhase;
  final Function(String) onPhaseSelected;

  const PhaseChoiceSheet({
    super.key,
    required this.currentPhase,
    required this.onPhaseSelected,
  });

  @override
  State<PhaseChoiceSheet> createState() => _PhaseChoiceSheetState();
}

class _PhaseChoiceSheetState extends State<PhaseChoiceSheet> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  String? _expandedPhase;

  final Map<String, String> _phaseEmojis = {
    'Discovery': '🌱',
    'Expansion': '🌸',
    'Transition': '🌿',
    'Consolidation': '🧵',
    'Recovery': '✨',
    'Breakthrough': '💥',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showConsentDialog(String phase) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          Copy.consentTitle(phase),
          style: heading3Style(context).copyWith(
            color: Colors.white,
          ),
        ),
        content: Text(
          Copy.consentBody,
          style: bodyStyle(context).copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              Copy.cancel,
              style: buttonStyle(context).copyWith(
                color: kcSecondaryColor,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: kcPrimaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close sheet
                widget.onPhaseSelected(phase);
              },
              child: Text(
                Copy.ok,
                style: buttonStyle(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: kcBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose Your Phase",
                    style: heading1Style(context).copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Each phase shapes how your thoughts take form.",
                    style: bodyStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            // Phase list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: Copy.phaseDescriptions.entries.map((entry) {
                  final phase = entry.key;
                  final description = entry.value;
                  final isExpanded = _expandedPhase == phase;
                  final isCurrent = widget.currentPhase == phase;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isCurrent 
                          ? kcPrimaryColor.withOpacity(0.1)
                          : kcSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent 
                            ? kcPrimaryColor.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Text(
                            _phaseEmojis[phase] ?? '○',
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Row(
                            children: [
                              Text(
                                phase,
                                style: heading3Style(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kcPrimaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Current",
                                    style: captionStyle(context).copyWith(
                                      color: kcPrimaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              description,
                              style: bodyStyle(context).copyWith(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          trailing: Icon(
                            isExpanded 
                                ? Icons.keyboard_arrow_up 
                                : Icons.keyboard_arrow_down,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          onTap: () {
                            setState(() {
                              _expandedPhase = isExpanded ? null : phase;
                            });
                          },
                        ),
                        
                        if (isExpanded) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: kcPrimaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextButton(
                                  onPressed: () => _showConsentDialog(phase),
                                  child: Text(
                                    "Apply $phase",
                                    style: buttonStyle(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}