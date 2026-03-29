import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/services/report_export_service.dart';
import 'package:my_app/shared/ui/lumara_bottom_tab_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'output_model.dart';
import 'outputs_storage.dart';

class OutputDetailScreen extends StatefulWidget {
  const OutputDetailScreen({super.key, required this.output});

  final WorkflowOutput output;

  @override
  State<OutputDetailScreen> createState() => _OutputDetailScreenState();
}

class _OutputDetailScreenState extends State<OutputDetailScreen> {
  int _selectedTab = 0;
  late WorkflowOutput _output;
  TextEditingController? _researchReportController;
  bool _researchEditing = false;
  bool _researchSaving = false;

  bool get _isResearchLikeOutput =>
      _output.type != 'competitor' && _output.type != 'writing';

  @override
  void initState() {
    super.initState();
    _output = widget.output;
    if (_isResearchLikeOutput) {
      _researchReportController = TextEditingController(
        text: (_output.data['report'] as String?) ?? '',
      );
    }
  }

  @override
  void dispose() {
    _researchReportController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        bottomNavigationBar: const LumaraUnifiedBottomBar(currentIndex: 2),
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
                    if (_output.type == 'competitor')
                      _buildCompetitorBody()
                    else if (_output.type == 'writing')
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
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
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
                _output.typeLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isResearchLikeOutput) ...[
              if (_researchEditing)
                IconButton(
                  icon: _researchSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF5B5BD6),
                          ),
                        )
                      : const Icon(Icons.check_rounded, color: Color(0xFF34D399)),
                  tooltip: 'Save',
                  onPressed: _researchSaving ? null : _saveResearchEdits,
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF7A7A9A)),
                  tooltip: 'Edit report',
                  onPressed: () => setState(() => _researchEditing = true),
                ),
            ],
            IconButton(
              onPressed: _onSharePressed,
              icon: const Icon(Icons.share_outlined, color: Color(0xFF7A7A9A)),
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final headline = _isResearchLikeOutput ? 'Research report' : _output.title;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
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
              _chip(_output.typeEmoji, const Color(0xFF14142A)),
              _chip(_formatDate(_output.createdAt), const Color(0xFF14142A)),
              ..._output.steps.map(
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

  MarkdownStyleSheet _researchMarkdownStyle() {
    return MarkdownStyleSheet(
      p: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: const Color(0xFFB0B0D0),
      ),
      h1: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      h2: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF8888FF),
      ),
      h3: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFC8C8FF),
      ),
      h4: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFB0B0D0),
      ),
      strong: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: const Color(0xFFE8E8F8),
      ),
      em: GoogleFonts.inter(
        fontStyle: FontStyle.italic,
        color: const Color(0xFFB0B0D0),
      ),
      code: GoogleFonts.robotoMono(
        fontSize: 13,
        color: const Color(0xFFE0E0F0),
        backgroundColor: const Color(0xFF0C0C1A),
      ),
      blockquote: GoogleFonts.inter(
        fontSize: 14,
        height: 1.55,
        color: const Color(0xFF9090B0),
        fontStyle: FontStyle.italic,
      ),
      listBullet: GoogleFonts.inter(
        color: const Color(0xFFB0B0D0),
        fontSize: 14,
      ),
      a: GoogleFonts.inter(
        color: const Color(0xFF5B5BD6),
        decoration: TextDecoration.underline,
      ),
      blockSpacing: 10,
      listIndent: 22,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFF1C1C30).withValues(alpha: 0.8)),
        ),
      ),
    );
  }

  Widget _buildResearchBody() {
    final c = _researchReportController!;
    final sources = _output.data['sources'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR QUESTION',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1C1C30)),
            ),
            child: SelectableText(
              _output.input.trim().isEmpty ? '—' : _output.input.trim(),
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFFC8C8E0),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'REPORT',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          if (_researchEditing) ...[
            Text(
              'Edit (Markdown)',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF33334A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              maxLines: null,
              minLines: 14,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFFE0E0F0),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0C0C1A),
                hintText: 'Report markdown…',
                hintStyle: GoogleFonts.robotoMono(
                  color: const Color(0xFF44445A),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1C1C30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1C1C30)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF5B5BD6)),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF14142A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1C1C30)),
              ),
              child: MarkdownBody(
                data: c.text.trim().isEmpty ? '_No report body._' : c.text,
                styleSheet: _researchMarkdownStyle(),
                selectable: true,
                shrinkWrap: true,
                fitContent: true,
                onTapLink: (text, href, title) async {
                  if (href == null || href.isEmpty) return;
                  final uri = Uri.tryParse(href);
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ),
          ],
          if (sources is List && sources.isNotEmpty) ...[
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
          _buildResearchExportFooter(),
        ],
      ),
    );
  }

  Widget _buildResearchExportFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Text(
          'EXPORT & NEXT STEP',
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF33334A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _researchSaving ? null : _exportResearchPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF5B5BD6), size: 20),
            label: Text(
              'Export as PDF',
              style: GoogleFonts.inter(
                color: const Color(0xFF5B5BD6),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1C1C30)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _researchSaving ? null : _exportResearchDocx,
            icon: const Icon(Icons.description_outlined, color: Color(0xFF5B5BD6), size: 20),
            label: Text(
              'Export as Word (.docx)',
              style: GoogleFonts.inter(
                color: const Color(0xFF5B5BD6),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1C1C30)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _openCreateContentFromResearch,
            icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            label: Text(
              'Create content',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B5BD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveResearchEdits() async {
    final c = _researchReportController;
    if (c == null) return;
    setState(() => _researchSaving = true);
    try {
      final newData = Map<String, dynamic>.from(_output.data);
      newData['report'] = c.text;
      final updated = WorkflowOutput(
        id: _output.id,
        type: _output.type,
        title: _output.title,
        input: _output.input,
        createdAt: _output.createdAt,
        data: newData,
        steps: _output.steps,
      );
      await OutputsStorage.upsert(updated);
      if (!mounted) return;
      setState(() {
        _output = updated;
        _researchEditing = false;
        _researchSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1A3A1A),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _researchSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: const Color(0xFF3A1515),
          ),
        );
      }
    }
  }

  String _researchExportFileStem() {
    final d = _output.createdAt;
    final ymd =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final short = _output.id.length >= 8 ? _output.id.substring(0, 8) : _output.id;
    return 'Research_${ymd}_$short';
  }

  String _researchSharePlainBody() {
    final q = _output.input.trim();
    final r = _researchReportController!.text.trim();
    final buf = StringBuffer();
    buf.writeln('YOUR QUESTION');
    buf.writeln(q.isEmpty ? '—' : q);
    buf.writeln();
    buf.writeln('REPORT');
    buf.writeln(r.isEmpty ? '—' : r);
    return buf.toString();
  }

  Future<void> _exportResearchPdf() async {
    final path = await ReportExportService.instance.exportWorkflowMarkdownToFile(
      title: _output.title,
      markdown: _researchReportController!.text,
      format: ReportExportFormat.pdf,
      createdAt: _output.createdAt,
      userQuestion: _output.input,
      fileBaseName: _researchExportFileStem(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null
              ? 'Saved PDF: ${path.split('/').last}'
              : 'Export failed',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: path != null ? const Color(0xFF1A3A1A) : const Color(0xFF3A1515),
      ),
    );
  }

  Future<void> _exportResearchDocx() async {
    final path = await ReportExportService.instance.exportWorkflowMarkdownToFile(
      title: _output.title,
      markdown: _researchReportController!.text,
      format: ReportExportFormat.docx,
      createdAt: _output.createdAt,
      userQuestion: _output.input,
      fileBaseName: _researchExportFileStem(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null
              ? 'Saved Word file: ${path.split('/').last}'
              : 'Export failed',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: path != null ? const Color(0xFF1A3A1A) : const Color(0xFF3A1515),
      ),
    );
  }

  void _openCreateContentFromResearch() {
    final markdown = _researchReportController!.text;
    final report = ResearchReport(
      id: _output.id,
      query: _output.input.trim().isNotEmpty ? _output.input.trim() : _output.title,
      summary: '',
      detailedFindings: markdown,
      generatedAt: _output.createdAt,
    );
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const WritingScreen(),
        settings: RouteSettings(
          arguments: <String, dynamic>{'researchContext': report},
        ),
      ),
    );
  }

  Future<void> _onSharePressed() async {
    if (_isResearchLikeOutput) {
      await _showResearchShareSheet();
      return;
    }
    if (_output.type == 'writing') {
      await _shareWritingOutput();
      return;
    }
    final brief = _output.data['brief'] as String? ?? _output.input;
    await SharePlus.instance.share(
      ShareParams(text: brief, subject: _output.title),
    );
  }

  Future<void> _shareWritingOutput() async {
    final platformsRaw = _output.data['platforms'];
    final labelsRaw = _output.data['platform_labels'];
    final platforms = platformsRaw is Map
        ? Map<String, dynamic>.from(platformsRaw)
        : <String, dynamic>{};
    final labels =
        labelsRaw is Map ? Map<String, dynamic>.from(labelsRaw) : <String, dynamic>{};
    final tabIds = platforms.keys.where((k) => labels.containsKey(k)).toList();
    String text;
    if (tabIds.isEmpty) {
      text = _output.input;
    } else {
      final selectedIdx = _selectedTab.clamp(0, tabIds.length - 1);
      final selectedId = tabIds[selectedIdx];
      text = platforms[selectedId]?.toString() ?? _output.input;
    }
    await SharePlus.instance.share(
      ShareParams(text: text, subject: _output.title),
    );
  }

  Future<void> _showResearchShareSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14142A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.article_outlined, color: Color(0xFF5B5BD6)),
                title: Text('Share Markdown (.md)', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareResearchFile(ReportExportFormat.markdown);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF5B5BD6)),
                title: Text('Share PDF', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareResearchFile(ReportExportFormat.pdf);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Color(0xFF5B5BD6)),
                title: Text('Share Word (.docx)', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareResearchFile(ReportExportFormat.docx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined, color: Color(0xFF7A7A9A)),
                title: Text('Copy full text', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _researchSharePlainBody()));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFF1A3A1A),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_outlined, color: Color(0xFF7A7A9A)),
                title: Text('Share as plain text', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      text: _researchSharePlainBody(),
                      subject: 'Research report',
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Color(0xFF5B5BD6)),
                title: Text('Create content', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCreateContentFromResearch();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareResearchFile(ReportExportFormat format) async {
    final ok = await ReportExportService.instance.shareWorkflowMarkdown(
      title: _output.title,
      markdown: _researchReportController!.text,
      format: format,
      createdAt: _output.createdAt,
      userQuestion: _output.input,
      fileBaseName: _researchExportFileStem(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Share sheet opened' : 'Share failed',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: ok ? const Color(0xFF1A3A1A) : const Color(0xFF3A1515),
      ),
    );
  }

  Widget _buildCompetitorBody() {
    final card = _output.data['card'];
    final brief = _output.data['brief'] as String? ?? _output.input;
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
    final platformsRaw = _output.data['platforms'];
    final labelsRaw = _output.data['platform_labels'];

    final platforms = platformsRaw is Map
        ? Map<String, dynamic>.from(platformsRaw)
        : <String, dynamic>{};
    final labels =
        labelsRaw is Map ? Map<String, dynamic>.from(labelsRaw) : <String, dynamic>{};

    final tabIds = platforms.keys.where((k) => labels.containsKey(k)).toList();
    if (tabIds.isEmpty) {
      final report = _output.data['report'] as String? ?? '';
      final body = report.trim().isNotEmpty ? report : _output.input;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: body.trim().isEmpty ? '_No content._' : body,
          styleSheet: _researchMarkdownStyle(),
          selectable: true,
          shrinkWrap: true,
          fitContent: true,
        ),
      );
    }

    final selectedIdx = _selectedTab.clamp(0, tabIds.length - 1);
    final selectedId = tabIds[selectedIdx];
    final selectedLabel = labels[selectedId]?.toString() ?? selectedId;
    final content = platforms[selectedId]?.toString() ?? '';
    final researchReport = (_output.data['report'] as String?)?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (researchReport.isNotEmpty) ...[
            Text(
              'Research report (used for writing)',
              style: GoogleFonts.inter(
                color: const Color(0xFF8A8AB0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: researchReport,
              styleSheet: _researchMarkdownStyle(),
              selectable: true,
              shrinkWrap: true,
              fitContent: true,
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF1C1C30), height: 1),
            const SizedBox(height: 16),
          ],
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

