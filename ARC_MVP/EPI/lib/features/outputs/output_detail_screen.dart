import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'output_model.dart';

class OutputDetailScreen extends StatefulWidget {
  const OutputDetailScreen({super.key, required this.output});

  final WorkflowOutput output;

  @override
  State<OutputDetailScreen> createState() => _OutputDetailScreenState();
}

class _OutputDetailScreenState extends State<OutputDetailScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const Divider(color: Color(0xFF1C1C30), height: 1),
                    if (widget.output.type == 'competitor')
                      _buildCompetitorBody()
                    else if (widget.output.type == 'writing')
                      _buildWritingBody()
                    else
                      _buildResearchBody(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '← Back',
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B5BD6),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.output.typeLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.share_outlined, color: Color(0xFF7A7A9A)),
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.output.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(widget.output.typeEmoji, const Color(0xFF14142A)),
              _chip(_formatDate(widget.output.createdAt), const Color(0xFF14142A)),
              ...widget.output.steps.map(
                (s) => _chip(s.split(' ').first, const Color(0xFF0F0F20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
          color: const Color(0xFF7070A0),
          fontSize: 10,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildResearchBody() {
    final report = widget.output.data['report'] as String? ?? widget.output.input;
    final sources = widget.output.data['sources'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildSectionedText(report),
          if (sources is List) ...[
            const SizedBox(height: 22),
            Text(
              'Sources',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8888FF),
              ),
            ),
            const SizedBox(height: 10),
            ...sources.map((s) => _sourceRow(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildCompetitorBody() {
    final card = widget.output.data['card'];
    final brief = widget.output.data['brief'] as String? ?? widget.output.input;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (card is Map) ...[
            _competitorCard(Map<String, dynamic>.from(card)),
            const SizedBox(height: 16),
          ],
          ..._buildSectionedText(brief),
        ],
      ),
    );
  }

  Widget _competitorCard(Map<String, dynamic> card) {
    final pricing = card['pricing'];
    String? pricingModel;
    if (pricing is Map) {
      pricingModel = pricing['model']?.toString();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (card['name'] ?? '').toString(),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (card['tagline'] ?? '').toString(),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF7070A0),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildCardRow('Pricing', pricingModel),
          _buildCardRow('Target', card['target_customer']?.toString()),
          _buildCardRow('Threat', card['threat_level']?.toString().toUpperCase()),
          const SizedBox(height: 12),
          _buildTagList('Strengths ✅', card['strengths'], const Color(0xFF34D399)),
          _buildTagList('Weaknesses ⚠️', card['weaknesses'], const Color(0xFFFFB347)),
          _buildTagList('Recent Moves 📡', card['recent_moves'], const Color(0xFF5B5BD6)),
        ],
      ),
    );
  }

  Widget _buildCardRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF33334A),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFFB0B0D0),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagList(String label, Object? raw, Color color) {
    if (raw is! List) return const SizedBox.shrink();
    final items = raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in items)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1C1C30)),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB0B0D0),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWritingBody() {
    final platformsRaw = widget.output.data['platforms'];
    final labelsRaw = widget.output.data['platform_labels'];

    final platforms = platformsRaw is Map
        ? Map<String, dynamic>.from(platformsRaw)
        : <String, dynamic>{};
    final labels =
        labelsRaw is Map ? Map<String, dynamic>.from(labelsRaw) : <String, dynamic>{};

    final tabIds = platforms.keys.where((k) => labels.containsKey(k)).toList();
    if (tabIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.output.input,
          style: GoogleFonts.inter(color: const Color(0xFFB0B0D0), fontSize: 14, height: 1.6),
        ),
      );
    }

    final selectedIdx = _selectedTab.clamp(0, tabIds.length - 1);
    final selectedId = tabIds[selectedIdx];
    final selectedLabel = labels[selectedId]?.toString() ?? selectedId;
    final content = platforms[selectedId]?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabIds.length; i++)
                  _platformTab(
                    id: tabIds[i],
                    label: labels[tabIds[i]]?.toString() ?? tabIds[i],
                    selected: i == selectedIdx,
                    onTap: () => setState(() => _selectedTab = i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14142A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1C1C30)),
            ),
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFB0B0D0),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.copy_outlined, color: Colors.white, size: 18),
              label: Text(
                'Copy $selectedLabel',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B5BD6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: content.trim().isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Copied to clipboard'),
                          backgroundColor: Color(0xFF1A3A1A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformTab({
    required String id,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? const Color(0xFF5B5BD6).withValues(alpha: 0.15)
              : const Color(0xFF0F0F1E),
          border: Border.all(
            color: selected ? const Color(0xFF5B5BD6) : const Color(0xFF1A1A2C),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? const Color(0xFF8888FF) : const Color(0xFF55556A),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSectionedText(String report) {
    final sections = report.split('\n## ');
    final widgets = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i].trim();
      if (section.isEmpty) continue;

      if (i == 0 && !section.contains('\n')) {
        widgets.add(
          Text(
            section,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFB0B0D0),
              height: 1.6,
            ),
          ),
        );
        continue;
      }

      final lines = section.split('\n');
      final heading = lines.first.trim();
      final body = lines.skip(1).join('\n').trim();

      widgets.add(const SizedBox(height: 20));
      widgets.add(
        Text(
          heading,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8888FF),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFFB0B0D0),
            height: 1.6,
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return [
        Text(
          report,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFFB0B0D0),
            height: 1.6,
          ),
        ),
      ];
    }

    return widgets;
  }

  Widget _sourceRow(Object? raw) {
    if (raw is! Map) return const SizedBox.shrink();
    final m = Map<String, dynamic>.from(raw);
    final title = m['title']?.toString() ?? m['url']?.toString() ?? '';
    final urlStr = m['url']?.toString() ?? '';
    if (urlStr.trim().isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(urlStr);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: GoogleFonts.inter(color: const Color(0xFF7070A0))),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B5BD6),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

