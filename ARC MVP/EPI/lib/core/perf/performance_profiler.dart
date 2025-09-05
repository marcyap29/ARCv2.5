import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

/// Performance Profiler for P19
/// Comprehensive performance monitoring and optimization tools
class PerformanceProfiler {
  static const String _logTag = 'PerformanceProfiler';
  
  static final Map<String, PerformanceMetric> _metrics = {};
  static final List<FrameTiming> _frameTimings = [];
  static Timer? _profilingTimer;
  static bool _isProfiling = false;
  
  /// Start comprehensive performance profiling
  static void startProfiling() {
    if (_isProfiling) return;
    
    _isProfiling = true;
    _log('Starting performance profiling...');
    
    // Start frame timing monitoring
    SchedulerBinding.instance.addTimingsCallback(_onFrameTiming);
    
    // Start periodic profiling
    _profilingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _collectMetrics();
    });
    
    _log('Performance profiling started');
  }
  
  /// Stop performance profiling
  static void stopProfiling() {
    if (!_isProfiling) return;
    
    _isProfiling = false;
    _log('Stopping performance profiling...');
    
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTiming);
    _profilingTimer?.cancel();
    _profilingTimer = null;
    
    _log('Performance profiling stopped');
  }
  
  /// Record a custom performance metric
  static void recordMetric(String name, double value, {String? unit}) {
    _metrics[name] = PerformanceMetric(
      name: name,
      value: value,
      unit: unit ?? 'ms',
      timestamp: DateTime.now(),
    );
  }
  
  /// Measure execution time of a function
  static Future<T> measureExecution<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      recordMetric(operationName, stopwatch.elapsedMilliseconds.toDouble());
      _log('$operationName completed in ${stopwatch.elapsedMilliseconds}ms');
      
      return result;
    } catch (e) {
      stopwatch.stop();
      recordMetric('${operationName}_error', stopwatch.elapsedMilliseconds.toDouble());
      _log('$operationName failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }
  
  /// Get current performance report
  static PerformanceReport getPerformanceReport() {
    final now = DateTime.now();
    final recentFrames = _frameTimings.where(
      (frame) => now.difference(frame.timestamp).inSeconds < 10
    ).toList();
    
    double averageFps = 0;
    double minFps = double.infinity;
    double maxFps = 0;
    
    if (recentFrames.isNotEmpty) {
      final frameDurations = recentFrames.map((f) => f.totalSpan.inMicroseconds / 1000.0).toList();
      final averageFrameTime = frameDurations.reduce((a, b) => a + b) / frameDurations.length;
      averageFps = averageFrameTime > 0 ? 1000.0 / averageFrameTime : 0;
      
      minFps = frameDurations.map((d) => 1000.0 / d).reduce((a, b) => a < b ? a : b);
      maxFps = frameDurations.map((d) => 1000.0 / d).reduce((a, b) => a > b ? a : b);
    }
    
    return PerformanceReport(
      timestamp: now,
      averageFps: averageFps,
      minFps: minFps == double.infinity ? 0 : minFps,
      maxFps: maxFps,
      frameCount: recentFrames.length,
      metrics: Map.from(_metrics),
      recommendations: _generateRecommendations(averageFps, recentFrames.length),
    );
  }
  
  /// Frame timing callback
  static void _onFrameTiming(List<FrameTiming> timings) {
    if (!_isProfiling) return;
    
    _frameTimings.addAll(timings);
    
    // Keep only last 100 frames to prevent memory issues
    if (_frameTimings.length > 100) {
      _frameTimings.removeRange(0, _frameTimings.length - 100);
    }
  }
  
  /// Collect additional performance metrics
  static void _collectMetrics() {
    if (!_isProfiling) return;
    
    // Memory usage (simplified)
    final memoryUsage = _getMemoryUsage();
    recordMetric('memory_usage', memoryUsage, unit: 'MB');
    
    // Widget rebuild count (simplified)
    recordMetric('widget_rebuilds', _getWidgetRebuildCount().toDouble());
  }
  
  /// Get approximate memory usage
  static double _getMemoryUsage() {
    // This is a simplified implementation
    // In a real app, you'd use platform-specific APIs
    return 50.0; // Placeholder
  }
  
  /// Get approximate widget rebuild count
  static int _getWidgetRebuildCount() {
    // This is a simplified implementation
    // In a real app, you'd track rebuilds more precisely
    return 10; // Placeholder
  }
  
  /// Generate performance recommendations
  static List<String> _generateRecommendations(double fps, int frameCount) {
    final recommendations = <String>[];
    
    if (fps < 30) {
      recommendations.add('⚠️ FPS is very low ($fps). Consider optimizing animations and reducing widget complexity.');
    } else if (fps < 45) {
      recommendations.add('⚠️ FPS is below target ($fps). Consider optimizing heavy operations.');
    } else if (fps >= 60) {
      recommendations.add('✅ Excellent performance ($fps FPS)!');
    }
    
    if (frameCount < 10) {
      recommendations.add('⚠️ Low frame count. Consider increasing animation frequency.');
    }
    
    final memoryUsage = _metrics['memory_usage']?.value ?? 0;
    if (memoryUsage > 100) {
      recommendations.add('⚠️ High memory usage (${memoryUsage}MB). Consider optimizing memory usage.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('✅ Performance looks good!');
    }
    
    return recommendations;
  }
  
  static void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: _logTag);
    }
  }
}

/// Performance metric data class
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  
  const PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
  });
}

/// Performance report data class
class PerformanceReport {
  final DateTime timestamp;
  final double averageFps;
  final double minFps;
  final double maxFps;
  final int frameCount;
  final Map<String, PerformanceMetric> metrics;
  final List<String> recommendations;
  
  const PerformanceReport({
    required this.timestamp,
    required this.averageFps,
    required this.minFps,
    required this.maxFps,
    required this.frameCount,
    required this.metrics,
    required this.recommendations,
  });
}

/// Performance profiling debug panel
class PerformanceProfilingPanel extends StatefulWidget {
  const PerformanceProfilingPanel({super.key});
  
  @override
  State<PerformanceProfilingPanel> createState() => _PerformanceProfilingPanelState();
}

class _PerformanceProfilingPanelState extends State<PerformanceProfilingPanel> {
  PerformanceReport? _report;
  bool _isProfiling = false;
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _updateReport();
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  void _updateReport() {
    setState(() {
      _report = PerformanceProfiler.getPerformanceReport();
    });
  }
  
  void _toggleProfiling() {
    if (_isProfiling) {
      PerformanceProfiler.stopProfiling();
      _updateTimer?.cancel();
    } else {
      PerformanceProfiler.startProfiling();
      _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateReport());
    }
    
    setState(() {
      _isProfiling = !_isProfiling;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Performance Profiling',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                ElevatedButton(
                  onPressed: _toggleProfiling,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isProfiling ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isProfiling ? 'Stop' : 'Start'),
                ),
              ],
            ),
            
            if (_report != null) ...[
              const SizedBox(height: 16),
              _buildPerformanceMetrics(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceMetrics() {
    final report = _report!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FPS Metrics
        Card(
          color: report.averageFps >= 45 ? Colors.green.shade50 : Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Frame Rate',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Average: ${report.averageFps.toStringAsFixed(1)} FPS'),
                Text('Min: ${report.minFps.toStringAsFixed(1)} FPS'),
                Text('Max: ${report.maxFps.toStringAsFixed(1)} FPS'),
                Text('Frames: ${report.frameCount}'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Custom Metrics
        if (report.metrics.isNotEmpty) ...[
          const Text(
            'Custom Metrics',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...report.metrics.values.map((metric) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(metric.name),
                Text('${metric.value.toStringAsFixed(1)} ${metric.unit}'),
              ],
            ),
          )),
          const SizedBox(height: 12),
        ],
        
        // Recommendations
        if (report.recommendations.isNotEmpty) ...[
          const Text(
            'Recommendations',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...report.recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(rec)),
              ],
            ),
          )),
        ],
      ],
    );
  }
}
