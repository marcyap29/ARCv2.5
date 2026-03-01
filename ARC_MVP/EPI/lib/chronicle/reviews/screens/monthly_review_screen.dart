import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:my_app/chronicle/reviews/models/monthly_review.dart';
import 'package:my_app/chronicle/reviews/services/review_generator_service.dart';
import 'package:my_app/chronicle/reviews/services/review_cache_service.dart';
import 'package:my_app/chronicle/reviews/services/review_share_service.dart';
import 'package:my_app/chronicle/reviews/widgets/emotional_trajectory_chart.dart';
import 'package:my_app/chronicle/reviews/widgets/review_word_cloud.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/timeline/timeline_with_ideas_view.dart';

/// Monthly Review screen — surfaces at end of each month.
/// Pulls from CHRONICLE Layer 1 and Layer 0.
class MonthlyReviewScreen extends StatefulWidget {
  /// Month key (e.g. "2025-01"). If null, uses previous month.
  final String? monthKey;
  final bool forceRegenerate;

  const MonthlyReviewScreen({super.key, this.monthKey, this.forceRegenerate = false});

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
  MonthlyReview? _review;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview({bool forceRegenerate = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final monthKey = widget.monthKey ?? _defaultMonthKey();
      final cache = ReviewCacheService();
      final service = ReviewGeneratorService();

      if (!widget.forceRegenerate && !forceRegenerate) {
        final cached = await cache.getMonthlyReview(userId, monthKey);
        if (cached != null && mounted) {
          setState(() {
            _review = cached;
            _loading = false;
          });
          return;
        }
      }

      final review = await service.generateMonthlyReview(userId, monthKey);
      await cache.saveMonthlyReview(userId, review);
      if (mounted) {
        setState(() {
          _review = review;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _defaultMonthKey() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kcPrimaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Monthly Review',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_review != null)
            IconButton(
              icon: const Icon(Icons.share, color: kcPrimaryTextColor),
              onPressed: () async {
                final shareService = ReviewShareService();
                await shareService.shareMonthlyReview(_review!);
              },
            ),
          if (_review != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: kcPrimaryTextColor),
              onPressed: () => _loadReview(forceRegenerate: true),
              tooltip: 'Regenerate',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kcAccentColor));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: kcDangerColor, size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not load review',
                style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadReview,
                style: ElevatedButton.styleFrom(backgroundColor: kcPrimaryColor),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_review == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadReview,
      color: kcAccentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildNarrativeSection(),
            const SizedBox(height: 24),
            _buildThemeEvolutionSection(),
            const SizedBox(height: 24),
            EmotionalTrajectoryChart(
              dataPoints: _review!.emotionalTrajectory,
              descriptor: _review!.emotionalTrajectoryDescriptor,
            ),
            const SizedBox(height: 24),
            _buildBreakthroughSection(),
            const SizedBox(height: 24),
            _buildPatternAlertsSection(),
            const SizedBox(height: 24),
            ReviewWordCloud(
              wordCloudData: _review!.wordCloudData,
              title: 'Word Cloud',
              height: 220,
            ),
            const SizedBox(height: 24),
            _buildSeedSection(),
            const SizedBox(height: 24),
            _buildStatsBar(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _review!.monthDisplayName,
                style: heading1Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_review!.stats.totalEntries} ${_review!.stats.totalEntries == 1 ? 'entry' : 'entries'}',
                style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kcPrimaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kcPrimaryColor.withOpacity(0.5)),
          ),
          child: Text(
            '${_review!.stats.totalEntries}',
            style: heading3Style(context).copyWith(color: kcAccentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrativeSection() {
    return _SectionCard(
      title: "LUMARA's Narrative Synthesis",
      icon: Icons.auto_stories,
      child: _review!.narrativeSynthesis.isEmpty
          ? Text(
              'No synthesis available for this month.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            )
          : MarkdownBody(
              data: _review!.narrativeSynthesis,
              styleSheet: MarkdownStyleSheet(
                p: bodyStyle(context).copyWith(color: kcPrimaryTextColor, height: 1.5),
                h1: heading2Style(context).copyWith(color: kcPrimaryTextColor),
                h2: heading3Style(context).copyWith(color: kcPrimaryTextColor),
                h3: heading4Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              selectable: true,
            ),
    );
  }

  Widget _buildThemeEvolutionSection() {
    final ev = _review!.themeEvolution;
    final hasAny = ev.emerged.isNotEmpty ||
        ev.persisted.isNotEmpty ||
        ev.faded.isNotEmpty ||
        ev.intensified.isNotEmpty;

    if (!hasAny) {
      return _SectionCard(
        title: 'Theme Evolution',
        icon: Icons.trending_up,
        child: Text(
          'Need at least 2 months of data for theme comparison.',
          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
      );
    }

    return _SectionCard(
      title: 'Theme Evolution',
      icon: Icons.trending_up,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ev.emerged.isNotEmpty) ...[
            _themeChipRow('Emerged', ev.emerged, kcSuccessColor),
            const SizedBox(height: 8),
          ],
          if (ev.persisted.isNotEmpty) ...[
            _themeChipRow('Persisted', ev.persisted, kcPrimaryColor),
            const SizedBox(height: 8),
          ],
          if (ev.intensified.isNotEmpty) ...[
            _themeChipRow('Intensified', ev.intensified, kcAccentColor),
            const SizedBox(height: 8),
          ],
          if (ev.faded.isNotEmpty)
            _themeChipRow('Faded', ev.faded, kcSecondaryTextColor),
        ],
      ),
    );
  }

  Widget _themeChipRow(String label, List<String> themes, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: captionStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: themes
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Text(
                      t,
                      style: bodyStyle(context).copyWith(
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBreakthroughSection() {
    if (_review!.breakthroughHighlights.isEmpty) {
      return _SectionCard(
        title: 'Breakthrough Highlights',
        icon: Icons.star,
        child: Text(
          'No standout entries this month.',
          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
      );
    }

    return _SectionCard(
      title: 'Breakthrough Highlights',
      icon: Icons.star,
      child: Column(
        children: _review!.breakthroughHighlights.map((b) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _navigateToEntry(b.entryId),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kcBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: kcSecondaryTextColor),
                        const SizedBox(width: 6),
                        Text(
                          '${b.date.month}/${b.date.day}/${b.date.year}',
                          style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.previewSnippet,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.highlightReason,
                      style: captionStyle(context).copyWith(
                        color: kcAccentColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _navigateToEntry(String entryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TimelineWithIdeasView(initialScrollToEntryId: entryId),
      ),
    );
  }

  Widget _buildPatternAlertsSection() {
    if (_review!.patternAlerts.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Pattern Alerts',
      icon: Icons.lightbulb_outline,
      child: Column(
        children: _review!.patternAlerts.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: kcWarningColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.description,
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kcPrimaryColor.withOpacity(0.3),
            kcAccentColor.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcAccentColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: kcAccentColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Seed For Next Month',
                style: heading4Style(context).copyWith(color: kcAccentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _review!.seedForNextMonth,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final s = _review!.stats;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcBorderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Entries', '${s.totalEntries}'),
          _statItem('Avg/week', s.avgEntriesPerWeek.toStringAsFixed(1)),
          _statItem('Streak', '${s.longestStreak}'),
          _statItem('Top day', s.mostActiveDay),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: captionStyle(context).copyWith(
            color: kcAccentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: captionStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kcAccentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: heading4Style(context).copyWith(color: kcPrimaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
