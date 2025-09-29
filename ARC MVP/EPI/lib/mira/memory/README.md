# EPI MIRA Memory Improvements

## Overview

This directory contains the enhanced MIRA memory system implementing true **narrative infrastructure** for the Evolving Personal Intelligence (EPI) framework. Unlike traditional AI memory systems, EPI's memory is designed to be sovereign, explainable, phase-aware, and dignity-preserving.

## Architecture

### Core Principles

**MIRA** (Memory Integration & Recall Architecture) handles:
- **Semantic Memory Graph**: Nodes, edges, and relationships
- **Phase-Aware Recall**: Memory adapts to ATLAS phases
- **Identity Anchoring**: Narrative continuity across time
- **Multimodal Integration**: Text, images, audio, sensor data

**MCP** (Memory Container Protocol) handles:
- **Portable JSON Bundles**: User-sovereign data format
- **Schema Validation**: Guarantees auditability and provenance
- **Cross-Agent Federation**: Controlled memory sharing
- **Privacy by Design**: Encryption and access controls

## Key Features

### 1. Attribution & Explainability (`attribution_service.dart`)

Every AI response includes transparent memory usage tracking:

```dart
// Response trace showing which memories were used
{
  "response_trace": [
    {"node_ref": "entry_2025_09_28_01", "relation": "supports", "confidence": 0.9},
    {"node_ref": "entry_2025_09_20_03", "relation": "contradicts", "confidence": 0.7}
  ]
}
```

**Features:**
- Real-time attribution tracking
- Human-readable citation generation
- Memory usage transparency scoring
- Explainable AI responses with provenance

### 2. Scoped Memory Domains (`domain_scoping_service.dart`)

Separate "memory buckets" with controlled cross-domain synthesis:

```dart
enum MemoryDomain {
  personal,     // High privacy, limited sharing
  work,         // Moderate privacy, professional context
  health,       // Maximum privacy, HIPAA-like protection
  creative,     // Open sharing, inspiration focus
  relationships,// High privacy, emotional significance
  finance,      // Maximum security, regulatory compliance
  learning,     // Knowledge building, cross-references
  spiritual,    // Personal, respectful handling
  meta,         // System-level, moderate access
}
```

**Features:**
- Domain access policies with privacy levels
- Cross-domain synthesis with user consent
- Isolation rules for sensitive domains
- Audit trails for all domain interactions

### 3. Lifecycle & Decay Management (`lifecycle_management_service.dart`)

Natural memory evolution with VEIL integration:

```dart
// ATLAS phase-aware decay multipliers
_phaseDecayMultipliers = {
  'Discovery': 0.5,      // 50% slower decay (retain everything)
  'Expansion': 0.8,      // 20% slower decay (growth focus)
  'Transition': 1.5,     // 50% faster decay (change focus)
  'Consolidation': 0.6,  // 40% slower decay (integration)
  'Recovery': 0.7,       // 30% slower decay (healing)
  'Breakthrough': 0.9,   // 10% slower decay (achievement)
};
```

**Features:**
- Phase-aware decay strategies
- Reinforcement through usage and relevance
- VEIL hooks for resilience restoration
- Automatic pruning with user consent
- Spaced repetition for learning memories

### 4. Conflict Resolution (`conflict_resolution_service.dart`)

Dignified handling of memory contradictions:

```dart
// Dignified resolution prompt example
"I want to honor the complexity of your experience. I've noticed two
reflections that seem to hold different truths:

Earlier reflection: 'I felt confident about the decision...'
Recent reflection: 'I'm having doubts about that choice...'

Both hold meaning in your story. Would you like to help me understand
how these perspectives relate to each other?"
```

**Features:**
- Semantic contradiction detection
- Temporal inconsistency resolution
- Emotional evolution acknowledgment
- Value system integration
- User-dignified resolution prompts

### 5. Enhanced Schema (`enhanced_memory_schema.dart`)

MCP-compliant data models with EPI features:

```dart
class EnhancedMiraNode extends MiraNode {
  final MemoryDomain domain;           // Scoped access control
  final PrivacyLevel privacy;          // Privacy classification
  final String? phaseContext;          // ATLAS phase when created
  final SAGEStructure? sage;           // Situation, Action, Growth, Essence
  final LifecycleMetadata lifecycle;   // Decay and reinforcement
  final ProvenanceData provenance;     // Sovereignty and auditability
  final PIIFlags piiFlags;             // Privacy protection
}
```

**Features:**
- SAGE narrative structure (Situation, Action, Growth, Essence)
- Comprehensive provenance tracking
- PII detection and protection flags
- Phase-aware context preservation
- Lifecycle metadata for decay management

### 6. Integrated Service (`enhanced_mira_memory_service.dart`)

Comprehensive memory service orchestrating all features:

```dart
// Store memory with full EPI features
await memoryService.storeMemory(
  content: "Today I realized...",
  domain: MemoryDomain.personal,
  privacy: PrivacyLevel.personal,
  sage: SAGEStructure(
    situation: "Reflecting on recent challenges",
    action: "Decided to change my approach",
    growth: "Learned about my resilience",
    essence: "Growth comes through adaptation"
  ),
);

// Retrieve with attribution
final result = await memoryService.retrieveMemories(
  query: "resilience and growth",
  domains: [MemoryDomain.personal, MemoryDomain.learning],
  responseId: "resp_123", // For attribution tracking
);
```

**Features:**
- Unified API for all memory operations
- Automatic conflict detection and resolution
- MCP-compliant bundle generation
- Comprehensive audit trails
- User sovereignty controls

## Implementation Integration

### With Existing LUMARA System

```dart
// In LumaraAssistantCubit
final memoryResult = await _enhancedMemoryService.retrieveMemories(
  query: userMessage,
  domains: [MemoryDomain.personal, MemoryDomain.creative],
  responseId: responseId,
);

// Generate response with full attribution
final explainableResponse = await _enhancedMemoryService.generateExplainableResponse(
  content: aiResponse,
  referencedNodes: memoryResult.nodes,
  responseId: responseId,
  includeReasoningDetails: true,
);
```

### With ARC Journaling

```dart
// When user creates journal entry
await _enhancedMemoryService.storeMemory(
  content: journalEntry.content,
  domain: MemoryDomain.personal,
  sage: SAGEStructure.fromJournalEntry(journalEntry),
  phaseContext: currentAtlasPhase,
  keywords: extractedKeywords,
  emotions: extractedEmotions,
);
```

### With ATLAS Phase Detection

```dart
// Phase change triggers memory lifecycle updates
await _enhancedMemoryService.handlePhaseTransition(
  fromPhase: previousPhase,
  toPhase: newPhase,
  triggerDate: DateTime.now(),
);
```

## User Experience

### Memory Dashboard

Users can view comprehensive memory insights:
- Domain distribution and privacy levels
- Memory health and decay scores
- Active conflicts requiring resolution
- Attribution transparency scores
- Recent memory activity

### Memory Commands

Enhanced memory commands for user control:
- `/memory show` - View memory status and open loops
- `/memory conflicts` - Review and resolve memory conflicts
- `/memory domains` - Manage domain access policies
- `/memory export` - Export user's complete memory data
- `/memory health` - Check memory system health

### Conflict Resolution Flow

When conflicts are detected:
1. **Dignified Notification**: Respectful presentation of the conflict
2. **Context Provision**: Show both memories with timestamps and context
3. **Resolution Options**: Multiple approaches (keep both, merge, contextualize)
4. **User Explanation**: Option for user to provide their perspective
5. **Learning Integration**: System learns from resolution patterns

## Competitive Differentiation

### vs. ChatGPT/OpenAI
- **EPI**: User-sovereign memory bundles, fully exportable
- **OpenAI**: Platform-locked conversation history

### vs. Claude/Anthropic
- **EPI**: Explainable memory usage with attribution traces
- **Anthropic**: Black-box context window management

### vs. Gemini/Google
- **EPI**: Phase-aware memory that adapts to personal growth
- **Google**: Static context without developmental awareness

### vs. Meta AI
- **EPI**: Dignity-preserving conflict resolution
- **Meta**: Algorithmic contradiction handling

### vs. Microsoft Copilot
- **EPI**: Domain-scoped memory with privacy controls
- **Microsoft**: Enterprise focus without personal sovereignty

### vs. xAI/Grok
- **EPI**: VEIL-integrated lifecycle with ethical decay
- **xAI**: Performance-focused without ethical considerations

## Technical Standards

### MCP Compliance
- JSON Schema validation for all memory structures
- Append-only operation logs for auditability
- Portable bundle format for data sovereignty
- Privacy flags and encryption support

### ATLAS Integration
- Phase-aware memory reinforcement and decay
- Transition-triggered memory lifecycle events
- Growth-aligned memory consolidation

### VEIL Integration
- Ethical decay with resilience restoration
- User consent for memory pruning
- Dignity-preserving memory handling

### SAGE Framework
- Structured narrative capture (Situation, Action, Growth, Essence)
- Wisdom extraction from life experiences
- Continuous meaning-making support

## Future Enhancements

### Planned Features
- **Visual Memory Mapping**: Interactive memory network visualization
- **Dream Team Federation**: Controlled memory sharing between AI agents
- **Temporal Pattern Recognition**: Advanced lifecycle pattern detection
- **Multi-Modal Memory**: Image, audio, and sensor data integration
- **Collaborative Memory**: Shared memory spaces with consent management

### Research Directions
- **Neuroplasticity-Inspired Decay**: Biological memory models
- **Quantum Memory States**: Superposition of conflicting memories
- **Federated Learning**: Privacy-preserving memory sharing
- **Semantic Memory Compression**: Efficient long-term storage

## Getting Started

### Installation
```dart
// Add to your EPI module
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';

// Initialize the service
final memoryService = EnhancedMiraMemoryService(
  miraService: MiraService.instance,
);

await memoryService.initialize(
  userId: currentUserId,
  sessionId: currentSessionId,
  currentPhase: currentAtlasPhase,
);
```

### Basic Usage
```dart
// Store a memory
final nodeId = await memoryService.storeMemory(
  content: "Your journal entry or conversation",
  domain: MemoryDomain.personal,
  privacy: PrivacyLevel.personal,
);

// Retrieve memories
final memories = await memoryService.retrieveMemories(
  query: "search terms",
  domains: [MemoryDomain.personal],
  responseId: "response_id_for_attribution",
);

// Handle conflicts
final conflicts = await memoryService.getActiveConflicts();
if (conflicts.isNotEmpty) {
  final flow = await memoryService.handleMemoryConflict(
    conflictId: conflicts.first.id,
  );
  // Present flow.resolutionPrompt to user
}
```

This enhanced MIRA memory system transforms EPI from a simple journaling app into a true **narrative intelligence platform** that grows with the user while maintaining full sovereignty and transparency.