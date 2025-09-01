import 'dart:math';
import 'package:flutter/material.dart';

class SpiralLayout {
  /// Creates true spiral positions using golden angle for optimal distribution
  /// Returns offsets around (0,0); caller should add canvas-center offset
  static List<Offset> positions(int n, {double step = 22, double jitter = 0}) {
    const golden = pi * (3 - sqrt(5)); // ~2.399963... (golden angle in radians)
    final rand = Random();
    final pts = <Offset>[];
    
    for (var i = 0; i < n; i++) {
      // Radial growth - creates outward spiral motion
      final r = step * sqrt(i + 1);
      
      // Golden angle spacing - prevents clustering and creates natural distribution
      final th = i * golden;
      
      // Calculate spiral position
      var x = r * cos(th);
      var y = r * sin(th);
      
      // Optional jitter for organic feel (but keep minimal for sacred geometry)
      if (jitter > 0) {
        x += (rand.nextDouble() - 0.5) * jitter;
        y += (rand.nextDouble() - 0.5) * jitter;
      }
      
      pts.add(Offset(x, y));
    }
    
    return pts;
  }
  
  /// Alternative spiral with tighter initial coils
  static List<Offset> tightSpiral(int n, {double initialRadius = 8, double growth = 1.5}) {
    const golden = pi * (3 - sqrt(5));
    final pts = <Offset>[];
    
    for (var i = 0; i < n; i++) {
      final r = initialRadius + (growth * i);
      final th = i * golden;
      
      final x = r * cos(th);
      final y = r * sin(th);
      
      pts.add(Offset(x, y));
    }
    
    return pts;
  }
  
  /// Validates spiral quality - ensures nodes are properly distributed
  static bool isValidSpiral(List<Offset> positions) {
    if (positions.length < 3) return true;
    
    // Check that consecutive nodes increase in distance from center
    for (int i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final curr = positions[i];
      
      final prevDist = sqrt(prev.dx * prev.dx + prev.dy * prev.dy);
      final currDist = sqrt(curr.dx * curr.dx + curr.dy * curr.dy);
      
      // Allow some tolerance for natural spiral variation
      if (currDist < prevDist * 0.8) {
        return false; // Too much inward movement
      }
    }
    
    return true;
  }
}