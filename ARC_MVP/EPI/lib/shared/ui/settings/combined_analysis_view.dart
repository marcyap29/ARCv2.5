// lib/shared/ui/settings/combined_analysis_view.dart
// Combined Analysis View - merges Phase Analysis with Advanced Analytics tabs

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

// Advanced Analytics imports
import 'package:my_app/prism/atlas/phase/your_patterns_view.dart';
import 'package:my_app/insights/widgets/aurora_card.dart';
import 'package:my_app/insights/widgets/veil_card.dart';
import 'package:my_app/ui/veil/veil_policy_card.dart';
import 'package:my_app/ui/phase/sentinel_analysis_view.dart';
import 'dart:math' as math;

class CombinedAnalysisView extends StatefulWidget {
  const CombinedAnalysisView({super.key});

  @override
  State<CombinedAnalysisView> createState() => _CombinedAnalysisViewState();
}

class _CombinedAnalysisViewState extends State<CombinedAnalysisView> {
  int _selectedTab = 0;
  final PageController _pageController = PageController();

  final List<_AnalysisTab> _tabs = const [
    _AnalysisTab(
      title: 'Patterns',
      icon: Icons.hub,
      subtitle: 'Keyword & emotion visualization',
    ),
    _AnalysisTab(
      title: 'AURORA',
      icon: Icons.brightness_auto,
      subtitle: 'Circadian Intelligence',
    ),
    _AnalysisTab(
      title: 'VEIL',
      icon: Icons.visibility_off,
      subtitle: 'AI Prompt Intelligence',
    ),
    _AnalysisTab(
      title: 'SENTINEL',
      icon: Icons.shield,
      subtitle: 'Emotional risk detection',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Analysis',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Horizontally scrollable tab bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = index;
                    });
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? kcAccentColor : kcSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? kcAccentColor : kcBorderColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 18,
                          color: isSelected ? Colors.white : kcPrimaryTextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.title,
                          style: bodyStyle(context).copyWith(
                            color: isSelected ? Colors.white : kcPrimaryTextColor,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: kcBorderColor),
          // Page view for tab content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              children: [
                _buildPatternsTab(),
                _buildAuroraTab(),
                _buildVeilTab(),
                _buildSentinelTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Patterns Tab (from Advanced Analytics)
  // ============================================================
  Widget _buildPatternsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatternsCard(),
        ],
      ),
    );
  }

  Widget _buildPatternsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const YourPatternsView()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kcBorderColor),
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
                        'Your Patterns',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Keyword & emotion visualization',
                        style: bodyStyle(context).copyWith(
                          fontSize: 12,
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: kcSecondaryTextColor,
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
                      color: kcPrimaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analyzes your journal entries to identify recurring keywords, emotions, and their connections.',
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcSecondaryTextColor,
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

  // ============================================================
  // AURORA Tab
  // ============================================================
  Widget _buildAuroraTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraCard(),
        ],
      ),
    );
  }

  // ============================================================
  // VEIL Tab
  // ============================================================
  Widget _buildVeilTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VeilCard(),
          SizedBox(height: 16),
          VeilPolicyCard(),
        ],
      ),
    );
  }

  // ============================================================
  // SENTINEL Tab
  // ============================================================
  Widget _buildSentinelTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SentinelAnalysisView(),
        ],
      ),
    );
  }

}

class _AnalysisTab {
  final String title;
  final IconData icon;
  final String subtitle;

  const _AnalysisTab({
    required this.title,
    required this.icon,
    required this.subtitle,
  });
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

