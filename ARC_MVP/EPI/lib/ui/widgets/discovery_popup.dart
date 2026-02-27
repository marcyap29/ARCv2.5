import 'package:flutter/material.dart';
import '../../services/periodic_discovery_service.dart';
import '../../services/phase_aware_analysis_service.dart';

class DiscoveryPopup extends StatefulWidget {
  final DiscoverySuggestion suggestion;
  final VoidCallback onDismiss;
  final ValueChanged<String> onAcceptSuggestion;

  const DiscoveryPopup({
    super.key,
    required this.suggestion,
    required this.onDismiss,
    required this.onAcceptSuggestion,
  });

  @override
  State<DiscoveryPopup> createState() => _DiscoveryPopupState();
}

class _DiscoveryPopupState extends State<DiscoveryPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getDiscoveryColor(theme).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getDiscoveryIcon(),
                              color: _getDiscoveryColor(theme),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.suggestion.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Message
                      Text(
                        widget.suggestion.message,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Phase context if available
                      if (widget.suggestion.phaseContext != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.psychology,
                                color: theme.colorScheme.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Detected: ${_formatPhase(widget.suggestion.phaseContext!.primaryPhase)} (${widget.suggestion.phaseContext!.confidence.toStringAsFixed(0)}% confidence)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Suggestion preview
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: theme.colorScheme.secondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Suggestion',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.suggestion.suggestion,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _dismiss,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: theme.colorScheme.outline.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                'Maybe Later',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _acceptSuggestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getDiscoveryColor(theme),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Explore This',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _acceptSuggestion() {
    widget.onAcceptSuggestion(widget.suggestion.suggestion);
    _dismiss();
  }

  IconData _getDiscoveryIcon() {
    switch (widget.suggestion.type) {
      case DiscoveryType.pattern:
        return Icons.analytics;
      case DiscoveryType.celebration:
        return Icons.celebration;
      case DiscoveryType.support:
        return Icons.support_agent;
      case DiscoveryType.focus:
        return Icons.center_focus_strong;
      case DiscoveryType.breakthrough:
        return Icons.rocket_launch;
      case DiscoveryType.selfcare:
        return Icons.self_improvement;
      case DiscoveryType.exploration:
        return Icons.explore;
      case DiscoveryType.insight:
        return Icons.lightbulb;
    }
  }

  Color _getDiscoveryColor(ThemeData theme) {
    switch (widget.suggestion.type) {
      case DiscoveryType.pattern:
        return Colors.blue;
      case DiscoveryType.celebration:
        return Colors.orange;
      case DiscoveryType.support:
        return Colors.purple;
      case DiscoveryType.focus:
        return Colors.green;
      case DiscoveryType.breakthrough:
        return Colors.amber;
      case DiscoveryType.selfcare:
        return Colors.teal;
      case DiscoveryType.exploration:
        return Colors.indigo;
      case DiscoveryType.insight:
        return theme.colorScheme.primary;
    }
  }

  String _formatPhase(UserPhase phase) {
    switch (phase) {
      case UserPhase.recovery:
        return 'Recovery';
      case UserPhase.discovery:
        return 'Discovery';
      case UserPhase.breakthrough:
        return 'Breakthrough';
      case UserPhase.consolidation:
        return 'Consolidation';
      // case UserPhase.exhaustion: // COMMENTED OUT - not in enum
      //   return 'Exhaustion';
      // case UserPhase.grief: // COMMENTED OUT - not in enum
      //   return 'Grief';
      // case UserPhase.celebration: // COMMENTED OUT - not in enum
      //   return 'Celebration';
      case UserPhase.reflection:
        return 'Reflection';
      case UserPhase.transition:
        return 'Transition';
      // case UserPhase.uncertainty: // COMMENTED OUT - not in enum
      //   return 'Uncertainty';
    }
  }
}
