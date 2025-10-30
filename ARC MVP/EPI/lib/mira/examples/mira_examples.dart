// lib/mira/examples/mira_examples.dart
// MIRA v0.2 Code Examples and Usage Patterns
// Comprehensive examples for all major features

import '../core/schema_v2.dart';
import '../retrieval/retrieval_engine.dart';
import '../policy/policy_engine.dart';
import '../veil/veil_jobs.dart';
import '../sync/crdt_sync.dart';
import '../multimodal/multimodal_pointers.dart';
import '../migration/migration_service.dart';
import '../observability/metrics.dart';
import 'package:my_app/lumara/chat/ulid.dart';

/// Example: Basic Memory Creation and Retrieval
class BasicMemoryExample {
  static Future<void> runExample() async {
    print('=== Basic Memory Example ===');
    
    // Initialize components
    final policyEngine = PolicyEngine();
    // final retrievalEngine = RetrievalEngine(policyEngine: policyEngine);
    
    // Create a memory node
    final memory = MiraNodeV2.create(
      type: NodeType.entry,
      data: {
        'content': 'I had an amazing breakthrough in my project today. The solution came to me while I was taking a walk.',
        'keywords': ['breakthrough', 'project', 'solution', 'walk', 'creativity'],
        'emotions': ['excitement', 'satisfaction', 'relief'],
        'phase_context': 'Discovery',
        'domain': 'work',
        'privacy': 'personal',
      },
      source: 'ARC',
      operation: 'create',
      traceId: 'trace_001',
    );
    
    print('Created memory: ${memory.id}');
    print('Content: ${memory.narrative}');
    print('Keywords: ${memory.keywords}');
    print('Provenance: ${memory.provenance.source} - ${memory.provenance.operation}');
    
    // Create related keyword nodes
    final keywordNode = MiraNodeV2.create(
      type: NodeType.keyword,
      data: {
        'text': 'breakthrough',
        'frequency': 1,
        'confidence': 0.9,
        'context': 'work',
      },
      source: 'ARC',
      operation: 'create',
    );
    
    // Create emotion node
    final emotionNode = MiraNodeV2.create(
      type: NodeType.emotion,
      data: {
        'text': 'excitement',
        'intensity': 0.8,
        'context': 'work',
        'trigger': 'breakthrough',
      },
      source: 'ARC',
      operation: 'create',
    );
    
    // Create edges connecting the nodes
    final mentionEdge = MiraEdgeV2.create(
      src: memory.id,
      dst: keywordNode.id,
      label: EdgeType.mentions,
      data: {'weight': 0.9, 'context': 'work'},
      source: 'ARC',
      operation: 'create',
    );
    
    final emotionEdge = MiraEdgeV2.create(
      src: memory.id,
      dst: emotionNode.id,
      label: EdgeType.expresses,
      data: {'intensity': 0.8, 'context': 'breakthrough'},
      source: 'ARC',
      operation: 'create',
    );
    
    print('Created ${keywordNode.type} node: ${keywordNode.id}');
    print('Created ${emotionNode.type} node: ${emotionNode.id}');
    print('Created edges: ${mentionEdge.id}, ${emotionEdge.id}');
  }
}

/// Example: Advanced Retrieval with Scoring
class RetrievalExample {
  static Future<void> runExample() async {
    print('=== Retrieval Example ===');
    
    final policyEngine = PolicyEngine();
    // final retrievalEngine = RetrievalEngine(policyEngine: policyEngine);
    
    // Simulate retrieval (in real implementation, this would query the repository)
    final query = 'breakthrough work creativity';
    final domains = [MemoryDomain.personal, MemoryDomain.work];
    final actor = 'user';
    final purpose = Purpose.retrieval;
    
    print('Query: "$query"');
    print('Domains: ${domains.map((d) => d.name).join(', ')}');
    print('Actor: $actor');
    print('Purpose: ${purpose.name}');
    
    // In a real implementation, this would return actual results
    print('Retrieval would return memories with composite scoring:');
    print('- 45% semantic similarity');
    print('- 20% recency');
    print('- 15% phase affinity');
    print('- 10% domain match');
    print('- 10% engagement');
    print('- Maximum 8 memories per response');
  }
}

/// Example: Policy Engine Usage
class PolicyExample {
  static Future<void> runExample() async {
    print('=== Policy Example ===');
    
    final policyEngine = PolicyEngine();
    
    // Test different access scenarios
    final scenarios = [
      {
        'name': 'Personal memory access by user',
        'domain': MemoryDomain.personal,
        'privacy': PrivacyLevel.personal,
        'actor': 'user',
        'purpose': Purpose.retrieval,
      },
      {
        'name': 'Work memory sharing with work agent',
        'domain': MemoryDomain.work,
        'privacy': PrivacyLevel.public,
        'actor': 'work_agent',
        'purpose': Purpose.sharing,
      },
      {
        'name': 'Health data access by work agent',
        'domain': MemoryDomain.health,
        'privacy': PrivacyLevel.sensitive,
        'actor': 'work_agent',
        'purpose': Purpose.analysis,
      },
      {
        'name': 'Creative content export',
        'domain': MemoryDomain.creative,
        'privacy': PrivacyLevel.personal,
        'actor': 'user',
        'purpose': Purpose.export,
      },
    ];
    
    for (final scenario in scenarios) {
      final decision = policyEngine.checkAccess(
        domain: scenario['domain'] as MemoryDomain,
        privacyLevel: scenario['privacy'] as PrivacyLevel,
        actor: scenario['actor'] as String,
        purpose: scenario['purpose'] as Purpose,
      );
      
      print('${scenario['name']}: ${decision.allowed ? 'ALLOWED' : 'DENIED'}');
      print('  Reason: ${decision.reason}');
      if (decision.conditions.isNotEmpty) {
        print('  Conditions: ${decision.conditions.join(', ')}');
      }
      print('');
    }
    
    // Test PII redaction
    final shouldRedact = policyEngine.shouldRedactPII(
      privacyLevel: PrivacyLevel.sensitive,
      hasPII: true,
      userOverride: false,
    );
    print('Should redact PII for sensitive data: $shouldRedact');
  }
}

/// Example: VEIL Jobs and Memory Lifecycle
class VeilJobsExample {
  static Future<void> runExample() async {
    print('=== VEIL Jobs Example ===');
    
    // Create sample data
    final nodes = [
      MiraNodeV2.create(
        type: NodeType.summary,
        data: {'content': 'Great day at work, made progress on project'},
        source: 'ARC',
        operation: 'create',
      ),
      MiraNodeV2.create(
        type: NodeType.summary,
        data: {'content': 'Great day at work, made progress on project'}, // Duplicate
        source: 'ARC',
        operation: 'create',
      ),
      MiraNodeV2.create(
        type: NodeType.summary,
        data: {'content': 'Different content about something else'},
        source: 'ARC',
        operation: 'create',
      ),
    ];
    
    final edges = [
      MiraEdgeV2.create(
        src: 'node1',
        dst: 'node2',
        label: EdgeType.mentions,
        data: {'weight': 0.01}, // Below threshold
        source: 'ARC',
        operation: 'create',
      ),
      MiraEdgeV2.create(
        src: 'node3',
        dst: 'node4',
        label: EdgeType.mentions,
        data: {'weight': 0.8}, // Above threshold
        source: 'ARC',
        operation: 'create',
      ),
    ];
    
    // Initialize scheduler
    final scheduler = VeilJobScheduler();
    
    // Register jobs
    scheduler.registerJob('dedupe_summaries', DedupeSummariesJob(nodes: nodes));
    scheduler.registerJob('stale_edge_prune', StaleEdgePruneJob(edges: edges));
    scheduler.registerJob('memory_decay', MemoryDecayJob(nodes: nodes, decayConfig: DecayConfig.defaultConfig()));
    
    print('Registered VEIL jobs:');
    print('- dedupe_summaries: Remove duplicate summaries');
    print('- stale_edge_prune: Remove low-weight edges');
    print('- memory_decay: Apply decay to old memories');
    
    // Run jobs
    final results = await scheduler.runScheduledJobs();
    
    for (final result in results) {
      print('${result.jobType}:');
      print('  Success: ${result.success}');
      print('  Items processed: ${result.itemsProcessed}');
      print('  Items modified: ${result.itemsModified}');
      if (result.errors.isNotEmpty) {
        print('  Errors: ${result.errors.join(', ')}');
      }
      print('');
    }
  }
}

/// Example: CRDT Sync and Concurrency
class SyncExample {
  static Future<void> runExample() async {
    print('=== CRDT Sync Example ===');
    
    // Initialize sync engines for two devices
    final device1 = CrdtSyncEngine(
      deviceId: 'mobile_001',
      deviceType: 'mobile',
      appVersion: '1.0.0',
    );
    
    final device2 = CrdtSyncEngine(
      deviceId: 'desktop_002',
      deviceType: 'desktop',
      appVersion: '1.0.0',
    );
    
    // Device 1 creates an operation
    final operation1 = device1.createOperation(
      operationType: 'create',
      objectId: 'node_123',
      objectType: 'node',
      data: {
        'content': 'Original content from mobile',
        'device_id': 'mobile_001',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
    
    print('Device 1 created operation: ${operation1.id}');
    print('Object: ${operation1.objectId}');
    print('Data: ${operation1.data}');
    
    // Device 2 creates a conflicting operation
    final operation2 = device2.createOperation(
      operationType: 'update',
      objectId: 'node_123',
      objectType: 'node',
      data: {
        'content': 'Updated content from desktop',
        'device_id': 'desktop_002',
        'timestamp': DateTime.now().add(Duration(minutes: 1)).toUtc().toIso8601String(),
      },
    );
    
    print('Device 2 created operation: ${operation2.id}');
    print('Object: ${operation2.objectId}');
    print('Data: ${operation2.data}');
    
    // Simulate sync
    final conflicts = await device1.mergeOperations([operation2]);
    
    print('Sync conflicts: ${conflicts.length}');
    for (final conflict in conflicts) {
      if (conflict.hasConflict) {
        print('Conflict detected: ${conflict.conflictType}');
        print('Resolution: ${conflict.resolutionStrategy}');
      } else {
        print('No conflict, operation applied');
      }
    }
    
    // Test set merging
    final localData = {'tags': ['work', 'important'], 'keywords': ['project', 'deadline']};
    final remoteData = {'tags': ['work', 'urgent'], 'keywords': ['project', 'meeting']};
    
    final mergedTags = device1.mergeTags(localData, remoteData);
    print('Merged tags: ${mergedTags['tags']}');
    print('Merged keywords: ${mergedTags['keywords']}');
  }
}

/// Example: Multimodal Pointers
class MultimodalExample {
  static Future<void> runExample() async {
    print('=== Multimodal Pointers Example ===');
    
    final manager = MultimodalPointerManager();
    
    // Create text pointer
    final textPointer = manager.createPointer(
      mediaType: MediaType.text,
      sourceUri: 'file:///documents/notes.txt',
      mimeType: 'text/plain',
      source: 'ARC',
      operation: 'create',
      fileSize: 1024,
      sha256: 'abc123def456',
    );
    
    print('Created text pointer: ${textPointer.id}');
    print('Source: ${textPointer.sourceUri}');
    print('Size: ${textPointer.fileSize} bytes');
    print('SHA-256: ${textPointer.sha256}');
    
    // Create image pointer with EXIF data
    final imagePointer = manager.createPointer(
      mediaType: MediaType.image,
      sourceUri: 'ph://photo123',
      mimeType: 'image/jpeg',
      source: 'ARC',
      operation: 'create',
      fileSize: 2048000,
      sha256: 'def456ghi789',
      exifData: ExifData(
        creationTime: DateTime(2024, 1, 15, 14, 30),
        cameraMake: 'Apple',
        cameraModel: 'iPhone 15 Pro',
        width: 4032,
        height: 3024,
        gpsCoordinates: {'latitude': 37.7749, 'longitude': -122.4194},
      ),
    );
    
    print('Created image pointer: ${imagePointer.id}');
    print('Source: ${imagePointer.sourceUri}');
    print('Camera: ${imagePointer.exifData?.cameraMake} ${imagePointer.exifData?.cameraModel}');
    print('Dimensions: ${imagePointer.exifData?.width}x${imagePointer.exifData?.height}');
    print('GPS: ${imagePointer.exifData?.gpsCoordinates}');
    print('Normalized creation time: ${imagePointer.normalizedCreationTime}');
    
    // Add embeddings
    final textEmbedding = manager.addEmbedding(
      pointerId: textPointer.id,
      model: 'text-embedding-ada-002',
      modality: 'text',
      values: List.generate(512, (i) => (i * 0.001) % 1.0), // Mock embedding
      sourceUri: 'file:///documents/notes.txt',
    );
    
    final imageEmbedding = manager.addEmbedding(
      pointerId: imagePointer.id,
      model: 'clip-vit-base-patch32',
      modality: 'image',
      values: List.generate(512, (i) => (i * 0.002) % 1.0), // Mock embedding
      sourceUri: 'ph://photo123',
    );
    
    print('Added text embedding: ${textEmbedding.id}');
    print('Added image embedding: ${imageEmbedding.id}');
    
    // Get statistics
    final stats = manager.getStatistics();
    print('Manager statistics:');
    print('Total pointers: ${stats['total_pointers']}');
    print('Active pointers: ${stats['active_pointers']}');
    print('Embeddings by modality: ${stats['embeddings_by_modality']}');
  }
}

/// Example: Migration from v0.1 to v0.2
class MigrationExample {
  static Future<void> runExample() async {
    print('=== Migration Example ===');
    
    // Simulate v0.1 data
    final v1Data = {
      'schema_version': 1,
      'nodes': [
        {
          'id': 'node_001',
          'type': 0, // NodeType.entry
          'schemaVersion': 1,
          'data': {
            'content': 'Old memory from v0.1',
            'keywords': ['old', 'memory'],
          },
          'createdAt': '2024-01-01T10:00:00Z',
          'updatedAt': '2024-01-01T10:00:00Z',
        },
      ],
      'edges': [
        {
          'id': 'edge_001',
          'src': 'node_001',
          'dst': 'keyword_001',
          'label': 0, // EdgeType.mentions
          'schemaVersion': 1,
          'data': {'weight': 0.8},
          'createdAt': '2024-01-01T10:00:00Z',
        },
      ],
    };
    
    print('Original v0.1 data:');
    print('Schema version: ${v1Data['schema_version']}');
    print('Nodes: ${(v1Data['nodes'] as List).length}');
    print('Edges: ${(v1Data['edges'] as List).length}');
    
    // Check if migration is needed
    final needsMigration = MigrationService.needsMigration(v1Data);
    print('Needs migration: $needsMigration');
    
    if (needsMigration) {
      // Run migration
      final result = await MigrationService.migrateToV2(v1Data);
      
      print('Migration result:');
      print('Success: ${result.success}');
      print('Nodes migrated: ${result.nodesMigrated}');
      print('Edges migrated: ${result.edgesMigrated}');
      print('Pointers migrated: ${result.pointersMigrated}');
      
      if (result.errors.isNotEmpty) {
        print('Errors: ${result.errors.join(', ')}');
      }
      
      // Validate migrated data
      final isValid = MigrationService.validateMigratedData(result.report['migrated_data']);
      print('Migrated data is valid: $isValid');
      
      // Show migrated node structure
      final migratedNodes = result.report['migrated_data']['nodes'] as List;
      if (migratedNodes.isNotEmpty) {
        final migratedNode = migratedNodes.first as Map<String, dynamic>;
        print('Migrated node structure:');
        print('ID: ${migratedNode['id']} (ULID: ${ULID.isValid(migratedNode['id'])})');
        print('Schema ID: ${migratedNode['schema_id']}');
        print('Has provenance: ${migratedNode.containsKey('provenance')}');
        print('Is tombstoned: ${migratedNode['is_tombstoned']}');
      }
    }
  }
}

/// Example: Metrics and Observability
class MetricsExample {
  static Future<void> runExample() async {
    print('=== Metrics Example ===');
    
    final metrics = MiraMetricsAggregator();
    
    // Simulate retrieval metrics
    metrics.retrieval.recordRetrieval(
      query: 'breakthrough work',
      resultCount: 5,
      consideredCount: 20,
      results: [], // Mock results
      duration: Duration(milliseconds: 150),
    );
    
    // Simulate policy metrics
    metrics.policy.recordPolicyDecision(
      decision: PolicyDecision(
        allowed: true,
        reason: 'Policy rule allows access',
      ),
      domain: 'personal',
      privacyLevel: 'personal',
      actor: 'user',
      purpose: 'retrieval',
    );
    
    // Simulate VEIL job metrics
    final veilResult = VeilJobResult(
      jobId: 'job_001',
      jobType: 'dedupe_summaries',
      success: true,
      itemsProcessed: 100,
      itemsModified: 5,
      errors: [],
      metrics: {},
      timestamp: DateTime.now(),
    );
    metrics.veil.recordJobExecution(veilResult);
    
    // Simulate system health metrics
    metrics.health.recordMemoryUsage(
      nodeCount: 1000,
      edgeCount: 2000,
      pointerCount: 500,
      tombstonedCount: 50,
    );
    
    // Get all metrics
    final allMetrics = metrics.getAllMetrics();
    print('All metrics collected:');
    print('Retrieval operations: ${allMetrics['retrieval']['counters']['retrieval_operations']}');
    print('Policy decisions: ${allMetrics['policy']['counters']['policy_decisions']}');
    print('VEIL jobs executed: ${allMetrics['veil']['counters']['veil_jobs_executed']}');
    print('Memory nodes: ${allMetrics['system']['gauges']['memory_nodes_total']}');
    
    // Get health status
    final health = metrics.getHealthStatus();
    print('System health:');
    print('Status: ${health['status']}');
    print('Retrieval hit rate: ${health['retrieval_hit_rate']}');
    print('Policy deny rate: ${health['policy_deny_rate']}');
    print('Error rate: ${health['error_rate']}');
  }
}

/// Main example runner
void main() async {
  print('MIRA v0.2 Examples\n');
  
  await BasicMemoryExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await RetrievalExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await PolicyExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await VeilJobsExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await SyncExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await MultimodalExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await MigrationExample.runExample();
  print('\n' + '='*50 + '\n');
  
  await MetricsExample.runExample();
  
  print('\nAll examples completed! 🎉');
}
