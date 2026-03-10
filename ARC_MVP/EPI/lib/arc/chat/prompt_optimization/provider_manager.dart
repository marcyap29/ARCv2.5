// lib/arc/chat/prompt_optimization/provider_manager.dart
// Manages LLM provider selection and failover for universal prompt optimization.

import 'package:flutter/foundation.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'providers/provider_adapter.dart';
import 'providers/groq_adapter.dart';

class ProviderManager {
  ProviderManager({required LumaraAPIConfig apiConfig})
      : _apiConfig = apiConfig,
        _adapters = <String, ProviderAdapter>{};

  final LumaraAPIConfig _apiConfig;
  final Map<String, ProviderAdapter> _adapters;
  bool _initialized = false;

  void _ensureAdapters() {
    if (_initialized) return;
    _initialized = true;

    final groqKey = _apiConfig.getApiKey(LLMProvider.groq);
    if (groqKey != null && groqKey.isNotEmpty) {
      _adapters['groq'] = GroqAdapter(apiKey: groqKey);
    }
    // OpenAI and Claude adapters removed; only Groq is used.
  }

  /// Resolve primary provider name from API config (best or manual).
  String? _getPrimaryName() {
    final best = _apiConfig.getBestProvider();
    if (best == null) return null;
    return switch (best.provider) {
      LLMProvider.groq => 'groq',
      _ => 'groq',
    };
  }

  /// Get provider with automatic failover (only Groq in use).
  Future<ProviderAdapter> getProvider() async {
    _ensureAdapters();
    final primaryName = _getPrimaryName();
    if (primaryName != null) {
      final adapter = _adapters[primaryName];
      if (adapter != null && await adapter.isAvailable()) {
        return adapter;
      }
    }

    debugPrint('[ProviderManager] Groq unavailable, no fallbacks (other APIs removed).');
    const fallbacks = ['groq'];
    for (final name in fallbacks) {
      final adapter = _adapters[name];
      if (adapter != null && await adapter.isAvailable()) {
        debugPrint('[ProviderManager] Using: $name');
        return adapter;
      }
    }
    throw StateError('No available LLM providers. Configure Groq API key.');
  }

  /// Set primary provider by name (only 'groq' supported).
  Future<void> setPrimaryProvider(String providerName) async {
    if (providerName.toLowerCase() != 'groq') {
      throw ArgumentError('Only Groq is supported. Unknown provider: $providerName');
    }
    await _apiConfig.setManualProvider(LLMProvider.groq);
    debugPrint('[ProviderManager] Primary set to: groq');
  }

  /// Names of configured adapters (have API keys).
  List<String> getAvailableProviderNames() {
    _ensureAdapters();
    return _adapters.keys.toList();
  }
}
