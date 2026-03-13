// lib/arc/outputs/output_detail_screen.dart
//
// Phase 5a: Full content view for an OutputItem.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/widgets/tag_chip_row.dart';
import 'package:my_app/shared/app_colors.dart';

class OutputDetailScreen extends StatelessWidget {
  final OutputItem item;

  const OutputDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMd().add_Hm().format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
            if (item.autoTags.isNotEmpty || item.userTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              TagChipRow(
                autoTags: item.autoTags,
                userTags: item.userTags,
                editable: false,
              ),
            ],
            if (item.contentJson != null && item.contentJson!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Content',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  item.contentJson!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kcPrimaryTextColor,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
