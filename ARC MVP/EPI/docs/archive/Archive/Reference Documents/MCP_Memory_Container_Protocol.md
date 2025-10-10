# Memory Container Protocol (MCP) v1.0

## Overview

The **Memory Container Protocol (MCP)** is EPI's standard for sovereign, portable, and auditable memory storage. MCP ensures that all user memory data is owned by the user, fully exportable, and compatible across different EPI implementations and AI agents.

## Core Principles

### 1. User Sovereignty
- **User-Owned**: All memory data belongs to the user, not the platform
- **Portable**: Complete memory can be exported and imported between systems
- **Controllable**: Users have full control over memory access, sharing, and deletion

### 2. Transparency & Auditability
- **Explainable**: Every memory usage is tracked and attributable
- **Auditable**: Complete history of all memory operations
- **Provenance**: Full tracking of memory creation, modification, and access

### 3. Privacy by Design
- **Encrypted**: Sensitive data encrypted with user-controlled keys
- **Scoped**: Memory organized into privacy-aware domains
- **Consent-Based**: All memory sharing requires explicit user consent

### 4. Developmental Awareness
- **Phase-Aware**: Memory adapts to user's ATLAS life phases
- **Evolving**: Memory naturally decays and reinforces based on relevance
- **Contextual**: Memory retrieval considers user's current developmental context

## MCP Bundle Structure

### Bundle Manifest (`manifest.json`)

```json
{
  "bundle_id": "mcp_user123_2025_09_28_alpha_v1",
  "version": "1.0.0",
  "mcp_version": "1.0",
  "created_at": "2025-09-28T19:00:00Z",
  "updated_at": "2025-09-28T19:00:00Z",
  "owner": "user_123",
  "storage_profile": "balanced",
  "encryption": {
    "enabled": true,
    "algorithm": "AES-256-GCM",
    "key_derivation": "PBKDF2-SHA256"
  },
  "counts": {
    "nodes": 153,
    "edges": 420,
    "pointers": 112,
    "embeddings": 980,
    "attributions": 45,
    "conflicts": 2
  },
  "domains": ["personal", "work", "creative", "learning"],
  "privacy_levels": ["public", "personal", "private"],
  "checksums": {
    "nodes_jsonl": "sha256:9b1c...a7",
    "edges_jsonl": "sha256:8a2d...f3",
    "pointers_jsonl": "sha256:7e4b...c9"
  },
  "schema_version": "mcp_bundle.v1"
}
```

### Memory Nodes (`nodes.jsonl`)

Each line contains a complete memory node:

```json
{
  "id": "entry_2025_09_28_01",
  "type": "journal_entry",
  "schema_version": "enhanced_node.v1",
  "timestamp": "2025-09-28T18:00:00Z",
  "created_at": "2025-09-28T18:00:00Z",
  "updated_at": "2025-09-28T18:00:00Z",
  "domain": "personal",
  "privacy": "personal",
  "phase_context": "Consolidation",
  "narrative": {
    "situation": "Completed MVP milestone.",
    "action": "Pushed new build to TestFlight.",
    "growth": "Learned how to handle MCP bundle exports.",
    "essence": "Progress through structure."
  },
  "content": "Today I reached a major milestone...",
  "keywords": ["MVP", "memory", "milestone", "progress"],
  "emotions": {"satisfaction": 0.7, "fatigue": 0.3},
  "lifecycle": {
    "access_count": 3,
    "reinforcement_score": 1.2,
    "last_accessed": "2025-09-28T20:00:00Z",
    "scheduled_decay": null,
    "is_archived": false
  },
  "provenance": {
    "source": "ARC",
    "device": "iPhone_15_Pro",
    "version": "1.2.0",
    "user_id": "user_123",
    "session_id": "sess_abc123"
  },
  "pii_flags": {
    "contains_pii": false,
    "faces_detected": false,
    "location_data": false,
    "requires_redaction": false
  },
  "pointer_ref": "ptr_text_001",
  "embedding_ref": "emb_v1_t001"
}
```

### Memory Edges (`edges.jsonl`)

Relationships between memory nodes:

```json
{
  "id": "edge_001",
  "source": "entry_2025_09_28_01",
  "target": "theme_resilience",
  "relation": "expresses",
  "weight": 0.8,
  "timestamp": "2025-09-28T18:00:00Z",
  "lifecycle": {
    "reinforcement_score": 1.0,
    "access_count": 1
  },
  "provenance": {
    "source": "MIRA",
    "method": "semantic_analysis"
  },
  "schema_version": "enhanced_edge.v1"
}
```

### Content Pointers (`pointers.jsonl`)

References to actual content (text, images, audio):

```json
{
  "id": "ptr_text_001",
  "type": "text",
  "content_hash": "sha256:abc123...",
  "size_bytes": 1024,
  "mime_type": "text/plain",
  "encoding": "utf-8",
  "storage_location": "local://texts/ptr_text_001.txt",
  "encryption": {
    "encrypted": false,
    "algorithm": null
  },
  "schema_version": "pointer.v1"
}
```

### Embeddings (`embeddings.jsonl`)

Vector embeddings for semantic search:

```json
{
  "id": "emb_v1_t001",
  "ref": "entry_2025_09_28_01",
  "model": "text-embedding-ada-002",
  "vector": [0.1, -0.2, 0.5, ...],
  "dimensions": 1536,
  "created_at": "2025-09-28T18:01:00Z",
  "schema_version": "embedding.v1"
}
```

### Attribution Records (`attributions.jsonl`)

Memory usage tracking for explainable AI:

```json
{
  "response_id": "resp_123",
  "timestamp": "2025-09-28T20:00:00Z",
  "model": "LUMARA Enhanced",
  "traces": [
    {
      "node_ref": "entry_2025_09_28_01",
      "relation": "supports",
      "confidence": 0.9,
      "reasoning": "Directly relates to user's current milestone work"
    }
  ],
  "context": {
    "query": "How am I progressing?",
    "user_id": "user_123",
    "session_id": "sess_abc123",
    "phase": "Consolidation"
  },
  "schema_version": "attribution.v1"
}
```

### Conflict Records (`conflicts.jsonl`)

Memory contradiction tracking:

```json
{
  "id": "conflict_001",
  "node_a": "entry_2025_09_15_01",
  "node_b": "entry_2025_09_28_01",
  "conflict_type": "emotional_contradiction",
  "description": "Conflicting emotions about project success",
  "severity": 0.6,
  "detected": "2025-09-28T18:01:00Z",
  "resolved": null,
  "resolution": null,
  "context": {
    "domain_a": "work",
    "domain_b": "work",
    "phase_context": "Consolidation"
  },
  "schema_version": "conflict.v1"
}
```

## Domain Scoping

### Domain Types

| Domain | Description | Privacy Level | Cross-Domain | Retention |
|--------|-------------|---------------|--------------|-----------|
| `personal` | Private thoughts, emotions | High | Limited | 5 years |
| `work` | Professional activities | Moderate | Allowed | 3 years |
| `health` | Medical, wellness data | Maximum | Restricted | 7 years |
| `creative` | Ideas, inspirations | Low | Encouraged | 10 years |
| `relationships` | Social connections | High | Limited | 5 years |
| `finance` | Financial information | Maximum | Prohibited | 7 years |
| `learning` | Education, skills | Moderate | Encouraged | 10 years |
| `spiritual` | Beliefs, values | High | Limited | 15 years |
| `meta` | System, app-level | Low | Allowed | 2 years |

### Access Control

```json
{
  "domain_policies": {
    "personal": {
      "access_level": "strict",
      "encryption_required": true,
      "cross_domain_synthesis": false,
      "requires_consent": true
    },
    "work": {
      "access_level": "moderate",
      "encryption_required": false,
      "cross_domain_synthesis": true,
      "requires_consent": false
    }
  }
}
```

## Privacy Levels

### Classification System

- **Public**: Shareable with agents and export systems
- **Personal**: User-only but can be processed by EPI
- **Private**: User-only with minimal processing
- **Sensitive**: Encrypted with limited access
- **Confidential**: Maximum protection, user-controlled decryption

### Encryption Standards

```json
{
  "encryption_spec": {
    "algorithm": "AES-256-GCM",
    "key_derivation": "PBKDF2-SHA256",
    "iterations": 100000,
    "salt_length": 32,
    "tag_length": 16
  }
}
```

## Memory Lifecycle

### Decay Functions

Memory naturally decays based on:
- **Age**: Older memories decay faster
- **Access Frequency**: Unused memories decay
- **Reinforcement**: Important memories are strengthened
- **Phase Context**: ATLAS phase affects decay rates

### Phase-Aware Decay Multipliers

```json
{
  "phase_multipliers": {
    "Discovery": 0.5,     // Retain everything
    "Expansion": 0.8,     // Selective retention
    "Transition": 1.5,    // Accelerated pruning
    "Consolidation": 0.6, // Strong retention
    "Recovery": 0.7,      // Gentle retention
    "Breakthrough": 0.9   // Achievement focus
  }
}
```

### VEIL Integration

**Resilience Restoration**: Memories in health, spiritual, and relationship domains have enhanced resilience and can be automatically restored during recovery phases.

**Ethical Decay**: Memory pruning follows ethical guidelines:
- User consent required for permanent deletion
- Staged decay (archive → compress → delete)
- Resilience hooks for important memories
- Recovery options for accidental loss

## Active Memory Windows

### Chat History Integration

MCP integrates with LUMARA's chat system for persistent conversations:

```json
{
  "chat_memory_node": {
    "id": "chat_2025_09_28_001",
    "type": "conversation",
    "domain": "personal",
    "messages": [
      {
        "role": "user",
        "content": "How am I progressing with my goals?",
        "timestamp": "2025-09-28T20:00:00Z"
      },
      {
        "role": "assistant",
        "content": "Based on your recent milestones...",
        "timestamp": "2025-09-28T20:00:15Z",
        "attribution_ref": "attr_123"
      }
    ],
    "session_context": {
      "phase": "Consolidation",
      "mood": "reflective",
      "topics": ["progress", "goals", "milestones"]
    }
  }
}
```

### Context Windows

EPI maintains intelligent context windows that:
- Automatically include relevant memories
- Respect domain boundaries and privacy levels
- Provide attribution for all memory usage
- Adapt to current ATLAS phase
- Support cross-session continuity

## Inter-Agent Memory Federation

### Controlled Sharing

MCP supports controlled memory sharing between EPI agents:

```json
{
  "federation_manifest": {
    "sharing_agent": "aurora_assistant",
    "shared_domains": ["creative", "learning"],
    "privacy_constraints": {
      "max_privacy_level": "personal",
      "requires_user_consent": true,
      "audit_all_access": true
    },
    "access_duration": "PT24H",
    "revocation_policy": "immediate"
  }
}
```

### Memory Namespaces

Different EPI modules maintain separate memory namespaces:

- `arc::` - Journaling and reflection memories
- `atlas::` - Phase detection and life stage memories
- `aurora::` - Rhythm and routine memories
- `mira::` - Cross-module synthesis memories
- `veil::` - Privacy and safety memories
- `prism::` - Media and multimodal memories
- `echo::` - Response generation memories

## Implementation Guidelines

### Bundle Creation

1. **Initialize Manifest**: Create bundle metadata
2. **Collect Nodes**: Gather all memory nodes for export
3. **Generate Edges**: Export relationship data
4. **Create Pointers**: Reference actual content files
5. **Compute Embeddings**: Generate semantic vectors
6. **Record Attribution**: Include memory usage history
7. **Document Conflicts**: Export conflict resolution data
8. **Generate Checksums**: Ensure data integrity
9. **Apply Encryption**: Protect sensitive data
10. **Validate Schema**: Ensure MCP compliance

### Bundle Validation

```bash
# MCP Bundle validation checklist
✓ Manifest schema compliance
✓ All referenced pointers exist
✓ Checksums match content
✓ Privacy levels respected
✓ Domain boundaries enforced
✓ Attribution records complete
✓ Encryption properly applied
✓ SAGE structure preserved
✓ Provenance chain intact
✓ User consent documented
```

### Import/Export APIs

```dart
// Export user's complete memory
final bundle = await mcp.exportMemoryBundle(
  userId: 'user_123',
  domains: [MemoryDomain.personal, MemoryDomain.creative],
  includePrivate: true,
  format: 'mcp_v1',
);

// Import memory bundle
await mcp.importMemoryBundle(
  bundle: bundle,
  mergeStrategy: MergeStrategy.preserveExisting,
  conflictResolution: ConflictResolution.userChoice,
);
```

## Security Considerations

### Encryption at Rest
- All sensitive memory encrypted with user-derived keys
- Key derivation using PBKDF2-SHA256 with high iteration count
- Separate encryption keys per privacy level
- Forward secrecy for key rotation

### Access Controls
- Role-based access to memory domains
- Temporal access tokens for limited sharing
- Audit logging for all memory operations
- User consent tracking for cross-domain access

### Data Integrity
- Cryptographic checksums for all content
- Immutable audit logs using append-only storage
- Digital signatures for memory provenance
- Tamper detection for bundle validation

## Compliance & Standards

### Data Protection
- **GDPR**: Full user control and right to deletion
- **CCPA**: Complete data transparency and export
- **HIPAA**: Special handling for health domain memories
- **COPPA**: Age-appropriate memory handling for minors

### Technical Standards
- **JSON Schema**: Strict validation for all MCP data
- **RFC 7519**: JWT tokens for access control
- **RFC 8259**: Standard JSON formatting
- **ISO 8601**: Standard timestamp formatting

## Future Extensions

### Planned Features
- **Multi-Device Sync**: Secure synchronization across devices
- **Collaborative Memory**: Shared memory spaces with explicit consent
- **Memory Inheritance**: Transfer memories to trusted parties
- **Quantum-Safe Encryption**: Post-quantum cryptographic algorithms
- **Biometric Memory Locks**: Additional security for sensitive domains

### Research Directions
- **Homomorphic Encryption**: Computation on encrypted memories
- **Zero-Knowledge Proofs**: Memory validation without disclosure
- **Differential Privacy**: Mathematical privacy guarantees
- **Federated Learning**: Privacy-preserving memory insights

This MCP specification ensures that EPI users maintain complete sovereignty over their memory data while enabling powerful, transparent, and ethical AI interactions. Every memory operation is auditable, every privacy boundary is respected, and every user maintains full control over their digital narrative.