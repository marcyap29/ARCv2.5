// lib/ui/phase/advanced_analytics_view.dart
// Advanced Analytics View with 4 horizontally scrollable tabs

import 'package:flutter/material.dart';
import 'package:my_app/prism/atlas/phase/your_patterns_view.dart';
import 'package:my_app/insights/widgets/aurora_card.dart';
import 'package:my_app/insights/widgets/veil_card.dart';
import 'package:my_app/ui/veil/veil_policy_card.dart';
import 'package:my_app/ui/phase/sentinel_analysis_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/health/health_view.dart';
import 'dart:math' as math;

class AdvancedAnalyticsView extends StatefulWidget {
  const AdvancedAnalyticsView({super.key});

  @override
  State<AdvancedAnalyticsView> createState() => _AdvancedAnalyticsViewState();
}

class _AdvancedAnalyticsViewState extends State<AdvancedAnalyticsView> {
  int _selectedTab = 0;
  final PageController _pageController = PageController();

  final List<_AnalyticsTab> _tabs = const [
    _AnalyticsTab(
      title: 'Patterns',
      icon: Icons.auto_awesome,
      subtitle: 'Keyword & emotion visualization',
    ),
    _AnalyticsTab(
      title: 'AURORA',
      icon: Icons.brightness_auto,
      subtitle: 'Circadian Intelligence',
    ),
    _AnalyticsTab(
      title: 'VEIL',
      icon: Icons.visibility_off,
      subtitle: 'AI Prompt Intelligence',
    ),
    _AnalyticsTab(
      title: 'SENTINEL',
      icon: Icons.shield,
      subtitle: 'Emotional risk detection',
    ),
    _AnalyticsTab(
      title: 'Medical',
      icon: Icons.medical_services,
      subtitle: 'Health data tracking',
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
        title: const Text(
          'Advanced Analytics',
          style: TextStyle(color: kcPrimaryTextColor),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          size: 20,
                          color: isSelected ? Colors.white : kcPrimaryTextColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.title,
                          style: bodyStyle(context).copyWith(
                            color: isSelected ? Colors.white : kcPrimaryTextColor,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
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
                _buildMedicalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMiraGraphCard(context),
          // Medical Connections removed - now in dedicated Medical tab
        ],
      ),
    );
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

  Widget _buildMedicalTab() {
    return const HealthView();
  }
}

class _AnalyticsTab {
  final String title;
  final IconData icon;
  final String subtitle;

  const _AnalyticsTab({
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

