// lib/arc/chat/prompt_optimization/provider_manager.dart
// Manages LLM provider selection and failover for universal prompt optimization.

import 'package:flutter/foundation.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'providers/provider_adapter.dart';
import 'providers/groq_adapter.dart';
import 'providers/openai_adapter.dart';
import 'providers/claude_adapter.dart';

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

    final openaiKey = _apiConfig.getApiKey(LLMProvider.openai);
    if (openaiKey != null && openaiKey.isNotEmpty) {
      _adapters['openai'] = OpenAIAdapter(apiKey: openaiKey);
    }

    final anthropicKey = _apiConfig.getApiKey(LLMProvider.anthropic);
    if (anthropicKey != null && anthropicKey.isNotEmpty) {
      _adapters['claude'] = ClaudeAdapter(apiKey: anthropicKey);
    }
  }

  /// Resolve primary provider name from API config (best or manual).
  String? _getPrimaryName() {
    final best = _apiConfig.getBestProvider();
    if (best == null) return null;
    return switch (best.provider) {
      LLMProvider.groq => 'groq',
      LLMProvider.openai => 'openai',
      LLMProvider.anthropic => 'claude',
      _ => 'groq',
    };
  }

  /// Get provider with automatic failover (primary first, then fallbacks).
  Future<ProviderAdapter> getProvider() async {
    _ensureAdapters();
    final primaryName = _getPrimaryName();
    if (primaryName != null) {
      final adapter = _adapters[primaryName];
      if (adapter != null && await adapter.isAvailable()) {
        return adapter;
      }
    }

    debugPrint('[ProviderManager] Primary unavailable, trying fallbacks...');
    const fallbacks = ['groq', 'openai', 'claude'];
    for (final name in fallbacks) {
      final adapter = _adapters[name];
      if (adapter != null && await adapter.isAvailable()) {
        debugPrint('[ProviderManager] Using fallback: $name');
        return adapter;
      }
    }
    throw StateError('No available LLM providers');
  }

  /// Set primary provider by name (e.g. 'groq', 'openai', 'claude').
  /// Persists via LumaraAPIConfig.setManualProvider when applicable.
  Future<void> setPrimaryProvider(String providerName) async {
    final p = switch (providerName.toLowerCase()) {
      'groq' => LLMProvider.groq,
      'openai' => LLMProvider.openai,
      'claude' => LLMProvider.anthropic,
      _ => null,
    };
    if (p == null) throw ArgumentError('Unknown provider: $providerName');
    await _apiConfig.setManualProvider(p);
    debugPrint('[ProviderManager] Primary set to: $providerName');
  }

  /// Names of configured adapters (have API keys).
  List<String> getAvailableProviderNames() {
    _ensureAdapters();
    return _adapters.keys.toList();
  }
}
