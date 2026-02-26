import 'package:flutter/material.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/arcform/share/arcform_share_composition_screen.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';

class PhaseCelebrationView extends StatefulWidget {
  final String discoveredPhase;
  final String phaseDescription;
  final String phaseEmoji;

  const PhaseCelebrationView({
    super.key,
    required this.discoveredPhase,
    required this.phaseDescription,
    required this.phaseEmoji,
  });

  @override
  State<PhaseCelebrationView> createState() => _PhaseCelebrationViewState();
}

class _PhaseCelebrationViewState extends State<PhaseCelebrationView>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey _arcformRepaintBoundaryKey = GlobalKey();
  List<String> _arcformKeywords = [];
  Arcform3DData? _arcformData;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
    
    // Load Arcform data
    _loadArcformData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToPhaseTab() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeView(initialTab: 0), // LUMARA tab
      ),
      (route) => false,
    );
  }


  Future<void> _loadArcformData() async {
    try {
      // Generate Arcform data for current phase
      final phase = widget.discoveredPhase.toLowerCase();
      final skin = ArcformSkin.forUser('user', 'phase_$phase');
      
      // Get keywords for phase (simplified - in production, get from actual entries)
      _arcformKeywords = _getPhaseKeywords(phase);
      
      if (_arcformKeywords.isEmpty) {
        _arcformKeywords = ['Growth', 'Insight', 'Awareness'];
      }
      
      // Generate 3D layout
      final nodes = layout3D(
        keywords: _arcformKeywords,
        phase: phase,
        skin: skin,
        keywordWeights: {for (var kw in _arcformKeywords) kw: 0.6},
        keywordValences: {for (var kw in _arcformKeywords) kw: 0.0},
      );
      
      // Generate edges
      final rng = Seeded('${skin.seed}:edges');
      final edges = generateEdges(
        nodes: nodes,
        rng: rng,
        phase: phase,
        maxEdgesPerNode: 4,
        maxDistance: 1.4,
      );
      
      _arcformData = Arcform3DData(
        nodes: nodes,
        edges: edges,
        phase: phase,
        skin: skin,
        title: '$phase Constellation',
        content: 'Your $phase phase constellation',
        createdAt: DateTime.now(),
        id: 'phase_${phase}_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading Arcform data: $e');
    }
  }

  List<String> _getPhaseKeywords(String phase) {
    // Simplified keyword mapping - in production, get from actual journal entries
    switch (phase.toLowerCase()) {
      case 'discovery':
        return ['Exploration', 'Curiosity', 'Learning', 'New Paths'];
      case 'expansion':
        return ['Growth', 'Momentum', 'Reaching', 'Outward'];
      case 'transition':
        return ['Change', 'Shifting', 'Between', 'Transformation'];
      case 'consolidation':
        return ['Grounding', 'Weaving', 'Integration', 'Stability'];
      case 'recovery':
        return ['Healing', 'Rest', 'Renewal', 'Restoration'];
      case 'breakthrough':
        return ['Insight', 'Clarity', 'Sudden', 'Revelation'];
      default:
        return ['Growth', 'Insight', 'Awareness'];
    }
  }

  void _showShareSheet() {
    if (_arcformData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading Arcform...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to Arcform share composition screen
    // The composition screen will capture the Arcform using the repaintBoundaryKey
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArcformShareCompositionScreen(
          phase: widget.discoveredPhase,
          keywords: _arcformKeywords,
          arcformId: 'current',
          repaintBoundaryKey: _arcformRepaintBoundaryKey,
          transitionDate: DateTime.now(),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C0F14),
              Color(0xFF121621),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _slideAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Celebration emoji with scale animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: kcPrimaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(60),
                          border: Border.all(
                            color: kcPrimaryColor.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.phaseEmoji,
                            style: const TextStyle(fontSize: 60),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Phase name with slide animation
                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Text(
                            'You are in the',
                            style: bodyStyle(context).copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.discoveredPhase.toUpperCase(),
                            style: heading1Style(context).copyWith(
                              color: kcPrimaryColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Phase',
                            style: heading2Style(context).copyWith(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Description with slide animation
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kcPrimaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.phaseDescription,
                          style: bodyStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Primary button - "Explore Your Phase"
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        child: ElevatedButton(
                          onPressed: _navigateToPhaseTab,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kcPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Explore Your Phase',
                            style: heading3Style(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Share this moment button
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        child: OutlinedButton(
                          onPressed: _showShareSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: kcPrimaryColor.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.share_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Share this moment',
                                style: heading3Style(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Continue to App text link
                    SlideTransition(
                      position: _slideAnimation,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const HomeView()),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Continue to App',
                          style: bodyStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
