import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/home/home_cubit.dart';
import 'package:my_app/features/home/home_state.dart';
import 'package:my_app/features/journal/start_entry_flow.dart';
import 'package:my_app/features/arcforms/arcform_renderer_view.dart';
import 'package:my_app/features/timeline/timeline_view.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/tab_bar.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/rivet/rivet_provider.dart';
import 'package:my_app/core/rivet/rivet_models.dart';
import 'package:my_app/core/i18n/copy.dart';
import 'package:my_app/features/insights/cards/aurora_card.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/features/insights/cards/veil_card.dart';
import 'package:my_app/features/insights/your_patterns_view.dart';
import 'package:my_app/features/insights/info/insights_info_icon.dart';
import 'package:my_app/features/insights/info/info_icon.dart';
import 'package:my_app/features/insights/info/why_held_sheet.dart';
import 'package:my_app/insights/insight_cubit.dart';
import 'package:my_app/insights/widgets/insight_card_widget.dart';
import 'package:my_app/features/qa/qa_screen.dart';
import 'package:my_app/features/settings/settings_view.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/core/services/audio_service.dart';
import 'package:my_app/mode/first_responder/widgets/fr_status_indicator.dart';
import 'package:my_app/mode/coach/widgets/coach_mode_status_indicator.dart';
import 'package:my_app/lumara/ui/lumara_assistant_screen.dart';
import 'package:my_app/lumara/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/core/app_flags.dart';
import 'package:flutter/foundation.dart';
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
  
  List<TabItem> get _tabs {
    const baseTabs = [
      TabItem(icon: Icons.auto_graph, text: 'Phase'),
      TabItem(icon: Icons.timeline, text: 'Timeline'),
      TabItem(icon: Icons.insights, text: 'Insights'),
      TabItem(icon: Icons.add_circle, text: '+'), // This will be elevated
      TabItem(icon: Icons.settings, text: 'Settings'),
    ];
    
    if (AppFlags.isLumaraEnabled) {
      return [
        ...baseTabs,
        const TabItem(icon: Icons.psychology, text: 'LUMARA'),
      ];
    }
    return baseTabs;
  }

  List<String> get _tabNames {
    const baseNames = ['Phase', 'Timeline', 'Insights', '+', 'Settings'];
    if (AppFlags.isLumaraEnabled) {
      return [...baseNames, 'LUMARA'];
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

    _pages = [
      const ArcformRendererView(), // Phase (index 0)
      const TimelineView(), // Timeline (index 1)
      const _InsightsPage(), // Insights (index 2)
      const StartEntryFlow(), // + (index 3) - elevated
      const SettingsView(), // Settings (index 4)
      if (AppFlags.isLumaraEnabled)
        BlocProvider<LumaraAssistantCubit>.value(
          value: _lumaraCubit!,
          child: const LumaraAssistantScreen(),
        ), // LUMARA (index 5)
    ];
    
    // Initialize ethereal music (P22)
    _initializeEtherealMusic();
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
                onTabSelected: _homeCubit.changeTab,
                height: 80,
                elevatedTabIndex: 3, // Elevate the + button (index 3)
              ),
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

  @override
  void dispose() {
    _homeCubit.close();
    _lumaraCubit?.close();
    super.dispose();
  }
}

class _InsightsPage extends StatefulWidget {
  const _InsightsPage();

  @override
  State<_InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<_InsightsPage> {
  InsightCubit? _insightCubit;

  @override
  void initState() {
    super.initState();
    print('DEBUG: _InsightsPage initState called');
    // Initialize insight cubit after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('DEBUG: Post-frame callback executing');
      _initializeInsightCubit();
    });
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

  @override
  void dispose() {
    _insightCubit?.close();
    super.dispose();
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
                    const _RivetCard(),
                    const SizedBox(height: 20),
                    const AuroraCard(),
                    const SizedBox(height: 20),
                    const VeilCard(),
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
          Row(
            children: [
              _buildMiniRadialIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Your Patterns',
                        style: heading2Style(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InfoIcons.patterns(),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const YourPatternsView(),
                    ),
                  );
                },
                child: Text(
                  'Explore',
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Interactive visualization with multiple views and semantic insights.',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor.withOpacity(0.7),
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
      decoration: BoxDecoration(
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
  const _RivetCard();

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
    final alignWeight = 0.3; // 30% - how well entries match new phase
    final traceWeight = 0.3; // 30% - confidence in the match
    final sustainWeight = 0.25; // 25% - consistency over time
    final independentWeight = 0.15; // 15% - independent confirmation
    
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
    _loadRivetState();
  }

  Future<void> _loadRivetState() async {
    try {
      final rivetProvider = RivetProvider();
      const userId = 'default_user'; // TODO: Use actual user ID
      
      // Initialize provider if needed
      if (!rivetProvider.isAvailable) {
        await rivetProvider.initialize(userId);
      }
      
      // Safely get state
      final state = await rivetProvider.safeGetState(userId);
      
      if (state != null && rivetProvider.service != null) {
        // Update service with current state
        rivetProvider.service!.updateState(state);
        
        setState(() {
          _rivetState = state;
          _isLoading = false;
        });
      } else {
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
          // Header with title and subtitle
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
        ringColor = Colors.red;
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: score,
            strokeWidth: 8,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(ringColor),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(score * 100).round()}%',
              style: heading1Style(context).copyWith(
                color: ringColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getProgressLabel(status),
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  String _getProgressLabel(String status) {
    switch (status) {
      case 'ready':
        return Copy.rivetProgressReady;
      case 'almost':
        return Copy.rivetProgressAlmost;
      default:
        return Copy.rivetProgressNotReady;
    }
  }
  
  Widget _buildStatusMessage(BuildContext context, String status) {
    String message;
    Color messageColor;
    IconData icon;
    
    switch (status) {
      case 'ready':
        message = Copy.rivetStatusReady;
        messageColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'almost':
        message = Copy.rivetStatusAlmost;
        messageColor = Colors.orange;
        icon = Icons.schedule;
        break;
      default:
        message = Copy.rivetStatusNotReady;
        messageColor = Colors.red;
        icon = Icons.lock;
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
  
  Widget _buildActionButtons(BuildContext context, String status) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: status == 'ready' ? () {
              // Navigate to phase change
              // TODO: Implement phase change navigation
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'ready' ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              status == 'ready' ? Copy.rivetActionChangePhase : Copy.rivetActionKeepJournaling,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (status != 'ready') ...[
          const SizedBox(width: 12),
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
              Copy.rivetActionWhy,
              style: bodyStyle(context).copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
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
