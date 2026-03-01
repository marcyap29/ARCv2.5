import 'package:flutter/material.dart';
import 'package:my_app/chronicle/reviews/screens/monthly_review_screen.dart';
import 'package:my_app/chronicle/reviews/screens/yearly_review_screen.dart';
import 'package:my_app/chronicle/reviews/services/review_cache_service.dart';
import 'package:my_app/chronicle/reviews/services/review_generator_service.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Hub for Monthly and Yearly Reviews.
/// Shows available reviews and allows on-demand generation.
class ReviewsHubScreen extends StatefulWidget {
  const ReviewsHubScreen({super.key});

  @override
  State<ReviewsHubScreen> createState() => _ReviewsHubScreenState();
}

class _ReviewsHubScreenState extends State<ReviewsHubScreen> {
  List<String> _monthlyKeys = [];
  List<int> _yearlyYears = [];
  Set<String> _monthsWithEntries = {};
  bool _loading = true;
  String? _generatingFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final cache = ReviewCacheService();
      final layer0 = ChronicleRepos.layer0;
      await ChronicleRepos.ensureLayer0Initialized();

      final cachedMonthly = await cache.listMonthlyReviewKeys(userId);
      final cachedYearly = await cache.listYearlyReviewYears(userId);
      final monthsWithData = await layer0.getMonthsWithEntries(userId);

      if (mounted) {
        setState(() {
          _monthlyKeys = cachedMonthly;
          _yearlyYears = cachedYearly;
          _monthsWithEntries = monthsWithData.toSet();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
          'Reviews',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kcAccentColor))
          : RefreshIndicator(
              onRefresh: _load,
              color: kcAccentColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Reviews',
                      style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LUMARA narrative synthesis, theme evolution, and seeds.',
                      style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    _buildMonthlyList(),
                    const SizedBox(height: 32),
                    Text(
                      'Yearly Reviews',
                      style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The arc of your year.',
                      style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    _buildYearlyList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMonthlyList() {
    final now = DateTime.now();
    final recentMonths = <String>[];
    for (var i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i);
      recentMonths.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }

    return Column(
      children: recentMonths.map((key) {
        final hasCache = _monthlyKeys.contains(key);
        final hasData = _monthsWithEntries.contains(key);
        final displayName = _formatMonthKey(key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ReviewTile(
            title: displayName,
            subtitle: hasCache ? 'Ready' : (hasData ? 'Tap to generate' : 'No entries'),
            icon: hasCache ? Icons.auto_stories : Icons.schedule,
            isReady: hasCache,
            isGenerating: _generatingFor == 'monthly_$key',
            onTap: hasCache
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonthlyReviewScreen(monthKey: key),
                      ),
                    )
                : (hasData ? () => _generateMonthly(key) : null),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYearlyList() {
    final now = DateTime.now();
    final years = [now.year - 1, now.year - 2, now.year - 3];

    return Column(
      children: years.map((year) {
        final hasCache = _yearlyYears.contains(year);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ReviewTile(
            title: '$year',
            subtitle: hasCache ? 'Ready' : 'Tap to generate',
            icon: hasCache ? Icons.eco : Icons.schedule,
            isReady: hasCache,
            isGenerating: _generatingFor == 'yearly_$year',
            onTap: hasCache
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => YearlyReviewScreen(year: year),
                      ),
                    )
                : () => _generateYearly(year),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _generateMonthly(String monthKey) async {
    setState(() => _generatingFor = 'monthly_$monthKey');
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = ReviewGeneratorService();
      final cache = ReviewCacheService();
      final review = await service.generateMonthlyReview(userId, monthKey);
      await cache.saveMonthlyReview(userId, review);
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _generatingFor = null);
  }

  Future<void> _generateYearly(int year) async {
    setState(() => _generatingFor = 'yearly_$year');
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = ReviewGeneratorService();
      final cache = ReviewCacheService();
      final review = await service.generateYearlyReview(userId, year);
      await cache.saveYearlyReview(userId, review);
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _generatingFor = null);
  }

  String _formatMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null || monthNum < 1 || monthNum > 12) return key;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${names[monthNum - 1]} ${parts[0]}';
  }
}

class _ReviewTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isReady;
  final bool isGenerating;
  final VoidCallback? onTap;

  const _ReviewTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isReady,
    required this.isGenerating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kcSurfaceColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isGenerating ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kcBorderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isReady ? kcAccentColor : kcSecondaryTextColor,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: heading4Style(context).copyWith(color: kcPrimaryTextColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                    ),
                  ],
                ),
              ),
              if (isGenerating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kcAccentColor),
                )
              else if (onTap != null)
                Icon(Icons.chevron_right, color: kcSecondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}
