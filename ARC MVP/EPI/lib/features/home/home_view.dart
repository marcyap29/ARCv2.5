import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/home/home_cubit.dart';
import 'package:my_app/features/home/home_state.dart';
import 'package:my_app/features/journal/start_entry_flow.dart';
import 'package:my_app/features/arcforms/arcform_renderer_view.dart';
import 'package:my_app/features/timeline/timeline_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/tab_bar.dart';
import 'package:my_app/shared/text_style.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late HomeCubit _homeCubit;
  final List<TabItem> _tabs = const [
    TabItem(icon: Icons.edit_note, text: 'Journal'),
    TabItem(icon: Icons.auto_graph, text: 'Arcforms'),
    TabItem(icon: Icons.timeline, text: 'Timeline'),
    TabItem(icon: Icons.insights, text: 'Insights'),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _homeCubit.initialize();
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
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return Scaffold(
            body: _pages[_homeCubit.currentIndex],
            bottomNavigationBar: CustomTabBar(
              tabs: _tabs,
              selectedIndex: _homeCubit.currentIndex,
              onTabSelected: _homeCubit.changeTab,
              height: 80,
            ),
          );
        },
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.insights,
              size: 64,
              color: kcPrimaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Insights',
              style: heading1Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover patterns in your reflections',
              style: bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
