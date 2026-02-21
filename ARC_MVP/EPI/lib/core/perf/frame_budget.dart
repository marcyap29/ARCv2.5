import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

class FrameBudgetOverlay extends StatefulWidget {
  final double targetFps; // e.g., 45
  const FrameBudgetOverlay({super.key, this.targetFps = 45});
  
  @override 
  State<FrameBudgetOverlay> createState() => _FrameBudgetOverlayState();
}

class _FrameBudgetOverlayState extends State<FrameBudgetOverlay> {
  double _fps = 60;
  late final TimingsCallback _cb;

  @override 
  void initState() {
    super.initState();
    _cb = (List<FrameTiming> timings) {
      if (!mounted) return;
      final ms = timings.map((t) => t.totalSpan.inMicroseconds / 1000.0).toList();
      if (ms.isEmpty) return;
      final avg = ms.reduce((a, b) => a + b) / ms.length;
      final fps = (avg > 0) ? 1000.0 / avg : 60.0;
      setState(() => _fps = fps);
      if (kDebugMode && fps < widget.targetFps) {
        log('⚠️ FPS below target: ${fps.toStringAsFixed(1)} (< ${widget.targetFps})');
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_cb);
  }

  @override 
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_cb);
    super.dispose();
  }

  @override 
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    
    final ok = _fps >= widget.targetFps;
    return Positioned(
      right: 8, 
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ok 
            ? Colors.black.withOpacity(0.6) 
            : Colors.red.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'FPS ${_fps.toStringAsFixed(0)}', 
            style: const TextStyle(color: Colors.white)
          ),
        ),
      ),
    );
  }
}
