import 'package:flutter/material.dart';
import '../../core/i18n/copy.dart';
import '../../atlas/rivet/rivet_models.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';

/// Modal showing detailed RIVET gate status and reasoning
class RivetGateDetailsModal extends StatelessWidget {
  final RivetState rivetState;
  final double alignThreshold;
  final double traceThreshold;
  final int sustainTarget;
  final PhaseTransitionInsights? transitionInsights;

  const RivetGateDetailsModal({
    super.key,
    required this.rivetState,
    this.alignThreshold = 0.6,
    this.traceThreshold = 0.6,
    this.sustainTarget = 2,
    this.transitionInsights,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate status booleans
    final matchGood = rivetState.align >= alignThreshold;
    final confidenceGood = rivetState.trace >= traceThreshold;
    final consistencyGood = rivetState.sustainCount >= sustainTarget;
    final independentGood = rivetState.sawIndependentInWindow;
    
    final ready = matchGood && confidenceGood && consistencyGood && independentGood;
    final almost = confidenceGood && !ready && (sustainTarget - rivetState.sustainCount) <= 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: kcPrimaryTextColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Copy.rivetDetailsTitle,
                    style: heading2Style(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: kcSecondaryTextColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Explanation
            Text(
              Copy.rivetDetailsBlurb,
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            
            // Live values
            _buildValueRow(
              context,
              Copy.rivetDetailsValuesMatch((rivetState.align * 100).round()),
              rivetState.align,
              alignThreshold,
            ),
            const SizedBox(height: 12),
            _buildValueRow(
              context,
              Copy.rivetDetailsValuesConfidence((rivetState.trace * 100).round()),
              rivetState.trace,
              traceThreshold,
            ),
            const SizedBox(height: 12),
            _buildValueRow(
              context,
              Copy.rivetDetailsValuesConsistency(rivetState.sustainCount, sustainTarget),
              rivetState.sustainCount / sustainTarget,
              1.0,
            ),
            const SizedBox(height: 12),
            _buildValueRow(
              context,
              Copy.rivetDetailsValuesIndependent(independentGood ? "Yes" : "No"),
              independentGood ? 1.0 : 0.0,
              1.0,
            ),
            const SizedBox(height: 24),
            
            // State summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ready 
                    ? Colors.green.withOpacity(0.1)
                    : almost 
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ready 
                      ? Colors.green.withOpacity(0.3)
                      : almost 
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    ready 
                        ? Icons.check_circle
                        : almost 
                            ? Icons.schedule
                            : Icons.pause_circle,
                    color: ready 
                        ? Colors.green
                        : almost 
                            ? Colors.orange
                            : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ready 
                          ? Copy.rivetStateReady
                          : almost 
                              ? Copy.rivetStateAlmost
                              : Copy.rivetStateHold,
                      style: bodyStyle(context).copyWith(
                        color: ready 
                            ? Colors.green
                            : almost 
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Phase transition insights (if available)
            if (transitionInsights != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          color: Colors.purple,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Phase Transition Insights',
                          style: bodyStyle(context).copyWith(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      transitionInsights!.getPrimaryInsight(),
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (transitionInsights!.measurableSigns.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...transitionInsights!.measurableSigns.take(3).map((sign) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.purple)),
                            Expanded(
                              child: Text(
                                sign,
                                style: bodyStyle(context).copyWith(
                                  color: kcSecondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ],
            
            // Nudge footer (only when held/almost)
            if (!ready) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Copy.rivetNudge,
                        style: bodyStyle(context).copyWith(
                          color: Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow(
    BuildContext context,
    String label,
    double value,
    double threshold,
  ) {
    final isGood = value >= threshold;
    
    return Row(
      children: [
        Icon(
          isGood ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isGood ? Colors.green : Colors.orange,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${(value * 100).round()}%',
          style: bodyStyle(context).copyWith(
            color: isGood ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
