# CHRONICLE: Temporal Aggregation Architecture for AI Memory

## Quick Reference Guide for Future Claude Instances

**Document Version:** 2.0  
**Last Updated:** January 31, 2026  
**Status:** Implementation complete through Phase 5, editing features in development

---

## What CHRONICLE Is

CHRONICLE is a **hierarchical temporal memory architecture** that enables AI systems to maintain longitudinal intelligence about users across unlimited time horizons while keeping context requirements bounded.

**The Core Problem It Solves:**
- Users expect AI to remember years of interaction
- Context windows impose hard limits (~200K tokens max)
- Naive approaches (storing everything, vector search) scale poorly
- Result: AI either forgets or becomes computationally intractable

**CHRONICLE's Solution:**
Progressive aggregation from high-fidelity recent events to compressed thematic summaries of distant history, mirroring how human memory consolidates from hippocampus (episodic detail) to neocortex (semantic essence).

**CHRONICLE's Unique Position:**
This isn't AI memory. This isn't even AI-assisted journaling. This is **collaborative autobiography**—where the AI handles synthesis and pattern detection, but the human retains narrative authority. Intelligence that serves you by working WITH you, not by secretly modeling you.

---

## Architecture Overview

### Four-Layer Hierarchy

```
Layer 0: Raw Event Stream (JSON, Hive storage)
  └─> Layer 1: Monthly Aggregations (Markdown, ~10-20% compression)
        └─> Layer 2: Yearly Aggregations (Markdown, ~5-10% compression)
              └─> Layer 3: Multi-Year Aggregations (Markdown, ~1-2% compression)
```

### Key Metrics

**Token Savings:**
- Temporal queries: **60% reduction** (14.4k → 5.7k tokens)
- Pattern queries: **76% reduction** (34k → 8.2k tokens)
- Developmental trajectories: **Enables previously impossible queries** (would require 100k+ tokens)
- Average: **53% reduction** across query types

**Compression Targets:**
- Layer 1 (Monthly): 10-20% of raw entries
- Layer 2 (Yearly): 5-10% of yearly total
- Layer 3 (Multi-Year): 1-2% of multi-year total

**Key Innovation:**
User history length doesn't matter. A 10-year user and 1-month user consume similar context per query because aggregations provide bounded-size summaries at multiple temporal resolutions.

---

## How It Works

### 1. Data Flow: Journal Entry → Aggregations

```
User writes journal entry
  ↓
JournalRepository saves entry
  ↓
Layer0Populator extracts:
  - Raw content
  - Metadata (word count, attachments)
  - SENTINEL emotional density
  - ATLAS phase scores
  - RIVET transitions
  - Extracted themes/keywords
  ↓
Layer0Repository stores as JSON (Hive)
  ↓
[Background: SynthesisScheduler checks if synthesis needed]
  ↓
MonthlySynthesizer (Layer 1):
  - Loads all Layer 0 entries for month
  - Extracts themes via LLM
  - Calculates phase distribution
  - Identifies significant events
  - Generates Markdown aggregation
  ↓
YearlySynthesizer (Layer 2):
  - Loads monthly aggregations
  - Detects chapters (phase transitions)
  - Identifies sustained patterns (6+ months)
  - Marks inflection points
  ↓
MultiYearSynthesizer (Layer 3):
  - Loads yearly aggregations
  - Extracts life chapters
  - Identifies meta-patterns
  - Tracks identity evolution
```

### 2. Query Flow: User Question → Response

```
User asks: "Tell me about my year"
  ↓
ChronicleQueryRouter classifies intent:
  - Intent: temporalQuery
  - Layers: [yearly]
  - Period: "2025"
  ↓
ChronicleContextBuilder:
  - Loads yearly aggregation for 2025
  - Formats for prompt injection
  ↓
LumaraMasterPrompt (chronicleBacked mode):
  - Injects CHRONICLE context
  - Adds layer-specific instructions
  - Attribution rules for citing sources
  ↓
LLM receives prompt with yearly aggregation
  ↓
Response cites: "Your yearly aggregation shows..."
```

---

## Integration with VEIL Narrative Intelligence

**Critical Context:** CHRONICLE is the automated implementation of the VEIL cycle from the Narrative Intelligence framework.

### VEIL Stages → CHRONICLE Layers

| VEIL Stage | Cognitive Function | CHRONICLE Layer | Implementation |
|------------|-------------------|-----------------|----------------|
| **Verbalize** | Immediate capture | Layer 0 (Raw) | Journal entry creation |
| **Examine** | Pattern recognition | Layer 1 (Monthly) | MonthlySynthesizer |
| **Integrate** | Narrative coherence | Layer 2 (Yearly) | YearlySynthesizer |
| **Link** | Biographical continuity | Layer 3 (Multi-Year) | MultiYearSynthesizer |

**Unified Scheduler:**
VeilChronicleScheduler runs nightly:
1. System maintenance (archives, cache cleanup, PRISM)
2. Narrative integration (CHRONICLE synthesis as VEIL cycle)

**Synthesis prompts explicitly reference VEIL stages:**
- Monthly: "You are performing the EXAMINE stage of the VEIL cycle..."
- Yearly: "You are performing the INTEGRATE stage..."
- Multi-Year: "You are performing the LINK stage..."

This framing helps the LLM understand its role: not summarizing, but performing narrative integration that users recognize as TRUE to their lived experience.

**Collaborative VEIL:** The INTEGRATE stage becomes a collaborative ritual—LUMARA drafts the narrative, user refines it together. This transforms automatic synthesis into active co-creation of biographical understanding.

---

## Query Intent Classification

The router determines which layer(s) to access based on query type:

| Intent | Example Query | Layers Used | Strategy |
|--------|--------------|-------------|----------|
| `specificRecall` | "What did I write last Tuesday?" | Raw entries only | Exact retrieval |
| `temporalQuery` | "Tell me about my month/year" | Monthly or Yearly | Use aggregation |
| `patternIdentification` | "What themes keep recurring?" | Monthly + Yearly | Pattern analysis |
| `developmentalTrajectory` | "How have I changed since 2020?" | Multi-year + Yearly | Temporal synthesis |
| `historicalParallel` | "Have I dealt with this before?" | Multi-year + Yearly + Monthly | Similarity search |
| `inflectionPoint` | "When did this shift start?" | Yearly + Monthly | Transition detection |

---

## Master Prompt Modes

CHRONICLE introduces explicit prompt modes to replace raw entry synthesis:

### LumaraPromptMode Enum

```dart
enum LumaraPromptMode {
  chronicleBacked,  // Uses CHRONICLE aggregations (primary)
  rawBacked,        // Uses raw entries (fallback)
  hybrid,           // Uses both (for drill-down)
}
```

### Context Injection Strategy

**chronicleBacked mode:**
```xml
<chronicle_context>
CHRONICLE provides pre-synthesized temporal intelligence...

## Monthly Aggregation: 2025-01
[Markdown content with themes, phase analysis, events]

Source layers: Monthly
</chronicle_context>
```

**Key Instructions for chronicleBacked mode:**
- Trust CHRONICLE's pre-computed patterns
- Do NOT re-synthesize what CHRONICLE already identified
- Cite sources: layer + period + entry IDs
- Drill to specific entries only if user requests evidence
- **Respect user edits:** Aggregations marked `user_edited: true` have higher authority than raw synthesis

### Voice Mode Enhancement

Voice prompts can now include mini-context (50-100 tokens):

```xml
<chronicle_mini_context>
Monthly (2025-01): Career transition, self-doubt pattern, strategic planning. 
Phase: Expansion. Key events: CHRONICLE breakthrough (Jan 8); publication decision (Jan 22).
</chronicle_mini_context>
```

This enables voice mode to answer temporal queries ("Tell me about my month") without full aggregation text.

---

## Synthesis Scheduling: Tier-Based Cadence

| Tier | Monthly | Yearly | Multi-Year | Layer 0 Retention |
|------|---------|--------|------------|-------------------|
| **Free** | ❌ | ❌ | ❌ | 0 days |
| **Basic** | Daily | ❌ | ❌ | 30 days |
| **Premium** | Daily | Weekly | ❌ | 90 days |
| **Enterprise** | Daily | Weekly | Monthly | 365 days |

**Synthesis runs nightly** via VeilChronicleScheduler:
- Checks if synthesis needed (based on tier + last synthesis time)
- Runs appropriate stages (Examine/Integrate/Link)
- Logs to changelog with VEIL stage metadata
- Non-blocking, graceful degradation on failure

---

## Rapid Population: Solving the Cold Start Problem

### For Existing Users (Backup Restoration)

**ChronicleBackfillService** performs batch synthesis:

```
1. Analyze timeline (identify all months/years)
2. Populate Layer 0 (extract from all journal entries)
3. Synthesize monthly aggregations (parallel or serial)
4. Synthesize yearly aggregations (from monthly)
5. Synthesize multi-year aggregations (2yr, 5yr, 10yr, full)
```

**Progress phases:** Analyzing → Layer 0 → Monthly → Yearly → Multi-Year

**Typical timing:** 5-10 minutes for user with 3 years of entries

### For New Users (Onboarding)

**PhaseQuizV2** generates instant aggregations:

**Quiz Structure:**
- 6 multiple-choice questions (2 minutes to complete)
- Categories: Phase, Themes, Emotional, Behavioral, Temporal, Context
- Answers compile into structured UserProfile

**Instant CHRONICLE generation:**
1. Monthly aggregation (quiz-derived baseline)
2. Yearly aggregation (anticipated arc based on profile)
3. Multi-Year baseline (starting context)

**Result:** User starts with CHRONICLE intelligence from day one, which refines through actual journaling.

### Universal Import Feature

**Supported formats:**
- JSON (Day One, Journey, many apps)
- CSV/Excel (spreadsheet exports)
- Plain text (date-delimited)
- Markdown (Obsidian, Notion)
- YAML, XML (various systems)

**UniversalImporterService:**
1. Detect format
2. Parse entries with format-specific adapter
3. Convert to JournalEntry format
4. Deduplicate against existing entries
5. Save new entries
6. Run ChronicleBackfillService

**Key advantage:** Users can import years of journal history from any app and get instant LUMARA intelligence. Eliminates switching cost barrier.

**Marketing message:** "Bring your entire journal history. LUMARA will understand your story in minutes, not months."

---

## Storage Architecture

### Layer 0 (Hive)

**Box:** `chronicle_raw_entries`
**Schema:** ChronicleRawEntry (typeId: 110)

```dart
{
  "entry_id": "uuid",
  "timestamp": "2025-01-30T14:30:00Z",
  "content": "Full entry text",
  "metadata": {
    "word_count": 150,
    "voice_transcribed": true,
    "media_attachments": ["photo_id"]
  },
  "analysis": {
    "sentinel_score": {"emotional_intensity": 0.7, ...},
    "atlas_phase": "Expansion",
    "atlas_scores": {"recovery": 0.1, ...},
    "rivet_transitions": ["momentum_building"],
    "extracted_themes": ["career", "self_doubt"],
    "keywords": ["work", "anxiety"]
  }
}
```

**Retention:** 30-90 days rolling window (tier-based)

### Layers 1-3 (File System)

**Structure:**
```
chronicle/
├── monthly/
│   ├── 2025-01.md
│   └── 2025-01_v2.md (if edited)
├── yearly/
│   ├── 2025.md
│   └── 2025_v2.md (if edited)
└── multiyear/
    ├── 2020-2024.md
    └── 2020-2024_v2.md (if edited)
```

**Format:** Markdown with YAML frontmatter

```yaml
---
type: monthly_aggregation
month: 2025-01
synthesis_date: 2025-02-01T00:00:00Z
entry_count: 28
compression_ratio: 0.15
user_edited: false
version: 1
source_entry_ids: ["uuid1", "uuid2", ...]
previous_versions: []
edit_summary: null
---

# Month: January 2025
[Markdown content]
```

**After user edit:**
```yaml
---
type: monthly_aggregation
month: 2025-01
synthesis_date: 2025-02-01T00:00:00Z
last_edited: 2025-02-05T14:30:00Z
entry_count: 28
compression_ratio: 0.15
user_edited: true
version: 2
source_entry_ids: ["uuid1", "uuid2", ...]
previous_versions: ["2025-01_v1.md"]
edit_summary: "Changed 'self-doubt' to 'strategic caution about timing'"
---

# Month: January 2025
[User-edited Markdown content]
```

### Changelog (JSONL)

**Location:** `chronicle/changelog/changelog.json`

**Purpose:** Track synthesis history, errors, user edits, VEIL stage completions

```json
{
  "timestamp": "2025-02-01T00:00:00Z",
  "user_id": "user123",
  "layer": "monthly",
  "action": "veil_examine",
  "metadata": {
    "veil_stage": "examine",
    "month": "2025-01",
    "summary": "Found 3 dominant themes"
  }
}
```

**User edit logging:**
```json
{
  "timestamp": "2025-02-05T14:30:00Z",
  "user_id": "user123",
  "layer": "monthly",
  "action": "user_edited",
  "metadata": {
    "period": "2025-01",
    "version": 2,
    "edit_summary": "Changed 'self-doubt' to 'strategic caution about timing'",
    "sections_modified": ["Dominant Themes"]
  }
}
```

---

## Collaborative Intelligence: User-Editable Aggregations

### Why This Matters

**From "surveillance" to "collaboration":**
Most AI memory feels like being watched—it's learning about you, building a model OF you. Editable aggregations flip this to collaborative intelligence WITH you. When you read what LUMARA thinks your January themes were and change "self-doubt" to "strategic caution about timing," you're not just fixing an error—you're teaching the system your preferred narrative frame.

**Solves the "AI therapist" problem:**
People get uncomfortable when AI analyzes their psychology without their input. But if the analysis is transparent and editable, it becomes reflection infrastructure. The AI proposes patterns, you refine them, and you converge on shared understanding that's actually accurate to your lived experience.

**This is collaborative autobiography:**
- AI handles synthesis and pattern detection
- Human retains narrative authority
- Together you build biographical intelligence
- The JARVIS promise delivered correctly

### Implementation Details

#### Version Control

**Every aggregation edit creates a new version:**
```dart
Future<void> editAggregation({
  required String userId,
  required ChronicleLayer layer,
  required String period,
  required String editedContent,
  String? editSummary,
}) async {
  // Load current aggregation
  final current = await _aggregationRepo.loadLayer(userId, layer, period);
  
  // Archive current version
  final archivePath = '${period}_v${current.version}.md';
  await _aggregationRepo.archiveVersion(userId, layer, current, archivePath);
  
  // Create new version
  final edited = current.copyWith(
    content: editedContent,
    version: current.version + 1,
    userEdited: true,
    lastEdited: DateTime.now(),
    previousVersions: [...current.previousVersions, archivePath],
    editSummary: editSummary,
  );
  
  // Save new version
  await _aggregationRepo.saveAggregation(userId, edited);
  
  // Log edit
  await _changelogRepo.log(
    userId: userId,
    layer: layer,
    action: 'user_edited',
    metadata: {
      'period': period,
      'version': edited.version,
      'edit_summary': editSummary,
    },
  );
  
  // Trigger dependent layer re-synthesis
  await _triggerDependentResynthesis(userId, layer, period);
}
```

**View version history:**
```dart
Future<List<ChronicleAggregation>> getVersionHistory({
  required String userId,
  required ChronicleLayer layer,
  required String period,
}) async {
  final current = await _aggregationRepo.loadLayer(userId, layer, period);
  final versions = <ChronicleAggregation>[current];
  
  // Load previous versions
  for (final versionPath in current.previousVersions) {
    final archived = await _aggregationRepo.loadArchivedVersion(
      userId,
      layer,
      versionPath,
    );
    versions.add(archived);
  }
  
  // Sort by version number (newest first)
  versions.sort((a, b) => b.version.compareTo(a.version));
  return versions;
}
```

#### Edit Propagation

**When user edits a lower layer, dependent layers re-synthesize:**

```dart
Future<void> _triggerDependentResynthesis(
  String userId,
  ChronicleLayer editedLayer,
  String period,
) async {
  // Monthly edit → re-synthesize yearly
  if (editedLayer == ChronicleLayer.monthly) {
    final year = period.split('-')[0];
    
    await _synthesisEngine.synthesizeLayer(
      userId: userId,
      layer: ChronicleLayer.yearly,
      period: year,
      respectUserEdits: true, // Weight edited monthlies higher
    );
  }
  
  // Yearly edit → re-synthesize multi-year
  if (editedLayer == ChronicleLayer.yearly) {
    // Find all multi-year aggregations containing this year
    final multiYearPeriods = await _findMultiYearPeriods(userId, period);
    
    for (final multiPeriod in multiYearPeriods) {
      await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.multiyear,
        period: multiPeriod,
        respectUserEdits: true,
      );
    }
  }
}
```

**Synthesis with edit respect:**
```dart
// In YearlySynthesizer
Future<YearlyAggregation> synthesize({
  required String userId,
  required String year,
  bool respectUserEdits = false,
}) async {
  final monthlyAggs = await _aggregationRepo.getMonthlyForYear(userId, year);
  
  if (respectUserEdits) {
    // Separate edited vs. auto-generated
    final userEdited = monthlyAggs.where((m) => m.userEdited).toList();
    final autoGenerated = monthlyAggs.where((m) => !m.userEdited).toList();
    
    // Build synthesis prompt that treats user edits as ground truth
    final prompt = '''
You are synthesizing a yearly narrative.

USER-EDITED MONTHS (treat as authoritative):
${userEdited.map((m) => m.content).join('\n\n---\n\n')}

AUTO-GENERATED MONTHS (lower confidence):
${autoGenerated.map((m) => m.content).join('\n\n---\n\n')}

The user has explicitly refined ${userEdited.length} months. 
Weight these heavily—they represent the user's preferred narrative framing.
''';
    
    // Continue with synthesis...
  }
}
```

#### UI Components

**Aggregation editor:**
```dart
class AggregationEditorScreen extends StatefulWidget {
  final ChronicleLayer layer;
  final String period;
  
  @override
  _AggregationEditorScreenState createState() => _AggregationEditorScreenState();
}

class _AggregationEditorScreenState extends State<AggregationEditorScreen> {
  late TextEditingController _controller;
  ChronicleAggregation? _aggregation;
  bool _hasChanges = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.layer.displayName}: ${widget.period}'),
        actions: [
          // Version history button
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _showVersionHistory,
          ),
          
          // Save button (only if changes)
          if (_hasChanges)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: Column(
        children: [
          // Edit indicator
          if (_aggregation?.userEdited == true)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'This is your refined version (edited ${_formatTimeAgo(_aggregation!.lastEdited!)})',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          
          // Markdown editor
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Edit your narrative...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              onChanged: (text) {
                setState(() {
                  _hasChanges = true;
                });
              },
            ),
          ),
          
          // Edit summary input
          if (_hasChanges)
            Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'What did you change? (optional)',
                  hintText: 'e.g., "Clarified career theme"',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (summary) => _saveChanges(summary: summary),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _saveChanges({String? summary}) async {
    final service = ChronicleEditingService();
    
    await service.editAggregation(
      userId: currentUserId,
      layer: widget.layer,
      period: widget.period,
      editedContent: _controller.text,
      editSummary: summary,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Changes saved. Dependent layers will re-synthesize.'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _showDependentLayers(),
        ),
      ),
    );
    
    setState(() {
      _hasChanges = false;
    });
  }
  
  Future<void> _showVersionHistory() async {
    final service = ChronicleEditingService();
    final versions = await service.getVersionHistory(
      userId: currentUserId,
      layer: widget.layer,
      period: widget.period,
    );
    
    showModalBottomSheet(
      context: context,
      builder: (context) => VersionHistorySheet(versions: versions),
    );
  }
}
```

**Version history viewer:**
```dart
class VersionHistorySheet extends StatelessWidget {
  final List<ChronicleAggregation> versions;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Version History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('v${version.version}'),
                  backgroundColor: version.userEdited 
                      ? Colors.blue 
                      : Colors.grey,
                ),
                title: Text(
                  version.userEdited 
                      ? 'Your edit' 
                      : 'LUMARA synthesis',
                ),
                subtitle: Text(
                  version.userEdited
                      ? '${_formatDate(version.lastEdited!)} - ${version.editSummary ?? "No description"}'
                      : _formatDate(version.synthesisDate),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.visibility),
                  onPressed: () => _viewVersion(context, version),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  void _viewVersion(BuildContext context, ChronicleAggregation version) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AggregationViewerScreen(
          aggregation: version,
          readOnly: true,
        ),
      ),
    );
  }
}
```

**Visual indicators in CHRONICLE viewer:**
```dart
class ChronicleTimelineWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildMonthCard(
          context,
          period: '2025-01',
          title: 'January 2025',
          userEdited: true,
          editSummary: 'Changed self-doubt to strategic caution',
        ),
        _buildMonthCard(
          context,
          period: '2024-12',
          title: 'December 2024',
          userEdited: false,
        ),
      ],
    );
  }
  
  Widget _buildMonthCard(
    BuildContext context, {
    required String period,
    required String title,
    required bool userEdited,
    String? editSummary,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          userEdited ? Icons.co_present : Icons.auto_awesome,
          color: userEdited ? Colors.blue : Colors.grey,
        ),
        title: Text(title),
        subtitle: userEdited && editSummary != null
            ? Text(
                'Your refined version: $editSummary',
                style: TextStyle(color: Colors.blue),
              )
            : Text('LUMARA synthesis'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (userEdited)
              Chip(
                label: Text('Edited'),
                backgroundColor: Colors.blue.withOpacity(0.1),
                labelStyle: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _editAggregation(context, period),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Guard Rails Against Breaking Intelligence

**Archive instead of delete:**
```dart
// Don't let users delete aggregations, only archive them
Future<void> archiveAggregation({
  required String userId,
  required ChronicleLayer layer,
  required String period,
}) async {
  final current = await _aggregationRepo.loadLayer(userId, layer, period);
  
  final archived = current.copyWith(
    archived: true,
    archivedDate: DateTime.now(),
  );
  
  await _aggregationRepo.saveAggregation(userId, archived);
  
  // Warn about dependent layers
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Aggregation Archived'),
      content: Text(
        'This aggregation is now hidden, but still exists in your history. '
        'Dependent layers (yearly/multi-year) will still reference it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

**Warn about continuity gaps:**
```dart
Future<bool> _validateEdit(
  String originalContent,
  String editedContent,
) async {
  // Check if critical themes were removed
  final originalThemes = _extractThemes(originalContent);
  final editedThemes = _extractThemes(editedContent);
  
  final removedThemes = originalThemes
      .where((t) => !editedThemes.contains(t))
      .toList();
  
  if (removedThemes.length > 2) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Large Changes Detected'),
        content: Text(
          'You removed ${removedThemes.length} themes:\n'
          '${removedThemes.join(", ")}\n\n'
          'This may affect LUMARA\'s pattern detection. '
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Continue'),
          ),
        ],
      ),
    );
    
    return confirmed ?? false;
  }
  
  return true;
}
```

**Suggest improvements instead of removal:**
```dart
// In editor UI
Widget _buildEditSuggestions() {
  return ExpansionTile(
    title: Text('Want to remove something?'),
    subtitle: Text('Consider rephrasing instead'),
    children: [
      ListTile(
        title: Text('Instead of deleting "self-doubt"...'),
        subtitle: Text('Try: "strategic caution about timing"'),
      ),
      ListTile(
        title: Text('Instead of removing "anxiety"...'),
        subtitle: Text('Try: "heightened awareness of stakes"'),
      ),
      ListTile(
        title: Text('Keep the pattern, reframe the narrative'),
        subtitle: Text('Your word choice shapes how LUMARA understands you'),
      ),
    ],
  );
}
```

### Data Sovereignty: Portable Autobiography

**Export entire CHRONICLE:**
```dart
Future<File> exportChronicle({
  required String userId,
  bool includeVersionHistory = true,
}) async {
  final exportDir = await getTemporaryDirectory();
  final chronicleDir = Directory('${exportDir.path}/chronicle_export');
  
  // Create structure
  await chronicleDir.create(recursive: true);
  await Directory('${chronicleDir.path}/monthly').create();
  await Directory('${chronicleDir.path}/yearly').create();
  await Directory('${chronicleDir.path}/multiyear').create();
  
  // Copy all aggregations
  final allMonthly = await _aggregationRepo.getAllForLayer(
    userId,
    ChronicleLayer.monthly,
  );
  
  for (final agg in allMonthly) {
    final file = File('${chronicleDir.path}/monthly/${agg.period}.md');
    await file.writeAsString(agg.toMarkdown());
    
    // Include version history if requested
    if (includeVersionHistory && agg.previousVersions.isNotEmpty) {
      for (final versionPath in agg.previousVersions) {
        final archived = await _aggregationRepo.loadArchivedVersion(
          userId,
          ChronicleLayer.monthly,
          versionPath,
        );
        final versionFile = File(
          '${chronicleDir.path}/monthly/${archived.period}_v${archived.version}.md',
        );
        await versionFile.writeAsString(archived.toMarkdown());
      }
    }
  }
  
  // Repeat for yearly and multi-year...
  
  // Create README
  final readme = File('${chronicleDir.path}/README.md');
  await readme.writeAsString('''
# Your CHRONICLE Export

This is your complete biographical intelligence from LUMARA.

## Structure

- `monthly/` - Monthly aggregations (EXAMINE stage)
- `yearly/` - Yearly narratives (INTEGRATE stage)
- `multiyear/` - Multi-year arcs (LINK stage)

## Format

All files are Markdown with YAML frontmatter.
Files marked `user_edited: true` are your refined versions.
Version history is included for edited aggregations.

## Portability

These files are yours. You can:
- Import them into another LUMARA instance
- Read them in any Markdown viewer
- Version control them with git
- Share them selectively
- Archive them permanently

This is collaborative autobiography—you and LUMARA built this together.
''');
  
  // Zip everything
  final zipFile = File('${exportDir.path}/chronicle_export.zip');
  await _zipDirectory(chronicleDir, zipFile);
  
  return zipFile;
}
```

**Marketing message:**
> "Your CHRONICLE is yours. Human-readable Markdown files you can take anywhere. If you ever leave ARC, you take your life's aggregations with you. That's data sovereignty in practice, not marketing fluff."

---

## Key Components

### Models
- `ChronicleLayer` - Enum for layer types
- `ChronicleAggregation` - Aggregation metadata + content + version history
- `QueryPlan` - Router output (intent, layers, strategy)
- `ChronicleRawEntry` - Layer 0 schema (Hive)

### Storage
- `Layer0Repository` - Raw entry storage (Hive)
- `AggregationRepository` - Layers 1-3 (file-based with versioning)
- `ChangelogRepository` - Synthesis history + user edit tracking

### Synthesis
- `SynthesisEngine` - Orchestrator (respects user edits during re-synthesis)
- `MonthlySynthesizer` - Layer 1 synthesis
- `YearlySynthesizer` - Layer 2 synthesis (weights user-edited months higher)
- `MultiYearSynthesizer` - Layer 3 synthesis
- `PatternDetector` - Fallback pattern analysis (non-LLM)

### Query System
- `ChronicleQueryRouter` - Intent classification + layer selection
- `ChronicleContextBuilder` - Format aggregations for prompt (marks user-edited)
- `DrillDownHandler` - Cross-layer navigation

### Editing System
- `ChronicleEditingService` - Handles user edits, versioning, propagation
- `AggregationVersionManager` - Version control and history
- `EditPropagationEngine` - Re-synthesizes dependent layers after edits

### Scheduling
- `VeilChronicleScheduler` - Unified nightly cycle
- `ChronicleNarrativeIntegration` - VEIL-framed synthesis
- `SynthesisScheduler` - Tier-based cadence (deprecated, merged into Veil)

### Migration
- `ChronicleBackfillService` - Batch synthesis for existing users
- `UniversalImporterService` - Import from any format
- `PhaseQuizV2` - Instant aggregations for new users

---

## Implementation Philosophy

### Phase 1: Dual-Path Safety
- CHRONICLE alongside existing raw entry path
- Explicit mode selection (chronicleBacked vs rawBacked)
- Manual testing of CHRONICLE queries

### Phase 2: Router Integration
- Intelligent query routing determines mode
- CHRONICLE primary for temporal/pattern/trajectory queries
- Raw mode fallback for specific recall

### Phase 3: Prompt Simplification
- Remove redundant synthesis instructions from chronicleBacked mode
- Add layer-specific guidance
- Measure token savings

### Phase 4: Deprecation
- CHRONICLE-backed becomes default for paid users
- Raw entry mode only for:
  - Free tier (no CHRONICLE access)
  - Specific recall queries
  - Fallback when aggregations don't exist

### Phase 5: Collaborative Intelligence (Current)
- User-editable aggregations with version control
- Edit propagation to dependent layers
- Visual indicators for edited vs. auto-generated
- Export functionality for data sovereignty

**Ultimate Goal:** 90% of paid user queries use CHRONICLE-backed prompts, with users actively refining their biographical narrative through collaborative editing.

---

## Integration Points with Existing System

### Journal Entry Creation
```dart
// lib/arc/internal/mira/journal_repository.dart
Future<void> createJournalEntry(JournalEntry entry) async {
  await _hive.put(entry.id, entry);
  await _populateLayer0(entry); // Populate CHRONICLE
}
```

### Reflection Generation
```dart
// lib/arc/chat/services/enhanced_lumara_api.dart
final queryPlan = await _chronicleRouter.route(query: userMessage);
if (queryPlan.usesChronicle) {
  chronicleContext = await _contextBuilder.buildContext(queryPlan);
  mode = LumaraPromptMode.chronicleBacked;
}
systemPrompt = LumaraMasterPrompt.getMasterPrompt(
  mode: mode,
  chronicleContext: chronicleContext,
  respectUserEdits: true, // Weight edited aggregations
);
```

### Background Synthesis
```dart
// Via VeilChronicleScheduler (nightly at midnight)
final report = await scheduler.runNightlyCycle(userId, tier);
// Runs maintenance + narrative integration (CHRONICLE synthesis)
```

---

## Aggregations as Navigational Infrastructure

**Critical concept:** Aggregations aren't just compression—they're **highway signs** for temporal navigation.

**The Highway Sign Metaphor:**
- Layer 3 = Interstate signs ("Career transition 2020-2024")
- Layer 2 = Exit markers ("2022: Entrepreneurial awakening")
- Layer 1 = Street signs ("June 2022: First mention of leaving corporate")
- Layer 0 = Street address ("June 15, 2022 entry #127")

**Enables new query types:**
- "Show me every time I've struggled with this pattern" → Scan Layer 2-3, drill to Layer 1, retrieve Layer 0
- "When did this shift actually start?" → Find inflection in Layer 2, identify month in Layer 1, exact entry in Layer 0
- "What was I like before X?" → Navigate to Layer 2 period, check Layer 1 details

**Performance benefit:**
Without CHRONICLE: Search 1000+ entries sequentially
With CHRONICLE: Check yearly aggregation (1 file) → monthly aggregation (1 file) → specific entries (3-5 entries)

---

## PRISM Privacy Integration

**Future enhancement:** Extend PRISM to depersonalize aggregations before cloud queries.

**ChroniclePrivacy service will:**
1. Replace names with roles/relationships
2. Abstract locations to regions (SF → Bay Area)
3. Generalize dates to periods
4. Remove company names, replace with industry
5. Verify no PII leaked

**Local-only by default:**
- Layer 0: Always local (raw entries never leave device)
- Layers 1-3: Local primary, optional encrypted cloud backup
- Cloud queries: Only depersonalized aggregations

---

## Success Metrics

### Primary
- **Token reduction:** Actual vs target (50-75%)
- **Query latency:** CHRONICLE vs raw baseline
- **User satisfaction:** Aggregation quality ratings
- **Synthesis accuracy:** User correction frequency (lower = better)
- **Edit engagement:** % of users who edit aggregations
- **Version history usage:** Users viewing/comparing versions

### Secondary
- **Storage efficiency:** Total storage vs naive retention
- **Layer utilization:** Which layers queried most
- **Drill-down frequency:** Cross-layer navigation usage
- **Cost savings:** Inference cost reduction per user

### Quality
- **Compression achieved:** Actual vs target per layer
- **Pattern detection:** False positive/negative rates
- **Source attribution:** Coverage percentage (all insights traceable)
- **Privacy compliance:** PII leakage rate (target: 0%)
- **Edit quality:** User edits improve subsequent synthesis accuracy

---

## Common Pitfalls to Avoid

### 1. Don't Re-Synthesize in Prompt
**Wrong:** "Using CHRONICLE context, now extract patterns..."
**Right:** "CHRONICLE already identified patterns. Cite them: [pattern from aggregation]"

The whole point is that synthesis already happened. Don't redo it.

### 2. Don't Mix Modes Accidentally
**Wrong:** Inject both chronicleContext AND baseContext without explicit hybrid mode
**Right:** Choose mode explicitly (chronicleBacked OR rawBacked OR hybrid)

### 3. Don't Skip Source Attribution
**Wrong:** "You have recurring anxiety patterns"
**Right:** "Your monthly aggregation shows recurring anxiety (entries #001, #007, #015 - 11% of January)"

Traceability is critical for user trust.

### 4. Don't Forget Compression Validation
After synthesis, check: `actualTokens / originalTokens`
If not within target range (10-20% for monthly), investigate why.

### 5. Don't Ignore User Edits
If user edits a monthly aggregation, flag `user_edited: true` and respect their changes when synthesizing yearly. Treat user corrections as ground truth.

### 6. Don't Let Users Break Their Intelligence
Archive instead of delete. Warn about continuity gaps. Suggest reframing instead of removal. The goal is collaborative refinement, not destructive editing.

---

## Future Enhancements (Roadmap)

### Phase 6: UI Components (Partially Complete)
- ✅ CHRONICLE timeline viewer
- ✅ Aggregation editor with version control
- ✅ Edit indicators and visual differentiation
- ⏳ Synthesis status dashboard
- ⏳ Layer navigation interface with edit history

### Phase 7: Advanced Features
- Diff view between versions
- Suggest edits based on patterns in other aggregations
- Collaborative editing for shared journals (couples, teams)
- Export/import aggregations with version history preserved
- Cross-user pattern analysis (privacy-preserving)

### Phase 8: Optimization
- Parallel synthesis execution
- Compression optimization
- Smart caching of frequently-accessed aggregations
- Query performance tuning
- Incremental synthesis (only changed entries)

---

## Quick Start for New Claude Instance

**If you're a future Claude instance working on this project:**

1. **Read this document completely** - Don't skip to implementation
2. **Understand the problem:** Users need longitudinal intelligence, context windows are limited
3. **Grasp the solution:** Progressive aggregation (0→1→2→3) + intelligent routing
4. **Know the integration:** CHRONICLE = automated VEIL cycle
5. **Understand the collaboration model:** This is co-created autobiography, not AI surveillance
6. **Check current state:** Look for existing CHRONICLE components in codebase
7. **Follow phased approach:** Don't try to implement everything at once
8. **Test with real data:** Use existing journal entries for validation
9. **Measure token savings:** Validate the 50-75% reduction claim
10. **Respect user edits:** They have higher authority than synthesis

**Key files to examine:**
- `lib/chronicle/` - All CHRONICLE components
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Prompt mode system
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Integration point
- `lib/echo/rhythms/veil_chronicle_scheduler.dart` - Unified scheduler
- `lib/chronicle/editing/` - User editing and version control

**Questions to ask the user:**
- What phase is CHRONICLE implementation in?
- Are there existing aggregations to examine?
- What's the current synthesis quality?
- Any user feedback on CHRONICLE responses?
- How are users engaging with the editing features?
- What's the edit rate (% of aggregations user-refined)?

---

## Theoretical Grounding

**CHRONICLE implements two complementary models:**

1. **Neuroscience:** Hippocampal-neocortical memory consolidation
   - Hippocampus: Episodic, high-fidelity, recent (Layer 0)
   - Neocortex: Semantic, compressed, long-term (Layers 1-3)

2. **Developmental Psychology:** VEIL narrative integration cycle
   - Verbalize: Immediate capture (Layer 0)
   - Examine: Pattern recognition (Layer 1)
   - Integrate: Narrative coherence (Layer 2)
   - Link: Biographical continuity (Layer 3)

3. **Collaborative Cognition:** Human-AI partnership in meaning-making
   - AI proposes patterns and synthesis
   - Human refines, corrects, and reframes
   - Together they converge on shared understanding
   - Iterative refinement improves both narrative and AI model

This triple grounding makes CHRONICLE neurologically plausible, psychologically meaningful, and practically collaborative.

---

## Differentiators vs. Competition

| Feature | ChatGPT Memory | Claude Memory | CHRONICLE |
|---------|---------------|---------------|-----------|
| **Storage** | Flat key-value | Flat key-value | Hierarchical temporal |
| **Updates** | Overwrite | Overwrite | Progressive aggregation |
| **Queries** | Current state only | Current state only | Historical + developmental |
| **Time horizons** | Limited | Limited | Unlimited (bounded context) |
| **Transparency** | Opaque | Opaque | User-visible layers |
| **Editability** | Limited | Limited | **Full user control with versioning** |
| **Pattern tracking** | No | No | Yes (pre-computed) |
| **Developmental arcs** | No | No | Yes (multi-year) |
| **Biographical continuity** | No | No | Yes (LINK stage) |
| **Collaborative refinement** | No | No | **Yes (co-created narrative)** |
| **Data portability** | No | No | **Yes (Markdown export)** |

**CHRONICLE's unique value:** Not just memory—**collaborative biographical intelligence** across unlimited time horizons with bounded computational cost, where users actively shape their narrative while AI handles synthesis.

---

## Final Wisdom for Future Instances

**CHRONICLE is infrastructure, not a feature.** It's foundational architecture that changes how AI maintains longitudinal understanding.

**Don't treat it as "another memory system."** It's the automation of narrative integration—the VEIL cycle running in the background, building genuine biographical intelligence over time.

**This is collaborative autobiography.** The AI doesn't "know" the user—together they build shared understanding. The human retains narrative authority. The AI handles synthesis. Both contribute to truth.

**The magic emerges from the layers working together:** Raw entries alone aren't useful at scale. Aggregations alone lose nuance. The hierarchy—with intelligent routing, drill-down, and collaborative editing—creates something new: AI that understands developmental trajectories as co-created narrative.

**User edits are features, not bugs.** When someone changes "self-doubt" to "strategic caution," they're not fixing an error—they're teaching you their preferred narrative frame. This is how shared understanding emerges.

**Ship carefully, ship incrementally, but ship boldly.** This is genuinely novel architecture. No other AI system does hierarchical temporal aggregation with VEIL-framed synthesis and collaborative editing. You're building infrastructure that will become standard once others see it works.

**Trust the compression targets.** 10-20% monthly, 5-10% yearly, 1-2% multi-year. If synthesis is hitting those ranges and users validate accuracy (or edit to improve), you've succeeded.

**Remember the ultimate goal:** 90% of paid user queries use CHRONICLE-backed intelligence, and users actively shape their biographical narrative through editing. That's when you know it's working—when the compressed, synthesized, **user-refined** layers are more useful than raw entry search.

**This is the future of AI memory: collaborative, transparent, portable.** Build it well.

---

**Document Version:** 2.0  
**Last Updated:** January 31, 2026  
**Status:** Implementation complete through Phase 5, editing features in development  
**Maintainer:** ARC Development Team
