import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:my_app/arc/ui/arcforms/arcform_renderer_cubit.dart';
import 'package:my_app/arc/ui/arcforms/arcform_renderer_state.dart';
// import 'package:my_app/arc/ui/arcforms/widgets/arcform_layout.dart';
import 'package:my_app/arc/ui/arcforms/widgets/simple_3d_arcform.dart';
import 'package:my_app/arc/ui/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/arc/ui/arcforms/services/emotional_valence_service.dart';
import 'package:my_app/arc/ui/arcforms/constellation/constellation_arcform_renderer.dart';
import 'package:my_app/shared/ui/onboarding/phase_celebration_view.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/arcform_export_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class ArcformRendererView extends StatelessWidget {
  const ArcformRendererView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ArcformRendererCubit()..initialize(),
      child: const ArcformRendererViewContent(),
    );
  }
}

class ArcformRendererViewContent extends StatefulWidget {
  const ArcformRendererViewContent({super.key});

  @override
  State<ArcformRendererViewContent> createState() => _ArcformRendererViewContentState();
}

class _ArcformRendererViewContentState extends State<ArcformRendererViewContent> {
  final GlobalKey _arcformRepaintBoundaryKey = GlobalKey();
  
  // New state for phase selection UI
  bool _showGeometrySelector = false;
  String? _previewPhase;
  GeometryPattern? _previewGeometry;

  @override
  void initState() {
    super.initState();
    // Refresh the phase cache when the Phase tab is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPhaseFromCache();
    });
  }

  /// Refresh the phase from the user profile cache
  Future<void> _refreshPhaseFromCache() async {
    try {
      final currentPhase = await UserPhaseService.getCurrentPhase();
      final cubit = context.read<ArcformRendererCubit>();
      final correctGeometry = _phaseToGeometryPattern(currentPhase);
      
      // Update the cubit with the current phase from cache
      cubit.changePhaseAndGeometry(currentPhase, correctGeometry);
      print('DEBUG: Refreshed phase from cache: $currentPhase with geometry $correctGeometry');
    } catch (e) {
      print('DEBUG: Error refreshing phase from cache: $e');
    }
  }

  ArcformGeometry _convertToArcformGeometry(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return ArcformGeometry.spiral;
      case GeometryPattern.flower:
        return ArcformGeometry.flower;
      case GeometryPattern.branch:
        return ArcformGeometry.branch;
      case GeometryPattern.weave:
        return ArcformGeometry.weave;
      case GeometryPattern.glowCore:
        return ArcformGeometry.glowCore;
      case GeometryPattern.fractal:
        return ArcformGeometry.fractal;
    }
  }

  AtlasPhase _convertToAtlasPhase(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return AtlasPhase.discovery;
      case GeometryPattern.flower:
        return AtlasPhase.expansion;
      case GeometryPattern.branch:
        return AtlasPhase.transition;
      case GeometryPattern.weave:
        return AtlasPhase.consolidation;
      case GeometryPattern.glowCore:
        return AtlasPhase.recovery;
      case GeometryPattern.fractal:
        return AtlasPhase.breakthrough;
    }
  }

  List<KeywordScore> _convertNodesToKeywords(List<Node> nodes) {
    final emotionalService = EmotionalValenceService();
    return nodes.map((node) {
      final sentiment = emotionalService.getEmotionalValence(node.label);
      return KeywordScore(
        text: node.label,
        score: node.size / 20.0, // Normalize size to 0-1 range
        sentiment: sentiment,
      );
    }).toList();
  }

  Widget _buildConstellationArcformCard(BuildContext context, String currentPhase, GeometryPattern geometry) {
    final description = UserPhaseService.getPhaseDescription(currentPhase);
    final phaseColor = _getPhaseColor(geometry);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: phaseColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stars,
                color: Color(0xFFD1B3FF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Constellation Arcform',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _exportArcform(context, context.read<ArcformRendererCubit>().state as ArcformRendererLoaded),
                icon: const Icon(
                  Icons.share,
                  color: Color(0xFFD1B3FF),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicatorWithChangeButton(BuildContext context, String currentPhase, GeometryPattern geometry, ArcformRendererMode rendererMode) {
    print('DEBUG: _buildPhaseIndicatorWithChangeButton - currentPhase: $currentPhase, geometry: $geometry');
    final description = UserPhaseService.getPhaseDescription(currentPhase);
    final phaseColor = _getPhaseColor(geometry);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            phaseColor.withOpacity(0.1),
            phaseColor.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: phaseColor.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: phaseColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'CURRENT PHASE',
                    style: captionStyle(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Renderer mode toggle button
              Flexible(
                child: GestureDetector(
                  onTap: () => _toggleRendererMode(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kcSurfaceAltColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: phaseColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars,
                          color: phaseColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            rendererMode == ArcformRendererMode.constellation ? 'Constellation' : 'Molecule 3D',
                            style: captionStyle(context).copyWith(
                              color: phaseColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Phase change button
              GestureDetector(
                onTap: () => rendererMode == ArcformRendererMode.constellation 
                    ? _showConstellationPhaseSelector(context)
                    : _showGeometrySelectorDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kcSurfaceAltColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: phaseColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        color: phaseColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Change',
                        style: captionStyle(context).copyWith(
                          color: phaseColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _getPhaseIcon(geometry),
                color: phaseColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            currentPhase.toUpperCase(),
            style: heading1Style(context).copyWith(
              color: phaseColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: bodyStyle(context).copyWith(
              color: phaseColor.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPhaseColor(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return const Color(0xFF4F46E5); // Discovery - Blue
      case GeometryPattern.flower:
        return const Color(0xFF7C3AED); // Expansion - Purple  
      case GeometryPattern.branch:
        return const Color(0xFF059669); // Transition - Green
      case GeometryPattern.weave:
        return const Color(0xFFD97706); // Consolidation - Orange
      case GeometryPattern.glowCore:
        return const Color(0xFFDC2626); // Recovery - Red
      case GeometryPattern.fractal:
        return const Color(0xFF7C2D12); // Breakthrough - Brown
    }
  }

  IconData _getPhaseIcon(GeometryPattern geometry) {
    switch (geometry) {
      case GeometryPattern.spiral:
        return Icons.explore; // Discovery
      case GeometryPattern.flower:
        return Icons.local_florist; // Expansion
      case GeometryPattern.branch:
        return Icons.account_tree; // Transition
      case GeometryPattern.weave:
        return Icons.grid_view; // Consolidation
      case GeometryPattern.glowCore:
        return Icons.healing; // Recovery
      case GeometryPattern.fractal:
        return Icons.auto_fix_high; // Breakthrough
    }
  }

  void _showKeywordDialog(BuildContext context, String keyword) {
    final emotionalService = EmotionalValenceService();
    final emotionalColor = emotionalService.getEmotionalColor(keyword);
    final temperature = emotionalService.getTemperatureDescription(keyword);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kcSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: emotionalColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: emotionalColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  keyword,
                  style: heading1Style(context).copyWith(
                    color: emotionalColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: emotionalColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    temperature,
                    style: captionStyle(context).copyWith(
                      color: emotionalColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: buttonStyle(context).copyWith(
                  color: kcPrimaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleRendererMode() {
    final cubit = context.read<ArcformRendererCubit>();
    final currentState = cubit.state;
    
    if (currentState is ArcformRendererLoaded) {
      final newMode = currentState.rendererMode == ArcformRendererMode.constellation
          ? ArcformRendererMode.molecule3d
          : ArcformRendererMode.constellation;
      
      cubit.changeRendererMode(newMode);
      
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${newMode == ArcformRendererMode.constellation ? 'Constellation' : 'Molecule 3D'} mode'),
          backgroundColor: kcPrimaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showGeometrySelectorDialog() {
    setState(() {
      _showGeometrySelector = true;
      _previewPhase = null;
      _previewGeometry = null;
    });
  }

  void _showConstellationPhaseSelector(BuildContext context) {
    final cubit = context.read<ArcformRendererCubit>();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD1B3FF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1B3FF).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          color: Color(0xFFD1B3FF),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Constellation Arcform',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a phase to preview its geometry:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Phase options - wrapped in Flexible to prevent overflow
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPhaseOption(context, cubit, AtlasPhase.discovery, 'Discovery'),
                        _buildPhaseOption(context, cubit, AtlasPhase.expansion, 'Expansion'),
                        _buildPhaseOption(context, cubit, AtlasPhase.transition, 'Transition'),
                        _buildPhaseOption(context, cubit, AtlasPhase.consolidation, 'Consolidation'),
                        _buildPhaseOption(context, cubit, AtlasPhase.recovery, 'Recovery'),
                        _buildPhaseOption(context, cubit, AtlasPhase.breakthrough, 'Breakthrough'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseOption(BuildContext context, ArcformRendererCubit cubit, AtlasPhase phase, String displayName) {
    final phaseColor = _getAtlasPhaseColor(phase);
    final currentState = cubit.state;
    final isSelected = currentState is ArcformRendererLoaded && 
        _convertToAtlasPhase(currentState.selectedGeometry) == phase;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _changeConstellationPhase(context, cubit, phase);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? phaseColor.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? phaseColor : Colors.grey[700]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getAtlasPhaseIcon(phase),
                  color: phaseColor,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: phaseColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _changeConstellationPhase(BuildContext context, ArcformRendererCubit cubit, AtlasPhase phase) {
    try {
      final geometryPattern = _convertAtlasPhaseToGeometryPattern(phase);
      final phaseName = _getAtlasPhaseName(phase);
      
      // Update user profile
      _updateUserPhase(phaseName);
      
      cubit.changePhaseAndGeometry(phaseName, geometryPattern);
      
      // Show phase celebration
      _showPhaseCelebration(phaseName);
    } catch (e) {
      print('ERROR: Failed to change constellation phase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error changing phase: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  GeometryPattern _convertAtlasPhaseToGeometryPattern(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.discovery:
        return GeometryPattern.spiral;
      case AtlasPhase.expansion:
        return GeometryPattern.flower;
      case AtlasPhase.transition:
        return GeometryPattern.branch;
      case AtlasPhase.consolidation:
        return GeometryPattern.weave;
      case AtlasPhase.recovery:
        return GeometryPattern.glowCore;
      case AtlasPhase.breakthrough:
        return GeometryPattern.fractal;
    }
  }

  String _getAtlasPhaseName(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.discovery:
        return 'Discovery';
      case AtlasPhase.expansion:
        return 'Expansion';
      case AtlasPhase.transition:
        return 'Transition';
      case AtlasPhase.consolidation:
        return 'Consolidation';
      case AtlasPhase.recovery:
        return 'Recovery';
      case AtlasPhase.breakthrough:
        return 'Breakthrough';
    }
  }

  Color _getAtlasPhaseColor(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.discovery:
        return const Color(0xFF4F46E5); // Blue
      case AtlasPhase.expansion:
        return const Color(0xFF7C3AED); // Purple
      case AtlasPhase.transition:
        return const Color(0xFF059669); // Green
      case AtlasPhase.consolidation:
        return const Color(0xFFD97706); // Orange
      case AtlasPhase.recovery:
        return const Color(0xFFDC2626); // Red
      case AtlasPhase.breakthrough:
        return const Color(0xFF7C2D12); // Brown
    }
  }

  IconData _getAtlasPhaseIcon(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.discovery:
        return Icons.explore;
      case AtlasPhase.expansion:
        return Icons.local_florist;
      case AtlasPhase.transition:
        return Icons.account_tree;
      case AtlasPhase.consolidation:
        return Icons.grid_view;
      case AtlasPhase.recovery:
        return Icons.healing;
      case AtlasPhase.breakthrough:
        return Icons.auto_fix_high;
    }
  }

  void _hideGeometrySelectorDialog() {
    setState(() {
      _showGeometrySelector = false;
      _previewPhase = null;
      _previewGeometry = null;
    });
  }

  void _handlePhasePreview(String phase) {
    setState(() {
      _previewPhase = phase;
      _previewGeometry = _phaseToGeometryPattern(phase);
    });
    
    // Update the cubit to show preview
    final cubit = context.read<ArcformRendererCubit>();
    cubit.explorePhaseGeometry(_previewGeometry!);
  }

  void _savePhase() async {
    if (_previewPhase != null && _previewGeometry != null) {
      // Store the phase name before clearing the preview state
      final savedPhase = _previewPhase!;
      
      // Update the user profile
      await _updateUserPhase(savedPhase);
      
      // Update the cubit with the new phase
      final cubit = context.read<ArcformRendererCubit>();
      cubit.changePhaseAndGeometry(savedPhase, _previewGeometry!);
      
      // Hide the dialog
      _hideGeometrySelectorDialog();
      
      // Show phase celebration
      _showPhaseCelebration(savedPhase);
    }
  }


  /// Update the user's phase in the user profile to refresh the phase cache
  Future<void> _updateUserPhase(String newPhase) async {
    try {
      // Import Hive and UserProfile
      final userBox = Hive.box('user_profile');
      final userProfile = userBox.get('profile');
      
      if (userProfile != null) {
        // Update the onboarding current season with the new phase
        final updatedProfile = userProfile.copyWith(
          onboardingCurrentSeason: newPhase,
        );
        await userBox.put('profile', updatedProfile);
        print('DEBUG: Updated user profile phase to: $newPhase');
      }
    } catch (e) {
      print('DEBUG: Error updating user phase: $e');
    }
  }

  /// Show phase celebration when user changes phase
  void _showPhaseCelebration(String phase) {
    final phaseDescription = UserPhaseService.getPhaseDescription(phase);
    String phaseEmoji;
    
    switch (phase.toLowerCase()) {
      case 'discovery':
        phaseEmoji = '🌱';
        break;
      case 'expansion':
        phaseEmoji = '🌸';
        break;
      case 'transition':
        phaseEmoji = '🌿';
        break;
      case 'consolidation':
        phaseEmoji = '🧵';
        break;
      case 'recovery':
        phaseEmoji = '✨';
        break;
      case 'breakthrough':
        phaseEmoji = '💥';
        break;
      default:
        phaseEmoji = '🌱';
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhaseCelebrationView(
          discoveredPhase: phase,
          phaseDescription: phaseDescription,
          phaseEmoji: phaseEmoji,
        ),
      ),
    );
  }

  GeometryPattern _phaseToGeometryPattern(String phase) {
    switch (phase) {
      case 'Discovery':
        return GeometryPattern.spiral;
      case 'Expansion':
        return GeometryPattern.flower;
      case 'Transition':
        return GeometryPattern.branch;
      case 'Consolidation':
        return GeometryPattern.weave;
      case 'Recovery':
        return GeometryPattern.glowCore;
      case 'Breakthrough':
        return GeometryPattern.fractal;
      default:
        return GeometryPattern.spiral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArcformRendererCubit, ArcformRendererState>(
      builder: (context, state) {
        if (state is ArcformRendererInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ArcformRendererLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ArcformRendererError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading Arcform',
                  style: heading2Style(context),
                ),
                const SizedBox(height: 10),
                Text(
                  state.message,
                  style: bodyStyle(context),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    context.read<ArcformRendererCubit>().initialize();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                  ),
                  child: Text('Retry', style: buttonStyle(context)),
                ),
              ],
            ),
          );
        }

        if (state is ArcformRendererLoaded) {
          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Phase indicator header with change button
                    _buildPhaseIndicatorWithChangeButton(context, state.currentPhase, state.selectedGeometry, state.rendererMode),
                    // Constellation Arcform card (moved higher to avoid blocking constellation)
                    if (state.rendererMode == ArcformRendererMode.constellation)
                      _buildConstellationArcformCard(context, state.currentPhase, state.selectedGeometry),
                    // Main Arcform layout - switch between 2D and 3D
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(top: 4, bottom: 70), // Reduced top padding to move interface higher and bottom padding for navigation bar
                        child: RepaintBoundary(
                          key: _arcformRepaintBoundaryKey,
                          child: state.rendererMode == ArcformRendererMode.constellation
                              ? ConstellationArcformRenderer(
                                  phase: _convertToAtlasPhase(state.selectedGeometry),
                                  keywords: _convertNodesToKeywords(state.nodes),
                                  palette: EmotionPalette.defaultPalette,
                                  seed: 42,
                                  onNodeTapped: (nodeId) {
                                    // Find the node by ID and show dialog
                                    final node = state.nodes.firstWhere(
                                      (n) => n.id == nodeId,
                                      orElse: () => state.nodes.first,
                                    );
                                    _showKeywordDialog(context, node.label);
                                  },
                                  onExport: () => _exportArcform(context, state),
                                )
                              : Simple3DArcform(
                                  nodes: state.nodes,
                                  edges: state.edges,
                                  onNodeMoved: (nodeId, x, y) {
                                    context
                                        .read<ArcformRendererCubit>()
                                        .updateNodePosition(nodeId, x, y);
                                  },
                                  onNodeTapped: (keyword) {
                                    _showKeywordDialog(context, keyword);
                                  },
                                  selectedGeometry: _convertToArcformGeometry(state.selectedGeometry),
                                  onGeometryChanged: (geometry) {
                                    // Only refresh the cache when exploring different phases
                                    _refreshPhaseFromCache();
                                  },
                                  // New parameters for phase selection
                                  showGeometrySelector: _showGeometrySelector,
                                  previewPhase: _previewPhase,
                                  onPhasePreview: (phase) => _handlePhasePreview(phase),
                                  onSavePhase: _savePhase,
                                  onCancelPreview: _hideGeometrySelectorDialog,
                                  // on3DToggle removed - not supported by Simple3DArcform
                                  onExport: () => _exportArcform(context, state),
                                  onAutoRotate: () {
                                    // This will be handled by the Simple3DArcform widget
                                  },
                                  onResetView: () {
                                    // This will be handled by the Simple3DArcform widget
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return const Center(child: Text('Unknown state'));
      },
    );
  }

  /// Export arcform as PNG and share it
  void _exportArcform(BuildContext context, ArcformRendererLoaded state) {
    ArcformExportService.exportAndShareArcform(
      repaintBoundaryKey: _arcformRepaintBoundaryKey,
      phaseName: state.currentPhase,
      geometryName: state.selectedGeometry.name,
      context: context,
    );
  }
}
