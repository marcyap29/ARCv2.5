// Screen to choose timeline entries that were previously synced from the Google Drive sync folder
// and push their current content back to Drive (re-sync to folder).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class SyncFolderPushScreen extends StatefulWidget {
  final JournalRepository journalRepo;
  final String syncFolderId;
  final String syncFolderName;

  const SyncFolderPushScreen({
    super.key,
    required this.journalRepo,
    required this.syncFolderId,
    required this.syncFolderName,
  });

  @override
  State<SyncFolderPushScreen> createState() => _SyncFolderPushScreenState();
}

class _SyncFolderPushScreenState extends State<SyncFolderPushScreen> {
  final GoogleDriveService _driveService = GoogleDriveService.instance;

  List<({SyncedTxtRecord record, JournalEntry entry})> _items = [];
  final Set<String> _selectedEntryIds = {};
  bool _loading = true;
  bool _pushing = false;
  String _pushProgress = '';

  @override
  void initState() {
    super.initState();
    _loadSyncedEntries();
  }

  Future<void> _loadSyncedEntries() async {
    setState(() => _loading = true);
    final records = await _driveService.getSyncedTxtRecords(syncFolderId: widget.syncFolderId);
    final items = <({SyncedTxtRecord record, JournalEntry entry})>[];
    for (final r in records) {
      if (r.journalEntryId.isEmpty) continue;
      final entry = await widget.journalRepo.getJournalEntryById(r.journalEntryId);
      if (entry != null) {
        items.add((record: r, entry: entry));
      }
    }
    items.sort((a, b) => b.entry.updatedAt.compareTo(a.entry.updatedAt));
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _pushSelectedToDrive() async {
    final toPush = _items.where((e) => _selectedEntryIds.contains(e.entry.id)).toList();
    if (toPush.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select one or more entries to push to Drive'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _pushing = true;
      _pushProgress = 'Pushing 0/${toPush.length}...';
    });
    int done = 0;
    int failed = 0;
    for (final item in toPush) {
      if (!mounted) break;
      setState(() => _pushProgress = 'Pushing ${done + 1}/${toPush.length}...');
      final ok = await _driveService.pushEntryContentToDrive(
        entry: item.entry,
        driveFileId: item.record.driveFileId,
        journalRepo: widget.journalRepo,
      );
      if (ok) {
        done++;
      } else {
        failed++;
      }
    }
    if (mounted) {
      setState(() {
        _pushing = false;
        _pushProgress = '';
      });
      if (done > 0) {
        _selectedEntryIds.removeAll(toPush.map((e) => e.entry.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed > 0
                ? 'Updated $done on Drive. $failed failed.'
                : 'Updated $done ${done == 1 ? 'entry' : 'entries'} on Drive.',
          ),
          backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        title: const Text('Push to Drive'),
        backgroundColor: kcSurfaceColor,
        foregroundColor: kcPrimaryTextColor,
        actions: [
          if (_items.isNotEmpty && !_loading && !_pushing)
            TextButton.icon(
              onPressed: _selectedEntryIds.length == _items.length
                  ? () => setState(() => _selectedEntryIds.clear())
                  : () => setState(() => _selectedEntryIds.addAll(_items.map((e) => e.entry.id))),
              icon: Icon(Icons.select_all, size: 20, color: kcAccentColor),
              label: Text(
                _selectedEntryIds.length == _items.length ? 'Clear' : 'Select all',
                style: TextStyle(color: kcAccentColor),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kcAccentColor))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_off, size: 64, color: kcSecondaryTextColor),
                        const SizedBox(height: 16),
                        Text(
                          'No entries from this sync folder',
                          style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sync .txt files from "${widget.syncFolderName}" first, then you can push changes back here.',
                          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_pushing)
                      LinearProgressIndicator(
                        backgroundColor: kcSurfaceAltColor,
                        valueColor: const AlwaysStoppedAnimation<Color>(kcAccentColor),
                      ),
                    if (_pushProgress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          _pushProgress,
                          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 13),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final selected = _selectedEntryIds.contains(item.entry.id);
                          return ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: _pushing
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedEntryIds.add(item.entry.id);
                                        } else {
                                          _selectedEntryIds.remove(item.entry.id);
                                        }
                                      });
                                    },
                              activeColor: kcAccentColor,
                            ),
                            title: Text(
                              item.entry.title.isEmpty ? 'Untitled' : item.entry.title,
                              style: bodyStyle(context).copyWith(
                                color: kcPrimaryTextColor,
                                fontWeight: selected ? FontWeight.w600 : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              DateFormat.yMMMd().add_Hm().format(item.entry.updatedAt),
                              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
                            ),
                            onTap: _pushing
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        _selectedEntryIds.remove(item.entry.id);
                                      } else {
                                        _selectedEntryIds.add(item.entry.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    if (!_loading && _items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          onPressed: _pushing || _selectedEntryIds.isEmpty
                              ? null
                              : _pushSelectedToDrive,
                          icon: _pushing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload, size: 20),
                          label: Text(
                            _pushing
                                ? 'Updating...'
                                : 'Update ${_selectedEntryIds.length} on Drive',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kcAccentColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
