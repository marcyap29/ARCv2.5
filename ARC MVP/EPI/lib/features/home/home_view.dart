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
import 'package:my_app/features/insights/rivet_gate_details_modal.dart';
import 'package:my_app/features/insights/cards/veil_card.dart';
import 'package:my_app/features/qa/qa_screen.dart';
import 'package:my_app/features/settings/settings_view.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

// Debug flag for showing RIVET engineering labels
const bool kShowRivetDebugLabels = false;

class HomeView extends StatefulWidget {
  final int initialTab;
  
  const HomeView({super.key, this.initialTab = 0});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late HomeCubit _homeCubit;
  final List<TabItem> _tabs = const [
    TabItem(icon: Icons.edit_note, text: 'Journal'),
    TabItem(icon: Icons.auto_graph, text: 'Phase'),
    TabItem(icon: Icons.timeline, text: 'Timeline'),
    TabItem(icon: Icons.insights, text: 'Insights'),
    TabItem(icon: Icons.settings, text: 'Settings'),
  ];

  final List<String> _tabNames = const ['Journal', 'Phase', 'Timeline', 'Insights', 'Settings'];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _homeCubit.initialize();
    if (widget.initialTab != 0) {
      _homeCubit.changeTab(widget.initialTab);
    }
    _pages = [
      const StartEntryFlow(),
      const ArcformRendererView(),
      const TimelineView(),
      const _InsightsPage(),
      const SettingsView(),
    ];
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
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            final selectedIndex = state is HomeLoaded ? state.selectedIndex : 0;
            return Scaffold(
              body: SafeArea(
                child: _pages[selectedIndex],
              ),
              bottomNavigationBar: CustomTabBar(
                tabs: _tabs,
                selectedIndex: selectedIndex,
                onTabSelected: _homeCubit.changeTab,
                height: 80,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InsightsPage extends StatelessWidget {
  const _InsightsPage();

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
                  if (kDebugMode)
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
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _RivetCard(),
                    const SizedBox(height: 20),
                    const AuroraCard(),
                    const SizedBox(height: 20),
                    const VeilCard(),
                    const SizedBox(height: 20),
                    // Future insight cards can be added here
                    Container(
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
                          Text(
                            'More Insights Coming Soon',
                            style: heading2Style(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Additional insights about your patterns and growth will be available here.',
                            style: bodyStyle(context).copyWith(
                              color: kcPrimaryTextColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  
  // RIVET thresholds (matching RivetService defaults)
  static const double _alignThreshold = 0.6;
  static const double _traceThreshold = 0.6;
  static const int _sustainTarget = 2;

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
  
  void _showDetailsModal() {
    if (_rivetState != null) {
      showDialog(
        context: context,
        builder: (context) => RivetGateDetailsModal(
          rivetState: _rivetState!,
          alignThreshold: _alignThreshold,
          traceThreshold: _traceThreshold,
          sustainTarget: _sustainTarget,
        ),
      );
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

    // Calculate status booleans
    final matchGood = _rivetState!.align >= _alignThreshold;
    final confidenceGood = _rivetState!.trace >= _traceThreshold;
    final consistencyGood = _rivetState!.sustainCount >= _sustainTarget;
    final independentGood = _rivetState!.sawIndependentInWindow;
    
    final ready = matchGood && confidenceGood && consistencyGood && independentGood;
    final almost = confidenceGood && !ready && (_sustainTarget - _rivetState!.sustainCount) <= 1;

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
          // Header with title, subtitle, and info tooltip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.gps_fixed,
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
              Tooltip(
                message: Copy.rivetTooltip,
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: kcSecondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Dual dials with simple copy
          Row(
            children: [
              Expanded(
                child: _SimpleDial(
                  title: Copy.rivetDialMatch,
                  subtitle: matchGood ? Copy.rivetDialGood : Copy.rivetDialLow,
                  value: _rivetState!.align,
                  threshold: _alignThreshold,
                  debugLabel: kShowRivetDebugLabels ? 'ALIGN' : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _SimpleDial(
                  title: Copy.rivetDialConfidence,
                  subtitle: confidenceGood ? Copy.rivetDialGood : Copy.rivetDialLow,
                  value: _rivetState!.trace,
                  threshold: _traceThreshold,
                  debugLabel: kShowRivetDebugLabels ? 'TRACE' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Status banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ready 
                  ? Colors.green.withOpacity(0.1)
                  : almost 
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ready 
                    ? Colors.green.withOpacity(0.3)
                    : almost 
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ready 
                      ? Icons.lock_open
                      : almost 
                          ? Icons.schedule
                          : Icons.lock,
                  color: ready 
                      ? Colors.green
                      : almost 
                          ? Colors.orange
                          : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ready 
                        ? Copy.rivetBannerReady
                        : almost 
                            ? Copy.rivetStateAlmost
                            : Copy.rivetBannerHeld,
                    style: bodyStyle(context).copyWith(
                      color: ready 
                          ? Colors.green
                          : almost 
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!ready)
                  TextButton(
                    onPressed: _showDetailsModal,
                    child: Text(
                      Copy.rivetBannerWhy,
                      style: bodyStyle(context).copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Simple checklist
          _buildChecklist(context, matchGood, confidenceGood, consistencyGood, independentGood),
        ],
      ),
    );
  }
  
  Widget _buildChecklist(
    BuildContext context,
    bool matchGood,
    bool confidenceGood,
    bool consistencyGood,
    bool independentGood,
  ) {
    return Column(
      children: [
        _buildCheckItem(
          context,
          Copy.rivetCheckMatch(matchGood ? Copy.rivetDialGood : Copy.rivetDialLow),
          matchGood,
        ),
        const SizedBox(height: 8),
        _buildCheckItem(
          context,
          Copy.rivetCheckConfidence(confidenceGood ? Copy.rivetDialGood : Copy.rivetDialLow),
          confidenceGood,
        ),
        const SizedBox(height: 8),
        _buildCheckItem(
          context,
          Copy.rivetCheckConsistency(_rivetState!.sustainCount, _sustainTarget),
          consistencyGood,
        ),
        const SizedBox(height: 8),
        _buildCheckItem(
          context,
          independentGood ? Copy.rivetCheckIndependentOk : Copy.rivetCheckIndependentMissing,
          independentGood,
        ),
      ],
    );
  }
  
  Widget _buildCheckItem(BuildContext context, String text, bool isGood) {
    return Row(
      children: [
        Icon(
          isGood ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isGood ? Colors.green : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleDial extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double threshold;
  final String? debugLabel;

  const _SimpleDial({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.threshold,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value >= threshold;
    final percentage = (value * 100).round();

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isActive ? Colors.green : Colors.orange,
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: kcPrimaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isActive ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (debugLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            debugLabel!,
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }
}
