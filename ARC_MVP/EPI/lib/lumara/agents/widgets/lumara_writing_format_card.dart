import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared with Agents home and LUMARA Writing. IDs are sent to the Worker as `writing_preferences.format`.
class LumaraWritingFormatIds {
  LumaraWritingFormatIds._();

  static const researchPaper = 'research_paper';
  static const article = 'article';
  static const shortThreads = 'short_threads';
  static const mediumSocial = 'medium_social';
  /// Legacy worker / persisted ids — map to [article] in UI.
  static const largeSubstack = 'large_substack';
  static const xlWhitePaper = 'xl_white_paper';

  static const List<MapEntry<String, String>> options = [
    MapEntry(shortThreads, 'Short'),
    MapEntry(mediumSocial, 'Medium'),
    MapEntry(article, 'Article'),
    MapEntry(researchPaper, 'Research'),
  ];

  /// Collapse removed tiers so selectors always show a valid chip.
  static String normalizeSelectableId(String id) {
    if (id == largeSubstack || id == xlWhitePaper) return article;
    return id;
  }

  static bool showIncludeSourcesCheckbox(String id) {
    switch (id) {
      case researchPaper:
      case article:
        return true;
      default:
        return false;
    }
  }
}

/// Writing format selector, optional research-paper specs, and "include sources" for long-form.
class LumaraWritingFormatCard extends StatefulWidget {
  const LumaraWritingFormatCard({
    super.key,
    required this.selectedId,
    required this.onSelect,
    required this.specsController,
    this.researchPaperSpecsController,
    this.hintText =
        'Optional: focus, word or page length, audience, tone notes…',
    this.includeSources = false,
    this.onIncludeSourcesChanged,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;
  final TextEditingController specsController;
  /// When set, research paper shows this controller for focus/pages/etc. (more comprehensive than article).
  final TextEditingController? researchPaperSpecsController;
  final String hintText;

  final bool includeSources;
  final ValueChanged<bool>? onIncludeSourcesChanged;

  @override
  State<LumaraWritingFormatCard> createState() =>
      _LumaraWritingFormatCardState();
}

class _LumaraWritingFormatCardState extends State<LumaraWritingFormatCard> {
  @override
  Widget build(BuildContext context) {
    final id = widget.selectedId;
    final specsHint = id == LumaraWritingFormatIds.researchPaper
        ? 'Focus, page length, citation style, thesis — research-length output is more comprehensive than a typical article.'
        : widget.hintText;
    final rpController =
        widget.researchPaperSpecsController ?? widget.specsController;

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
            'WRITING FORMAT',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick target length. Add specifics below.',
            style: GoogleFonts.inter(
              color: const Color(0xFF5A5A7A),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LumaraWritingFormatIds.options.map((e) {
              final active = id == e.key;
              return GestureDetector(
                onTap: () => widget.onSelect(e.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? const Color(0xFF5B5BD6).withValues(alpha: 0.15)
                        : const Color(0xFF0F0F1E),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF5B5BD6)
                          : const Color(0xFF1A1A2C),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? const Color(0xFF8888FF)
                          : const Color(0xFF55556A),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (LumaraWritingFormatIds.showIncludeSourcesCheckbox(id)) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: widget.includeSources,
                    onChanged: widget.onIncludeSourcesChanged == null
                        ? null
                        : (v) =>
                            widget.onIncludeSourcesChanged!(v ?? false),
                    activeColor: const Color(0xFF5B5BD6),
                    side: const BorderSide(color: Color(0xFF44445A)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Include a list of sources at the end',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFC0C0E0),
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            id == LumaraWritingFormatIds.researchPaper
                ? 'RESEARCH DETAILS'
                : 'FORMAT DETAILS',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF33334A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller:
                id == LumaraWritingFormatIds.researchPaper ? rpController : widget.specsController,
            minLines: id == LumaraWritingFormatIds.researchPaper ? 3 : 2,
            maxLines: 8,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFFE0E0F0),
            ),
            decoration: InputDecoration(
              hintText: specsHint,
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFF44445A),
                fontSize: 12,
              ),
              filled: true,
              fillColor: const Color(0xFF0C0C1A),
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
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
