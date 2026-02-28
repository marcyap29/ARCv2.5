// lib/lumara/ui/lumara_settings_screen.dart
// LUMARA settings and API key management screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/enhanced_lumara_api.dart';
import '../services/download_state_service.dart';
import 'package:my_app/telemetry/analytics.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/context_scope.dart';
import '../services/lumara_reflection_settings_service.dart';
import 'package:my_app/services/subscription_service.dart';
import 'package:my_app/arc/chat/voice/config/wispr_config_service.dart';

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
  
  // Debouncing timer to prevent too frequent API refreshes
  Timer? _refreshDebounceTimer;
  
  // Track previous download states to detect completion
  final Map<String, double> _previousProgress = {};
  
  // Track which models have already been processed to prevent infinite loops
  final Set<String> _processedCompletions = {};
  
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
  
  // Web Access settings
  bool _webAccessEnabled = false; // Opt-in by default
  
  // External Services - Wispr Flow (Voice Transcription)
  final TextEditingController _wisprApiKeyController = TextEditingController();
  bool _wisprApiKeyConfigured = false;
  static const String _wisprApiKeyPrefKey = 'wispr_flow_api_key';
  
  // Subscription status
  SubscriptionTier _subscriptionTier = SubscriptionTier.free;

  // Agent Operating System (user context for Writing/Research agents)
  final TextEditingController _agentOsUserContextController = TextEditingController();
  final TextEditingController _agentOsCommunicationController = TextEditingController();
  final TextEditingController _agentOsMemoryController = TextEditingController();
  bool _agentOsLoading = true;
  
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
    _loadSubscriptionTier();
    _loadCurrentSettings();
    _loadReflectionSettings();
    _loadAgentOsSettings();
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
  
  /// Load subscription tier
  Future<void> _loadSubscriptionTier() async {
    final tier = await SubscriptionService.instance.getSubscriptionTier();
    if (mounted) {
      setState(() {
        _subscriptionTier = tier;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    _wisprApiKeyController.dispose();
    _agentOsUserContextController.dispose();
    _agentOsCommunicationController.dispose();
    _agentOsMemoryController.dispose();
    _downloadStateService.removeListener(_onDownloadStateChanged);
    _refreshDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAgentOsSettings() async {
    final settings = LumaraReflectionSettingsService.instance;
    final context = await settings.getAgentOsUserContext();
    final communication = await settings.getAgentOsCommunicationPreferences();
    final memory = await settings.getAgentOsMemory();
    if (mounted) {
      _agentOsUserContextController.text = context;
      _agentOsCommunicationController.text = communication;
      _agentOsMemoryController.text = memory;
      setState(() => _agentOsLoading = false);
    }
  }

  Future<void> _saveAgentOsSettings() async {
    final settings = LumaraReflectionSettingsService.instance;
    await settings.setAgentOsUserContext(_agentOsUserContextController.text);
    await settings.setAgentOsCommunicationPreferences(_agentOsCommunicationController.text);
    await settings.setAgentOsMemory(_agentOsMemoryController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent instructions saved')),
      );
    }
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
    
    // Load Wispr Flow API key
    final prefs = await SharedPreferences.getInstance();
    final wisprKey = prefs.getString(_wisprApiKeyPrefKey) ?? '';
    _wisprApiKeyController.text = wisprKey;
    
    setState(() {
      _selectedProvider = manualProvider;
      _wisprApiKeyConfigured = wisprKey.isNotEmpty;
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
        _webAccessEnabled = settings['webAccessEnabled'] as bool;
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
      webAccessEnabled: _webAccessEnabled,
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
            // Context Scope Section
            _buildContextScopeCard(theme),
            const SizedBox(height: 24),

            // Reflection Settings Section
            _buildReflectionSettingsCard(theme),
            const SizedBox(height: 24),

            // Therapeutic Presence Section
            _buildTherapeuticPresenceCard(theme),
            const SizedBox(height: 24),

            // Agent Operating System (user context for Writing/Research agents)
            _buildAgentOperatingSystemCard(theme),
            const SizedBox(height: 24),

            // API — provider selection, API keys, voice (Wispr) in one card
            if (_subscriptionTier == SubscriptionTier.premium) ...[
              _buildApiCard(theme),
              const SizedBox(height: 24),
            ],

            // Clear All API Keys button - Only for Pro/Paying users
            if (_subscriptionTier == SubscriptionTier.premium) ...[
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
          ],
        ),
      ),
    );
  }

  /// Unified API card: default provider, API keys for all external providers, voice (Wispr).
  static const List<LLMProvider> _externalProvidersOrder = [
    LLMProvider.gemini,  // Primary — shown first
    LLMProvider.groq,    // Fallback
    LLMProvider.openai,
    LLMProvider.anthropic,
    LLMProvider.venice,
    LLMProvider.openrouter,
  ];

  Widget _buildAgentOperatingSystemCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Agent instructions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customize how Writing and Research agents work for you. These are prepended to every agent run.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_agentOsLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Your context',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _agentOsUserContextController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'e.g. Senior engineer, new to Flutter. Prefer hands-on examples.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Communication style',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _agentOsCommunicationController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Direct and concise. Skip preamble. Technical language is fine.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Agent memory',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _agentOsMemoryController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'e.g. Project: BudgetBuddy. Using Flutter + Riverpod. Prefer functional components.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveAgentOsSettings,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save configuration'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApiCard(ThemeData theme) {
    final isDefaultGemini = _selectedProvider == null || _selectedProvider == LLMProvider.gemini;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.api, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'API',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose default provider and add API keys. LUMARA uses Gemini by default; Groq (Llama 3.3 70B) as fallback.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            // Default provider
            Text(
              'Default provider',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildDefaultProviderOption(theme, isDefaultGemini, isGemini: true),
            const SizedBox(height: 8),
            _buildDefaultProviderOption(theme, !isDefaultGemini, isGemini: false),
            const SizedBox(height: 24),
            // API keys
            Text(
              'API keys',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add keys for the providers you want to use.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ..._externalProvidersOrder.map((p) => _buildApiKeyField(p, theme)),
            const SizedBox(height: 24),
            // Voice (optional)
            Text(
              'Voice (optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Wispr Flow for real-time voice transcription.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildWisprApiKeyField(theme),
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

  Widget _buildDefaultProviderOption(ThemeData theme, bool isSelected, {bool isGemini = true}) {
    final provider = isGemini ? LLMProvider.gemini : LLMProvider.groq;
    final label = isGemini ? 'Gemini 3.0 Flash (Default)' : 'Groq · Llama 3.3 70B (Fallback)';
    final description = isGemini
        ? 'Google Gemini — primary provider. No API key needed when signed in.'
        : 'Groq Llama 3.3 70B — used when Gemini is unavailable.';
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
          await _apiConfig.setManualProvider(provider);
          await _lumaraApi.initialize();
          setState(() {
            _selectedProvider = provider;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Switched to $label')),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isGemini ? Colors.blue : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isGemini ? Colors.blue : Colors.orange).withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isGemini) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
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

  Widget _buildApiKeyField(LLMProvider provider, ThemeData theme) {
    final controller = _apiKeyControllers[provider]!;
    final config = _apiConfig.getConfig(provider);
    final isConfigured = config?.apiKey?.isNotEmpty == true;
    
    // Custom display names for API key fields
    String displayName;
    switch (provider) {
      case LLMProvider.groq:
        displayName = 'Groq';
        break;
      case LLMProvider.openai:
        displayName = 'ChatGPT';
        break;
      case LLMProvider.anthropic:
        displayName = 'Anthropic';
        break;
      case LLMProvider.venice:
        displayName = 'Venice AI';
        break;
      case LLMProvider.openrouter:
        displayName = 'OpenRouter';
        break;
      default:
        displayName = config?.name ?? provider.name;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                displayName,
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 4),
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
                    hintText: 'Enter $displayName API key',
                    suffixIcon: isConfigured
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
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
                onPressed: () async {
                  await _saveSpecificApiKey(provider);
                },
                icon: const Icon(Icons.save, size: 18),
                label: Text(controller.text.trim().isEmpty ? 'Clear' : 'Save'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  backgroundColor: controller.text.trim().isEmpty
                      ? theme.colorScheme.surfaceContainerHighest
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
    if (controller == null) return;

    final key = controller.text.trim();
    final isClearing = key.isEmpty;

    try {
      await _apiConfig.updateApiKey(provider, key);

      // Force refresh provider availability (clears in-memory state when key removed)
      await _apiConfig.refreshProviderAvailability();

      if (!isClearing) {
        // Reinitialize LUMARA API to pick up the new key
        await _lumaraApi.initialize();
      }

      // Get display name for success message
      final config = _apiConfig.getConfig(provider);
      String displayName;
      switch (provider) {
        case LLMProvider.groq:
          displayName = 'Groq';
          break;
        case LLMProvider.openai:
          displayName = 'ChatGPT';
          break;
        case LLMProvider.anthropic:
          displayName = 'Anthropic';
          break;
        case LLMProvider.venice:
          displayName = 'Venice AI';
          break;
        case LLMProvider.openrouter:
          displayName = 'OpenRouter';
          break;
        default:
          displayName = config?.name ?? provider.name;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(isClearing ? Icons.info_outline : Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(isClearing
                      ? '$displayName API key cleared.'
                      : '$displayName API key saved and activated!'),
                ),
              ],
            ),
            backgroundColor: isClearing ? Colors.orange : Colors.green,
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
                const Icon(Icons.error, color: Colors.white),
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


  /// Build Wispr Flow API key field
  Widget _buildWisprApiKeyField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over, color: theme.colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Wispr Flow',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (_wisprApiKeyConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Configured',
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
          const SizedBox(height: 4),
          Text(
            'Real-time voice transcription for LUMARA voice mode',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wisprApiKeyController,
                  decoration: InputDecoration(
                    hintText: 'Paste API key from wisprflow.ai (only the key, no instructions)',
                    suffixIcon: _wisprApiKeyConfigured
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
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
                onPressed: () async {
                  await _saveWisprApiKey();
                },
                icon: const Icon(Icons.save, size: 18),
                label: Text(_wisprApiKeyController.text.trim().isEmpty ? 'Clear' : 'Save'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  backgroundColor: _wisprApiKeyController.text.trim().isEmpty
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Get your API key at wisprflow.ai — paste only the key (no quotes or "LUMARA tab" text). Personal use only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Save Wispr Flow API key (or clear if field is empty)
  Future<void> _saveWisprApiKey() async {
    final key = _wisprApiKeyController.text.trim();

    // Allow saving empty to clear the key — always clear cache so next voice session uses current storage
    if (key.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_wisprApiKeyPrefKey, '');
        WisprConfigService.instance.clearCache();
        setState(() {
          _wisprApiKeyConfigured = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wispr Flow API key cleared. Voice mode will use on-device transcription.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing Wispr API key: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    // Validate: reject values that look like instructions instead of an API key
    final keyLower = key.toLowerCase();
    final looksLikeInstructions = keyLower.contains('lumara') && keyLower.contains('settings') ||
        (keyLower.contains('tab') && keyLower.contains('->')) ||
        key.contains('"') ||
        key.length < 20;
    if (looksLikeInstructions && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'That doesn\'t look like an API key. In LUMARA Settings → API, paste only your key from wisprflow.ai (no quotes or instructions).',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_wisprApiKeyPrefKey, key);
      
      // Clear the WisprConfigService cache so new key is used on next voice mode session
      WisprConfigService.instance.clearCache();

      setState(() {
        _wisprApiKeyConfigured = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Wispr Flow API key saved! Voice mode will use your key.'),
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error saving Wispr API key: $e'),
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

    // Remove Wispr key from storage too (it lives in SharedPreferences, not LumaraAPIConfig)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wisprApiKeyPrefKey, '');
    WisprConfigService.instance.clearCache();

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
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
        activeThumbColor: theme.colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

}
