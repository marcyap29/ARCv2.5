import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../media/import/media_import_service.dart';
import '../../media/settings/storage_profiles.dart';

/// Bottom sheet for importing media with storage profile options
class ImportBottomSheet extends StatefulWidget {
  final String entryId;
  final MediaImportService importService;
  final Function(MediaImportResult) onImportComplete;
  final VoidCallback? onDismiss;

  const ImportBottomSheet({
    super.key,
    required this.entryId,
    required this.importService,
    required this.onImportComplete,
    this.onDismiss,
  });

  @override
  State<ImportBottomSheet> createState() => _ImportBottomSheetState();
}

class _ImportBottomSheetState extends State<ImportBottomSheet> {
  StoragePolicy _selectedPolicy = StoragePolicy.minimal; // Default to Space-Saver
  bool _isImporting = false;
  String? _importStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121621),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Import Media',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Storage policy selector
          if (!_isImporting) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Storage Policy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStoragePolicySelector(),
                ],
              ),
            ),

            // Import options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildImportOption(
                    icon: Icons.photo_library,
                    title: 'Import from Photos',
                    subtitle: 'Select images and videos',
                    onTap: () => _showMediaPicker(AssetType.image),
                  ),
                  const SizedBox(height: 12),
                  _buildImportOption(
                    icon: Icons.video_library,
                    title: 'Import Videos',
                    subtitle: 'Select video files',
                    onTap: () => _showMediaPicker(AssetType.video),
                  ),
                  const SizedBox(height: 12),
                  _buildImportOption(
                    icon: Icons.audiotrack,
                    title: 'Import Audio',
                    subtitle: 'Select voice recordings',
                    onTap: () => _showMediaPicker(AssetType.audio),
                  ),
                ],
              ),
            ),
          ],

          // Import progress
          if (_isImporting) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    _importStatus ?? 'Processing media...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          // Bottom padding
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStoragePolicySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildPolicyOption(
            policy: StoragePolicy.minimal,
            title: 'Save space',
            subtitle: 'Keep only thumbnails and transcripts',
            isDefault: true,
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          _buildPolicyOption(
            policy: StoragePolicy.balanced,
            title: 'Balanced',
            subtitle: 'Keep compressed analysis variants',
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          _buildPolicyOption(
            policy: StoragePolicy.hiFidelity,
            title: 'Keep local copy',
            subtitle: 'Store full-resolution encrypted files',
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyOption({
    required StoragePolicy policy,
    required String title,
    required String subtitle,
    bool isDefault = false,
  }) {
    final isSelected = _selectedPolicy == policy;
    
    return InkWell(
      onTap: () => setState(() => _selectedPolicy = policy),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Radio<StoragePolicy>(
              value: policy,
              groupValue: _selectedPolicy,
              onChanged: (value) => setState(() => _selectedPolicy = value!),
              activeColor: Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white30,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMediaPicker(AssetType assetType) async {
    try {
      // Request permissions
      final hasPermission = await widget.importService.requestPermissions();
      if (!hasPermission) {
        _showError('Permission denied. Please allow access to photos.');
        return;
      }

      // Get albums/assets
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        _showError('No media found on device.');
        return;
      }

      final recentAlbum = albums.first;
      final assets = await recentAlbum.getAssetListRange(start: 0, end: 100);

      // Filter by asset type
      final filteredAssets = assets
          .where((asset) => _matchesAssetType(asset, assetType))
          .toList();

      if (filteredAssets.isEmpty) {
        _showError('No ${assetType.name} files found.');
        return;
      }

      // Show asset picker (simplified - would use a proper picker in production)
      final selectedAsset = await _showAssetSelectionDialog(
        context,
        filteredAssets,
        assetType,
      );

      if (selectedAsset != null) {
        await _importAsset(selectedAsset, assetType);
      }
    } catch (e) {
      _showError('Failed to access media: $e');
    }
  }

  bool _matchesAssetType(AssetEntity asset, AssetType requestedType) {
    switch (requestedType) {
      case AssetType.image:
        return asset.type == AssetType.image;
      case AssetType.video:
        return asset.type == AssetType.video;
      case AssetType.audio:
        return asset.type == AssetType.audio;
      case AssetType.other:
        return asset.type == AssetType.other;
    }
  }

  Future<AssetEntity?> _showAssetSelectionDialog(
    BuildContext context,
    List<AssetEntity> assets,
    AssetType assetType,
  ) async {
    // Simplified asset picker - in production would use photo_manager's picker
    return showDialog<AssetEntity>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121621),
        title: Text(
          'Select ${assetType.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return ListTile(
                leading: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailData,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      );
                    }
                    return const Icon(Icons.image, color: Colors.white54);
                  },
                ),
                title: Text(
                  asset.title ?? 'Untitled',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${asset.width}×${asset.height}',
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () => Navigator.of(context).pop(asset),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _importAsset(AssetEntity asset, AssetType assetType) async {
    setState(() {
      _isImporting = true;
      _importStatus = 'Analyzing ${assetType.name}...';
    });

    try {
      final config = ImportConfig(
        profileOverride: StorageProfile.forPolicy(_selectedPolicy),
        currentMode: AppMode.personal,
      );

      MediaImportResult result;
      
      switch (assetType) {
        case AssetType.image:
          setState(() => _importStatus = 'Processing image...');
          result = await widget.importService.importImage(
            entryId: widget.entryId,
            asset: asset,
            config: config,
          );
          break;
        case AssetType.video:
          setState(() => _importStatus = 'Extracting keyframes...');
          result = await widget.importService.importVideo(
            entryId: widget.entryId,
            asset: asset,
            config: config,
          );
          break;
        case AssetType.audio:
          setState(() => _importStatus = 'Transcribing audio...');
          result = await widget.importService.importAudio(
            entryId: widget.entryId,
            asset: asset,
            config: config,
          );
          break;
        default:
          result = MediaImportResult.failure('Unsupported asset type');
      }

      setState(() {
        _isImporting = false;
        _importStatus = null;
      });

      widget.onImportComplete(result);

      if (result.success) {
        Navigator.of(context).pop();
        _showSuccess('${assetType.name.capitalize()} imported successfully!');
      } else {
        _showError(result.error ?? 'Import failed');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importStatus = null;
      });
      _showError('Import failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// Show the import bottom sheet
Future<void> showImportBottomSheet({
  required BuildContext context,
  required String entryId,
  required MediaImportService importService,
  required Function(MediaImportResult) onImportComplete,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ImportBottomSheet(
      entryId: entryId,
      importService: importService,
      onImportComplete: onImportComplete,
    ),
  );
}