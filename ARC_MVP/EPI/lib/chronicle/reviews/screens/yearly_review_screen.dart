import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:my_app/chronicle/reviews/models/yearly_review.dart';
import 'package:my_app/chronicle/reviews/services/review_generator_service.dart';
import 'package:my_app/chronicle/reviews/services/review_cache_service.dart';
import 'package:my_app/chronicle/reviews/services/review_share_service.dart';
import 'package:my_app/chronicle/reviews/widgets/theme_lifecycle_timeline.dart';
import 'package:my_app/chronicle/reviews/widgets/monthly_emotional_arc_chart.dart';
import 'package:my_app/chronicle/reviews/widgets/identity_evolution_widget.dart';
import 'package:my_app/chronicle/reviews/widgets/review_word_cloud.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/timeline/timeline_with_ideas_view.dart';

/// Yearly Review screen — surfaces at start of each year.
/// Pulls from CHRONICLE Layer 2, Layer 1, and Layer 0.
class YearlyReviewScreen extends StatefulWidget {
  final int year;
  final bool forceRegenerate;

  const YearlyReviewScreen({super.key, required this.year, this.forceRegenerate = false});

  @override
  State<YearlyReviewScreen> createState() => _YearlyReviewScreenState();
}

class _YearlyReviewScreenState extends State<YearlyReviewScreen> {
  YearlyReview? _review;
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
      final cache = ReviewCacheService();
      final service = ReviewGeneratorService();

      if (!widget.forceRegenerate && !forceRegenerate) {
        final cached = await cache.getYearlyReview(userId, widget.year);
        if (cached != null && mounted) {
          setState(() {
            _review = cached;
            _loading = false;
          });
          return;
        }
      }

      final review = await service.generateYearlyReview(userId, widget.year);
      await cache.saveYearlyReview(userId, review);
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
          'Year in Review',
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
              onPressed: () => _shareReview(context),
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

  Future<void> _shareReview(BuildContext context) async {
    // Share service will handle this
    final shareService = ReviewShareService();
    await shareService.shareYearlyReview(_review!);
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
            _buildYearNarrativeSection(),
            const SizedBox(height: 24),
            ThemeLifecycleTimeline(
              lifecycles: _review!.themeLifecycles,
              year: _review!.year,
            ),
            const SizedBox(height: 24),
            MonthlyEmotionalArcChart(
              monthlyArc: _review!.monthlyEmotionalArc,
              year: _review!.year,
            ),
            const SizedBox(height: 24),
            if (_review!.yearOverYear != null) ...[
              _buildYearOverYearSection(),
              const SizedBox(height: 24),
            ],
            IdentityEvolutionWidget(
              identityEvolution: _review!.identityEvolution,
              year: _review!.year,
            ),
            const SizedBox(height: 24),
            _buildBreakthroughReelSection(),
            const SizedBox(height: 24),
            ReviewWordCloud(
              wordCloudData: _review!.annualWordCloud,
              title: 'Annual Word Cloud',
              height: 220,
            ),
            const SizedBox(height: 24),
            if (_review!.unresolvedThreads.isNotEmpty) ...[
              _buildUnresolvedThreadsSection(),
              const SizedBox(height: 24),
            ],
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
                '${_review!.year}',
                style: heading1Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_review!.stats.totalEntries} entries · ${_review!.stats.activeMonths} active months',
                style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kcPrimaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kcPrimaryColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${_review!.stats.totalEntries}',
            style: heading3Style(context).copyWith(color: kcAccentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildYearNarrativeSection() {
    return _SectionCard(
      title: "LUMARA's Year Narrative",
      icon: Icons.auto_stories,
      child: _review!.yearNarrative.isEmpty
          ? Text(
              'No yearly synthesis available.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            )
          : MarkdownBody(
              data: _review!.yearNarrative,
              styleSheet: MarkdownStyleSheet(
                p: bodyStyle(context).copyWith(color: kcPrimaryTextColor, height: 1.5),
                h1: heading2Style(context).copyWith(color: kcPrimaryTextColor),
                h2: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              selectable: true,
            ),
    );
  }

  Widget _buildYearOverYearSection() {
    final yoy = _review!.yearOverYear!;
    return _SectionCard(
      title: 'Year-Over-Year Comparison',
      icon: Icons.compare_arrows,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _yoyColumn('${yoy.previousYear}', yoy.lastYearEntryCount, yoy.lastYearAvgIntensity),
              const Icon(Icons.arrow_forward, color: kcAccentColor),
              _yoyColumn('${_review!.year}', yoy.thisYearEntryCount, yoy.thisYearAvgIntensity),
            ],
          ),
          const SizedBox(height: 16),
          if (yoy.newThemes.isNotEmpty) ...[
            Text('New themes', style: captionStyle(context).copyWith(color: kcSecondaryTextColor)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: yoy.newThemes.take(5).map((t) => _themeChip(t, kcSuccessColor)).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (yoy.droppedThemes.isNotEmpty) ...[
            Text('Faded themes', style: captionStyle(context).copyWith(color: kcSecondaryTextColor)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: yoy.droppedThemes.take(5).map((t) => _themeChip(t, kcSecondaryTextColor)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _yoyColumn(String year, int entries, double avgIntensity) {
    return Column(
      children: [
        Text(year, style: heading4Style(context).copyWith(color: kcPrimaryTextColor)),
        Text('$entries entries', style: captionStyle(context).copyWith(color: kcSecondaryTextColor)),
        Text('Avg intensity: ${avgIntensity.toStringAsFixed(2)}', style: captionStyle(context).copyWith(color: kcSecondaryTextColor)),
      ],
    );
  }

  Widget _themeChip(String theme, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(theme, style: bodyStyle(context).copyWith(color: color, fontSize: 12)),
    );
  }

  Widget _buildBreakthroughReelSection() {
    if (_review!.breakthroughReel.isEmpty) {
      return _SectionCard(
        title: 'Breakthrough Reel',
        icon: Icons.star,
        child: Text(
          'No standout entries this year.',
          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
      );
    }

    return _SectionCard(
      title: 'Breakthrough Reel',
      icon: Icons.star,
      child: SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _review!.breakthroughReel.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final b = _review!.breakthroughReel[i];
            final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final monthLabel = monthNames[b.date.month];
            return SizedBox(
              width: 200,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$monthLabel ${b.date.day}',
                        style: captionStyle(context).copyWith(color: kcAccentColor),
                      ),
                      Text(
                        b.previewSnippet,
                        style: bodyStyle(context).copyWith(fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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

  Widget _buildUnresolvedThreadsSection() {
    return _SectionCard(
      title: 'Carrying Forward',
      icon: Icons.forward,
      child: Column(
        children: _review!.unresolvedThreads.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_forward, size: 16, color: kcAccentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.theme, style: bodyStyle(context).copyWith(color: kcPrimaryTextColor, fontWeight: FontWeight.w600)),
                      Text(t.framing, style: captionStyle(context).copyWith(color: kcSecondaryTextColor)),
                    ],
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
            kcPrimaryColor.withValues(alpha: 0.3),
            kcAccentColor.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcAccentColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: kcAccentColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Seed For Next Year',
                style: heading4Style(context).copyWith(color: kcAccentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _review!.seedForNextYear,
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
          _statItem('Active months', '${s.activeMonths}'),
          _statItem('Streak', '${s.longestStreak}'),
          _statItem('Words', s.totalWords != null ? '${s.totalWords}' : '—'),
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
