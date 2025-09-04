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
import 'dart:math' as math;

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
  ];

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
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _homeCubit,
      child: BlocListener<HomeCubit, HomeState>(
        listener: (context, state) {
          if (state is HomeLoaded) {
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
                            'Coming Soon',
                            style: heading2Style(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'More insights about your patterns and growth will be available here.',
                            style: bodyStyle(context)?.copyWith(
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
  String _statusMessage = '';

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
        // Update service with current state and get status message
        rivetProvider.service!.updateState(state);
        final statusMessage = rivetProvider.service!.getStatusSummary();
        
        setState(() {
          _rivetState = state;
          _statusMessage = statusMessage;
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
          _statusMessage = 'RIVET unavailable';
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
        _statusMessage = 'Error loading RIVET state';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RIVET Gate Status',
                    style: heading2Style(context),
                  ),
                  Text(
                    'Phase-stability monitoring system',
                    style: bodyStyle(context)?.copyWith(
                      color: kcPrimaryTextColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryTextColor),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _DualDial(
                    title: 'ALIGN',
                    subtitle: 'Fidelity',
                    value: _rivetState!.align,
                    threshold: 0.6,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _DualDial(
                    title: 'TRACE',
                    subtitle: 'Evidence',
                    value: _rivetState!.trace,
                    threshold: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _rivetState!.align >= 0.6 && _rivetState!.trace >= 0.6
                        ? Icons.lock_open
                        : Icons.lock,
                    color: _rivetState!.align >= 0.6 && _rivetState!.trace >= 0.6
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: bodyStyle(context)?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DualDial extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double threshold;

  const _DualDial({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.threshold,
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
            color: kcPrimaryTextColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
