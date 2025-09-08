import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../debrief_models.dart';

class DebriefTimer extends StatefulWidget {
  final DateTime startTime;
  final DebriefStep currentStep;
  final Duration? estimatedRemaining;
  
  const DebriefTimer({
    super.key,
    required this.startTime,
    required this.currentStep,
    this.estimatedRemaining,
  });

  @override
  State<DebriefTimer> createState() => _DebriefTimerState();
}

class _DebriefTimerState extends State<DebriefTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final elapsed = DateTime.now().difference(widget.startTime);
        final elapsedMinutes = elapsed.inMinutes;
        final elapsedSeconds = elapsed.inSeconds % 60;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kcPrimaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated clock icon
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Icon(
                    Icons.access_time,
                    color: kcPrimaryColor.withOpacity(0.7 + 0.3 * _animation.value),
                    size: 16,
                  );
                },
              ),
              const SizedBox(width: 6),
              
              // Elapsed time
              Text(
                '${elapsedMinutes.toString().padLeft(2, '0')}:${elapsedSeconds.toString().padLeft(2, '0')}',
                style: captionStyle(context).copyWith(
                  color: kcSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              
              // Estimated remaining (if provided)
              if (widget.estimatedRemaining != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: kcSecondaryColor.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  '~${widget.estimatedRemaining!.inMinutes}m left',
                  style: captionStyle(context).copyWith(
                    color: kcSecondaryColor.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}