import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:my_app/shared/app_colors.dart';

/// Import status screen under Settings → Import.
/// Shows current import progress and a list of files with status (pending / in progress / completed / failed).
/// When no import is active, shows "Choose files to import" to start one.
class ImportStatusScreen extends StatelessWidget {
  /// Called when user taps "Choose files to import" (e.g. opens file picker from Settings).
  final VoidCallback? onChooseFiles;

  const ImportStatusScreen({
    super.key,
    this.onChooseFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        title: const Text('Import'),
        backgroundColor: kcSurfaceColor,
        foregroundColor: kcPrimaryTextColor,
      ),
      body: BlocBuilder<ImportProgressCubit, ImportProgressState>(
        builder: (context, state) {
          if (state.isActive) {
            return _buildActiveImport(context, state);
          }
          if (state.completed || state.error != null) {
            return _buildCompletedOrFailed(context, state);
          }
          return _buildIdle(context);
        },
      ),
    );
  }

  Widget _buildActiveImport(BuildContext context, ImportProgressState state) {
    final hasFraction = state.fraction > 0 && state.fraction <= 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Import in progress',
            style: TextStyle(
              color: kcPrimaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hasFraction ? state.fraction : null,
              backgroundColor: kcSurfaceAltColor,
              valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
              minHeight: 8,
            ),
          ),
          if (!hasFraction)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'You can keep using the app',
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ),
          if (state.fileItems != null && state.fileItems!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Files',
              style: TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...state.fileItems!.asMap().entries.map((e) => _FileStatusRow(
                  fileName: e.value.fileName,
                  status: e.value.status,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedOrFailed(BuildContext context, ImportProgressState state) {
    final cubit = context.read<ImportProgressCubit>();
    final isError = state.error != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 48,
            color: isError ? kcDangerColor : kcSuccessColor,
          ),
          const SizedBox(height: 16),
          Text(
            isError ? 'Import failed' : 'Import complete',
            style: TextStyle(
              color: kcPrimaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isError ? (state.error ?? state.message) : state.message,
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
          if (state.fileItems != null && state.fileItems!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Files',
              style: TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...state.fileItems!.map((e) => _FileStatusRow(
                  fileName: e.fileName,
                  status: e.status,
                )),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              cubit.clearCompleted();
              if (context.mounted) Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: kcPrimaryColor,
              foregroundColor: kcPrimaryTextColor,
            ),
            child: const Text('Done'),
          ),
          if (onChooseFiles != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onChooseFiles,
              style: OutlinedButton.styleFrom(
                foregroundColor: kcPrimaryTextColor,
                side: const BorderSide(color: kcPrimaryColor),
              ),
              child: const Text('Import more'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 56,
            color: kcSecondaryTextColor.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'No import in progress',
            style: TextStyle(
              color: kcPrimaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Restore from .zip, .mcpkg, or .arcx backup files.',
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (onChooseFiles != null)
            FilledButton.icon(
              onPressed: onChooseFiles,
              icon: const Icon(Icons.folder_open, size: 20),
              label: const Text('Choose files to import'),
              style: FilledButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                foregroundColor: kcPrimaryTextColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileStatusRow extends StatelessWidget {
  final String fileName;
  final ImportFileStatus status;

  const _FileStatusRow({
    required this.fileName,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;
    switch (status) {
      case ImportFileStatus.pending:
        icon = Icons.schedule;
        color = kcSecondaryTextColor;
        label = 'Pending';
        break;
      case ImportFileStatus.importing:
        icon = Icons.sync;
        color = kcPrimaryColor;
        label = 'In progress';
        break;
      case ImportFileStatus.completed:
        icon = Icons.check_circle;
        color = kcSuccessColor;
        label = 'Completed';
        break;
      case ImportFileStatus.failed:
        icon = Icons.error;
        color = kcDangerColor;
        label = 'Failed';
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: TextStyle(
                    color: kcPrimaryTextColor,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
