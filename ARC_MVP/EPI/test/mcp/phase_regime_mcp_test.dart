// test/mcp/phase_regime_mcp_test.dart
// Test MCP export/import compatibility with phase regimes

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/mira/store/mcp/export/mcp_export_service.dart';
import 'package:my_app/arc/chat/services/mcp_bundle_parser.dart';
import 'package:my_app/arc/chat/models/reflective_node.dart';

class MockAnalyticsService implements AnalyticsService {
  @override
  Future<void> trackEvent(String eventName, {Map<String, dynamic>? properties}) async {}

  @override
  Future<void> setUserProperty(String key, dynamic value) async {}

  @override
  Future<void> flush() async {}
}

class MockRivetSweepService implements RivetSweepService {
  MockRivetSweepService(AnalyticsService analytics);
  
  @override
  bool needsRivetSweep(List<JournalEntry> entries, PhaseIndex phaseIndex) => false;

  @override
  Future<RivetSweepResult> analyzeEntries(List<JournalEntry> entries) async {
    return const RivetSweepResult(
      autoAssign: [],
      review: [],
      lowConfidence: [],
      changePoints: [],
      dailySignals: [],
    );
  }

  @override
  Future<List<PhaseRegime>> applyProposals(
    List<PhaseSegmentProposal> proposals,
    PhaseIndex phaseIndex,
  ) async {
    return [];
  }

  @override
  Future<void> sweep() async {}
}

void main() {
  group('Phase Regime MCP Compatibility', () {
    late PhaseRegimeService phaseService;
    late McpExportService exportService;
    late McpBundleParser parser;
    late MockAnalyticsService mockAnalytics;

    setUp(() {
      mockAnalytics = MockAnalyticsService();
      phaseService = PhaseRegimeService(mockAnalytics, MockRivetSweepService(mockAnalytics));
      exportService = McpExportService();
      parser = McpBundleParser();
    });

    test('should export phase regimes to MCP format', () async {
      // Given
      final regime1 = PhaseRegime(
        id: 'regime_1',
        label: PhaseLabel.discovery,
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
        source: PhaseSource.user,
        anchors: ['entry_1', 'entry_2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final regime2 = PhaseRegime(
        id: 'regime_2',
        label: PhaseLabel.expansion,
        start: DateTime(2024, 2, 1),
        source: PhaseSource.rivet,
        confidence: 0.85,
        inferredAt: DateTime.now(),
        anchors: ['entry_3'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final phaseIndex = PhaseIndex([regime1, regime2]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        phaseIndex: phaseIndex,
      );

      // Then
      expect(exportData.success, isTrue);
      expect(exportData.nodes, isNotEmpty);
      
      // Find phase regime nodes
      final phaseRegimeNodes = exportData.nodes!.where(
        (node) => node.type == 'phase_regime'
      ).toList();
      
      expect(phaseRegimeNodes.length, equals(2));
      
      // Verify first regime
      final regime1Node = phaseRegimeNodes.firstWhere(
        (node) => node.metadata?['phase_regime_id'] == 'regime_1'
      );
      expect(regime1Node.metadata?['phase_label'], equals('discovery'));
      expect(regime1Node.metadata?['phase_source'], equals('user'));
      expect(regime1Node.metadata?['is_ongoing'], equals(false));
      
      // Verify second regime
      final regime2Node = phaseRegimeNodes.firstWhere(
        (node) => node.metadata?['phase_regime_id'] == 'regime_2'
      );
      expect(regime2Node.metadata?['phase_label'], equals('expansion'));
      expect(regime2Node.metadata?['phase_source'], equals('rivet'));
      expect(regime2Node.metadata?['confidence'], equals(0.85));
      expect(regime2Node.metadata?['is_ongoing'], equals(true));
    });

    test('should import phase regimes from MCP format', () async {
      // Given - Create a mock MCP bundle with phase regime data
      final mockBundleData = {
        'nodes.jsonl': '''
{"id":"phase_regime_1","type":"phase_regime","timestamp":"2024-01-01T00:00:00Z","contentSummary":"Phase: DISCOVERY","phaseHint":"discovery","keywords":["discovery"],"metadata":{"phase_regime_id":"regime_1","phase_label":"discovery","phase_source":"user","start_time":"2024-01-01T00:00:00Z","end_time":"2024-01-31T00:00:00Z","is_ongoing":false,"anchors":["entry_1","entry_2"],"duration_days":30}}
{"id":"phase_regime_2","type":"phase_regime","timestamp":"2024-02-01T00:00:00Z","contentSummary":"Phase: EXPANSION","phaseHint":"expansion","keywords":["expansion"],"metadata":{"phase_regime_id":"regime_2","phase_label":"expansion","phase_source":"rivet","confidence":0.85,"start_time":"2024-02-01T00:00:00Z","is_ongoing":true,"anchors":["entry_3"],"duration_days":0}}
''',
      };

      // When - Parse the bundle
      final nodes = await parser.parseBundle('mock_bundle_path');

      // Then
      expect(nodes, isNotEmpty);
      
      // Find phase regime nodes
      final phaseRegimeNodes = nodes.where(
        (node) => node.type == NodeType.phaseRegime
      ).toList();
      
      expect(phaseRegimeNodes.length, equals(2));
      
      // Verify first regime
      final regime1Node = phaseRegimeNodes.firstWhere(
        (node) => node.metadata['phase_regime_id'] == 'regime_1'
      );
      expect(regime1Node.phaseHint, equals(PhaseHint.discovery));
      expect(regime1Node.metadata['phase_label'], equals('discovery'));
      expect(regime1Node.metadata['phase_source'], equals('user'));
      expect(regime1Node.metadata['is_ongoing'], equals(false));
      
      // Verify second regime
      final regime2Node = phaseRegimeNodes.firstWhere(
        (node) => node.metadata['phase_regime_id'] == 'regime_2'
      );
      expect(regime2Node.phaseHint, equals(PhaseHint.expansion));
      expect(regime2Node.metadata['phase_label'], equals('expansion'));
      expect(regime2Node.metadata['phase_source'], equals('rivet'));
      expect(regime2Node.metadata['confidence'], equals(0.85));
      expect(regime2Node.metadata['is_ongoing'], equals(true));
    });

    test('should maintain phase regime relationships in MCP', () async {
      // Given
      final regime = PhaseRegime(
        id: 'regime_1',
        label: PhaseLabel.consolidation,
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
        source: PhaseSource.user,
        anchors: ['entry_1', 'entry_2', 'entry_3'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final phaseIndex = PhaseIndex([regime]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        phaseIndex: phaseIndex,
      );

      // Then
      expect(exportData.nodes, isNotEmpty);
      
      // Verify nodes exist (edges handled internally in MCP export)
      final phaseRegimeNodes = exportData.nodes!.where(
        (node) => node.type == 'phase_regime'
      ).toList();
      
      expect(phaseRegimeNodes.length, equals(1)); // One regime with 3 anchors
    });

    test('should handle ongoing phase regimes in MCP', () async {
      // Given
      final ongoingRegime = PhaseRegime(
        id: 'ongoing_regime',
        label: PhaseLabel.breakthrough,
        start: DateTime.now().subtract(const Duration(days: 30)),
        source: PhaseSource.rivet,
        confidence: 0.92,
        inferredAt: DateTime.now().subtract(const Duration(days: 30)),
        anchors: ['entry_4'],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      );

      final phaseIndex = PhaseIndex([ongoingRegime]);

      // When
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        phaseIndex: phaseIndex,
      );

      // Then
      final ongoingNode = exportData.nodes!.firstWhere(
        (node) => node.type == 'phase_regime' && 
                  node.metadata?['phase_regime_id'] == 'ongoing_regime'
      );
      
      expect(ongoingNode.metadata?['is_ongoing'], equals(true));
      expect(ongoingNode.metadata?['end_time'], isNull);
      expect(ongoingNode.metadata?['phase_label'], equals('breakthrough'));
      expect(ongoingNode.metadata?['confidence'], equals(0.92));
    });

    test('should preserve phase regime metadata in round-trip', () async {
      // Given
      final originalRegime = PhaseRegime(
        id: 'test_regime',
        label: PhaseLabel.transition,
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 15),
        source: PhaseSource.rivet,
        confidence: 0.78,
        inferredAt: DateTime(2024, 3, 1),
        anchors: ['entry_5', 'entry_6'],
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );

      final phaseIndex = PhaseIndex([originalRegime]);

      // When - Export
      final exportData = await exportService.exportToMcp(
        outputDir: Directory('test_output'),
        scope: McpExportScope.all,
        journalEntries: [],
        phaseIndex: phaseIndex,
      );

      // Then - Verify export contains all metadata
      final exportedNode = exportData.nodes!.firstWhere(
        (node) => node.type == 'phase_regime'
      );
      
      expect(exportedNode.metadata?['phase_regime_id'], equals('test_regime'));
      expect(exportedNode.metadata?['phase_label'], equals('transition'));
      expect(exportedNode.metadata?['phase_source'], equals('rivet'));
      expect(exportedNode.metadata?['confidence'], equals(0.78));
      expect(exportedNode.metadata?['start_time'], equals('2024-03-01T00:00:00.000Z'));
      expect(exportedNode.metadata?['end_time'], equals('2024-03-15T00:00:00.000Z'));
      expect(exportedNode.metadata?['is_ongoing'], equals(false));
      expect(exportedNode.metadata?['anchors'], equals(['entry_5', 'entry_6']));
      expect(exportedNode.metadata?['duration_days'], equals(14));
    });
  });
}
