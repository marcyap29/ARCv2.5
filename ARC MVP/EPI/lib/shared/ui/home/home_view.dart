import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/ui/home/home_cubit.dart';
import 'package:my_app/shared/ui/home/home_state.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/tab_bar.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/core/services/audio_service.dart';
import 'package:my_app/mode/first_responder/widgets/fr_status_indicator.dart';
import 'package:my_app/mode/coach/widgets/coach_mode_status_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'dart:math' as math;
import 'package:my_app/shared/ui/journal/unified_journal_view.dart';
import 'package:my_app/shared/ui/insights/unified_insights_view.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/arc/chat/ui/lumara_assistant_screen.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/arc/chat/data/context_scope.dart';

// Debug flag for showing RIVET engineering labels
const bool kShowRivetDebugLabels = false;

class HomeView extends StatefulWidget {
  final int initialTab;
  
  const HomeView({super.key, this.initialTab = 0}); // Default to Phase tab (index 0)

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late HomeCubit _homeCubit;
  // Insights moved under Health as Analytics
  
  // Navigation: 3 main tabs (Journal + LUMARA + Insights)
  List<TabItem> get _tabs {
    return const [
      TabItem(icon: Icons.book, text: 'Journal'),
      TabItem(icon: Icons.psychology, text: 'LUMARA'),
      TabItem(icon: Icons.insights, text: 'Insights'),
    ];
  }

  List<String> get _tabNames {
    return const ['Journal', 'LUMARA', 'Insights'];
  }

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _homeCubit.initialize();
      if (widget.initialTab != 0) {
        _homeCubit.changeTab(widget.initialTab);
      } else {
        _homeCubit.changeTab(0); // Set Journal tab as default
      }

    // Check photo permissions and refresh timeline if granted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPhotoPermissionsAndRefresh();
    });
    
    // Initialize ethereal music (P22)
    _initializeEtherealMusic();
  }

  /// Check photo permissions and refresh timeline if granted
  Future<void> _checkPhotoPermissionsAndRefresh() async {
    try {
      print('DEBUG: Checking photo permissions...');
      final hasPermissions = await PhotoLibraryService.requestPermissions();
      if (hasPermissions) {
        print('DEBUG: Photo permissions granted, refreshing timeline...');
        // Refresh timeline to reload photo references
        context.read<TimelineCubit>().refreshEntries();
      } else {
        print('DEBUG: Photo permissions not granted');
      }
    } catch (e) {
      print('ERROR: Failed to check photo permissions: $e');
    }
  }

  Future<void> _initializeEtherealMusic() async {
    try {
      final audioService = AudioService();
      await audioService.initialize();
      
      // Start with ethereal track for sacred atmosphere
      await audioService.switchToEtherealTrack();
      
      // Fade in gently after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        audioService.fadeInEthereal(duration: const Duration(seconds: 4));
        
        // Play for 2 loops then fade out
        _scheduleFadeOut(audioService);
      });
      
      if (kDebugMode) {
        print('Ethereal music initialized and fading in');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize ethereal music: $e');
      }
    }
  }

  void _scheduleFadeOut(AudioService audioService) async {
    // Wait for approximately 2 loops of the ethereal track
    // Assuming track is about 2-3 minutes, wait for 4-6 minutes total
    await Future.delayed(const Duration(minutes: 5));
    
    // Fade out over 10 seconds
    await audioService.fadeOut(duration: const Duration(seconds: 10));
    print('DEBUG: HomeView - Ethereal music faded out after 2 loops');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _homeCubit,
              child: BlocListener<HomeCubit, HomeState>(
        listener: (context, state) {
          if (state is HomeLoaded) {
            // Track tab navigation
            AnalyticsService.trackTabNavigation(_tabNames[state.selectedIndex]);
            
            // Refresh timeline when switching to Journal tab (index 0)
            if (state.selectedIndex == 0) {
              context.read<TimelineCubit>().refreshEntries();
            }
            
            // Refresh phase cache when switching to Insights tab (index 2)
            if (state.selectedIndex == 2) {
              _refreshPhaseCache();
            }
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            final selectedIndex = state is HomeLoaded ? state.selectedIndex : 0;
            return Scaffold(
              appBar: AppBar(
                backgroundColor: kcBackgroundColor,
                elevation: 0,
                // Settings moved to TabBar as a tab
              ),
              body: SafeArea(
                child: Stack(
                  children: [
                    // Main content - use Expanded or SizedBox.expand to prevent overflow
                    Positioned.fill(
                      child: _getPageForIndex(selectedIndex, context),
                    ),
                    // Status indicators at top right
                    Positioned(
                      top: 0,
                      right: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.6,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FRStatusIndicator(),
                            CoachModeStatusIndicator(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: CustomTabBar(
                tabs: _tabs,
                selectedIndex: selectedIndex,
                onTabSelected: (index) {
                  print('DEBUG: Tab selected: $index');
                  print('DEBUG: Current selected index was: $selectedIndex');

                  _homeCubit.changeTab(index);
                },
                onNewJournalPressed: () async {
                  // Clear any existing session cache to ensure fresh start
                  await JournalSessionCache.clearSession();
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JournalScreen(),
                    ),
                  );
                },
                showCenterButton: false,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Get the appropriate page widget for the given index
  Widget _getPageForIndex(int index, BuildContext context) {
    switch (index) {
      case 0:
        return const UnifiedJournalView();
      case 1:
        // LUMARA - use Builder to get context with provider access
        return Builder(
          builder: (builderContext) {
            // Try to access cubit from app level
            try {
              final cubit = BlocProvider.of<LumaraAssistantCubit>(builderContext, listen: false);
              return BlocProvider.value(
                value: cubit,
                child: const LumaraAssistantScreen(),
              );
            } catch (e) {
              // If provider not available, create a local one
              debugPrint('LUMARA: Provider not found at app level, creating local instance: $e');
              return BlocProvider(
                create: (context) {
                  const scope = LumaraScope.defaultScope;
                  final contextProvider = ContextProvider(scope);
                  return LumaraAssistantCubit(
                    contextProvider: contextProvider,
                  )..initialize();
                },
                child: const LumaraAssistantScreen(),
              );
            }
          },
        );
      case 2:
        return const UnifiedInsightsView();
      default:
        return const UnifiedJournalView();
    }
  }

  /// Refresh the phase cache when Phase tab is opened
  Future<void> _refreshPhaseCache() async {
    try {
      // Import the UserPhaseService
      final currentPhase = await UserPhaseService.getCurrentPhase();
      print('DEBUG: Refreshed phase cache from Phase tab: $currentPhase');
    } catch (e) {
      print('DEBUG: Error refreshing phase cache from Phase tab: $e');
    }
  }
  
  


  @override
  void dispose() {
    _homeCubit.close();
    super.dispose();
  }
}

// Legacy Insights page moved under Health as Analytics
// Keeping removed implementation minimal to avoid dead code
/*
class _InsightsPage extends StatefulWidget {
  const _InsightsPage({super.key});

  @override
  State<_InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<_InsightsPage> with WidgetsBindingObserver {
  InsightCubit? _insightCubit;
  final GlobalKey<_RivetCardState> _rivetCardKey = GlobalKey<_RivetCardState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _patternsAnchor = GlobalKey();
  final GlobalKey _auroraAnchor = GlobalKey();
  final GlobalKey _veilAnchor = GlobalKey();
  final GlobalKey _themesAnchor = GlobalKey();
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('DEBUG: _InsightsPage initState called');
    // Initialize insight cubit after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('DEBUG: Post-frame callback executing');
      _initializeInsightCubit();
      // Refresh RIVET card when Insights page loads
      refreshRivetCard();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh RIVET card when dependencies change (e.g., when navigating to Insights)
    print('DEBUG: _InsightsPage didChangeDependencies called');
    refreshRivetCard();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh RIVET card when app becomes active (user might have added entries)
    if (state == AppLifecycleState.resumed) {
      print('DEBUG: App resumed, refreshing RIVET card');
      refreshRivetCard();
    }
  }
  
  void refreshRivetCard() {
    print('DEBUG: refreshRivetCard called from Insights page');
    print('DEBUG: _rivetCardKey: $_rivetCardKey');
    print('DEBUG: _rivetCardKey.currentState: ${_rivetCardKey.currentState}');
    print('DEBUG: _rivetCardKey.currentWidget: ${_rivetCardKey.currentWidget}');
    print('DEBUG: _rivetCardKey.currentContext: ${_rivetCardKey.currentContext}');

    if (_rivetCardKey.currentState != null) {
      print('DEBUG: Calling _refreshRivetState on RIVET card...');
      try {
        _rivetCardKey.currentState!._refreshRivetState();
        print('DEBUG: _refreshRivetState call completed');
      } catch (e) {
        print('ERROR: Failed to call _refreshRivetState: $e');
      }
    } else {
      print('DEBUG: ERROR - RIVET card key current state is null!');
      print('DEBUG: Widget tree may not be fully built yet');
    }
  }

  void _initializeInsightCubit() {
    try {
      print('DEBUG: Initializing InsightCubit...');
      final cubit = InsightCubitFactory.create(
        journalRepository: context.read(),
        rivetProvider: context.read<RivetProvider>(),
        userId: 'default_user',
      );
      cubit.generateInsights();
      setState(() {
        _insightCubit?.close();
        _insightCubit = cubit;    // <- forces rebuild so BlocBuilder subscribes
      });
      print('DEBUG: InsightCubit created and setState called');
    } catch (e) {
      print('ERROR: Failed to initialize InsightCubit: $e');
      // Continue without insight cards if initialization fails
    }
  }



  void _onSelectSection(int index) {
    setState(() {
      _selectedSection = index;
    });
    switch (index) {
      case 0:
        _scrollTo(_patternsAnchor);
        break;
      case 1:
        _scrollTo(_auroraAnchor);
        break;
      case 2:
        _scrollTo(_veilAnchor);
        break;
      case 3:
        _scrollTo(_themesAnchor);
        break;
    }
  }

  Future<void> _scrollTo(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          alignment: 0.1,
          curve: Curves.easeInOut,
        );
      }
    } catch (_) {}
  }

  Widget _buildSelectedInsightsSection(BuildContext context) {
    switch (_selectedSection) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: _patternsAnchor,
              child: _buildMiraGraphCard(context),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 0),
            // AURORA
            const AuroraCard(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 0),
            // VEIL
            const VeilCard(),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: _themesAnchor,
              child: _buildInsightsSection(),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInsightsSection() {
    if (_insightCubit == null) {
      // Skeleton while cubit spins up
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return BlocProvider<InsightCubit>.value(
      value: _insightCubit!,               // <-- the single, owned instance
      child: BlocBuilder<InsightCubit, InsightState>(
        builder: (context, state) {
          print('DEBUG: UI sees state: ${state.runtimeType}');
          
          if (state is InsightInitial || state is InsightLoading) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (state is InsightLoaded) {
            print('DEBUG: UI rendering ${state.cards.length} insight cards');
            return InsightCardsList(
              cards: state.cards,
              onCardTap: (card) {
                print('Tapped insight card: ${card.title}');
              },
            );
          }
          if (state is InsightError) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  const Text('Unable to load insights', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(state.message, style: TextStyle(color: Colors.red.withOpacity(0.7))),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: kcPrimaryGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.insights,
                    size: 28,
                    color: kcPrimaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Insights',
                    style: heading1Style(context),
                  ),
                  const Spacer(),
                  const InsightsInfoIcon(),
                  if (kDebugMode) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.bug_report,
                        color: kcPrimaryTextColor,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const QAScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSectionChip('Patterns', 0),
                    const SizedBox(width: 8),
                    _buildSectionChip('AURORA', 1),
                    const SizedBox(width: 8),
                    _buildSectionChip('VEIL', 2),
                    const SizedBox(width: 8),
                    _buildSectionChip('Themes', 3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                controller: _scrollController,
                child: _buildSelectedInsightsSection(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionChip(String label, int index) {
    final bool isSelected = _selectedSection == index;
    return GestureDetector(
      onTap: () => _onSelectSection(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(isSelected ? 0.35 : 0.2)),
        ),
        child: Text(
          label,
          style: bodyStyle(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMiraGraphCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const YourPatternsView(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
          children: [
            _buildMiniRadialIcon(),
            const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Text(
              'Patterns',
              style: heading2Style(context).copyWith(fontSize: 18),
            ),
                      Text(
                        'Keyword & emotion visualization',
                        style: bodyStyle(context).copyWith(
                          fontSize: 11,
                          color: kcPrimaryTextColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: kcPrimaryTextColor.withOpacity(0.6),
            ),
          ],
        ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kcPrimaryTextColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analyzes your journal entries to identify recurring keywords, emotions, and their connections. Keywords show frequency, emotional tone, and associated phases.',
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcPrimaryTextColor.withOpacity(0.7),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPatternInfoChip(
                          context,
                          'Keywords',
                          'Repeated words from your entries',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPatternInfoChip(
                          context,
                          'Emotions',
                          'Positive, reflective, neutral',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.blue.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Unlike Phase, Patterns show what you write about, not your life stage.',
                            style: bodyStyle(context).copyWith(
                              fontSize: 10,
                              color: Colors.blue.withOpacity(0.9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternInfoChip(BuildContext context, String label, String desc) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: bodyStyle(context).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: kcPrimaryTextColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: bodyStyle(context).copyWith(
              fontSize: 9,
              color: kcPrimaryTextColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRadialIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: MiniRadialPainter(),
      ),
    );
  }
}
*/

// Legacy RIVET card implementation removed


class MiniRadialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = kcPrimaryTextColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw center circle
    canvas.drawCircle(center, 2, Paint()..color = kcPrimaryTextColor..style = PaintingStyle.fill);

    // Draw radial lines (simplified version of radial visualization)
    final angles = [0, 60, 120, 180, 240, 300]; // 6 spokes

    for (final angle in angles) {
      final radians = angle * 3.14159 / 180;
      final startPoint = Offset(
        center.dx + 3 * math.cos(radians),
        center.dy + 3 * math.sin(radians),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(radians),
        center.dy + radius * math.sin(radians),
      );

      canvas.drawLine(startPoint, endPoint, paint);

      // Draw small circles at the end of each spoke
      canvas.drawCircle(endPoint, 1.5, Paint()..color = kcPrimaryTextColor.withOpacity(0.7)..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Custom FAB location that positions the button lower, closer to bottom navigation
// Custom FloatingActionButton location removed - using elevated tab design instead
