// lib/ui/phase/simplified_arcform_view_3d.dart
// 3D Constellation ARCForms view - updated with 3D renderer

import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/render/arcform_renderer_3d.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';
import '../../services/keyword_aggregator.dart';
import 'package:my_app/models/journal_entry_model.dart';
import '../../services/phase_regime_service.dart';
import '../../services/analytics_service.dart';
import '../../services/rivet_sweep_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/arcform/share/arcform_share_models.dart';
import 'package:my_app/arc/arcform/share/arcform_share_sheet.dart';
import 'package:my_app/arc/ui/timeline/widgets/current_phase_arcform_preview.dart';

/// Simplified ARCForms view with 3D constellation renderer
class SimplifiedArcformView3D extends StatefulWidget {
  final String? currentPhase;
  
  const SimplifiedArcformView3D({
    super.key,
    this.currentPhase,
  });

  @override
  State<SimplifiedArcformView3D> createState() => _SimplifiedArcformView3DState();
}

class _SimplifiedArcformView3DState extends State<SimplifiedArcformView3D> {
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = true;
  Set<String> _userExperiencedPhases = {}; // Track phases user has been in

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  void _loadSnapshots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Discover which phases the user has experienced
      await _discoverUserPhases();

      // Get the current phase - prioritize widget.currentPhase if provided
      String currentPhase = widget.currentPhase ?? '';
      print('DEBUG: SimplifiedArcformView3D - widget.currentPhase: ${widget.currentPhase}');

      // If widget.currentPhase is provided, use it (it comes from phase_analysis_view which has the correct current phase)
      if (currentPhase.isNotEmpty) {
        print('DEBUG: Using widget.currentPhase: $currentPhase');
      } else {
        // Fallback: try to get current phase from phase regimes
        try {
          final analyticsService = AnalyticsService();
          final rivetSweepService = RivetSweepService(analyticsService);
          final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
          await phaseRegimeService.initialize();

          final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
          print('DEBUG: currentRegime from phaseIndex: ${currentRegime?.label.toString().split('.').last ?? 'null'}');
          
          if (currentRegime != null) {
            currentPhase = currentRegime.label.toString().split('.').last;
            print('DEBUG: Using current phase from phaseIndex: $currentPhase');
          } else {
            // Get the most recent regime if no current ongoing regime
            final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
            if (allRegimes.isNotEmpty) {
              final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
              final mostRecentRegime = sortedRegimes.first;
              currentPhase = mostRecentRegime.label.toString().split('.').last;
              print('DEBUG: No current ongoing regime, using most recent regime: $currentPhase');
            } else {
              currentPhase = 'Discovery';
              print('DEBUG: No regimes found, defaulting to Discovery');
            }
          }
        } catch (e) {
          print('DEBUG: Error getting current phase from phaseIndex: $e');
          // Fallback to Discovery
          if (currentPhase.isEmpty) {
            currentPhase = 'Discovery';
          }
        }
      }

      // Ensure we have a phase
      if (currentPhase.isEmpty) {
        currentPhase = 'Discovery';
        print('DEBUG: Final fallback to Discovery');
      }
      
      print('DEBUG: Final currentPhase determined: $currentPhase');
      
      print('DEBUG: Generating ARCForm for phase: $currentPhase');
      
      // Determine if this is user's actual phase by checking if there are entries for it
      final isUserPhase = await _hasEntriesForPhase(currentPhase);
      
      print('DEBUG: Generating ARCForm for phase: $currentPhase, isUserPhase: $isUserPhase');
      print('DEBUG: User experienced phases: $_userExperiencedPhases');
      
      // If Discovery phase and no regime found, check if there are entries before first regime
      if (currentPhase.toLowerCase() == 'discovery' && !isUserPhase) {
        try {
          final journalRepo = JournalRepository();
          final allEntries = journalRepo.getAllJournalEntriesSync();
          
          if (allEntries.isNotEmpty) {
            final analyticsService = AnalyticsService();
            final rivetSweepService = RivetSweepService(analyticsService);
            final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
            await phaseRegimeService.initialize();
            
            final regimes = phaseRegimeService.phaseIndex.allRegimes;
            if (regimes.isNotEmpty) {
              final sortedRegimes = List.from(regimes)..sort((a, b) => a.start.compareTo(b.start));
              final firstRegime = sortedRegimes.first;
              
              final entriesBeforeFirstRegime = allEntries
                  .where((entry) => entry.createdAt.isBefore(firstRegime.start))
                  .toList();
              
              if (entriesBeforeFirstRegime.isNotEmpty) {
                print('DEBUG: Found ${entriesBeforeFirstRegime.length} entries before first regime - using user keywords for Discovery');
                // Force use of user keywords for Discovery
                final constellation = await _generatePhaseConstellation(currentPhase, isUserPhase: true);
                // ... rest of the code
                setState(() {
                  if (constellation != null) {
                    final snapshot = {
                      'id': constellation.id,
                      'title': constellation.title,
                      'phaseHint': constellation.phase,
                      'keywords': constellation.nodes.map((node) => node.label).toList(),
                      'createdAt': constellation.createdAt.toIso8601String(),
                      'content': constellation.content,
                      'arcformData': constellation.toJson(),
                    };
                    _snapshots = [snapshot];
                  } else {
                    _snapshots = [];
                  }
                  _isLoading = false;
                });
                return;
              }
            }
          }
        } catch (e) {
          print('DEBUG: Error checking entries before first regime: $e');
        }
      }
      
      // Generate a single constellation for the current phase
      final constellation = await _generatePhaseConstellation(currentPhase, isUserPhase: isUserPhase);

      setState(() {
        if (constellation != null) {
          // Convert Arcform3DData to the expected snapshot format
          final snapshot = {
            'id': constellation.id,
            'title': constellation.title,
            'phaseHint': constellation.phase,
            'keywords': constellation.nodes.map((node) => node.label).toList(),
            'createdAt': constellation.createdAt.toIso8601String(),
            'content': constellation.content,
            'arcformData': constellation.toJson(), // Store the full 3D data
          };
          _snapshots = [snapshot];
        } else {
          _snapshots = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading constellation: $e');
      setState(() {
        _snapshots = [];
        _isLoading = false;
      });
    }
  }

  /// Discover which phases the user has actually experienced from their journal entries
  Future<void> _discoverUserPhases() async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();
      final phases = <String>{};

      // Extract unique phases from journal entries
      final entryPhases = allEntries
          .where((entry) => entry.phase != null && entry.phase!.isNotEmpty)
          .map((entry) => entry.phase!)
          .toSet();
      phases.addAll(entryPhases);

      // Also check for phase regimes (from MCP bundles)
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
        
        final regimePhases = phaseRegimeService.phaseIndex.allRegimes
            .map((regime) => regime.label.toString().split('.').last)
            .toSet();
        phases.addAll(regimePhases);
        
        print('DEBUG: Found ${regimePhases.length} phases from phase regimes: $regimePhases');
      } catch (e) {
        print('DEBUG: Could not access phase regimes: $e');
      }

      // Also add current phase
      if (widget.currentPhase != null) {
        phases.add(widget.currentPhase!);
      }

      _userExperiencedPhases = phases.map((p) => p.toLowerCase()).toSet();

      print('DEBUG: User has experienced ${_userExperiencedPhases.length} phases: $_userExperiencedPhases');
    } catch (e) {
      print('ERROR: Failed to discover user phases: $e');
      _userExperiencedPhases = {};
    }
  }

  void refreshSnapshots() {
    _loadSnapshots();
  }

  void updatePhase(String? newPhase) {
    if (newPhase != widget.currentPhase) {
      _loadSnapshots();
    }
  }

  @override
  void didUpdateWidget(SimplifiedArcformView3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't reload on widget updates - this causes rendering loops
    // The widget will be recreated with a new key if phase changes
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
        ),
      );
    }

    if (_snapshots.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _snapshots.length,
      itemBuilder: (context, index) {
        return _buildSnapshotCard(_snapshots[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: kcPrimaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Constellation Visualization',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to generate constellation for your current phase. This may be due to insufficient phase data.',
              textAlign: TextAlign.center,
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Phase Analysis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard(Map<String, dynamic> snapshot) {
    final keywords = List<String>.from(snapshot['keywords'] ?? []);
    final phaseHint = snapshot['phaseHint'] ?? 'Discovery';
    final createdAt = DateTime.tryParse(snapshot['createdAt'] ?? '') ?? DateTime.now();
    
    // Generate 3D constellation data
    final arcformData = _generateArcformData(snapshot, phaseHint);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: kcSurfaceColor,
      child: InkWell(
        onTap: () {
          // Go directly to full-screen 3D view
          _showFullScreenArcform(phaseHint);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with constellation icon
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: kcPrimaryColor,
                    size: 20, // Reduced from 24
                  ),
                  const SizedBox(width: 6), // Reduced from 8
                  Expanded(
                    child: Text(
                      '$phaseHint Phase',
                      style: heading3Style(context).copyWith(
                        fontSize: 16, // Reduced font size
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4), // Add spacing before chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                    decoration: BoxDecoration(
                      color: _getPhaseColor(phaseHint).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10), // Reduced from 12
                      border: Border.all(color: _getPhaseColor(phaseHint).withOpacity(0.3)),
                    ),
                    child: Text(
                      phaseHint.toUpperCase(),
                      style: TextStyle(
                        color: _getPhaseColor(phaseHint),
                        fontSize: 9, // Reduced from 10
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share button
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    color: kcSecondaryTextColor,
                    onPressed: () => _showShareSheetForSnapshot(context, snapshot, phaseHint, keywords, arcformData),
                    tooltip: 'Share this Phase',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 3D Constellation Preview
              Container(
                height: 200, // Increased from 150 to show full ARCform
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kcBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getPhaseColor(phaseHint).withOpacity(0.5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: arcformData != null
                      ? IgnorePointer(
                          ignoring: true, // Explicitly disable all pointer events
                          child: Arcform3D(
                            nodes: arcformData.nodes,
                            edges: arcformData.edges,
                            phase: arcformData.phase,
                            skin: arcformData.skin,
                            showNebula: true,
                            enableLabels: true, // Enable keyword labels
                            initialZoom: 1.5, // Zoom out further for card preview to show full ARCform
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                color: kcPrimaryColor.withOpacity(0.7),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Generating constellation...',
                                style: TextStyle(
                                  color: kcPrimaryColor.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${keywords.length} stars',
                                style: TextStyle(
                                  color: kcSecondaryTextColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Keywords as constellation points
              if (keywords.isNotEmpty) ...[
                Text(
                  'Phase Elements:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: kcSecondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: keywords.take(6).map((keyword) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPhaseColor(phaseHint).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getPhaseColor(phaseHint).withOpacity(0.3)),
                    ),
                    child: Text(
                      keyword,
                      style: TextStyle(
                        color: _getPhaseColor(phaseHint),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
                
                if (keywords.length > 6) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${keywords.length - 6} more points',
                    style: TextStyle(
                      color: kcSecondaryTextColor,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // OTHER PHASE SHAPES PREVIEW
              _buildOtherPhasesSection(phaseHint),

              const SizedBox(height: 16),

              // Metadata
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: kcSecondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      color: kcSecondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Arcform3DData? _generateArcformData(Map<String, dynamic> snapshot, String phase) {
    try {
      // Check if we have stored 3D data
      if (snapshot['arcformData'] != null) {
        final arcformJson = snapshot['arcformData'] as Map<String, dynamic>;
        return Arcform3DData.fromJson(arcformJson);
      }
      
      // Fallback: generate from keywords if no 3D data
      final keywords = List<String>.from(snapshot['keywords'] ?? []);
      if (keywords.isEmpty) return null;

      final skin = ArcformSkin.forUser('user', snapshot['id']?.toString() ?? 'default');
      
      // Generate 3D layout
      final nodes = layout3D(
        keywords: keywords,
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in keywords) kw: 0.5 + (kw.length / 20.0)},
        keywordValences: {for (var kw in keywords) kw: _estimateValence(kw)},
      );

      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: phase,
        maxEdgesPerNode: 3,
        maxDistance: 1.2,
      );

      return Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: phase,
        skin: skin,
        title: snapshot['title'] ?? 'Constellation Visualization',
        content: snapshot['content']?.toString(),
        createdAt: DateTime.tryParse(snapshot['createdAt'] ?? '') ?? DateTime.now(),
        id: snapshot['id']?.toString() ?? 'unknown',
      );
    } catch (e) {
      print('Error generating ARCForm data: $e');
      return null;
    }
  }

  double _estimateValence(String keyword) {
    // Simple valence estimation based on keyword content
    final lower = keyword.toLowerCase();
    if (lower.contains('happy') || lower.contains('joy') || lower.contains('love') || 
        lower.contains('success') || lower.contains('growth') || lower.contains('positive')) {
      return 0.5 + (keyword.length / 40.0);
    } else if (lower.contains('sad') || lower.contains('angry') || lower.contains('fear') ||
               lower.contains('worry') || lower.contains('stress') || lower.contains('negative')) {
      return -0.5 - (keyword.length / 40.0);
    }
    return 0.0;
  }

  Future<Arcform3DData?> _generatePhaseConstellation(String phase, {bool isUserPhase = false}) async {
    try {
      // Capitalize the phase name for display
      final capitalizedPhase = phase.isEmpty 
          ? 'Discovery' 
          : phase[0].toUpperCase() + phase.substring(1).toLowerCase();
      
      // Create skin for this phase
      final skin = ArcformSkin.forUser('user', 'phase_$capitalizedPhase');

      // Get keywords: actual from journal if this is user's phase, hardcoded if demo/example
      final List<String> keywords;
      if (isUserPhase) {
        // User's actual phase - use real keywords from journal entries
        keywords = await _getActualPhaseKeywords(capitalizedPhase);
      } else {
        // Demo/example phase - use hardcoded keywords
        keywords = _getHardcodedPhaseKeywords(capitalizedPhase);
      }

      // Filter out blank keywords for 3D layout (keep only non-empty keywords)
      final nonEmptyKeywords = keywords.where((kw) => kw.isNotEmpty).toList();

      // Generate 3D layout with phase-optimized node count
      // Don't override maxNodes - let layout3D use the phase-optimized count
      final nodes = layout3D(
        keywords: nonEmptyKeywords.isNotEmpty ? nonEmptyKeywords : ['Phase'], // Fallback to at least one node
        phase: capitalizedPhase,
        skin: skin,
        keywordWeights: {for (var kw in nonEmptyKeywords) kw: 0.6 + (kw.length / 30.0)},
        keywordValences: {for (var kw in nonEmptyKeywords) kw: _getPhaseValence(kw, capitalizedPhase)},
      );

      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: capitalizedPhase,
        maxEdgesPerNode: 4,
        maxDistance: 1.4,
      );

      return Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: capitalizedPhase,
        skin: skin,
        title: '$capitalizedPhase Constellation',
        content: isUserPhase
            ? 'Your personal 3D constellation for $capitalizedPhase phase'
            : 'Example 3D constellation for $capitalizedPhase phase',
        createdAt: DateTime.now(),
        id: 'phase_${capitalizedPhase.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      print('Error generating phase constellation for $phase: $e');
      return null;
    }
  }

  /// Check if user has journal entries for a given phase
  Future<bool> _hasEntriesForPhase(String phase) async {
    try {
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntriesSync();
      
      if (allEntries.isEmpty) {
        print('DEBUG: _hasEntriesForPhase($phase) - No entries found');
        return false;
      }
      
      // Try to get phase regime for this phase
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
        
        final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
        print('DEBUG: _hasEntriesForPhase($phase) - Total regimes: ${allRegimes.length}');
        
        // Find regime for this phase
        final regimes = allRegimes
            .where((r) => r.label.toString().split('.').last.toLowerCase() == phase.toLowerCase())
            .toList();
        
        print('DEBUG: _hasEntriesForPhase($phase) - Found ${regimes.length} regimes for this phase');
        
        if (regimes.isNotEmpty) {
          // Check if there are entries in this regime's timeframe
          for (final regime in regimes) {
            final regimeStart = regime.start;
            final regimeEnd = regime.end ?? DateTime.now();
            
            final entriesInRegime = allEntries
                .where((entry) => entry.createdAt.isAfter(regimeStart.subtract(const Duration(days: 1))) && 
                                  entry.createdAt.isBefore(regimeEnd.add(const Duration(days: 1))))
                .toList();
            
            if (entriesInRegime.isNotEmpty) {
              print('DEBUG: _hasEntriesForPhase($phase) - Found ${entriesInRegime.length} entries in regime (${regimeStart} to ${regimeEnd})');
              return true;
            }
          }
        }
        
        // Special case for Discovery: check if there are entries before the first regime
        if (phase.toLowerCase() == 'discovery' && allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)..sort((a, b) => a.start.compareTo(b.start));
          final firstRegime = sortedRegimes.first;
          
          final entriesBeforeFirstRegime = allEntries
              .where((entry) => entry.createdAt.isBefore(firstRegime.start))
              .toList();
          
          if (entriesBeforeFirstRegime.isNotEmpty) {
            print('DEBUG: _hasEntriesForPhase($phase) - Found ${entriesBeforeFirstRegime.length} entries before first regime (${firstRegime.start})');
            return true;
          }
        }
      } catch (e) {
        print('DEBUG: Error checking phase regime for $phase: $e');
      }
      
      // Fallback: check if phase is in experienced phases
      final inExperiencedPhases = _userExperiencedPhases.contains(phase.toLowerCase());
      print('DEBUG: _hasEntriesForPhase($phase) - Fallback check: inExperiencedPhases=$inExperiencedPhases');
      return inExperiencedPhases;
    } catch (e) {
      print('ERROR: Failed to check entries for phase $phase: $e');
      return false;
    }
  }

    /// Get actual keywords from user's journal entries for their current phase
    /// Uses the same method as ARCForm Timeline for consistency
    Future<List<String>> _getActualPhaseKeywords(String phase) async {
        try {
          final journalRepo = JournalRepository();
          final allEntries = journalRepo.getAllJournalEntriesSync();
          
          // Try to get phase regime data to find entries by date range (same as Timeline)
          try {
            final analyticsService = AnalyticsService();
            final rivetSweepService = RivetSweepService(analyticsService);
            final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
            await phaseRegimeService.initialize();
            
            // Find regime(s) for the requested phase (same as Timeline)
            final phaseRegimes = phaseRegimeService.phaseIndex.allRegimes
                .where((r) => r.label.toString().split('.').last.toLowerCase() == phase.toLowerCase())
                .toList();
            
            List<JournalEntry> regimeEntries = [];
            
            if (phaseRegimes.isNotEmpty) {
              // Use entries from all regimes of this phase (same as Timeline)
              for (final regime in phaseRegimes) {
                final regimeStart = regime.start;
                final regimeEnd = regime.end ?? DateTime.now();
                
                final entriesInRegime = allEntries
                    .where((entry) => 
                        entry.createdAt.isAfter(regimeStart.subtract(const Duration(days: 1))) && 
                        entry.createdAt.isBefore(regimeEnd.add(const Duration(days: 1))))
                    .toList();
                
                regimeEntries.addAll(entriesInRegime);
              }
                  
              print('DEBUG: Found ${regimeEntries.length} entries in $phase phase regime(s)');
            } else if (phase.toLowerCase() == 'discovery') {
              // Special case for Discovery: get entries before first regime
              final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
              if (allRegimes.isNotEmpty) {
                final sortedRegimes = List.from(allRegimes)..sort((a, b) => a.start.compareTo(b.start));
                final firstRegime = sortedRegimes.first;
                
                regimeEntries = allEntries
                    .where((entry) => entry.createdAt.isBefore(firstRegime.start))
                    .toList();
                
                print('DEBUG: Found ${regimeEntries.length} entries before first regime for Discovery phase');
              } else {
                // No regimes at all - use all entries
                regimeEntries = allEntries;
                print('DEBUG: No regimes found - using all ${regimeEntries.length} entries for Discovery');
              }
            } else {
              // Fallback: get recent entries (last 30 days)
              final recentCutoff = DateTime.now().subtract(const Duration(days: 30));
              regimeEntries = allEntries
                  .where((entry) => entry.createdAt.isAfter(recentCutoff))
                  .toList();
                  
              print('DEBUG: Using fallback - found ${regimeEntries.length} recent entries');
            }
            
            if (regimeEntries.isEmpty) {
              print('DEBUG: No entries found for $phase phase, using hardcoded keywords');
              return _getHardcodedPhaseKeywords(phase);
            }

            // Use the same method as Timeline: get keywords from entry.keywords
            final allKeywords = <String>[];
            for (final entry in regimeEntries) {
              allKeywords.addAll(entry.keywords);
            }

            // Count keyword frequency (same as Timeline)
            final keywordCounts = <String, int>{};
            for (final keyword in allKeywords) {
              keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
            }

            // Sort by frequency and get top keywords (same as Timeline)
            final sortedKeywords = keywordCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            // Get top 15-20 keywords (most popular from this phase) - same as Timeline
            final topKeywords = sortedKeywords
                .take(20)
                .map((e) => e.key)
                .where((kw) => kw.isNotEmpty)
                .toList();

            print('DEBUG: Found ${topKeywords.length} top keywords for $phase phase');
            
            // Also get aggregated keywords from entry content (same as Timeline)
            final journalTexts = regimeEntries.map((e) => e.content).toList();
            final aggregatedKeywords = KeywordAggregator.getTopAggregatedKeywords(
              journalTexts,
              topN: 10,
            );

            // Combine and deduplicate (same as Timeline)
            final combinedKeywords = <String>[];
            combinedKeywords.addAll(topKeywords);
            combinedKeywords.addAll(aggregatedKeywords);
            
            final uniqueKeywords = combinedKeywords.toSet().toList();
            
            print('DEBUG: Combined ${topKeywords.length} entry keywords with ${aggregatedKeywords.length} aggregated keywords');
            print('DEBUG: Total unique keywords: ${uniqueKeywords.length}');

            return uniqueKeywords.take(20).toList();
          } catch (e) {
            print('DEBUG: Error accessing phase regime data: $e');
            // Fallback: get recent entries (last 30 days)
            final recentCutoff = DateTime.now().subtract(const Duration(days: 30));
            final recentEntries = allEntries
                .where((entry) => entry.createdAt.isAfter(recentCutoff))
                .toList();
            
            if (recentEntries.isEmpty) {
              return _getHardcodedPhaseKeywords(phase);
            }
            
            // Use same method: entry.keywords + aggregated
            final allKeywords = <String>[];
            for (final entry in recentEntries) {
              allKeywords.addAll(entry.keywords);
            }
            
            final keywordCounts = <String, int>{};
            for (final keyword in allKeywords) {
              keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
            }
            
            final sortedKeywords = keywordCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            
            final topKeywords = sortedKeywords
                .take(20)
                .map((e) => e.key)
                .where((kw) => kw.isNotEmpty)
                .toList();
            
            final journalTexts = recentEntries.map((e) => e.content).toList();
            final aggregatedKeywords = KeywordAggregator.getTopAggregatedKeywords(
              journalTexts,
              topN: 10,
            );
            
            final combinedKeywords = <String>[];
            combinedKeywords.addAll(topKeywords);
            combinedKeywords.addAll(aggregatedKeywords);
            
            return combinedKeywords.toSet().toList().take(20).toList();
          }
        } catch (e) {
          print('ERROR: Failed to load actual keywords for $phase: $e');
          return _getHardcodedPhaseKeywords(phase);
        }
      }

  /// Get hardcoded demo keywords for example/demo phases
  List<String> _getHardcodedPhaseKeywords(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return [
          'growth', 'insight', 'learning', 'curiosity', 'exploration',
          'discovery', 'wonder', 'creativity', 'innovation', 'breakthrough',
          'transformation', 'journey', 'adventure', 'possibility', 'potential',
          'excitement', 'enthusiasm', 'energy', 'inspiration', 'vision'
        ];
      case 'exploration':
      case 'expansion':
        return [
          'expansion', 'growth', 'opportunity', 'success', 'achievement',
          'progress', 'momentum', 'confidence', 'strength', 'power',
          'ambition', 'drive', 'determination', 'focus', 'clarity',
          'vision', 'purpose', 'direction', 'leadership', 'influence'
        ];
      case 'transition':
        return [
          'change', 'transition', 'shift', 'adaptation', 'flexibility',
          'uncertainty', 'anxiety', 'hope', 'anticipation', 'preparation',
          'letting go', 'moving forward', 'new beginnings', 'closure',
          'reflection', 'integration', 'balance', 'harmony', 'patience', 'trust'
        ];
      case 'consolidation':
        return [
          'stability', 'consolidation', 'integration', 'synthesis', 'wholeness',
          'completion', 'mastery', 'expertise', 'wisdom', 'understanding',
          'peace', 'contentment', 'satisfaction', 'fulfillment', 'gratitude',
          'appreciation', 'celebration', 'joy', 'serenity', 'tranquility'
        ];
      case 'recovery':
        return [
          'healing', 'recovery', 'restoration', 'renewal', 'rebirth',
          'gentleness', 'self-care', 'compassion', 'patience', 'acceptance',
          'forgiveness', 'release', 'letting go', 'peace', 'tranquility',
          'serenity', 'calm', 'stillness', 'rest', 'nurturing'
        ];
      case 'breakthrough':
        return [
          'breakthrough', 'revelation', 'epiphany', 'awakening', 'enlightenment',
          'transcendence', 'liberation', 'freedom', 'clarity', 'understanding',
          'wisdom', 'transformation', 'evolution', 'ascension', 'elevation',
          'illumination', 'realization', 'insight', 'clarity', 'vision'
        ];
      default:
        return [
          'balance', 'harmony', 'equilibrium', 'stability', 'peace',
          'contentment', 'satisfaction', 'well-being', 'health', 'vitality',
          'energy', 'strength', 'resilience', 'adaptability', 'flexibility',
          'growth', 'learning', 'development', 'wisdom', 'understanding'
        ];
    }
  }

  double _getPhaseValence(String keyword, String phase) {
    final lower = keyword.toLowerCase();
    
    // Phase-specific valence mapping
    switch (phase.toLowerCase()) {
      case 'discovery':
        if (lower.contains('growth') || lower.contains('learning') || lower.contains('curiosity') ||
            lower.contains('exploration') || lower.contains('wonder') || lower.contains('creativity') ||
            lower.contains('innovation') || lower.contains('breakthrough') || lower.contains('excitement')) {
          return 0.6 + (keyword.length / 50.0);
        }
        return 0.2 + (keyword.length / 60.0);
        
      case 'exploration':
      case 'expansion':
        if (lower.contains('success') || lower.contains('achievement') || lower.contains('progress') ||
            lower.contains('confidence') || lower.contains('strength') || lower.contains('power') ||
            lower.contains('ambition') || lower.contains('drive') || lower.contains('leadership')) {
          return 0.7 + (keyword.length / 40.0);
        }
        return 0.3 + (keyword.length / 50.0);
        
      case 'transition':
        if (lower.contains('hope') || lower.contains('anticipation') || lower.contains('new beginnings') ||
            lower.contains('balance') || lower.contains('harmony') || lower.contains('trust')) {
          return 0.3 + (keyword.length / 60.0);
        } else if (lower.contains('uncertainty') || lower.contains('anxiety') || lower.contains('letting go')) {
          return -0.2 - (keyword.length / 80.0);
        }
        return 0.0;
        
      case 'consolidation':
        if (lower.contains('stability') || lower.contains('mastery') || lower.contains('wisdom') ||
            lower.contains('peace') || lower.contains('contentment') || lower.contains('fulfillment') ||
            lower.contains('gratitude') || lower.contains('celebration') || lower.contains('joy')) {
          return 0.8 + (keyword.length / 45.0);
        }
        return 0.4 + (keyword.length / 55.0);
        
      case 'recovery':
        if (lower.contains('healing') || lower.contains('renewal') || lower.contains('gentleness') ||
            lower.contains('compassion') || lower.contains('acceptance') || lower.contains('forgiveness') ||
            lower.contains('peace') || lower.contains('serenity') || lower.contains('nurturing')) {
          return 0.5 + (keyword.length / 50.0);
        }
        return 0.1 + (keyword.length / 70.0);
        
      case 'breakthrough':
        if (lower.contains('breakthrough') || lower.contains('revelation') || lower.contains('epiphany') ||
            lower.contains('awakening') || lower.contains('enlightenment') || lower.contains('transcendence') ||
            lower.contains('liberation') || lower.contains('freedom') || lower.contains('illumination')) {
          return 0.9 + (keyword.length / 35.0);
        }
        return 0.6 + (keyword.length / 45.0);
        
      default:
        if (lower.contains('balance') || lower.contains('harmony') || lower.contains('peace') ||
            lower.contains('contentment') || lower.contains('well-being') || lower.contains('growth')) {
          return 0.4 + (keyword.length / 50.0);
        }
        return 0.0;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  /// Show full-screen 3D ARCForm viewer for a specific phase
  void _showFullScreenArcform(String phase) async {
    // Check if this is a phase the user has experienced (current OR past phases)
    final isUserPhase = _userExperiencedPhases.contains(phase.toLowerCase());

    print('DEBUG: Viewing $phase phase - isUserPhase: $isUserPhase (experienced phases: $_userExperiencedPhases)');

    // Generate constellation data for this phase
    final arcform = await _generatePhaseConstellation(phase, isUserPhase: isUserPhase);

    if (arcform == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate constellation for $phase phase')),
        );
      }
      return;
    }

    // Navigate directly to full-screen viewer
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenPhaseViewer(arcform: arcform),
        ),
      );
    }
  }

  /// Build section showing other phase shapes as examples
  Widget _buildOtherPhasesSection(String currentPhase) {
    // Get list of other phases to show (exclude current phase)
    final allPhases = [
      'Discovery',
      'Expansion',
      'Transition',
      'Consolidation',
      'Recovery',
      'Breakthrough',
    ];

    final otherPhases = allPhases
        .where((phase) => phase.toLowerCase() != currentPhase.toLowerCase())
        .toList();

    if (otherPhases.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other Phase Shapes:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: kcSecondaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: otherPhases.map((phase) => _buildPhasePreviewChip(phase)).toList(),
        ),
      ],
    );
  }

  /// Build a small chip showing a phase preview
  Widget _buildPhasePreviewChip(String phase) {
    final phaseColor = _getPhaseColor(phase);
    return GestureDetector(
      onTap: () {
        // Navigate to this phase's full 3D view
        _showFullScreenArcform(phase);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: phaseColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: phaseColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phase icon (different for each phase type)
            Icon(
              _getPhaseIcon(phase),
              color: phaseColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              phase,
              style: TextStyle(
                color: phaseColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get icon for each phase type
  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Icons.explore;
      case 'expansion':
        return Icons.air;
      case 'transition':
        return Icons.shuffle;
      case 'consolidation':
        return Icons.verified;
      case 'recovery':
        return Icons.spa;
      case 'breakthrough':
        return Icons.auto_awesome;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  /// Get color for phase name (matches Phase Legend colors)
  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF7C3AED); // Purple
      case 'expansion':
        return const Color(0xFF059669); // Green
      case 'transition':
        return const Color(0xFFD97706); // Orange
      case 'consolidation':
        return const Color(0xFF2563EB); // Blue
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFFFBBF24); // Yellow
      default:
        return kcPrimaryColor;
    }
  }

  void _showShareSheetForSnapshot(
    BuildContext context,
    Map<String, dynamic> snapshot,
    String phase,
    List<String> keywords,
    Arcform3DData? arcformData,
  ) {
    // Get arcform ID from snapshot
    final arcformId = snapshot['id'] as String? ?? snapshot['arcformId'] as String? ?? 'current';
    
    // Create initial payload
    final payload = ArcformSharePayload(
      shareMode: ArcShareMode.social, // Default to social
      arcformId: arcformId,
      phase: phase,
      keywords: keywords,
    );

    // Create preview widget if arcform data is available
    Widget? preview;
    if (arcformData != null) {
      preview = Arcform3D(
        nodes: arcformData.nodes,
        edges: arcformData.edges,
        phase: arcformData.phase,
        skin: arcformData.skin,
        showNebula: true,
        enableLabels: true,
      );
    }

    showArcformShareSheet(
      context: context,
      payload: payload,
      fromView: 'timeline_card',
      arcformPreview: preview,
    );
  }
}
