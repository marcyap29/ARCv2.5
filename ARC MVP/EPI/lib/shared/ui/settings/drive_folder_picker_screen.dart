// Google Drive folder picker: browse folders and select multiple for import.

import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Result of the picker: list of selected folder IDs (empty if cancelled).
class DriveFolderPickerResult {
  final List<String> selectedFolderIds;
  const DriveFolderPickerResult(this.selectedFolderIds);
}

/// Result when picking a single folder for sync (e.g. "Use this folder for sync").
class DriveSyncFolderResult {
  final String folderId;
  final String folderName;
  const DriveSyncFolderResult(this.folderId, this.folderName);
}

class DriveFolderPickerScreen extends StatefulWidget {
  /// When true, show "Use this folder for sync" and return one folder (DriveSyncFolderResult).
  final bool useAsSyncFolder;

  const DriveFolderPickerScreen({super.key, this.useAsSyncFolder = false});

  @override
  State<DriveFolderPickerScreen> createState() => _DriveFolderPickerScreenState();
}

class _DriveFolderPickerScreenState extends State<DriveFolderPickerScreen> {
  final GoogleDriveService _drive = GoogleDriveService.instance;

  /// Navigation stack: (folderId, displayName). First is root.
  final List<(String id, String name)> _folderStack = [
    (GoogleDriveService.rootFolderId, 'My Drive'),
  ];
  List<drive.File> _items = [];
  bool _loading = true;
  String? _error;
  /// Selected folder IDs (for multi-folder import).
  final Set<String> _selectedFolderIds = {};

  String get _currentFolderId => _folderStack.last.$1;

  @override
  void initState() {
    super.initState();
    _loadCurrentFolder();
  }

  Future<void> _loadCurrentFolder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _drive.listFiles(folderId: _currentFolderId, pageSize: 200);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _navigateInto(String folderId, String folderName) {
    setState(() => _folderStack.add((folderId, folderName)));
    _loadCurrentFolder();
  }

  void _navigateBack() {
    if (_folderStack.length > 1) {
      setState(() => _folderStack.removeLast());
      _loadCurrentFolder();
    } else {
      if (widget.useAsSyncFolder) {
        Navigator.of(context).pop(); // Cancel: no result
      } else {
        Navigator.of(context).pop(const DriveFolderPickerResult([]));
      }
    }
  }

  void _confirmSyncFolder(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop(DriveSyncFolderResult(_currentFolderId, _folderStack.last.$2));
  }

  @override
  Widget build(BuildContext context) {
    final title = _folderStack.last.$2;

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        title: Text(
          title,
          style: bodyStyle(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: kcSurfaceColor,
        foregroundColor: kcPrimaryTextColor,
        actions: [
          if (widget.useAsSyncFolder)
            TextButton.icon(
              onPressed: () => _confirmSyncFolder(context),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Use this folder'),
            )
          else if (_selectedFolderIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_selectedFolderIds.length} selected',
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: bodyStyle(context).copyWith(color: kcDangerColor, fontSize: 13),
              ),
            ),
            OutlinedButton(
              onPressed: _loadCurrentFolder,
              child: const Text('Retry'),
            ),
          ] else if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: kcAccentColor)),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final name = item.name ?? 'Unknown';
                  final id = item.id;
                  final isFolder = (item.mimeType ?? '') == 'application/vnd.google-apps.folder';

                  if (isFolder && id != null) {
                    final selected = _selectedFolderIds.contains(id);
                    return ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.useAsSyncFolder)
                            Checkbox(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedFolderIds.add(id);
                                  } else {
                                    _selectedFolderIds.remove(id);
                                  }
                                });
                              },
                              activeColor: kcAccentColor,
                            ),
                          if (!widget.useAsSyncFolder) const SizedBox(width: 0),
                          Icon(Icons.folder, color: Colors.amber[700], size: 28),
                        ],
                      ),
                      title: Text(
                        name,
                        style: bodyStyle(context).copyWith(color: kcPrimaryTextColor),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: kcSecondaryTextColor),
                      onTap: () => _navigateInto(id, name),
                    );
                  }

                  // File row (no checkbox; just show)
                  return ListTile(
                    leading: Icon(
                      _iconForFile(name),
                      color: kcSecondaryTextColor,
                      size: 28,
                    ),
                    title: Text(
                      name,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: widget.useAsSyncFolder
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sync folder: .txt files in this folder can be imported into the Timeline with a Sync button.',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _confirmSyncFolder(context),
                          icon: const Icon(Icons.folder_special, size: 20),
                          label: const Text('Use this folder for sync'),
                          style: FilledButton.styleFrom(
                            backgroundColor: kcAccentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Select folders to import from. We\'ll import backup files (.arcx, .zip) and text files (.txt) from selected folders.',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _selectedFolderIds.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(
                                    DriveFolderPickerResult(_selectedFolderIds.toList()),
                                  ),
                          icon: const Icon(Icons.download_done, size: 20),
                          label: Text(
                            _selectedFolderIds.isEmpty
                                ? 'Select folders above'
                                : 'Import from ${_selectedFolderIds.length} folder(s)',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kcAccentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForFile(String name) {
    if (name.endsWith('.txt')) return Icons.description;
    if (name.endsWith('.arcx') || name.endsWith('.zip')) return Icons.archive;
    if (name.contains('manifest') && name.endsWith('.json')) return Icons.list_alt;
    return Icons.insert_drive_file;
  }
}
