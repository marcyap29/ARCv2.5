// Google Drive folder picker: browse folders and select multiple for import.

import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Result of the picker: selected folder IDs and/or selected file IDs for import.
class DriveFolderPickerResult {
  final List<String> selectedFolderIds;
  final List<String> selectedFileIds;
  const DriveFolderPickerResult(this.selectedFolderIds, [this.selectedFileIds = const []]);
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
  /// Selected file IDs (for multi-file import; .arcx, .zip, manifest .json, .txt, .md).
  final Set<String> _selectedFileIds = {};
  bool _creatingFolder = false;

  static bool _isImportableFile(String name) {
    return name.endsWith('.arcx') || name.endsWith('.zip') ||
        name.endsWith('.txt') || name.endsWith('.md') ||
        (name.startsWith('arc_backup_manifest_') && name.endsWith('.json'));
  }

  String get _currentFolderId => _folderStack.last.$1;

  String _selectionCountText() {
    final f = _selectedFolderIds.length;
    final files = _selectedFileIds.length;
    if (f > 0 && files > 0) return '$f folder(s), $files file(s)';
    if (f > 0) return '$f folder(s) selected';
    return '$files file(s) selected';
  }

  String _importButtonLabel() {
    final f = _selectedFolderIds.length;
    final files = _selectedFileIds.length;
    if (f > 0 && files > 0) return 'Import from $f folder(s) + $files file(s)';
    if (f > 0) return 'Import from $f folder(s)';
    return 'Import $files file(s)';
  }

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

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'New folder',
          style: bodyStyle(ctx).copyWith(color: kcPrimaryTextColor, fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Folder name',
              labelStyle: const TextStyle(color: kcSecondaryTextColor),
              hintText: 'e.g. LUMARA Backups',
              hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.7)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kcAccentColor)),
            ),
            style: const TextStyle(color: kcPrimaryTextColor),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter a folder name';
              return null;
            },
            onFieldSubmitted: (v) => Navigator.of(ctx).maybePop(v.trim().isEmpty ? null : v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: kcSecondaryTextColor)),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final name = controller.text.trim();
                Navigator.of(ctx).pop(name);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: kcAccentColor, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _creatingFolder = true);
    try {
      final result = await _drive.createFolder(
        parentFolderId: _currentFolderId,
        folderName: name,
      );
      if (!mounted) return;
      if (result != null) {
        await _loadCurrentFolder();
        // Navigate into the new folder so the user can use it immediately
        _navigateInto(result.id, result.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created "${result.name}"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not create folder. Check your connection and try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _creatingFolder = false);
    }
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
          IconButton(
            icon: _creatingFolder
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kcAccentColor),
                  )
                : const Icon(Icons.create_new_folder),
            tooltip: 'Create new folder here',
            onPressed: _creatingFolder ? null : () => _showCreateFolderDialog(context),
          ),
          if (widget.useAsSyncFolder)
            TextButton.icon(
              onPressed: () => _confirmSyncFolder(context),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Use this folder'),
            )
          else if (_selectedFolderIds.isNotEmpty || _selectedFileIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  _selectionCountText(),
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

                  // File row: checkbox if importable, else just show
                  final importable = id != null && _isImportableFile(name);
                  final fileSelected = _selectedFileIds.contains(id);
                  return ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (importable)
                          Checkbox(
                            value: fileSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedFileIds.add(id);
                                } else {
                                  _selectedFileIds.remove(id);
                                }
                              });
                            },
                            activeColor: kcAccentColor,
                          ),
                        if (importable) const SizedBox(width: 0),
                        Icon(
                          _iconForFile(name),
                          color: importable ? kcPrimaryTextColor : kcSecondaryTextColor,
                          size: 28,
                        ),
                      ],
                    ),
                    title: Text(
                      name,
                      style: bodyStyle(context).copyWith(
                        color: importable ? kcPrimaryTextColor : kcSecondaryTextColor,
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
                          'Select folders and/or individual files to import. Backup files (.arcx, .zip) and text files (.txt, .md) can be chosen per file.',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _selectedFolderIds.isEmpty && _selectedFileIds.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(
                                    DriveFolderPickerResult(
                                      _selectedFolderIds.toList(),
                                      _selectedFileIds.toList(),
                                    ),
                                  ),
                          icon: const Icon(Icons.download_done, size: 20),
                          label: Text(
                            _selectedFolderIds.isEmpty && _selectedFileIds.isEmpty
                                ? 'Select folders or files above'
                                : _importButtonLabel(),
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
