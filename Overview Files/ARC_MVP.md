# ARC MVP - Implementation Guide

## Overview
ARC is the first module of EPI (Evolving Personal Intelligence), a journaling app that treats reflection as a sacred act. The core differentiation is that each journal entry generates a visual Arcform — a glowing, constellation-like structure that evolves with the user's story.

## Current Issues & Solutions

### 1. White Screen on App Boot
**Problem**: App hangs during startup, showing white screen.

**Root Cause**: Box name mismatch between bootstrap and startup logic.

**Solution**: 
- Bootstrap uses `Boxes.userProfile` constant
- Startup view tries to open `'userProfile'` string
- Fix: Use consistent box names throughout

**Files to Update**:
- `lib/features/startup/startup_view.dart` - Change `'userProfile'` to `'user_profile'`
- `lib/features/onboarding/onboarding_cubit.dart` - Change `'userProfile'` to `'user_profile'`

### 2. App Freezes After Onboarding
**Problem**: App completes onboarding but never proceeds to Arcform creation.

**Root Cause**: Multiple issues in HomeView:
- Duplicate `initState()` method
- Missing HomeCubit provider
- Incorrect context reading

**Solution**: Fix HomeView structure and state management.

## Core ARC MVP Data Pipeline

### Journal Entry → Keywords → Arcform Snapshot

```
Journal Entry (text + mood) 
    ↓
Keyword Extraction (5-10 meaningful words)
    ↓
Arcform Snapshot (geometry + visualization)
    ↓
Timeline View (chronological display)
```

### Data Models

#### JournalEntry
```dart
{
  "id": "uuid",
  "title": "Generated from content",
  "content": "User's journal text",
  "createdAt": "timestamp",
  "mood": "calm|hopeful|stressed|tired|grateful",
  "keywords": ["word1", "word2", "word3"],
  "sageAnnotation": {
    "situation": "AI-generated analysis",
    "action": "What user did",
    "growth": "Personal development",
    "essence": "Core meaning"
  }
}
```

#### ArcformSnapshot
```dart
{
  "id": "uuid",
  "entryId": "journal_entry_id",
  "keywords": ["word1", "word2", "word3"],
  "geometry": "spiral|flower|branch|weave|glowCore|fractal",
  "colorMap": {"word1": "#hex", "word2": "#hex"},
  "edges": [[0,1,0.8], [1,2,0.8]],
  "phaseHint": "Discovery|Integration|Transcendence",
  "createdAt": "timestamp"
}
```

## Implementation Steps

### Step 1: Fix Startup Issues
1. **Update box names** in startup and onboarding files
2. **Fix HomeView** duplicate initState and missing provider
3. **Test app boot** and navigation flow

### Step 2: Implement ARC MVP Core
1. **Create ArcformService** for data pipeline management
2. **Update JournalCaptureCubit** to create Arcforms after save
3. **Enhance ArcformRenderer** to display real data
4. **Connect Timeline** to show Arcform snapshots

### Step 3: Add Missing Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  uuid: ^4.0.0
  permission_handler: ^11.0.1
  path_provider: ^2.1.1
  audioplayers: ^5.2.1
  logger: ^2.0.2+1
  sentry_flutter: ^7.10.1
```

## Key Components

### 1. ArcformService
- **Purpose**: Core service for creating and managing Arcforms
- **Responsibilities**: 
  - Generate geometry patterns from content/keywords
  - Create color mappings
  - Generate edge connections
  - Determine ATLAS phase hints
  - Save/load snapshots

### 2. Keyword Extraction
- **Current**: Basic word filtering (3+ chars, exclude common words)
- **Future**: AI-powered semantic extraction
- **Validation**: 5-10 keywords per entry

### 3. Geometry Patterns
- **Spiral**: Default for simple entries
- **Flower**: 3+ keywords, moderate content
- **Branch**: 5+ keywords, longer content
- **Fractal**: 7+ keywords, extensive content
- **Weave**: Interconnected patterns
- **Glow Core**: Central focus with orbiting elements

### 4. Color Mapping
- **Primary**: #4F46E5 (Blue)
- **Secondary**: #7C3AED (Purple)
- **Accent**: #D1B3FF (Light Purple)
- **Success**: #6BE3A0 (Green)
- **Warning**: #F7D774 (Yellow)
- **Danger**: #FF6B6B (Red)

## User Experience Flow

### 1. Onboarding (3 steps)
- **Purpose**: Why are you here? (growth, coaching, journaling, etc.)
- **Feeling**: How do you want to feel? (calm, energized, reflective, focused)
- **Rhythm**: What cadence fits you? (daily, weekly, free-flow)

### 2. Journal Capture
- **Text Input**: Minimalist, auto-saving
- **Voice Recording**: Optional, with transcription
- **Mood Selection**: 5 emotional states
- **Keyword Extraction**: AI-suggested, user-editable

### 3. SAGE Echo
- **Post-processing**: Situation, Action, Growth, Essence
- **User Review**: Edit AI-generated insights
- **Confidence Scoring**: 85% typical accuracy

### 4. Arcform Creation
- **Automatic**: Generated after journal save
- **Visual**: Constellation-like visualization
- **Interactive**: Draggable nodes, geometry switching
- **Persistent**: Saved to local storage

### 5. Timeline View
- **Chronological**: Entries + Arcform snapshots
- **Filtering**: All, text-only, with-Arcform
- **Pagination**: Load more as needed

## Technical Architecture

### State Management
- **BLoC Pattern**: Cubits for feature-specific state
- **Repository Pattern**: Data access abstraction
- **Local Storage**: Hive for offline-first approach

### Data Flow
```
UI → Cubit → Repository → Hive Storage
  ↑         ↓
State ←─── Data
```

### Error Handling
- **Graceful Degradation**: App continues if Arcform creation fails
- **User Feedback**: Clear error messages and retry options
- **Logging**: Comprehensive error tracking with Sentry

## Performance Considerations

### Animation
- **Target**: 60 FPS smooth animations
- **Optimization**: Efficient node rendering, minimal rebuilds
- **Platform**: iOS-optimized feel

### Storage
- **Local First**: All data stored locally
- **Efficient**: Minimal memory footprint
- **Scalable**: Handle thousands of entries

## Testing Strategy

### Unit Tests
- **ArcformService**: Geometry generation, color mapping
- **Keyword Extraction**: Word filtering, validation
- **Data Models**: Serialization, validation

### Integration Tests
- **Journal → Arcform Pipeline**: End-to-end flow
- **State Persistence**: Data survives app restarts
- **Navigation**: Onboarding → Journal → Arcform → Timeline

### UI Tests
- **User Flows**: Complete journaling experience
- **Responsiveness**: Different screen sizes
- **Accessibility**: Screen reader support

## Future Enhancements

### Phase 2: ATLAS
- **Pattern Recognition**: Identify recurring themes
- **Growth Tracking**: Visualize personal development
- **Goal Setting**: Intentional reflection prompts

### Phase 3: AURORA
- **Emotional Intelligence**: Mood pattern analysis
- **Stress Detection**: Early warning systems
- **Wellness Insights**: Holistic health tracking

### Phase 4: VEIL
- **Privacy Controls**: Granular data sharing
- **Encryption**: End-to-end security
- **Export Options**: Data portability

### Phase 5: Polymeta
- **Network Analysis**: Keyword relationships
- **Community Insights**: Anonymous pattern sharing
- **Research Integration**: Academic collaboration

## Success Metrics

### User Engagement
- **Daily Active Users**: Target 70% retention
- **Session Duration**: Average 5-10 minutes
- **Entry Frequency**: 3-5 entries per week

### Technical Performance
- **App Launch**: <3 seconds to interactive
- **Arcform Generation**: <2 seconds after save
- **Animation Smoothness**: 60 FPS maintained

### Data Quality
- **Keyword Relevance**: 90% user satisfaction
- **SAGE Accuracy**: 85% confidence threshold
- **Geometry Appropriateness**: 80% pattern match

## Implementation Checklist

- [ ] Fix startup white screen issue
- [ ] Fix onboarding freeze after completion
- [ ] Implement ArcformService core functionality
- [ ] Connect journal capture to Arcform creation
- [ ] Add keyword extraction validation
- [ ] Implement geometry pattern selection
- [ ] Create Arcform visualization renderer
- [ ] Add timeline view with Arcform snapshots
- [ ] Implement data persistence with Hive
- [ ] Add error handling and user feedback
- [ ] Test complete user flow
- [ ] Performance optimization
- [ ] Documentation and code comments

## Conclusion

The ARC MVP represents the foundation of the EPI system, demonstrating the core value proposition of transforming journal entries into meaningful visual representations. By fixing the current startup issues and implementing the data pipeline, users will experience the transformative power of seeing their thoughts and feelings visualized as evolving constellations.

The system is designed to be both technically robust and emotionally resonant, providing a sacred space for reflection while building the foundation for future AI-powered personal intelligence features.
