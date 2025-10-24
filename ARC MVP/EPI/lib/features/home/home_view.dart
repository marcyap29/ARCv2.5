import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/home/home_cubit.dart';
import 'package:my_app/features/home/home_state.dart';
import 'package:my_app/arc/core/start_entry_flow.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';
import 'package:my_app/features/timeline/timeline_view.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/tab_bar.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/rivet/validation/rivet_provider.dart';
import 'package:my_app/rivet/models/rivet_models.dart';
import 'package:my_app/core/i18n/copy.dart';
// AURORA card removed - was just a placeholder
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/atlas/phase_detection/cards/veil_card.dart';
import 'package:my_app/atlas/phase_detection/your_patterns_view.dart';
import 'package:my_app/atlas/phase_detection/info/insights_info_icon.dart';
import 'package:my_app/atlas/phase_detection/info/info_icon.dart';
import 'package:my_app/atlas/phase_detection/info/why_held_sheet.dart';
import 'package:my_app/insights/insight_cubit.dart';
import 'package:my_app/insights/widgets/insight_card_widget.dart';
import 'package:my_app/features/qa/qa_screen.dart';
import 'package:my_app/features/settings/settings_view.dart';
import 'package:my_app/lumara/ui/lumara_assistant_screen.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/core/services/audio_service.dart';
import 'package:my_app/mode/first_responder/widgets/fr_status_indicator.dart';
import 'package:my_app/mode/coach/widgets/coach_mode_status_indicator.dart';
import 'package:my_app/lumara/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/core/app_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'dart:math' as math;

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
  LumaraAssistantCubit? _lumaraCubit;
  final GlobalKey<_InsightsPageState> _insightsPageKey = GlobalKey<_InsightsPageState>();
  
  List<TabItem> get _tabs {
    const baseTabs = [
      TabItem(icon: Icons.auto_graph, text: 'Phase'),
      TabItem(icon: Icons.timeline, text: 'Timeline'),
      TabItem(icon: Icons.add, text: 'Write'), // Write button as elevated tab
      TabItem(icon: Icons.insights, text: 'Insights'),
      TabItem(icon: Icons.settings, text: 'Settings'),
    ];

    if (AppFlags.isLumaraEnabled) {
      return [
        baseTabs[0], // Phase
        baseTabs[1], // Timeline
        baseTabs[2], // Write (elevated)
        const TabItem(icon: Icons.psychology, text: 'LUMARA'),
        baseTabs[3], // Insights
        baseTabs[4], // Settings
      ];
    }
    return baseTabs;
  }

  List<String> get _tabNames {
    const baseNames = ['Phase', 'Timeline', 'Write', 'Insights', 'Settings'];
    if (AppFlags.isLumaraEnabled) {
      return ['Phase', 'Timeline', 'Write', 'LUMARA', 'Insights', 'Settings'];
    }
    return baseNames;
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _homeCubit.initialize();
      if (widget.initialTab != 0) {
        _homeCubit.changeTab(widget.initialTab);
      } else {
        _homeCubit.changeTab(0); // Set Phase tab as default
      }

    // Initialize LUMARA cubit if enabled
    if (AppFlags.isLumaraEnabled) {
      _lumaraCubit = LumaraAssistantCubit(
        contextProvider: ContextProvider(LumaraScope.defaultScope),
      );
      // Initialize the cubit once when HomeView is created
      _lumaraCubit!.initializeLumara();
    }

    // Check photo permissions and refresh timeline if granted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPhotoPermissionsAndRefresh();
    });

    _pages = [
      const PhaseAnalysisView(), // Phase Analysis (index 0)
      const TimelineView(), // Timeline (index 1)
      const Center(child: Text('Write Action')), // Write placeholder (index 2) - won't be shown
      if (AppFlags.isLumaraEnabled)
        BlocProvider<LumaraAssistantCubit>.value(
          value: _lumaraCubit!,
          child: const LumaraAssistantScreen(),
        ) // LUMARA (index 3)
      else
        const Center(child: Text('LUMARA not available')),
      _InsightsPage(key: _insightsPageKey), // Insights (index 4 or 3)
      const SettingsView(), // Settings (index 5 or 4)
    ];
    
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
            
            // Refresh timeline when switching to Timeline tab (index 2)
            if (state.selectedIndex == 2) {
              context.read<TimelineCubit>().refreshEntries();
            }
            
            // Refresh phase cache when switching to Phase tab (index 1)
            if (state.selectedIndex == 1) {
              _refreshPhaseCache();
            }
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            final selectedIndex = state is HomeLoaded ? state.selectedIndex : 0;
            return Scaffold(
              body: SafeArea(
                child: Stack(
                  children: [
                    _pages[selectedIndex],
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

                  // Handle Write tab action instead of navigation
                  if (_tabs[index].text == 'Write') {
                    _onWritePressed();
                    return;
                  }

                  _homeCubit.changeTab(index);
                  // Refresh RIVET card when Insights tab is selected
                  final insightsIndex = AppFlags.isLumaraEnabled ? 4 : 3; // Adjusted for Write tab
                  if (index == insightsIndex) {
                    print('DEBUG: Insights tab selected, refreshing RIVET card');
                    print('DEBUG: Calling _refreshRivetCardInInsights...');
                    _refreshRivetCardInInsights();
                  }
                },
                height: 100, // Increased height to accommodate elevated Write button
                elevatedTabIndex: 2, // Write button is at index 2, elevated above other tabs
              ),
            // Write button is now integrated into the elevated tab bar design
            );
          },
        ),
      ),
    );
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
  
  /// Refresh RIVET card in Insights page
  void _refreshRivetCardInInsights() {
    print('DEBUG: _refreshRivetCardInInsights called from home view');
    print('DEBUG: _insightsPageKey: $_insightsPageKey');
    print('DEBUG: _insightsPageKey.currentState: ${_insightsPageKey.currentState}');

    if (_insightsPageKey.currentState != null) {
      print('DEBUG: Found InsightsPage state, calling refreshRivetCard...');
      try {
        _insightsPageKey.currentState!.refreshRivetCard();
        print('DEBUG: Successfully called refreshRivetCard on InsightsPage');
      } catch (e) {
        print('ERROR: Failed to call refreshRivetCard on InsightsPage: $e');
      }
    } else {
      print('DEBUG: ERROR - InsightsPage state is null!');
      print('DEBUG: Widget tree may not be fully built yet');
    }
  }

  void _onWritePressed() async {
    // Clear any existing session cache to ensure fresh start
    await JournalSessionCache.clearSession();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartEntryFlow(
          onExitToPhase: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _homeCubit.close();
    _lumaraCubit?.close();
    super.dispose();
  }
}

class _InsightsPage extends StatefulWidget {
  const _InsightsPage({super.key});

  @override
  State<_InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<_InsightsPage> with WidgetsBindingObserver {
  InsightCubit? _insightCubit;
  final GlobalKey<_RivetCardState> _rivetCardKey = GlobalKey<_RivetCardState>();

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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMiraGraphCard(context),
                    const SizedBox(height: 20),
                    // RIVET Card removed - now only in Phase tab
                    // AURORA Card removed - placeholder not needed
                    const VeilCard(), // To be repurposed as AI Prompt Intelligence card
                    const SizedBox(height: 20),
                    // Insight Cards
                    _buildInsightsSection(),
                  ],
                ),
              ),
            ),
          ],
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
        child: Row(
          children: [
            _buildMiniRadialIcon(),
            const SizedBox(width: 12),
            Text(
              'Your Patterns',
              style: heading2Style(context).copyWith(fontSize: 18),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: kcPrimaryTextColor.withOpacity(0.6),
            ),
          ],
        ),
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

class _RivetCard extends StatefulWidget {
  const _RivetCard({super.key});

  @override
  State<_RivetCard> createState() => _RivetCardState();
}

class _RivetCardState extends State<_RivetCard> {
  RivetState? _rivetState;
  bool _isLoading = true;
  
  // Simplified readiness calculation
  double _calculateReadinessScore() {
    if (_rivetState == null) return 0.0;
    
    // Weight the different metrics for a single readiness score
    const alignWeight = 0.3; // 30% - how well entries match new phase
    const traceWeight = 0.3; // 30% - confidence in the match
    const sustainWeight = 0.25; // 25% - consistency over time
    const independentWeight = 0.15; // 15% - independent confirmation
    
    final alignScore = _rivetState!.align;
    final traceScore = _rivetState!.trace;
    final sustainScore = (_rivetState!.sustainCount / 2.0).clamp(0.0, 1.0); // 2 is target
    final independentScore = _rivetState!.sawIndependentInWindow ? 1.0 : 0.0;
    
    return (alignScore * alignWeight + 
            traceScore * traceWeight + 
            sustainScore * sustainWeight + 
            independentScore * independentWeight);
  }
  
  String _getReadinessStatus(double score) {
    if (score >= 0.8) return 'ready';
    if (score >= 0.6) return 'almost';
    return 'not_ready';
  }

  @override
  void initState() {
    super.initState();
    print('DEBUG: _RivetCard initState called - widget hashCode: $hashCode');
    _loadRivetState();
  }

  Future<void> _loadRivetState() async {
    print('DEBUG: _loadRivetState called');
    setState(() {
      _isLoading = true;
    });
    
    try {
      final rivetProvider = RivetProvider();
      const userId = 'default_user'; // TODO: Use actual user ID
      
      print('DEBUG: RIVET provider available: ${rivetProvider.isAvailable}');
      
      // Initialize provider if needed
      if (!rivetProvider.isAvailable) {
        print('DEBUG: Initializing RIVET provider...');
        await rivetProvider.initialize(userId);
        print('DEBUG: RIVET provider initialized: ${rivetProvider.isAvailable}');
      }
      
      // Safely get state
      print('DEBUG: Getting RIVET state for user: $userId');
      final state = await rivetProvider.safeGetState(userId);
      print('DEBUG: RIVET state retrieved: $state');
      
      if (state != null && rivetProvider.service != null) {
        // Update service with current state
        rivetProvider.service!.updateState(state);
        
        setState(() {
          _rivetState = state;
          _isLoading = false;
        });
        print('DEBUG: RIVET state updated successfully: $_rivetState');
      } else {
        print('DEBUG: No RIVET state found, using default state');
        setState(() {
          _rivetState = const RivetState(
            align: 0,
            trace: 0,
            sustainCount: 0,
            sawIndependentInWindow: false,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR: Failed to load RIVET state for insights: $e');
      setState(() {
        _rivetState = const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        );
        _isLoading = false;
      });
    }
  }
  
  Future<void> _refreshRivetState() async {
    print('DEBUG: _refreshRivetState called - widget hashCode: $hashCode');
    print('DEBUG: Current RIVET state before refresh: $_rivetState');
    print('DEBUG: Current loading state: $_isLoading');
    await _loadRivetState();
    print('DEBUG: RIVET state after refresh: $_rivetState');
    print('DEBUG: Loading state after refresh: $_isLoading');
  }
  

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _rivetState == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryTextColor),
          ),
        ),
      );
    }

    // Calculate simplified readiness
    final readinessScore = _calculateReadinessScore();
    final status = _getReadinessStatus(readinessScore);

    return Container(
      padding: const EdgeInsets.all(20),
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
          // Header with title, subtitle, and refresh button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 20,
                  color: kcPrimaryTextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Copy.rivetTitle,
                      style: heading2Style(context),
                    ),
                    Text(
                      Copy.rivetSubtitle,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refreshRivetState,
                icon: const Icon(
                  Icons.refresh,
                  color: kcPrimaryTextColor,
                  size: 20,
                ),
                tooltip: 'Refresh RIVET state',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Single progress ring with status
          Center(
            child: Column(
              children: [
                _buildProgressRing(context, readinessScore, status),
                const SizedBox(height: 16),
                _buildStatusMessage(context, status),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          _buildActionButtons(context, status),
        ],
      ),
    );
  }
  
  Widget _buildProgressRing(BuildContext context, double score, String status) {
    Color ringColor;
    switch (status) {
      case 'ready':
        ringColor = Colors.green;
        break;
      case 'almost':
        ringColor = Colors.orange;
        break;
      default:
        ringColor = Colors.blue; // Changed from red to blue for more encouraging tone
    }

    final progressInfo = _getProgressInfo();

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: _getVisualProgress(), // Visual progress based on entries, not RIVET math
            strokeWidth: 8,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(ringColor),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              progressInfo['display']!,
              style: heading1Style(context).copyWith(
                color: ringColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              progressInfo['subtitle']!,
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor.withOpacity(0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  // Get visual progress for ring (simpler than RIVET math)
  double _getVisualProgress() {
    if (_rivetState == null) return 0.0;

    final sustainCount = _rivetState!.sustainCount;
    const targetCount = 2; // Need 2 qualifying entries

    // Visual progress based on entry count, capped at 0.9 until fully ready
    final progress = (sustainCount / targetCount).clamp(0.0, 0.9);

    // Only show 1.0 when actually ready
    if (sustainCount >= targetCount &&
        _rivetState!.sawIndependentInWindow &&
        _rivetState!.align >= 0.6 &&
        _rivetState!.trace >= 0.6) {
      return 1.0;
    }

    return progress;
  }

  // Get user-friendly progress information
  Map<String, String> _getProgressInfo() {
    if (_rivetState == null) {
      return {
        'display': 'Getting\nStarted',
        'subtitle': 'Begin journaling'
      };
    }

    final sustainCount = _rivetState!.sustainCount;
    const targetCount = 2;
    final entriesNeeded = (targetCount - sustainCount).clamp(0, targetCount);
    final hasIndependent = _rivetState!.sawIndependentInWindow;

    if (sustainCount >= targetCount && hasIndependent) {
      return {
        'display': 'Ready!',
        'subtitle': 'Phase unlocked'
      };
    } else if (sustainCount >= targetCount && !hasIndependent) {
      return {
        'display': 'Almost\nThere',
        'subtitle': 'Try different day'
      };
    } else if (sustainCount == 1) {
      return {
        'display': '1 More\nEntry',
        'subtitle': 'Great momentum!'
      };
    } else if (sustainCount == 0) {
      return {
        'display': '2 More\nEntries',
        'subtitle': 'Building evidence'
      };
    } else {
      return {
        'display': '$entriesNeeded More\nEntries',
        'subtitle': 'Keep exploring'
      };
    }
  }
  
  
  Widget _buildStatusMessage(BuildContext context, String status) {
    String message;
    Color messageColor;
    IconData icon;

    final readinessScore = _calculateReadinessScore();

    switch (status) {
      case 'ready':
        message = "Ready to explore a new phase";
        messageColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'almost':
        message = _getPersonalizedStatusMessage(readinessScore);
        messageColor = Colors.orange;
        icon = Icons.schedule;
        break;
      default:
        message = _getPersonalizedStatusMessage(readinessScore);
        messageColor = Colors.blue; // Changed from red to blue for encouragement
        icon = Icons.trending_up;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: messageColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: messageColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: messageColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: bodyStyle(context).copyWith(
                color: messageColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getPersonalizedStatusMessage(double score) {
    if (_rivetState == null) {
      return "Start journaling to build your story";
    }

    final sustainCount = _rivetState!.sustainCount;
    final hasIndependent = _rivetState!.sawIndependentInWindow;
    const targetCount = 2;

    if (sustainCount >= targetCount && hasIndependent) {
      return "Phase change ready - explore new territory!";
    } else if (sustainCount >= targetCount && !hasIndependent) {
      return "Almost ready - try journaling on a different day";
    } else if (sustainCount == 1) {
      return "Great momentum - 1 more quality entry needed";
    } else if (sustainCount == 0) {
      return "Building your foundation - every entry matters";
    } else {
      final needed = targetCount - sustainCount;
      return "Strong progress - $needed more qualifying entries";
    }
  }
  
  Widget _buildActionButtons(BuildContext context, String status) {
    if (status == 'ready') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Navigate to phase change
                // TODO: Implement phase change navigation
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Change Phase",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // For not ready status, show actionable guidance instead of grayed-out button
    return _buildActionableGuidance(context);
  }

  Widget _buildActionableGuidance(BuildContext context) {
    if (_rivetState == null) return const SizedBox.shrink();

    final guidance = _getSpecificGuidance();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Next Steps",
                    style: bodyStyle(context).copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...guidance.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• ",
                      style: bodyStyle(context).copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const WhyHeldSheet(),
            );
          },
          child: Text(
            "See detailed breakdown",
            style: bodyStyle(context).copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getSpecificGuidance() {
    if (_rivetState == null) return ["Start journaling to begin building your story"];

    final guidance = <String>[];
    final sustainCount = _rivetState!.sustainCount;
    final hasIndependent = _rivetState!.sawIndependentInWindow;
    final alignScore = _rivetState!.align;
    const targetCount = 2;

    // Entry-specific guidance
    if (sustainCount == 0) {
      guidance.add("✨ Write 2 thoughtful entries exploring your current life phase");
      guidance.add("🌱 Focus on meaningful experiences and feelings");
    } else if (sustainCount == 1) {
      guidance.add("🎯 1 more quality entry needed - you're building great momentum!");
      guidance.add("📝 Continue exploring themes from your current phase");
    } else if (sustainCount >= targetCount && !hasIndependent) {
      guidance.add("🗓️ Try journaling on a different day for independence");
      guidance.add("✨ You've built strong evidence - just need variety");
    }

    // Quality guidance
    if (alignScore < 0.4 && sustainCount > 0) {
      guidance.add("💭 Dive deeper into your current phase's themes and challenges");
    }

    // Independence guidance
    if (!hasIndependent && sustainCount > 0) {
      guidance.add("🔄 Journal at different times or on different days");
    }

    // Always provide encouraging completion message
    if (sustainCount >= targetCount && hasIndependent) {
      guidance.add("🎉 Ready to explore your next phase - amazing progress!");
    } else if (sustainCount == 1) {
      guidance.add("💪 Great foundation built - 1 more entry unlocks phase change");
    } else if (sustainCount == 0) {
      guidance.add("🚀 Every entry matters - you're building something meaningful");
    } else {
      final needed = targetCount - sustainCount;
      guidance.add("📈 Strong progress made - $needed more entries to unlock");
    }

    return guidance;
  }
}


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
