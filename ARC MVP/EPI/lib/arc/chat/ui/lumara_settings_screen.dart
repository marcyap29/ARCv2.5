// lib/lumara/ui/lumara_settings_screen.dart
// LUMARA settings and API key management screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/api_config.dart';
import '../services/enhanced_lumara_api.dart';
import '../services/download_state_service.dart';
import 'package:my_app/telemetry/analytics.dart';
import '../llm/bridge.pigeon.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/context_scope.dart';
import '../services/lumara_reflection_settings_service.dart';

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
  final LumaraNative _bridge = LumaraNative();
  final Map<LLMProvider, TextEditingController> _apiKeyControllers = {};
  
  // Debouncing timer to prevent too frequent API refreshes
  Timer? _refreshDebounceTimer;
  
  // Track previous download states to detect completion
  Map<String, double> _previousProgress = {};
  
  // Track which models have already been processed to prevent infinite loops
  Set<String> _processedCompletions = {};
  
  // Flag to prevent multiple simultaneous API refreshes
  bool _isRefreshing = false;
  
  // Timestamp of last refresh to prevent rapid successive refreshes
  DateTime? _lastRefreshTime;
  
  // Reflection Settings state
  double _similarityThreshold = 0.55;
  int _lookbackYears = 5;
  int _maxMatches = 5;
  bool _crossModalEnabled = true;
  
  // Therapeutic Presence settings
  bool _therapeuticPresenceEnabled = true;
  int _therapeuticDepthLevel = 2; // 1=Light, 2=Moderate, 3=Deep
  bool _therapeuticAutomaticMode = false;
  
  /// Safe progress calculation to prevent NaN and infinite values
  double _safeProgress(double progress) {
    if (progress.isNaN || !progress.isFinite) {
      debugPrint('[LumaraSettings] Warning: Invalid progress value $progress, using 0.0');
      return 0.0;
    }
    return progress.clamp(0.0, 1.0);
  }

  /// Get model info for a provider
  Map<String, dynamic>? _getModelInfo(LLMProviderConfig config) {
    if (!config.isInternal) return null;
    
    switch (config.provider) {
      case LLMProvider.llama3b:
        return {
          'id': 'Llama-3.2-3b-Instruct-Q4_K_M.gguf',
          'name': 'Llama 3.2 3B Instruct (Q4_K_M)',
          'size': '~1.9 GB',
          'url': 'https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-3b-instruct-q4_k_m.gguf?download=true',
        };
      case LLMProvider.qwen4b:
        return {
          'id': 'Qwen3-4B-Instruct-2507-Q4_K_S.gguf',
          'name': 'Qwen3 4B Instruct (Q4_K_S)',
          'size': '~2.5 GB',
          'url': 'https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_S.gguf?download=true',
        };
      default:
        return null;
    }
  }

  /// Start downloading a model
  Future<void> _startDownload(LLMProviderConfig config) async {
    final modelInfo = _getModelInfo(config);
    if (modelInfo == null) return;

    try {
      debugPrint('LUMARA Settings: Starting download for ${modelInfo['name']}');
      
      // Update download state
      _downloadStateService.startDownload(modelInfo['id'], modelName: modelInfo['name']);
      
      // Start the actual download
      final success = await _bridge.downloadModel(modelInfo['id'], modelInfo['url']);
      
      if (!success) {
        _downloadStateService.failDownload(modelInfo['id'], 'Download failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download ${modelInfo['name']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('LUMARA Settings: Download error: $e');
      _downloadStateService.failDownload(modelInfo['id'], e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cancel downloading a model
  Future<void> _cancelDownload(LLMProviderConfig config) async {
    final modelInfo = _getModelInfo(config);
    if (modelInfo == null) return;

    try {
      debugPrint('LUMARA Settings: Cancelling download for ${modelInfo['name']}');
      
      // Cancel the native download
      await _bridge.cancelModelDownload();
      
      // Update download state
      _downloadStateService.cancelDownload(modelInfo['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download cancelled: ${modelInfo['name']}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('LUMARA Settings: Cancel error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Delete a downloaded model
  Future<void> _deleteModel(LLMProviderConfig config) async {
    final modelInfo = _getModelInfo(config);
    if (modelInfo == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${modelInfo['name']}?'),
        content: Text(
          'This will permanently delete the downloaded model file (${modelInfo['size']}). '
          'You can download it again later if needed.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      debugPrint('LUMARA Settings: Deleting model ${modelInfo['name']}');
      
      // Delete the model file using the native bridge
      await _bridge.deleteModel(modelInfo['id']);
      
      // Update download state
      _downloadStateService.updateAvailability(modelInfo['id'], false);
      
      // Refresh API config to update provider availability
      await _refreshApiConfig();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${modelInfo['name']} deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('LUMARA Settings: Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    _loadReflectionSettings();
    _downloadStateService.addListener(_onDownloadStateChanged);
    // Refresh model states to handle model ID changes
    _downloadStateService.refreshAllStates();
    // Only refresh API config if we haven't already loaded settings
    // This prevents double-refreshing on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshApiConfig();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    _downloadStateService.removeListener(_onDownloadStateChanged);
    _refreshDebounceTimer?.cancel();
    super.dispose();
  }

  void _onDownloadStateChanged() {
    // Only log occasionally to avoid spam during downloads
    if (DateTime.now().millisecondsSinceEpoch % 5000 < 100) {
      debugPrint('LUMARA Settings: Download state changed, checking if refresh needed...');
    }
    if (mounted) {
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Only refresh API config if a download completed or failed
          // Don't refresh on every progress update to avoid performance issues
          _checkIfRefreshNeeded();
        }
      });
    }
  }

  void _checkIfRefreshNeeded() {
    // Check if any model just completed downloading
    final llamaState = _downloadStateService.getState('Llama-3.2-3b-Instruct-Q4_K_M.gguf');
    final qwenState = _downloadStateService.getState('Qwen3-4B-Instruct-2507-Q4_K_S.gguf');
    
    // Check for completion by detecting when progress reaches 100%
    final llamaProgress = llamaState?.progress ?? 0.0;
    final qwenProgress = qwenState?.progress ?? 0.0;
    
    // Only consider it "just completed" if:
    // 1. It was downloading before (progress < 1.0) AND now it's completed (progress == 1.0)
    // 2. OR it's marked as downloaded and wasn't downloaded before
    final llamaWasDownloading = (_previousProgress['llama'] ?? 0.0) < 1.0;
    final qwenWasDownloading = (_previousProgress['qwen'] ?? 0.0) < 1.0;
    
    final llamaJustCompleted = (llamaState?.isDownloaded == true && llamaWasDownloading) || 
                              (llamaProgress == 1.0 && llamaWasDownloading);
    final qwenJustCompleted = (qwenState?.isDownloaded == true && qwenWasDownloading) || 
                              (qwenProgress == 1.0 && qwenWasDownloading);
    
    // Update previous progress values
    _previousProgress['llama'] = llamaProgress;
    _previousProgress['qwen'] = qwenProgress;
    
    // Only refresh API config if we haven't already processed this completion
    if (llamaJustCompleted && !_processedCompletions.contains('llama')) {
      _processedCompletions.add('llama');
      debugPrint('LUMARA Settings: Download completed (Llama), refreshing API config...');
      _refreshApiConfig();
    } else if (qwenJustCompleted && !_processedCompletions.contains('qwen')) {
      _processedCompletions.add('qwen');
      debugPrint('LUMARA Settings: Download completed (Qwen), refreshing API config...');
      _refreshApiConfig();
    } else {
      // Just update the UI without expensive API refresh
      // Only log progress updates occasionally to avoid spam
      if (DateTime.now().millisecondsSinceEpoch % 10000 < 100) {
        debugPrint('LUMARA Settings: Progress update, refreshing UI only...');
      }
      
      // Debounce UI updates to prevent too frequent rebuilds
      _refreshDebounceTimer?.cancel();
      _refreshDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            // Rebuild UI with updated progress
          });
        }
      });
    }
  }

  Future<void> _refreshApiConfig() async {
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      debugPrint('LUMARA Settings: Refresh already in progress, skipping...');
      return;
    }
    
    // Prevent rapid successive refreshes (cooldown of 2 seconds)
    final now = DateTime.now();
    if (_lastRefreshTime != null && now.difference(_lastRefreshTime!).inSeconds < 2) {
      debugPrint('LUMARA Settings: Refresh cooldown active, skipping...');
      return;
    }
    
    _isRefreshing = true;
    _lastRefreshTime = now;
    
    try {
      debugPrint('LUMARA Settings: Refreshing API config...');
      // Only refresh model availability, skip full initialization
      // Add timeout to prevent hanging
      await _apiConfig.refreshModelAvailability().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('LUMARA Settings: API config refresh timed out');
          throw TimeoutException('API config refresh timed out', const Duration(seconds: 5));
        },
      );
      debugPrint('LUMARA Settings: API config refreshed successfully');
      if (mounted) {
        setState(() {
          // Rebuild UI with updated provider status
        });
      }
    } catch (e) {
      debugPrint('Error refreshing API config: $e');
      // Don't call setState if there was an error to avoid further issues
    } finally {
      _isRefreshing = false;
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

  Future<void> _loadReflectionSettings() async {
    final settingsService = LumaraReflectionSettingsService.instance;
    final settings = await settingsService.loadAllSettings();
    
    if (mounted) {
      setState(() {
        _similarityThreshold = settings['similarityThreshold'] as double;
        _lookbackYears = settings['lookbackYears'] as int;
        _maxMatches = settings['maxMatches'] as int;
        _crossModalEnabled = settings['crossModalEnabled'] as bool;
        _therapeuticPresenceEnabled = settings['therapeuticPresenceEnabled'] as bool;
        _therapeuticDepthLevel = settings['therapeuticDepthLevel'] as int;
        _therapeuticAutomaticMode = settings['therapeuticAutomaticMode'] as bool;
      });
    }
  }

  Future<void> _saveReflectionSettings() async {
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.saveAllSettings(
      similarityThreshold: _similarityThreshold,
      lookbackYears: _lookbackYears,
      maxMatches: _maxMatches,
      crossModalEnabled: _crossModalEnabled,
      therapeuticPresenceEnabled: _therapeuticPresenceEnabled,
      therapeuticDepthLevel: _therapeuticDepthLevel,
      therapeuticAutomaticMode: _therapeuticAutomaticMode,
    );
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
          tooltip: 'Back to Main Menu',
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

            // Context Scope Section
            _buildContextScopeCard(theme),
            const SizedBox(height: 24),

            // Reflection Settings Section
            _buildReflectionSettingsCard(theme),
            const SizedBox(height: 24),

            // Therapeutic Presence Section
            _buildTherapeuticPresenceCard(theme),
            const SizedBox(height: 24),

            // Provider Selection (includes download button)
            _buildProviderSelection(theme),
            const SizedBox(height: 24),

            // API Keys Card
            _buildApiKeysCard(theme),
            const SizedBox(height: 24),

            // Clear All API Keys button
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
        ),
      ),
    );
  }

  Widget _buildContextScopeCard(ThemeData theme) {
    return BlocBuilder<LumaraAssistantCubit, LumaraAssistantState>(
      builder: (context, state) {
        debugPrint('BlocBuilder rebuild - state: ${state.runtimeType}');
        
        // Get scope from state
        LumaraScope scope;
        if (state is LumaraAssistantLoaded) {
          scope = state.scope;
          debugPrint('Current scope: journal=${scope.journal}, phase=${scope.phase}, arcforms=${scope.arcforms}, voice=${scope.voice}, media=${scope.media}, drafts=${scope.drafts}, chats=${scope.chats}');
        } else {
          debugPrint('State is not LumaraAssistantLoaded, using default scope');
          scope = LumaraScope.defaultScope;
        }
        
        // Get cubit for toggle actions
        final cubit = context.read<LumaraAssistantCubit>();
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Context Sources',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Control what data LUMARA can access when answering your questions',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildScopeChip(theme, 'Journal', scope.journal, () {
                      debugPrint('=== TOGGLE JOURNAL CALLED ===');
                      debugPrint('Current scope.journal: ${scope.journal}');
                      cubit.toggleScope('journal');
                    }),
                    _buildScopeChip(theme, 'Phase', scope.phase, () {
                      cubit.toggleScope('phase');
                    }),
                    _buildScopeChip(theme, 'ARCForms', scope.arcforms, () {
                      cubit.toggleScope('arcforms');
                    }),
                    _buildScopeChip(theme, 'Voice', scope.voice, () {
                      cubit.toggleScope('voice');
                    }),
                    _buildScopeChip(theme, 'Media', scope.media, () {
                      cubit.toggleScope('media');
                    }),
                    _buildScopeChip(theme, 'Drafts', scope.drafts, () {
                      cubit.toggleScope('drafts');
                    }),
                    _buildScopeChip(theme, 'Chats', scope.chats, () {
                      cubit.toggleScope('chats');
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enable the data sources you want LUMARA to consider. More sources provide richer context but may take longer to process.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScopeChip(ThemeData theme, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        debugPrint('Scope chip tapped: $label, current state: $isActive');
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive 
              ? theme.colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              )
            else
              Icon(
                Icons.circle_outlined,
                size: 16,
                color: theme.colorScheme.outline.withOpacity(0.5),
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
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

    // External providers only (internal models removed)
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
            
            // Automatic Selection Toggle
            _buildAutomaticSelectionToggle(theme),
            
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

        // Add cleanup buttons for internal models section
        if (isInternal) ...[
          const SizedBox(height: 16),
          _buildDeleteModelButton(theme),
          const SizedBox(height: 12),
          _buildCleanupButton(theme),
        ],
      ],
    );
  }


  Widget _buildDeleteModelButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // Show model selection dialog
          final selectedModel = await _showModelSelectionDialog();
          if (selectedModel == null) return;

          // Show confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Model'),
              content: Text(
                'Are you sure you want to delete "${selectedModel['name']}"? This action cannot be undone and will free up ${selectedModel['size']} of storage space.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirmed != true) return;

          try {
            // Delete the specific model
            final modelId = selectedModel['id'] as String;
            await _bridge.deleteModel(modelId);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selectedModel['name']} deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error deleting model: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.delete_outline, size: 20),
        label: const Text('Delete Model'),
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

  Future<Map<String, dynamic>?> _showModelSelectionDialog() async {
    // Get list of downloaded models
    final downloadedModels = <Map<String, dynamic>>[];
    
    // Check each internal model
    final internalModels = [
      {
        'id': 'Llama-3.2-3b-Instruct-Q4_K_M.gguf',
        'name': 'Llama 3.2 3B Instruct',
        'size': '~1.9 GB',
      },
      {
        'id': 'Qwen3-4B-Instruct-2507-Q4_K_S.gguf',
        'name': 'Qwen3 4B Instruct',
        'size': '~2.5 GB',
      },
    ];

    for (final model in internalModels) {
      try {
        final modelId = model['id'] as String;
        final isDownloaded = await _bridge.isModelDownloaded(modelId);
        if (isDownloaded) {
          downloadedModels.add(model);
        }
      } catch (e) {
        // Skip models that can't be checked
        continue;
      }
    }

    if (downloadedModels.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No downloaded models found to delete'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Model to Delete'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: downloadedModels.length,
            itemBuilder: (context, index) {
              final model = downloadedModels[index];
              return ListTile(
                leading: const Icon(Icons.psychology, color: Colors.blue),
                title: Text(model['name']),
                subtitle: Text('Size: ${model['size']}'),
                onTap: () => Navigator.of(context).pop(model),
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

  Widget _buildAutomaticSelectionToggle(ThemeData theme) {
    final isAutomatic = _selectedProvider == null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isAutomatic ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
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
                    color: theme.colorScheme.onSurface,
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
          Switch(
            value: isAutomatic,
            onChanged: (value) async {
              if (value) {
                // Enable automatic selection
                await _apiConfig.setManualProvider(null);
                await _lumaraApi.initialize();
                setState(() {
                  _selectedProvider = null;
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to automatic provider selection'),
                      backgroundColor: Colors.blue,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                // Disable automatic selection - user needs to select a specific provider
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Select a specific provider below to disable automatic selection'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOption(ThemeData theme, LLMProviderConfig config, bool isInternal) {
    final isAvailable = config.isAvailable;
    final isSelected = _selectedProvider == config.provider;
    final modelInfo = _getModelInfo(config);
    
    // Get download state for internal models
    ModelDownloadState? downloadState;
    if (isInternal && modelInfo != null) {
      downloadState = _downloadStateService.getState(modelInfo['id']);
    }
    
    final isDownloading = downloadState?.isDownloading ?? false;
    final isDownloaded = downloadState?.isDownloaded ?? false;
    final progress = downloadState?.progress ?? 0.0;
    final statusMessage = downloadState?.statusMessage ?? '';
    
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
          child: Column(
            children: [
              Row(
                children: [
                  // Status indicator (green/red/blue light)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDownloading 
                          ? Colors.blue
                          : isAvailable 
                              ? Colors.green 
                              : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDownloading 
                              ? Colors.blue
                              : isAvailable 
                                  ? Colors.green 
                                  : Colors.red).withOpacity(0.3),
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
                              ? (isAvailable 
                                  ? 'Available to use - Privacy First' 
                                  : isDownloading
                                      ? 'Downloading...'
                                      : 'Local Model - Privacy First')
                              : 'Cloud API - External Service',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDownloading
                                ? Colors.blue
                                : isAvailable 
                                    ? Colors.green
                                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                            fontWeight: isAvailable && isInternal ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isInternal && modelInfo != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${modelInfo['size']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  if (isInternal && !isAvailable && !isDownloading)
                    ElevatedButton.icon(
                      onPressed: () => _startDownload(config),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else if (isInternal && isDownloading)
                    OutlinedButton.icon(
                      onPressed: () => _cancelDownload(config),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else if (isInternal && isDownloaded && isAvailable)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        if (isSelected) const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteModel(config),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete Model',
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    )
                  else if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  else if (!isAvailable && !isDownloading)
                    Icon(
                      Icons.block,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                ],
              ),
              
              // Download progress
              if (isDownloading) ...[
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _safeProgress(progress),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ],
              
              // Download complete message
              if (isDownloaded && !isDownloading) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Download complete! Ready to use.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildReflectionSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reflection Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSliderTile(
              theme,
              title: 'Similarity Threshold',
              subtitle: 'Minimum similarity score for matching entries (${_similarityThreshold.toStringAsFixed(2)})',
              value: _similarityThreshold,
              min: 0.1,
              max: 1.0,
              divisions: 18,
              onChanged: (value) {
                setState(() {
                  _similarityThreshold = value;
                });
                _saveReflectionSettings();
              },
            ),
            _buildSliderTile(
              theme,
              title: 'Lookback Period',
              subtitle: 'Years of history to search ($_lookbackYears years)',
              value: _lookbackYears.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (value) {
                setState(() {
                  _lookbackYears = value.round();
                });
                _saveReflectionSettings();
              },
            ),
            _buildSliderTile(
              theme,
              title: 'Max Matches',
              subtitle: 'Maximum number of similar entries to find ($_maxMatches)',
              value: _maxMatches.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (value) {
                setState(() {
                  _maxMatches = value.round();
                });
                _saveReflectionSettings();
              },
            ),
            _buildSwitchTile(
              theme,
              title: 'Cross-Modal Awareness',
              subtitle: 'Include photos, audio, and video in reflection analysis',
              value: _crossModalEnabled,
              onChanged: (value) {
                setState(() {
                  _crossModalEnabled = value;
                });
                _saveReflectionSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapeuticPresenceCard(ThemeData theme) {
    final depthLabels = ['Light', 'Moderate', 'Deep'];
    final depthDescriptions = [
      'Supportive and encouraging',
      'Reflective and insight-oriented',
      'Exploratory and emotionally resonant',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Therapeutic Presence',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              theme,
              title: 'Enable Therapeutic Presence',
              subtitle: 'Warm, reflective support for journaling and emotional processing',
              value: _therapeuticPresenceEnabled,
              onChanged: (value) {
                setState(() {
                  _therapeuticPresenceEnabled = value;
                });
                _saveReflectionSettings();
              },
            ),
            if (_therapeuticPresenceEnabled) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Automatic Mode Toggle
                    _buildSwitchTile(
                      theme,
                      title: 'Automatic Mode',
                      subtitle: 'Let the system automatically decide the therapeutic mode',
                      value: _therapeuticAutomaticMode,
                      onChanged: (value) {
                        setState(() {
                          _therapeuticAutomaticMode = value;
                        });
                        _saveReflectionSettings();
                      },
                    ),
                    const SizedBox(height: 16),
                    // Default Therapeutic Mode Slider (grayed out when automatic mode is on)
                    Opacity(
                      opacity: _therapeuticAutomaticMode ? 0.5 : 1.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.psychology,
                                color: _therapeuticAutomaticMode 
                                    ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                                    : theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Default Therapeutic Mode',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _therapeuticAutomaticMode
                                            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                                            : null,
                                      ),
                                    ),
                                    Text(
                                      depthDescriptions[_therapeuticDepthLevel - 1],
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: _therapeuticAutomaticMode
                                            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (_therapeuticAutomaticMode
                                          ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3)
                                          : theme.colorScheme.primary.withOpacity(0.2)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  depthLabels[_therapeuticDepthLevel - 1],
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: _therapeuticAutomaticMode
                                        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                                        : theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Slider(
                            value: _therapeuticDepthLevel.toDouble(),
                            min: 1,
                            max: 3,
                            divisions: 2,
                            activeColor: _therapeuticAutomaticMode
                                ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                                : theme.colorScheme.primary,
                            inactiveColor: theme.colorScheme.outline.withOpacity(0.3),
                            label: depthLabels[_therapeuticDepthLevel - 1],
                            onChanged: _therapeuticAutomaticMode ? null : (value) {
                              setState(() {
                                _therapeuticDepthLevel = value.round();
                              });
                              _saveReflectionSettings();
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: depthLabels.asMap().entries.map((entry) {
                              final index = entry.key;
                              final label = entry.value;
                              final isSelected = _therapeuticDepthLevel == index + 1;
                              return GestureDetector(
                                onTap: _therapeuticAutomaticMode ? null : () {
                                  setState(() {
                                    _therapeuticDepthLevel = index + 1;
                                  });
                                  _saveReflectionSettings();
                                },
                                child: Text(
                                  label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _therapeuticAutomaticMode
                                        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                                        : (isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.outline.withOpacity(0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

}

