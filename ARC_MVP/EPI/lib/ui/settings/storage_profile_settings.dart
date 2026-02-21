import 'package:flutter/material.dart';
import 'package:my_app/prism/processors/settings/storage_profiles.dart';
// import '../../media/crypto/hash_utils.dart'; // TODO: hash_utils not yet implemented

/// Settings screen for media storage profiles
class StorageProfileSettings extends StatefulWidget {
  final StorageSettings initialSettings;
  final Function(StorageSettings) onSettingsChanged;

  const StorageProfileSettings({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  @override
  State<StorageProfileSettings> createState() => _StorageProfileSettingsState();
}

class _StorageProfileSettingsState extends State<StorageProfileSettings> {
  late StorageSettings _settings;
  StorageEstimate? _storageEstimate;
  bool _isCalculatingStorage = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _calculateStorageUsage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Media Storage',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStorageUsageSection(),
          const SizedBox(height: 24),
          _buildGlobalDefaultSection(),
          const SizedBox(height: 24),
          _buildModeOverridesSection(),
          const SizedBox(height: 24),
          _buildAdvancedSettingsSection(),
          const SizedBox(height: 24),
          _buildMaintenanceSection(),
        ],
      ),
    );
  }

  Widget _buildStorageUsageSection() {
    return _buildSection(
      title: 'Storage Usage',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            if (_isCalculatingStorage)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Calculating storage usage...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              )
            else if (_storageEstimate != null) ...[
              _buildStorageRow('Total Files', '${_storageEstimate!.totalFiles}'),
              _buildStorageRow('Total Size', '${_storageEstimate!.totalSizeMB.toStringAsFixed(1)} MB'),
              const Divider(color: Colors.white12),
              _buildStorageRow('Thumbnails', '${_storageEstimate!.thumbnailSizeMB.toStringAsFixed(1)} MB'),
              _buildStorageRow('Transcripts', '${_storageEstimate!.transcriptSizeMB.toStringAsFixed(1)} MB'),
              _buildStorageRow('Analysis Data', '${_storageEstimate!.analysisSizeMB.toStringAsFixed(1)} MB'),
              _buildStorageRow('Full Resolution', '${_storageEstimate!.fullResSizeMB.toStringAsFixed(1)} MB'),
            ] else
              const Text(
                'Unable to calculate storage usage',
                style: TextStyle(color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalDefaultSection() {
    return _buildSection(
      title: 'Default Storage Policy',
      subtitle: 'Applied to all media unless overridden by app mode',
      child: Column(
        children: StorageProfile.allProfiles.map((profile) {
          return _buildProfileOption(
            profile: profile,
            isSelected: _settings.globalDefault == profile.policy,
            onSelected: () {
              setState(() {
                _settings = _settings.copyWith(globalDefault: profile.policy);
              });
              widget.onSettingsChanged(_settings);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModeOverridesSection() {
    return _buildSection(
      title: 'App Mode Overrides',
      subtitle: 'Customize storage policy for specific app modes',
      child: Column(
        children: AppMode.values.map((mode) {
          final currentPolicy = _settings.modeOverrides[mode] ?? _settings.globalDefault;
          final profile = StorageProfile.forPolicy(currentPolicy);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ExpansionTile(
              title: Text(
                _getModeDisplayName(mode),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                profile.displayName,
                style: const TextStyle(color: Colors.white60),
              ),
              iconColor: Colors.white54,
              collapsedIconColor: Colors.white54,
              children: StorageProfile.allProfiles.map((option) {
                return ListTile(
                  title: Text(
                    option.displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    option.description,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  leading: Radio<StoragePolicy>(
                    value: option.policy,
                    groupValue: currentPolicy,
                    onChanged: (policy) {
                      if (policy != null) {
                        final newOverrides = Map<AppMode, StoragePolicy>.from(_settings.modeOverrides);
                        newOverrides[mode] = policy;
                        setState(() {
                          _settings = _settings.copyWith(modeOverrides: newOverrides);
                        });
                        widget.onSettingsChanged(_settings);
                      }
                    },
                    activeColor: Colors.blue,
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvancedSettingsSection() {
    return _buildSection(
      title: 'Advanced Settings',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Enable Auto-Offload',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Automatically offload old files after ${_settings.autoOffloadDays} days',
              style: const TextStyle(color: Colors.white54),
            ),
            value: _settings.enableAutoOffload,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(enableAutoOffload: value);
              });
              widget.onSettingsChanged(_settings);
            },
            activeThumbColor: Colors.blue,
          ),
          const Divider(color: Colors.white12),
          ListTile(
            title: const Text(
              'Auto-Offload After',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${_settings.autoOffloadDays} days',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: _settings.enableAutoOffload ? _showOffloadDaysDialog : null,
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            title: const Text(
              'Enable Retention Pruner',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Automatically clean up orphaned files',
              style: TextStyle(color: Colors.white54),
            ),
            value: _settings.enableRetentionPruner,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(enableRetentionPruner: value);
              });
              widget.onSettingsChanged(_settings);
            },
            activeThumbColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    return _buildSection(
      title: 'Maintenance',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.blue),
            title: const Text(
              'Recalculate Storage',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Update storage usage statistics',
              style: TextStyle(color: Colors.white54),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: _calculateStorageUsage,
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text(
              'Clean Up Orphaned Files',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Remove unreferenced media files',
              style: TextStyle(color: Colors.white54),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: _showCleanupDialog,
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Clear All Media Cache',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Delete all locally stored media files',
              style: TextStyle(color: Colors.white54),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: _showClearCacheDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildProfileOption({
    required StorageProfile profile,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? Colors.blue.withOpacity(0.1)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected 
              ? Colors.blue.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: ListTile(
        title: Text(
          profile.displayName,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          profile.description,
          style: const TextStyle(color: Colors.white54),
        ),
        leading: Radio<StoragePolicy>(
          value: profile.policy,
          groupValue: isSelected ? profile.policy : null,
          onChanged: (_) => onSelected(),
          activeColor: Colors.blue,
        ),
        onTap: onSelected,
      ),
    );
  }

  String _getModeDisplayName(AppMode mode) {
    switch (mode) {
      case AppMode.personal:
        return 'Personal Journaling';
    }
  }

  Future<void> _calculateStorageUsage() async {
    setState(() {
      _isCalculatingStorage = true;
    });

    try {
      // Simulate storage calculation
      await Future.delayed(const Duration(seconds: 1));
      
      // In a real implementation, this would query the CAS store and media files
      final estimate = StorageEstimate(
        totalFiles: 42,
        totalSizeBytes: 15728640, // ~15MB
        thumbnailSizeBytes: 2097152, // ~2MB
        transcriptSizeBytes: 524288, // ~512KB
        analysisSizeBytes: 5242880, // ~5MB
        fullResSizeBytes: 7864320, // ~7.5MB
      );

      setState(() {
        _storageEstimate = estimate;
        _isCalculatingStorage = false;
      });
    } catch (e) {
      setState(() {
        _isCalculatingStorage = false;
      });
      _showError('Failed to calculate storage usage: $e');
    }
  }

  Future<void> _showOffloadDaysDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _OffloadDaysDialog(
        initialDays: _settings.autoOffloadDays,
      ),
    );

    if (result != null) {
      setState(() {
        _settings = _settings.copyWith(autoOffloadDays: result);
      });
      widget.onSettingsChanged(_settings);
    }
  }

  Future<void> _showCleanupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121621),
        title: const Text(
          'Clean Up Orphaned Files',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove media files that are no longer referenced by any journal entries. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Clean Up',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _performCleanup();
    }
  }

  Future<void> _showClearCacheDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121621),
        title: const Text(
          'Clear All Media Cache',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all locally stored media files. Original files in your Photos app will not be affected. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Clear Cache',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _clearAllCache();
    }
  }

  Future<void> _performCleanup() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF121621),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Cleaning up...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Perform cleanup (stub)
      await Future.delayed(const Duration(seconds: 2));
      // TODO: CASStore not yet implemented
      // final cleanedCount = await CASStore.cleanup({});
      final cleanedCount = 0; // Placeholder until CASStore is implemented

      Navigator.of(context).pop(); // Close loading dialog
      
      _showSuccess('Cleaned up $cleanedCount orphaned files');
      _calculateStorageUsage(); // Refresh storage stats
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showError('Cleanup failed: $e');
    }
  }

  Future<void> _clearAllCache() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF121621),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Clearing cache...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Clear cache (stub)
      await Future.delayed(const Duration(seconds: 2));
      
      Navigator.of(context).pop(); // Close loading dialog
      
      _showSuccess('Media cache cleared successfully');
      _calculateStorageUsage(); // Refresh storage stats
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showError('Failed to clear cache: $e');
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

class _OffloadDaysDialog extends StatefulWidget {
  final int initialDays;

  const _OffloadDaysDialog({required this.initialDays});

  @override
  State<_OffloadDaysDialog> createState() => _OffloadDaysDialogState();
}

class _OffloadDaysDialogState extends State<_OffloadDaysDialog> {
  late int _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.initialDays;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121621),
      title: const Text(
        'Auto-Offload After',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Files will be automatically offloaded after this many days:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          DropdownButton<int>(
            value: _selectedDays,
            dropdownColor: const Color(0xFF121621),
            style: const TextStyle(color: Colors.white),
            items: [7, 14, 30, 60, 90, 180]
                .map((days) => DropdownMenuItem(
                      value: days,
                      child: Text('$days days'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedDays = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedDays),
          child: const Text('Save'),
        ),
      ],
    );
  }
}