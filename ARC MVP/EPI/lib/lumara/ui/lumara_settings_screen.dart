// lib/lumara/ui/lumara_settings_screen.dart
// LUMARA settings and API key management screen

import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/enhanced_lumara_api.dart';
import '../services/download_state_service.dart';
import '../../telemetry/analytics.dart';
import 'model_download_screen.dart';

/// LUMARA settings screen for API key management and provider selection
class LumaraSettingsScreen extends StatefulWidget {
  const LumaraSettingsScreen({super.key});

  @override
  State<LumaraSettingsScreen> createState() => _LumaraSettingsScreenState();
}

class _LumaraSettingsScreenState extends State<LumaraSettingsScreen> {
  final LumaraAPIConfig _apiConfig = LumaraAPIConfig.instance;
  final EnhancedLumaraApi _lumaraApi = EnhancedLumaraApi(Analytics());
  final DownloadStateService _downloadStateService = DownloadStateService.instance;
  final Map<LLMProvider, TextEditingController> _apiKeyControllers = {};
  
  /// Safe progress calculation to prevent NaN and infinite values
  double _safeProgress(double progress) {
    if (progress.isNaN || !progress.isFinite) {
      debugPrint('[LumaraSettings] Warning: Invalid progress value $progress, using 0.0');
      return 0.0;
    }
    return progress.clamp(0.0, 1.0);
  }
  
  /// Clamp progress to 0-1 range, return null for invalid values (indeterminate progress)
  double? clamp01(num? x) {
    if (x == null) return null;
    final d = x.toDouble();
    if (!d.isFinite) return null;
    if (d < 0) return 0;
    if (d > 1) return 1;
    return d;
  }

  LLMProvider? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentSettings();
    _downloadStateService.addListener(_onDownloadStateChanged);
    // Refresh model states to handle model ID changes
    _downloadStateService.refreshAllStates();
    // Refresh API config to update provider availability
    _refreshApiConfig();
  }

  @override
  void dispose() {
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    _downloadStateService.removeListener(_onDownloadStateChanged);
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (mounted) {
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Rebuild UI when download state changes
          });
        }
      });
    }
  }

  Future<void> _refreshApiConfig() async {
    try {
      await _apiConfig.initialize();
      await _apiConfig.refreshModelAvailability();
      if (mounted) {
        setState(() {
          // Rebuild UI with updated provider status
        });
      }
    } catch (e) {
      debugPrint('Error refreshing API config: $e');
    }
  }

  void _initializeControllers() {
    for (final provider in LLMProvider.values) {
      _apiKeyControllers[provider] = TextEditingController();
    }
  }

  Future<void> _loadCurrentSettings() async {
    await _apiConfig.initialize();
    
    // Load existing API keys
    for (final provider in LLMProvider.values) {
      final apiKey = _apiConfig.getApiKey(provider);
      _apiKeyControllers[provider]?.text = apiKey ?? '';
    }

    // Get current manual provider selection
    final manualProvider = _apiConfig.getManualProvider();
    setState(() {
      _selectedProvider = manualProvider;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Overview
            _buildStatusCard(theme),
            const SizedBox(height: 24),

            // Provider Selection (includes download button)
            _buildProviderSelection(theme),
            const SizedBox(height: 24),

            // API Keys Card
            _buildApiKeysCard(theme),
            const SizedBox(height: 24),

            // Actions
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final availableProviders = _apiConfig.getAvailableProviders();
    final bestProvider = _apiConfig.getBestProvider();
    
    // Get current provider display name
    final currentProviderName = bestProvider?.name ?? 'None';
    final currentProviderType = bestProvider?.isInternal == true ? 'Internal' : 'Cloud API';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'LUMARA Status',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Current Provider: '),
                const SizedBox(width: 4),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: bestProvider != null
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: bestProvider != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            currentProviderName,
                            style: TextStyle(
                              color: bestProvider != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bestProvider != null
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentProviderType,
                          style: TextStyle(
                            color: bestProvider != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Available Providers: ${availableProviders.length}'),
            const SizedBox(height: 8),
            Text(
              bestProvider != null 
                  ? 'LUMARA is ready to provide intelligent reflections on your journal entries.'
                  : 'LUMARA is not available. Please configure a provider below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bestProvider != null 
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelection(ThemeData theme) {
    final allProviders = _apiConfig.getAllProviders();

    // Separate internal and external providers
    final internalProviders = allProviders.where((p) => p.isInternal).toList();
    final externalProviders = allProviders.where((p) => !p.isInternal).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Provider Selection',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Internal Models Section
            _buildProviderCategory(
              theme: theme,
              title: 'Internal Models',
              subtitle: 'Privacy-first, on-device processing',
              providers: internalProviders,
              isInternal: true,
            ),
            
            const SizedBox(height: 24),
            
            // Cloud API Section
            _buildProviderCategory(
              theme: theme,
              title: 'Cloud API',
              subtitle: 'External services with API keys',
              providers: externalProviders,
              isInternal: false,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProviderCategory({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required List<LLMProviderConfig> providers,
    required bool isInternal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isInternal ? Icons.security : Icons.cloud,
              color: isInternal ? theme.colorScheme.primary : theme.colorScheme.secondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isInternal ? theme.colorScheme.primary : theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

            // Provider options
        ...providers.map((config) => _buildProviderOption(theme, config, isInternal)),

        // Add "Clear Selection" option if there are available providers
        if (providers.any((p) => p.isAvailable)) ...[
          const SizedBox(height: 8),
          _buildClearSelectionOption(theme),
        ],

        // Show message if no providers available
        if (providers.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: theme.colorScheme.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isInternal
                        ? 'No internal models available. Check model installation.'
                        : 'No cloud APIs configured. Add API keys below.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Add download button for internal models section
        if (isInternal) ...[
          const SizedBox(height: 16),
          _buildDownloadButton(theme),
          const SizedBox(height: 12),
          _buildCleanupButton(theme),
        ],
      ],
    );
  }

  Widget _buildDownloadButton(ThemeData theme) {
    // Check if any model is currently downloading
    final llamaState = _downloadStateService.getState('Llama-3.2-3b-Instruct-Q4_K_M.gguf');
    final phiState = _downloadStateService.getState('Phi-3.5-mini-instruct-Q5_K_M.gguf');
    final qwenState = _downloadStateService.getState('Qwen3-4B-Instruct-2507-Q4_K_S.gguf');

    final isDownloading = (llamaState?.isDownloading ?? false) || 
                        (phiState?.isDownloading ?? false) || 
                        (qwenState?.isDownloading ?? false);
    final downloadingState = llamaState?.isDownloading == true ? llamaState : 
                            phiState?.isDownloading == true ? phiState : 
                            qwenState?.isDownloading == true ? qwenState : null;

    // Don't show download progress if any model is already downloaded
    final hasDownloadedModel = (llamaState?.isDownloaded ?? false) || 
                              (phiState?.isDownloaded ?? false) || 
                              (qwenState?.isDownloaded ?? false);

    // Show download progress only if actively downloading and not completed
    if (isDownloading && downloadingState != null && !hasDownloadedModel && !downloadingState.isDownloaded) {
      // Show download progress
      return SizedBox(
        width: double.infinity,
        child: Card(
          elevation: 1,
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        downloadingState.statusMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(_safeProgress(downloadingState.progress) * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (downloadingState.downloadSizeText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    downloadingState.downloadSizeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: clamp01(downloadingState.progress),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModelDownloadScreen(),
                        ),
                      );
                    },
                    child: const Text('View Download Details'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show regular download button when not downloading
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ModelDownloadScreen(),
            ),
          );
        },
        icon: const Icon(Icons.download, size: 20),
        label: const Text('Download On-Device Model'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanupButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Clear Corrupted Downloads'),
              content: const Text(
                'This will delete all corrupted or incomplete model downloads and force a fresh download. Continue?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Clear All'),
                ),
              ],
            ),
          );

          if (confirmed != true) return;

          try {
            // Clear all corrupted downloads
            await _lumaraApi.clearCorruptedDownloads();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Corrupted downloads cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error clearing downloads: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.cleaning_services, size: 20),
        label: const Text('Clear Corrupted Downloads'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildClearSelectionOption(ThemeData theme) {
    final isSelected = _selectedProvider == null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected 
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected 
            ? theme.colorScheme.primary.withOpacity(0.05)
            : null,
      ),
      child: InkWell(
        onTap: () async {
          // Clear manual provider selection to use automatic selection
          await _apiConfig.setManualProvider(null);

          // Reinitialize LUMARA API to use automatic selection
          await _lumaraApi.initialize();

          // Update UI
          setState(() {
            _selectedProvider = null;
          });

          // Show confirmation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Switched to automatic provider selection'),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: isSelected 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automatic Selection',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected 
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Let LUMARA choose the best available provider',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderOption(ThemeData theme, LLMProviderConfig config, bool isInternal) {
    final isAvailable = config.isAvailable;
    final isSelected = _selectedProvider == config.provider;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected 
              ? theme.colorScheme.primary
              : isAvailable 
                  ? theme.colorScheme.outline.withOpacity(0.3)
                  : theme.colorScheme.error.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected 
            ? theme.colorScheme.primary.withOpacity(0.05)
            : isAvailable 
                ? null
                : theme.colorScheme.error.withOpacity(0.05),
      ),
      child: InkWell(
        onTap: isAvailable ? () async {
          // Set this as the manually selected provider
          await _apiConfig.setManualProvider(config.provider);

          // Reinitialize LUMARA API to use the new provider
          await _lumaraApi.initialize();

          // Update UI
          setState(() {
            _selectedProvider = config.provider;
          });

          // Show confirmation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Switched to ${config.name}'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator (green/red light)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isAvailable ? Colors.green : Colors.red).withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Provider info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            config.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isAvailable 
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isInternal)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SECURE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isInternal 
                          ? (isAvailable ? 'Available to use - Privacy First' : 'Local Model - Privacy First')
                          : 'Cloud API - External Service',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isAvailable 
                            ? Colors.green
                            : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontWeight: isAvailable && isInternal ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                )
              else if (!isAvailable)
                Icon(
                  Icons.block,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildApiKeyField(LLMProvider provider, ThemeData theme) {
    final controller = _apiKeyControllers[provider]!;
    final config = _apiConfig.getConfig(provider);
    final isConfigured = config?.apiKey?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                provider.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (isConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter ${provider.name} API key',
                    suffixIcon: isConfigured
                        ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : Icon(Icons.key, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild to show/hide Save button
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () async {
                        await _saveSpecificApiKey(provider);
                      },
                icon: Icon(Icons.save, size: 18),
                label: Text('Save'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  backgroundColor: controller.text.trim().isEmpty
                      ? theme.colorScheme.surfaceVariant
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveSpecificApiKey(LLMProvider provider) async {
    final controller = _apiKeyControllers[provider];
    if (controller == null || controller.text.trim().isEmpty) {
      return;
    }

    try {
      await _apiConfig.updateApiKey(provider, controller.text.trim());

      // Force refresh provider availability
      await _apiConfig.refreshProviderAvailability();

      // Reinitialize LUMARA API to pick up the new key
      await _lumaraApi.initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${provider.name} API key saved and activated!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Reload to update UI state
        await _loadCurrentSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error saving API key: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }


  Widget _buildApiKeysCard(ThemeData theme) {
        final externalProviders = LLMProvider.values
            .where((p) => p != LLMProvider.qwen4b && p != LLMProvider.llama3b)
            .toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'API Keys',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Add your API keys to enable AI-powered reflections',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ...externalProviders.map((provider) => _buildApiKeyField(provider, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _testConnection,
                child: const Text('Test Connection'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _clearAllApiKeys,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Clear All API Keys'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearAllApiKeys() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All API Keys'),
        content: const Text(
          'This will remove all saved API keys. You will need to re-enter them. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _apiConfig.clearAllApiKeys();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All API keys cleared'),
          backgroundColor: Colors.orange,
        ),
      );

      // Reload UI
      await _loadCurrentSettings();
    }
  }

  // Removed auto-save on change - now using explicit Save button per field

  Future<void> _testConnection() async {
    final status = _lumaraApi.getStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Current provider: ${status['currentProvider']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    // Save all API keys
    for (final entry in _apiKeyControllers.entries) {
      final provider = entry.key;
      final controller = entry.value;
      if (controller.text.isNotEmpty) {
        await _apiConfig.updateApiKey(provider, controller.text);
      }
    }

    // Force refresh provider availability after saving all keys
    await _apiConfig.refreshProviderAvailability();

    // Reinitialize to check if any provider is now available
    await _apiConfig.initialize();
    final bestProvider = _apiConfig.getBestProvider();
    final isConfigured = bestProvider != null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isConfigured
              ? 'Settings saved! AI provider configured.'
              : 'Settings saved successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // If accessed from onboarding and now configured, offer to go back
      if (isConfigured && ModalRoute.of(context)?.settings.arguments == 'fromOnboarding') {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    }
  }
}

