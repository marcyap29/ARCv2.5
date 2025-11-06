import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/prism/atlas/phase/cards/aurora_card.dart';
import 'package:my_app/prism/atlas/phase/cards/veil_card.dart';
import 'package:my_app/prism/atlas/phase/your_patterns_view.dart';
import 'package:my_app/ui/veil/veil_policy_card.dart';
import 'package:my_app/insights/insight_cubit.dart';
import 'package:my_app/insights/widgets/insight_card_widget.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/qa/qa_screen.dart';
import 'package:my_app/shared/app_colors.dart';
import 'dart:math' as math;

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with WidgetsBindingObserver {
  InsightCubit? _insightCubit;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _patternsAnchor = GlobalKey();
  final GlobalKey _themesAnchor = GlobalKey();
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeInsightCubit();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _insightCubit?.close();
    super.dispose();
  }

  void _initializeInsightCubit() {
    try {
      final cubit = InsightCubitFactory.create(
        journalRepository: context.read(),
        rivetProvider: context.read(),
        userId: 'default_user',
      );
      cubit.generateInsights();
      setState(() {
        _insightCubit?.close();
        _insightCubit = cubit;
      });
    } catch (_) {}
  }

  void _onSelectSection(int index) {
    setState(() {
      _selectedSection = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report, color: kcPrimaryTextColor),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QAScreen()),
              ),
            ),
        ],
      ),
      body: AnalyticsContent(
        insightCubit: _insightCubit,
        scrollController: _scrollController,
        onCreateCubit: _initializeInsightCubit,
      ),
    );
  }

  Widget _buildSelectedSection(BuildContext context) {
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
            AuroraCard(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VeilCard(),
            VeilPolicyCard(),
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
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kcBorderColor,
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
                color: kcSurfaceColor,
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
                ],
              ),
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
        painter: _MiniRadialPainter(),
      ),
    );
  }

  Widget _buildInsightsSection() {
    if (_insightCubit == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kcBorderColor),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return BlocProvider<InsightCubit>.value(
      value: _insightCubit!,
      child: BlocBuilder<InsightCubit, InsightState>(
        builder: (context, state) {
          if (state is InsightInitial || state is InsightLoading) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kcBorderColor),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (state is InsightLoaded) {
            return InsightCardsList(
              cards: state.cards,
              onCardTap: (card) {},
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
                children: const [
                  Icon(Icons.error_outline, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text('Unable to load analytics', style: TextStyle(color: Colors.red)),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Embeddable Analytics content with Phase-style subtabs
class AnalyticsContent extends StatefulWidget {
  final InsightCubit? insightCubit;
  final ScrollController? scrollController;
  final VoidCallback? onCreateCubit;
  const AnalyticsContent({super.key, this.insightCubit, this.scrollController, this.onCreateCubit});

  @override
  State<AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<AnalyticsContent> {
  int _selectedSection = 0;
  InsightCubit? _insightCubit;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _insightCubit = widget.insightCubit;
    _scrollController = widget.scrollController ?? ScrollController();
    // If no cubit exists (embedded), try to create one via callback
    if (widget.onCreateCubit != null) {
      widget.onCreateCubit?.call();
    } else {
      // If embedded without callback, initialize cubit directly after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeInsightCubit();
      });
    }
  }

  void _initializeInsightCubit() {
    if (_insightCubit != null) return; // Already initialized
    
    try {
      final cubit = InsightCubitFactory.create(
        journalRepository: context.read(),
        rivetProvider: context.read(),
        userId: 'default_user',
      );
      cubit.generateInsights();
      setState(() {
        _insightCubit = cubit;
      });
    } catch (e) {
      debugPrint('Error initializing InsightCubit in AnalyticsContent: $e');
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController?.dispose();
    }
    // Only dispose cubit if we created it ourselves (not passed from parent)
    if (widget.insightCubit == null && _insightCubit != null) {
      _insightCubit?.close();
    }
    super.dispose();
  }

  void _onSelectSection(int index) {
    setState(() => _selectedSection = index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kcBackgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Phase-style subtabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPhaseStyleTab('Patterns', Icons.auto_awesome, 0),
                  const SizedBox(width: 8),
                  _buildPhaseStyleTab('AURORA', Icons.brightness_auto, 1),
                  const SizedBox(width: 8),
                  _buildPhaseStyleTab('VEIL', Icons.visibility_off, 2),
                  const SizedBox(width: 8),
                  _buildPhaseStyleTab('Themes', Icons.category, 3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 0.0),
              controller: _scrollController,
              child: _buildSelectedSection(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseStyleTab(String label, IconData icon, int index) {
    final bool isSelected = _selectedSection == index;
    return GestureDetector(
      onTap: () => _onSelectSection(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kcSurfaceAltColor : kcSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kcBorderColor.withOpacity(isSelected ? 0.8 : 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kcPrimaryTextColor.withOpacity(isSelected ? 0.95 : 0.8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSection(BuildContext context) {
    switch (_selectedSection) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMiraGraphCard(context),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuroraCard(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VeilCard(),
            VeilPolicyCard(),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightsSection(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
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
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kcBorderColor,
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
                color: kcSurfaceColor,
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
                ],
              ),
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
        painter: _MiniRadialPainter(),
      ),
    );
  }

  Widget _buildInsightsSection() {
    final cubit = _insightCubit ?? widget.insightCubit;
    if (cubit == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kcBorderColor),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider<InsightCubit>.value(
      value: cubit,
      child: BlocBuilder<InsightCubit, InsightState>(
        builder: (context, state) {
          if (state is InsightInitial || state is InsightLoading) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kcBorderColor),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (state is InsightLoaded) {
            return InsightCardsList(
              cards: state.cards,
              onCardTap: (card) {},
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
                children: const [
                  Icon(Icons.error_outline, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text('Unable to load analytics', style: TextStyle(color: Colors.red)),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _MiniRadialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = kcPrimaryTextColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 2, Paint()..color = kcPrimaryTextColor..style = PaintingStyle.fill);

    final angles = [0, 60, 120, 180, 240, 300];
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
      canvas.drawCircle(endPoint, 1.5, Paint()..color = kcPrimaryTextColor.withOpacity(0.7)..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


