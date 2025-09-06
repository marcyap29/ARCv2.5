import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/geometry/spiral_layout.dart';

void main() {
  // Test spiral layout with 8 nodes (same as sample data)
  final positions = SpiralLayout.positions(8, step: 25);
  
  print('Spiral positions for 8 nodes:');
  for (int i = 0; i < positions.length; i++) {
    print('Node ${i + 1}: (${positions[i].dx.toStringAsFixed(2)}, ${positions[i].dy.toStringAsFixed(2)})');
  }
  
  // Test with canvas center offset
  const center = Offset(200, 200);
  final centeredPositions = positions.map((pos) => pos + center).toList();
  
  print('\nWith canvas center (200, 200):');
  for (int i = 0; i < centeredPositions.length; i++) {
    print('Node ${i + 1}: (${centeredPositions[i].dx.toStringAsFixed(2)}, ${centeredPositions[i].dy.toStringAsFixed(2)})');
  }
}
