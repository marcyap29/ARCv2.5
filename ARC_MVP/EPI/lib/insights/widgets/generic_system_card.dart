import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Configuration for a generic system information card
class SystemCardConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<SystemCardSection> sections;
  final Widget? footer;

  const SystemCardConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.sections,
    this.footer,
  });
}

/// A section within a system card
class SystemCardSection {
  final String? title;
  final Widget content;
  final Color? backgroundColor;
  final Color? borderColor;

  const SystemCardSection({
    this.title,
    required this.content,
    this.backgroundColor,
    this.borderColor,
  });
}

/// Generic system information card widget
/// Replaces duplicate card implementations (AuroraCard, VeilCard) with unified, configurable component
class GenericSystemCard extends StatefulWidget {
  final SystemCardConfig config;
  final bool isLoading;
  final List<String>? expandableSections;
  final Map<String, List<String>>? expandableContent;

  const GenericSystemCard({
    super.key,
    required this.config,
    this.isLoading = false,
    this.expandableSections,
    this.expandableContent,
  });

  @override
  State<GenericSystemCard> createState() => _GenericSystemCardState();
}

class _GenericSystemCardState extends State<GenericSystemCard> {
  bool _showMoreInfo = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingCard();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          ...widget.config.sections.map(_buildSection),
          if (widget.expandableSections != null) ...[
            const SizedBox(height: 16),
            _buildExpandToggle(),
            if (_showMoreInfo) ..._buildExpandableContent(),
          ],
          if (widget.config.footer != null) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: kcBorderColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            widget.config.footer!,
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryTextColor),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.config.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.config.icon,
            size: 20,
            color: widget.config.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.config.title, style: heading2Style(context)),
              Text(
                widget.config.subtitle,
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryTextColor.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(SystemCardSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: section.backgroundColor != null || section.borderColor != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: section.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: section.borderColor != null
                    ? Border.all(color: section.borderColor!)
                    : null,
              ),
              child: _buildSectionContent(section),
            )
          : _buildSectionContent(section),
    );
  }

  Widget _buildSectionContent(SystemCardSection section) {
    if (section.title == null) return section.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title!,
          style: bodyStyle(context).copyWith(
            fontSize: 11,
            color: kcPrimaryTextColor.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        section.content,
      ],
    );
  }

  Widget _buildExpandToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showMoreInfo = !_showMoreInfo),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _showMoreInfo ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: kcPrimaryTextColor.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              _showMoreInfo ? 'Hide Details' : 'Show Available Options',
              style: bodyStyle(context).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kcPrimaryTextColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExpandableContent() {
    if (widget.expandableSections == null || widget.expandableContent == null) {
      return [];
    }

    return widget.expandableSections!.map((sectionTitle) {
      final items = widget.expandableContent![sectionTitle] ?? [];
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcSurfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle,
                style: bodyStyle(context).copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kcPrimaryTextColor.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      item,
                      style: bodyStyle(context).copyWith(
                        fontSize: 11,
                        color: kcPrimaryTextColor.withOpacity(0.7),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Helper widgets for common card content types
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? description;
  final Color? iconColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.description,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? kcPrimaryTextColor.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: bodyStyle(context).copyWith(
                  fontSize: 11,
                  color: kcPrimaryTextColor.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: bodyStyle(context).copyWith(
                  fontSize: 13,
                  color: kcPrimaryTextColor.withOpacity(0.9),
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: bodyStyle(context).copyWith(
                    fontSize: 11,
                    color: kcPrimaryTextColor.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
