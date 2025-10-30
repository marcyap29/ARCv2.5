import 'package:flutter/material.dart';
import 'constellation_arcform_renderer.dart';

/// Demo widget showing how to use the Constellation Arcform Renderer
class ConstellationDemo extends StatelessWidget {
  const ConstellationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample keywords with scores and sentiment
    final keywords = [
      const KeywordScore(text: 'growth', score: 0.9, sentiment: 0.8),
      const KeywordScore(text: 'discovery', score: 0.85, sentiment: 0.7),
      const KeywordScore(text: 'insight', score: 0.8, sentiment: 0.6),
      const KeywordScore(text: 'transformation', score: 0.75, sentiment: 0.9),
      const KeywordScore(text: 'clarity', score: 0.7, sentiment: 0.5),
      const KeywordScore(text: 'wisdom', score: 0.65, sentiment: 0.8),
      const KeywordScore(text: 'journey', score: 0.6, sentiment: 0.4),
      const KeywordScore(text: 'awareness', score: 0.55, sentiment: 0.6),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Constellation Arcform Demo'),
        backgroundColor: const Color(0xFF0A0A0F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Phase selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: AtlasPhase.values.map((phase) {
                return ElevatedButton(
                  onPressed: () {
                    // In a real app, this would update the phase
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1B3FF),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(phase.name),
                );
              }).toList(),
            ),
          ),
          
          // Constellation renderer
          Expanded(
            child: ConstellationArcformRenderer(
              phase: AtlasPhase.discovery,
              keywords: keywords,
              palette: EmotionPalette.defaultPalette,
              seed: 42,
              onNodeTapped: (nodeId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tapped node: $nodeId')),
                );
              },
              onExport: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export functionality would be implemented here')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
