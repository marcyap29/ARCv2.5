# MIRA Semantic Memory v0.2

**Memory Integration & Recall Architecture** - A comprehensive semantic memory system for EPI with advanced privacy controls, multimodal support, and intelligent retrieval.

## 🚀 Quick Start

```dart
import 'package:my_app/mira/core/schema_v2.dart';
import 'package:my_app/mira/retrieval/retrieval_engine.dart';
import 'package:my_app/mira/policy/policy_engine.dart';

// Initialize the system
final policyEngine = PolicyEngine();
final retrievalEngine = RetrievalEngine(policyEngine: policyEngine);

// Create a memory
final memory = MiraNodeV2.create(
  type: NodeType.entry,
  data: {
    'content': 'I had a breakthrough moment today!',
    'keywords': ['breakthrough', 'work', 'excitement'],
  },
  source: 'ARC',
  operation: 'create',
);

// Retrieve memories
final results = await retrievalEngine.retrieveMemories(
  query: 'breakthrough work',
  domains: [MemoryDomain.personal],
  actor: 'user',
  purpose: Purpose.retrieval,
);
```

## 📋 Table of Contents

- [Architecture](#architecture)
- [Core Features](#core-features)
- [API Reference](#api-reference)
- [Migration Guide](#migration-guide)
- [Examples](#examples)
- [Testing](#testing)
- [Contributing](#contributing)

## 🏗️ Architecture

MIRA v0.2 is built on a foundation of **deterministic IDs**, **provenance tracking**, and **privacy-first design**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Retrieval     │    │   Policy        │    │   VEIL Jobs     │
│   Engine        │◄──►│   Engine        │◄──►│   (Lifecycle)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MIRA Core v0.2                              │
│  • ULID-based IDs  • Provenance  • Soft Delete  • Schema v2   │
└─────────────────────────────────────────────────────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Multimodal    │    │   CRDT Sync     │    │   MCP Bundle    │
│   Pointers      │    │   (Concurrency) │    │   v1.1          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## ✨ Core Features

### 🔍 **Intelligent Retrieval**
- **Composite Scoring**: 45% semantic + 20% recency + 15% phase affinity + 10% domain match + 10% engagement
- **Phase Affinity**: Life-stage aware memory retrieval
- **Hard Negatives**: Query-specific exclusion lists
- **Memory Caps**: Maximum 8 memories per response

### 🔒 **Privacy & Security**
- **Domain Scoping**: Separate memory buckets (personal, work, health, etc.)
- **Privacy Levels**: 5-level classification (public → confidential)
- **PII Protection**: Automatic detection and redaction
- **Consent Logging**: Complete audit trail

### 🔄 **Sync & Concurrency**
- **CRDT-lite Merge**: Last-writer-wins for scalars, set-merge for tags
- **Device Ticks**: Monotonic ordering for conflict resolution
- **Wall-time**: Timestamp-based conflict resolution

### 🎯 **Multimodal Support**
- **Text, Image, Audio**: Unified pointer system
- **Embedding References**: Cross-modal similarity search
- **EXIF Normalization**: Consistent timestamp handling

### 🧹 **Lifecycle Management**
- **VEIL Jobs**: Automated memory hygiene
- **Decay System**: Half-life with phase multipliers
- **Deduplication**: Near-duplicate detection and merging

## 📚 API Reference

### Core Schema

#### `MiraNodeV2`
The enhanced memory node with v0.2 features:

```dart
class MiraNodeV2 {
  final String id;                    // ULID
  final String schemaId;              // Schema identifier
  final NodeType type;                // Node type
  final Provenance provenance;        // Full provenance tracking
  final String? embeddingsVer;        // Embedding model version
  final bool isTombstoned;            // Soft delete support
  // ... additional fields
}
```

#### `Provenance`
Complete audit trail for every object:

```dart
class Provenance {
  final String source;        // Where it originated (ARC, LUMARA, etc.)
  final String agent;         // Which agent created it
  final String operation;     // What operation (create, update, merge)
  final String traceId;       // Distributed tracing ID
  final DateTime timestamp;   // When this was recorded
}
```

### Retrieval Engine

#### Basic Retrieval
```dart
final results = await retrievalEngine.retrieveMemories(
  query: 'personal growth',
  domains: [MemoryDomain.personal, MemoryDomain.learning],
  actor: 'user',
  purpose: Purpose.retrieval,
  currentPhase: 'Discovery',
  limit: 20,
);
```

#### Memory Use Records (MUR)
```dart
final mur = retrievalEngine.createMemoryUseRecord(
  responseId: 'resp_123',
  results: results,
  consideredCount: 50,
  filters: {'domains': ['personal'], 'privacy_max': 'personal'},
);

// MUR provides full attribution
print('Used ${mur.used.length} memories out of ${mur.consideredCount} considered');
for (final used in mur.used) {
  print('${used.id}: ${used.reason} (weight: ${used.weight})');
}
```

### Policy Engine

#### Access Control
```dart
final decision = policyEngine.checkAccess(
  domain: MemoryDomain.health,
  privacyLevel: PrivacyLevel.sensitive,
  actor: 'work_agent',
  purpose: Purpose.sharing,
);

if (decision.allowed) {
  print('Access granted: ${decision.reason}');
} else {
  print('Access denied: ${decision.reason}');
}
```

#### Safe Export
```dart
final safeConfig = policyEngine.getSafeExportConfig(
  domains: [MemoryDomain.personal],
  maxPrivacyLevel: PrivacyLevel.personal,
  userOverride: false,
);
```

### VEIL Jobs

#### Automated Memory Hygiene
```dart
final scheduler = VeilJobScheduler();

// Register jobs
scheduler.registerJob('dedupe_summaries', DedupeSummariesJob(nodes: nodes));
scheduler.registerJob('memory_decay', MemoryDecayJob(nodes: nodes));
scheduler.registerJob('stale_edge_prune', StaleEdgePruneJob(edges: edges));

// Run all scheduled jobs
final results = await scheduler.runScheduledJobs();
for (final result in results) {
  print('${result.jobType}: ${result.itemsModified} items modified');
}
```

### Multimodal Pointers

#### Creating Pointers
```dart
final manager = MultimodalPointerManager();

final pointer = manager.createPointer(
  mediaType: MediaType.image,
  sourceUri: 'ph://photo123',
  mimeType: 'image/jpeg',
  source: 'ARC',
  operation: 'create',
  fileSize: 2048000,
  sha256: 'abc123def456',
  exifData: ExifData(
    creationTime: DateTime(2024, 1, 15, 14, 30),
    cameraMake: 'Apple',
    cameraModel: 'iPhone 15 Pro',
  ),
);
```

#### Adding Embeddings
```dart
final updatedPointer = manager.addEmbedding(
  pointerId: pointer.id,
  model: 'clip-vit-base-patch32',
  modality: 'image',
  values: [0.1, 0.2, 0.3, ...], // 512-dimensional vector
  sourceUri: 'ph://photo123',
);
```

### CRDT Sync

#### Device Sync
```dart
final syncEngine = CrdtSyncEngine(
  deviceId: 'mobile_001',
  deviceType: 'mobile',
  appVersion: '1.0.0',
);

// Create local operation
final operation = syncEngine.createOperation(
  operationType: 'create',
  objectId: 'node_123',
  objectType: 'node',
  data: {'content': 'New memory'},
);

// Merge remote operations
final conflicts = await syncEngine.mergeOperations(remoteOperations);
for (final conflict in conflicts) {
  if (conflict.hasConflict) {
    print('Conflict detected: ${conflict.conflictType}');
  }
}
```

### MCP Bundle v1.1

#### Creating Bundles
```dart
final bundle = McpBundleV2.create(
  owner: 'user123',
  nodes: nodes,
  edges: edges,
  pointers: pointers,
);

// Compute integrity hashes
final withHashes = await bundle.computeHashes();
print('Merkle root: ${withHashes.merkleRoot}');
```

#### Selective Export
```dart
final selectiveBundle = bundle.createSelectiveExport(
  domains: [MemoryDomain.personal, MemoryDomain.creative],
  maxPrivacyLevel: PrivacyLevel.personal,
  redactPII: true,
  userOverride: false,
);
```

## 🔄 Migration Guide

### From v0.1 to v0.2

MIRA v0.2 includes automatic migration from v0.1:

```dart
import 'package:my_app/mira/migration/migration_service.dart';

// Check if migration is needed
if (MigrationService.needsMigration(data)) {
  // Run migration
  final result = await MigrationService.migrateToV2(data);
  
  if (result.success) {
    print('Migration successful: ${result.nodesMigrated} nodes migrated');
  } else {
    print('Migration failed: ${result.errors}');
  }
}
```

### Migration Features
- **Automatic Detection**: Identifies v0.1 data automatically
- **ULID Conversion**: Converts old IDs to ULIDs
- **Provenance Addition**: Adds provenance to all objects
- **Schema Upgrade**: Upgrades to v0.2 schema
- **Backward Compatibility**: Maintains read support for v0.1

## 🧪 Testing

### Golden Tests
MIRA includes comprehensive golden tests to ensure deterministic behavior:

```dart
import 'package:my_app/test/mira/golden_tests.dart';

// Run all golden tests
RetrievalGoldenTests.runTests();
PolicyGoldenTests.runTests();
VeilGoldenTests.runTests();
CrdtSyncGoldenTests.runTests();
MultimodalGoldenTests.runTests();
```

### Metrics Collection
```dart
import 'package:my_app/mira/observability/metrics.dart';

final metrics = MiraMetricsAggregator();

// Record retrieval metrics
metrics.retrieval.recordRetrieval(
  query: 'test query',
  resultCount: 5,
  consideredCount: 20,
  results: results,
  duration: Duration(milliseconds: 150),
);

// Get system health
final health = metrics.getHealthStatus();
print('System status: ${health['status']}');
```

## 📊 Observability

### Metrics Available
- **Retrieval**: Hit rate, response time, score distribution
- **Policy**: Decision counts, deny rates by domain/actor
- **VEIL**: Job execution, items processed/modified
- **Export**: Success rate, bundle size, verification time
- **System**: Memory usage, sync status, error rates

### Health Monitoring
```dart
final health = metrics.getHealthStatus();
// Returns: {status: 'healthy'|'degraded', retrieval_hit_rate: 0.85, ...}
```

## 🔧 Configuration

### Environment Variables
```bash
# MIRA Configuration
MIRA_VERSION=0.2.0
MIRA_DEBUG=true
MIRA_METRICS_ENABLED=true

# Policy Configuration
MIRA_POLICY_STRICT_MODE=true
MIRA_PII_REDACTION_ENABLED=true

# VEIL Configuration
MIRA_VEIL_ENABLED=true
MIRA_VEIL_SCHEDULE=0 2 * * *  # Daily at 2 AM
```

## 🤝 Contributing

### Development Setup
1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run tests: `flutter test`
4. Run golden tests: `flutter test test/mira/golden_tests.dart`

### Code Style
- Follow Dart/Flutter conventions
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure backward compatibility

### Pull Request Process
1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Run full test suite
5. Submit PR with detailed description

## 📄 License

This project is part of the EPI (Enhanced Personal Intelligence) system. See the main project license for details.

## 🆘 Support

For questions, issues, or contributions:
- Create an issue in the repository
- Check the documentation
- Review the golden tests for examples
- Contact the development team

---

**MIRA v0.2** - Building the future of semantic memory, one memory at a time. 🧠✨
