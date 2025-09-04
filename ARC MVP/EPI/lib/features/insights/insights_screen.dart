import 'package:flutter/material.dart';
import '../../core/mira/mira_cubit.dart';
import '../../core/mira/mira_feature_flags.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'cards/themes_card.dart';
import 'cards/pairs_on_rise_card.dart';
import 'cards/phase_drift_card.dart';
import 'cards/precursors_card.dart';

/// Insights screen showing MIRA semantic memory analysis
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late MiraCubit _miraCubit;

  @override
  void initState() {
    super.initState();
    _miraCubit = MiraCubit();
    // Initialize MIRA cubit if enabled
    if (MiraFeatureFlags.miraEnabled) {
      _miraCubit.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If MIRA is disabled, show a placeholder
    if (!MiraFeatureFlags.miraEnabled) {
      return _buildDisabledState();
    }

    return Scaffold(
      backgroundColor: kcSurfaceColor,
      appBar: AppBar(
        title: Text(
          'Insights',
          style: heading2Style(context).copyWith(color: kcPrimaryColor),
        ),
        backgroundColor: kcSurfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryColor),
            onPressed: () {
              _miraCubit.refresh();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: kcPrimaryColor),
            onSelected: (value) {
              _handleMenuSelection(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'window_7',
                child: Text('7 days'),
              ),
              const PopupMenuItem(
                value: 'window_14',
                child: Text('14 days'),
              ),
              const PopupMenuItem(
                value: 'window_30',
                child: Text('30 days'),
              ),
              const PopupMenuItem(
                value: 'granularity_day',
                child: Text('Daily view'),
              ),
              const PopupMenuItem(
                value: 'granularity_week',
                child: Text('Weekly view'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<MiraState>(
        stream: Stream.periodic(const Duration(seconds: 1), (_) => _miraCubit.state),
        builder: (context, snapshot) {
          final state = snapshot.data ?? _miraCubit.state;
          
          if (state is MiraLoading) {
            return const Center(
              child: CircularProgressIndicator(color: kcPrimaryColor),
            );
          }

          if (state is MiraError) {
            return _buildErrorState(state.message);
          }

          if (state is MiraLoaded) {
            return _buildLoadedState(state);
          }

          return _buildInitialState();
        },
      ),
    );
  }

  Widget _buildDisabledState() {
    return Scaffold(
      backgroundColor: kcSurfaceColor,
      appBar: AppBar(
        title: Text(
          'Insights',
          style: heading2Style(context).copyWith(color: kcPrimaryColor),
        ),
        backgroundColor: kcSurfaceColor,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 64,
              color: kcSecondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Insights Coming Soon',
              style: heading3Style(context).copyWith(color: kcSecondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              'MIRA semantic memory analysis is currently disabled.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: kcDangerColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Insights',
            style: heading3Style(context).copyWith(color: kcDangerColor),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _miraCubit.refresh();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return const Center(
      child: CircularProgressIndicator(color: kcPrimaryColor),
    );
  }

  Widget _buildLoadedState(MiraLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with window info
          _buildHeader(state),
          const SizedBox(height: 16),

          // Insights cards
          const ThemesCard(),
          const SizedBox(height: 16),

          const PairsOnRiseCard(),
          const SizedBox(height: 16),

          const PhaseDriftCard(),
          const SizedBox(height: 16),

          const PrecursorsCard(),
          const SizedBox(height: 16),

          // Debug info if enabled
          if (MiraFeatureFlags.showDebugInfo) ...[
            _buildDebugInfo(state),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(MiraLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semantic Memory Analysis',
            style: heading3Style(context).copyWith(color: kcPrimaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Window: ${state.window.inDays} days • Granularity: ${state.granularity}',
            style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${state.topKeywords.length} themes • ${state.pairsOnRise.length} rising pairs • ${state.phaseTrajectory.length} time points',
            style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo(MiraLoaded state) {
    final stats = _miraCubit.getStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcSecondaryTextColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug Information',
            style: heading3Style(context).copyWith(color: kcSecondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Nodes: ${stats['totalNodes']} • Edges: ${stats['totalEdges']} • Processed Entries: ${stats['processedEntries']}',
            style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
          ),
          if (stats['nodeCounts'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Node Types: ${stats['nodeCounts']}',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
          if (stats['edgeCounts'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Edge Types: ${stats['edgeCounts']}',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ],
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'window_7':
        _miraCubit.updateWindow(const Duration(days: 7));
        break;
      case 'window_14':
        _miraCubit.updateWindow(const Duration(days: 14));
        break;
      case 'window_30':
        _miraCubit.updateWindow(const Duration(days: 30));
        break;
      case 'granularity_day':
        _miraCubit.updateGranularity('day');
        break;
      case 'granularity_week':
        _miraCubit.updateGranularity('week');
        break;
    }
  }
}
