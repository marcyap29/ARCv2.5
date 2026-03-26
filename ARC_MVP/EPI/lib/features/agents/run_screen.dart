import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/app/app.dart' show navigatorKey;
import 'package:my_app/features/outputs/output_detail_screen.dart';
import 'package:my_app/shared/ui/home/home_cubit.dart';
import 'package:uuid/uuid.dart';

import 'agents_data.dart';
import 'worker_service.dart';
import '../outputs/output_model.dart';
import '../outputs/outputs_storage.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({
    super.key,
    required this.chain,
    required this.input,
    this.requestParts = const <RequestPart>[],
    this.attachments = const <AgentAttachment>[],
    this.platforms,
    required this.personaKey,
    required this.useChronicle,
    required this.enabledAgentIds,
    this.writingFormatId = 'article',
    this.researchPaperSpecs = '',
  });

  final WorkflowChain chain;
  final String input;
  final List<RequestPart> requestParts;
  final List<AgentAttachment> attachments;
  final List<String>? platforms;
  final String personaKey;
  final bool useChronicle;

  /// Agent and plugin ids that were toggled on when the run started (orchestrator input).
  final List<String> enabledAgentIds;

  /// Passed to Worker as `writing_preferences.format` / `research_paper_specs`.
  final String writingFormatId;
  final String researchPaperSpecs;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

void _applyWritingFormatPlatformDefaults(
  String formatId,
  Map<String, bool> selections,
) {
  switch (formatId) {
    case 'substack':
      if (selections.containsKey('orbital_ai')) {
        selections['orbital_ai'] = true;
      }
      break;
    case 'linkedin_article':
      if (selections.containsKey('linkedin')) {
        selections['linkedin'] = true;
      }
      break;
    default:
      break;
  }
}

class _RunScreenState extends State<RunScreen> {
  String _phase = 'confirm';
  int _stepIdx = 0;
  bool _showBundle = false;
  late List<bool> _partDone;
  String _currentMessage = '';
  Map<String, dynamic>? _result;
  String _errorMessage = '';
  StreamSubscription<Map<String, dynamic>>? _streamSub;
  /// Set when a run completes and the output is persisted (for "View report").
  WorkflowOutput? _savedWorkflowOutput;
  Map<String, bool> _platformSelections = {};
  /// Latest status line per chain step index (keeps completed steps visible).
  final Map<int, String> _stepStatusByIndex = {};
  final List<String> _activityLog = [];

  @override
  void initState() {
    super.initState();
    _partDone = List<bool>.filled(widget.requestParts.length, false);
    _platformSelections = {
      for (final p in WritingPlatforms.all) p.id: p.defaultSelected,
    };
    final ids = widget.platforms;
    if (ids != null && ids.isNotEmpty) {
      for (final p in WritingPlatforms.all) {
        _platformSelections[p.id] = ids.contains(p.id);
      }
    }
    _applyWritingFormatPlatformDefaults(widget.writingFormatId, _platformSelections);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  bool _isPartRunning(int i) {
    if (_phase != 'running') return false;
    if (i >= _partDone.length || _partDone[i]) return false;
    for (var j = 0; j < i; j++) {
      if (!_partDone[j]) return false;
    }
    return true;
  }

  bool get _chainHasWriting =>
      widget.chain.steps.any((s) => s.toLowerCase().contains('writing'));

  List<String> get _selectedPlatformIds => _platformSelections.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList();

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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildYouSaidCard(),
                    if (widget.requestParts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildRequestPartsTrackingCard(),
                    ],
                    if (widget.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAttachmentsContextCard(),
                    ],
                    const SizedBox(height: 12),
                    _buildOrchestratorCard(),
                    const SizedBox(height: 12),
                    _buildChronicleCard(),
                    const SizedBox(height: 12),
                    if (_phase == 'confirm' && _chainHasWriting) ...[
                      _buildPlatformSelector(),
                      const SizedBox(height: 12),
                    ],
                    _buildChainCard(),
                    if (_phase == 'running' && _activityLog.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildActivityLogCard(),
                    ],
                    const SizedBox(height: 14),
                    if (_phase == 'error') ...[
                      _buildErrorCard(),
                      const SizedBox(height: 14),
                    ],
                    if (_phase == 'done') ...[
                      _buildDoneCard(),
                      const SizedBox(height: 14),
                    ],
                    if (_phase != 'done' && _phase != 'error') _buildCtas(),
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
                widget.chain.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 52),
          ],
        ),
      ),
    );
  }

  Widget _buildYouSaidCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU SAID',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.input.trim().isEmpty
                ? '(No message text — context from parts and attachments below.)'
                : '"${widget.input}"',
            style: GoogleFonts.inter(
              color: const Color(0xFF9090B0),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPartsTrackingCard() {
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
            'REQUEST PARTS',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.requestParts.length, (i) {
            final p = widget.requestParts[i];
            final done = i < _partDone.length && _partDone[i];
            final running = _isPartRunning(i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      done
                          ? Icons.check_circle
                          : running
                              ? Icons.timelapse
                              : Icons.radio_button_unchecked,
                      color: done
                          ? const Color(0xFF34D399)
                          : running
                              ? const Color(0xFF5B5BD6)
                              : const Color(0xFF44445A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title.trim().isEmpty
                              ? 'Part ${i + 1}'
                              : p.title,
                          style: GoogleFonts.inter(
                            color: done
                                ? const Color(0xFF34D399)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (p.detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            p.detail,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7070A0),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (running) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Running…',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF5B5BD6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (_phase == 'running' && !done && !running) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Waiting',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF2A2A40),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (_phase == 'confirm') ...[
                          const SizedBox(height: 4),
                          Text(
                            'Queued',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF2A2A40),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAttachmentsContextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📎',
                style: GoogleFonts.inter(fontSize: 15),
              ),
              const SizedBox(width: 8),
              Text(
                'ATTACHMENTS',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF5B5BD6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Filenames and sizes are passed into the worker context. Open files on device to extract text when supported.',
            style: GoogleFonts.inter(
              color: const Color(0xFF7070A0),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...widget.attachments.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    _iconForExtension(a.extension),
                    color: const Color(0xFF7A7A9A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${a.fileName} · ${AgentsData.formatBytes(a.sizeBytes)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFC0C0E0),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _iconForExtension(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf_outlined;
    if (e == 'doc' || e == 'docx') return Icons.description_outlined;
    if (e == 'jpg' ||
        e == 'jpeg' ||
        e == 'png' ||
        e == 'gif' ||
        e == 'webp' ||
        e == 'heic') {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildOrchestratorCard() {
    final persona = AgentsData.personas[widget.personaKey]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🧠', style: GoogleFonts.inter(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                'LUMARA UNDERSTOOD',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF5B5BD6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.chain.reason,
            style: GoogleFonts.inter(
              color: const Color(0xFF7070A0),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (widget.useChronicle) ...[
            const SizedBox(height: 8),
            Text(
              '+ CHRONICLE context: ${persona.recentEntries[0]}',
              style: GoogleFonts.inter(
                color: const Color(0xFF444464),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChronicleCard() {
    final persona = AgentsData.personas[widget.personaKey]!;
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
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E38),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('📖', style: GoogleFonts.inter(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHRONICLE context',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.useChronicle
                          ? 'Personalising from your journal and history'
                          : 'Off — running without personal context',
                      style: GoogleFonts.inter(
                        color: widget.useChronicle
                            ? const Color(0xFF5B5BD6)
                            : const Color(0xFF44445A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: 0.5,
                child: _buildToggle(widget.useChronicle),
              ),
            ],
          ),
          if (widget.useChronicle) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1C1C30), height: 1),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showBundle = !_showBundle),
              child: Text(
                '${_showBundle ? '▾' : '▸'} What gets pulled from CHRONICLE',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF5B5BD6),
                  fontSize: 12,
                ),
              ),
            ),
            if (_showBundle) ...[
              const SizedBox(height: 12),
              _bundleRow('PROFILE', persona.role),
              _bundleRow('TAGS', persona.tags.take(3).join(', ')),
              _bundleRow('RECENT', persona.recentEntries[0]),
              _bundleRow('MATCHED', persona.recentEntries.take(2).join('; ')),
              const SizedBox(height: 8),
              Text(
                'Injected as user_context block into every Worker synthesis prompt.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF2A2A40),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformSelector() {
    final noneSelected = _platformSelections.values.where((v) => v).isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('✍️', style: GoogleFonts.inter(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publishing platforms',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Where should we write this?',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF5A5A7A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1C1C30), height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in WritingPlatforms.all)
                _platformChip(
                  platform: p,
                  selected: _platformSelections[p.id] ?? false,
                  onToggle: () {
                    setState(() {
                      _platformSelections[p.id] = !(_platformSelections[p.id] ?? false);
                    });
                  },
                ),
            ],
          ),
          if (noneSelected) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ Select at least one platform',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _platformChip({
    required WritingPlatform platform,
    required bool selected,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? const Color(0xFF5B5BD6).withValues(alpha: 0.15)
              : const Color(0xFF0F0F1E),
          border: Border.all(
            color: selected ? const Color(0xFF5B5BD6) : const Color(0xFF1A1A2C),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(platform.emoji, style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              platform.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? const Color(0xFF8888FF) : const Color(0xFF55556A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bundleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
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
                color: const Color(0xFF7070A0),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pushActivityLogLine(String line) {
    final ts = TimeOfDay.now().format(context);
    _activityLog.add('[$ts] $line');
    const maxLines = 40;
    while (_activityLog.length > maxLines) {
      _activityLog.removeAt(0);
    }
  }

  String _subtitleForStep({
    required int index,
    required bool isComplete,
    required bool isActive,
  }) {
    if (isComplete) {
      final s = _stepStatusByIndex[index];
      if (s != null && s.trim().isNotEmpty) {
        return 'Done · ${s.length > 120 ? '${s.substring(0, 120)}…' : s}';
      }
      return 'Complete';
    }
    if (isActive) {
      return _currentMessage.isNotEmpty ? _currentMessage : 'Running...';
    }
    if (_phase == 'confirm') return 'Queued';
    return 'Waiting';
  }

  Widget _buildActivityLogCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY LOG',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ..._activityLog.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF6A6A8A),
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _phase == 'confirm' ? 'PROPOSED CHAIN' : 'RUNNING',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF33334A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.chain.steps.length,
            separatorBuilder: (context, index) {
              final complete = _isComplete(index);
              return Padding(
                padding: const EdgeInsets.only(left: 46, top: 2, bottom: 2),
                child: Text(
                  '↓ output feeds next step',
                  style: GoogleFonts.robotoMono(
                    color: complete
                        ? const Color(0xFF1E3A1E)
                        : const Color(0xFF1C1C2C),
                    fontSize: 10,
                  ),
                ),
              );
            },
            itemBuilder: (context, index) {
              final step = widget.chain.steps[index];
              final stepAgent = AgentsData.findAgentByStepLabel(step);
              final stepColor = AgentsData.stepColor(step);
              final isComplete = _isComplete(index);
              final isActive = _isActive(index);
              final waitingColor = _phase == 'confirm'
                  ? const Color(0xFF7070A0)
                  : const Color(0xFF44445A);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isComplete
                            ? const Color(0xFF122212)
                            : isActive
                                ? stepColor.withValues(alpha: 0.13)
                                : const Color(0xFF131325),
                        border: Border.all(
                          color: isComplete
                              ? const Color(0xFF34D399)
                              : isActive
                                  ? stepColor
                                  : const Color(0xFF22223A),
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: stepColor.withValues(alpha: 0.27),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        isComplete ? '✓' : '${index + 1}',
                        style: GoogleFonts.inter(
                          color: isComplete
                              ? const Color(0xFF34D399)
                              : isActive
                                  ? stepColor
                                  : waitingColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isComplete
                                  ? const Color(0xFF34D399)
                                  : isActive
                                      ? Colors.white
                                      : _phase == 'confirm'
                                          ? const Color(0xFFC0C0E0)
                                          : const Color(0xFF55556A),
                            ),
                            child: Text(step),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitleForStep(
                              index: index,
                              isComplete: isComplete,
                              isActive: isActive,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isComplete
                                  ? const Color(0xFF1E4A1E)
                                  : isActive
                                      ? stepColor
                                      : const Color(0xFF2A2A40),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stepAgent?.isPlugin == true) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFB923C).withValues(alpha: 0.3),
                          ),
                          color: const Color(0xFFFB923C).withValues(alpha: 0.07),
                        ),
                        child: Text(
                          'SwarmSpace',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFFFB923C),
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Opacity(
                      opacity: (isComplete || isActive || _phase == 'confirm')
                          ? 1
                          : 0.3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: stepColor.withValues(alpha: 0.2)),
                          color: stepColor.withValues(alpha: 0.07),
                        ),
                        child: Text(
                          step.split(' ').first,
                          style: GoogleFonts.robotoMono(
                            color: stepColor,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isComplete(int index) {
    if (_phase == 'done') return true;
    if (_phase != 'running') return false;
    return index < _stepIdx;
  }

  bool _isActive(int index) {
    if (_phase != 'running') return false;
    return index == _stepIdx;
  }

  String _previewReportText(String r) =>
      r.length > 300 ? '${r.substring(0, 300)}...' : r;

  Widget _buildDoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF183020)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C1C10), Color(0xFF0F0F22)],
        ),
      ),
      child: Column(
        children: [
          Text(
            '✓',
            style: GoogleFonts.inter(
              color: const Color(0xFF34D399),
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Done',
            style: GoogleFonts.inter(
              color: const Color(0xFF34D399),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your agent chain completed successfully. LUMARA has prepared outputs and a final synthesis report.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF5A5A7A),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (_result != null && _result!['report'] is String) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1C1C30)),
              ),
              child: Text(
                _previewReportText(_result!['report'] as String),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF7070A0),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ghostButton('Run another', () => Navigator.pop(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _primaryButton('View report →', () {
                  final o = _savedWorkflowOutput;
                  if (o == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Output is still saving. Try again in a moment.'),
                        backgroundColor: Color(0xFF2A2A3E),
                      ),
                    );
                    return;
                  }
                  _navigateToSavedOutput(o);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCtas() {
    if (_phase == 'confirm') {
      return Column(
        children: [
          _primaryButton('Looks right — run it →', _startRun),
          const SizedBox(height: 10),
          _ghostButton('Change my request', () => Navigator.pop(context)),
        ],
      );
    }
    return _primaryButton('Running...', null);
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B5BD6),
          disabledBackgroundColor: const Color(0xFF5B5BD6).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        children: [
          Text(
            '⚠️',
            style: GoogleFonts.inter(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFFFF6B6B),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF5A5A7A),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _startRun,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF222238)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A7A9A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF222238)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Go back',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A7A9A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ghostButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF222238)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF7A7A9A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: 44,
      height: 24,
      decoration: BoxDecoration(
        color: value ? const Color(0xFF5B5BD6) : const Color(0xFF252538),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: value ? 22 : 2,
            top: 2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSavedOutput(WorkflowOutput o) {
    HomeCubit? homeCubit;
    try {
      homeCubit = context.read<HomeCubit>();
    } catch (_) {
      homeCubit = null;
    }
    if (homeCubit != null) {
      Navigator.of(context).pop();
      homeCubit.changeTab(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Navigator.of(ctx).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => OutputDetailScreen(output: o),
            ),
          );
        }
      });
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OutputDetailScreen(output: o),
      ),
    );
  }

  void _startRun() {
    unawaited(_startRunAsync());
  }

  Future<void> _onWorkflowResult(Map<String, dynamic> event) async {
    if (!mounted) return;
    final data = event['data'];
    Map<String, dynamic>? resultMap;
    if (data is Map) {
      resultMap = Map<String, dynamic>.from(data);
    }
    setState(() {
      for (var i = 0; i < _partDone.length; i++) {
        _partDone[i] = true;
      }
      _result = resultMap;
    });
    final output = WorkflowOutput(
      id: const Uuid().v4(),
      type: WorkflowOutput.typeFromSteps(widget.chain.steps),
      title: widget.input.length > 60
          ? '${widget.input.substring(0, 60)}...'
          : widget.input,
      input: widget.input,
      createdAt: DateTime.now(),
      data: resultMap ?? <String, dynamic>{},
      steps: widget.chain.steps,
    );
    await OutputsStorage.save(output);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _phase = 'done';
      _savedWorkflowOutput = output;
    });
  }

  Future<void> _startRunAsync() async {
    await _streamSub?.cancel();
    _streamSub = null;

    if (!mounted) return;
    setState(() {
      _phase = 'running';
      _stepIdx = 0;
      _currentMessage = '';
      _errorMessage = '';
      _result = null;
      _savedWorkflowOutput = null;
      _stepStatusByIndex.clear();
      _activityLog.clear();
    });

    final endpoint = WorkerService.resolveEndpoint(widget.chain);

    ChronicleBundle? bundle;
    if (widget.useChronicle) {
      final persona = AgentsData.personas[widget.personaKey];
      if (persona != null) {
        bundle = ChronicleBundle(
          profile: persona.role,
          tags: persona.tags.join(', '),
          recent: persona.recentEntries.isNotEmpty
              ? persona.recentEntries[0]
              : '',
          topical: persona.recentEntries.take(2).join('; '),
        );
      }
    }

    Map<String, dynamic>? writingPrefs;
    if (_chainHasWriting) {
      writingPrefs = {
        'format': widget.writingFormatId,
        if (widget.researchPaperSpecs.isNotEmpty)
          'research_paper_specs': widget.researchPaperSpecs,
      };
    }

    try {
      _streamSub = WorkerService.streamWorkflow(
        endpoint: endpoint,
        input: widget.input,
        useChronicle: widget.useChronicle,
        chronicle: bundle,
        platforms: _chainHasWriting ? _selectedPlatformIds : null,
        writingPreferences: writingPrefs,
      ).listen(
        (event) {
          if (!mounted) return;

          final type = event['type'] as String? ?? '';
          final step = event['step'] as String? ?? '';
          final message = event['message'] as String? ?? '';

          switch (type) {
            case 'step_start':
              final idx = widget.chain.steps.indexWhere(
                (s) => s.toLowerCase() == step.toLowerCase(),
              );
              if (idx >= 0) {
                setState(() {
                  _stepIdx = idx;
                  _currentMessage = message;
                  if (message.isNotEmpty) {
                    _stepStatusByIndex[idx] = message;
                    _pushActivityLogLine('${widget.chain.steps[idx]} — $message');
                  } else {
                    _pushActivityLogLine('${widget.chain.steps[idx]} — started');
                  }
                });
              } else {
                setState(() {
                  _currentMessage = message;
                  _pushActivityLogLine(
                    step.isNotEmpty ? '$step — $message' : message,
                  );
                });
              }
              break;
            case 'progress':
              setState(() {
                _currentMessage = message;
                if (_stepIdx >= 0 &&
                    _stepIdx < widget.chain.steps.length &&
                    message.isNotEmpty) {
                  _stepStatusByIndex[_stepIdx] = message;
                }
                if (message.isNotEmpty) {
                  _pushActivityLogLine(message);
                }
              });
              break;
            case 'step_complete':
              final idx = widget.chain.steps.indexWhere(
                (s) => s.toLowerCase() == step.toLowerCase(),
              );
              if (idx >= 0) {
                setState(() {
                  if (message.isNotEmpty) {
                    _stepStatusByIndex[idx] = message;
                    _pushActivityLogLine(
                      '${widget.chain.steps[idx]} complete — $message',
                    );
                  } else {
                    _pushActivityLogLine('${widget.chain.steps[idx]} complete');
                  }
                  if (idx + 1 < widget.chain.steps.length) {
                    _stepIdx = idx + 1;
                  } else {
                    _stepIdx = widget.chain.steps.length;
                  }
                  _currentMessage = message;
                });
              }
              break;
            case 'result':
              unawaited(_onWorkflowResult(event));
              break;
            case 'error':
              setState(() {
                _phase = 'error';
                _errorMessage = message;
              });
              break;
          }
        },
        onError: (Object e, StackTrace _) {
          if (mounted) {
            setState(() {
              _phase = 'error';
              _errorMessage = 'Connection failed: $e';
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = 'error';
          _errorMessage = 'Connection failed: $e';
        });
      }
    }
  }
}
