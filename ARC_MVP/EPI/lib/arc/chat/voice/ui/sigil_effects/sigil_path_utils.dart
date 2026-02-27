/// Sigil Path Utilities
/// 
/// Shared path geometry for the LUMARA sigil visual effects.
/// Defines the paths along which particles flow and shimmer travels.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Sigil path definition
class SigilPath {
  /// Get the sigil path points for a given size
  /// 
  /// The LUMARA sigil is roughly a six-pointed star with curved paths
  /// These points define the main structure for particle flow
  static List<Offset> getPathPoints(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    final points = <Offset>[];
    
    // Create 6 points for the star shape
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      points.add(Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ));
    }
    
    return points;
  }
  
  /// Get intersection nodes (points where paths cross)
  /// These are where constellation points appear
  static List<Offset> getIntersectionNodes(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = size.width * 0.15;
    final outerRadius = size.width * 0.35;
    
    final nodes = <Offset>[center]; // Center is always a node
    
    // Inner ring of nodes
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      nodes.add(Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      ));
    }
    
    // Outer ring of nodes
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      nodes.add(Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      ));
    }
    
    return nodes;
  }
  
  /// Get the paths for shimmer to travel along
  static List<Path> getShimmerPaths(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.4;
    final innerRadius = size.width * 0.15;
    
    final paths = <Path>[];
    
    // Create paths from center to each outer point
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final outerPoint = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(outerPoint.dx, outerPoint.dy);
      
      paths.add(path);
    }
    
    // Create connecting paths between adjacent outer points
    for (int i = 0; i < 6; i++) {
      final angle1 = (i * 60 - 90) * math.pi / 180;
      final angle2 = ((i + 1) % 6 * 60 - 90) * math.pi / 180;
      
      final point1 = Offset(
        center.dx + outerRadius * math.cos(angle1),
        center.dy + outerRadius * math.sin(angle1),
      );
      final point2 = Offset(
        center.dx + outerRadius * math.cos(angle2),
        center.dy + outerRadius * math.sin(angle2),
      );
      
      final path = Path()
        ..moveTo(point1.dx, point1.dy)
        ..lineTo(point2.dx, point2.dy);
      
      paths.add(path);
    }
    
    return paths;
  }
  
  /// Calculate a point along a path at a given progress (0.0 to 1.0)
  static Offset getPointAlongPath(Path path, double progress) {
    final metrics = path.computeMetrics().first;
    final tangent = metrics.getTangentForOffset(metrics.length * progress);
    return tangent?.position ?? Offset.zero;
  }
}

/// Direction for particle flow
enum ParticleFlowDirection {
  /// Particles flow toward center (listening/collecting)
  inward,
  
  /// Particles flow away from center (speaking/emanating)
  outward,
  
  /// Particles orbit around (idle/ambient)
  orbital,
}
