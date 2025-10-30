import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/ui/settings/settings_cubit.dart';
import 'package:my_app/shared/ui/settings/widgets/settings_tile.dart';
import 'package:my_app/shared/ui/settings/widgets/confirmation_dialog.dart';
import 'package:my_app/arc/core/journal_repository.dart';

class DataView extends StatefulWidget {
  const DataView({super.key});

  @override
  State<DataView> createState() => _DataViewState();
}

class _DataViewState extends State<DataView> {
  Map<String, dynamic>? _storageInfo;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    final journalRepository = context.read<JournalRepository>();
    final settingsCubit = context.read<SettingsCubit>();
    final info = await settingsCubit.getStorageInfo(journalRepository);
    setState(() {
      _storageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Data',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Storage Info Section
              if (_storageInfo != null) ...[
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Storage Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Journal Entries: ${_storageInfo!['total_entries']}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Arcform Snapshots: ${_storageInfo!['total_snapshots']}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Estimated Size: ${_storageInfo!['estimated_size_mb']} MB',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Export Data Section
              SettingsTile(
                title: 'Export All Data',
                subtitle: 'Export your journal entries and arcform snapshots as JSON',
                trailing: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, color: Colors.blue),
                onTap: state.isLoading ? null : () => _exportData(context),
              ),
              const Divider(color: Colors.grey),

              // Delete All Data Section
              SettingsTile(
                title: 'Delete All Data',
                subtitle: 'Permanently delete all your journal entries and data',
                trailing: const Icon(Icons.delete_forever, color: Colors.red),
                onTap: () => _showDeleteConfirmation(context),
              ),

              // Error Display
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red[900],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final journalRepository = context.read<JournalRepository>();
    final settingsCubit = context.read<SettingsCubit>();
    
    await settingsCubit.exportAllData(journalRepository);
    
    if (mounted) {
      _loadStorageInfo(); // Refresh storage info after export
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final journalRepository = context.read<JournalRepository>();
    final settingsCubit = context.read<SettingsCubit>();
    
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete All Data',
      message: 'This will permanently delete all your journal entries and arcform snapshots. This action cannot be undone.\n\nAre you sure you want to continue?',
      confirmText: 'Delete All',
      cancelText: 'Cancel',
    );

    if (confirmed == true && mounted) {
      await settingsCubit.deleteAllData(journalRepository);
      
      if (mounted) {
        _loadStorageInfo(); // Refresh storage info after deletion
      }
    }
  }
}
