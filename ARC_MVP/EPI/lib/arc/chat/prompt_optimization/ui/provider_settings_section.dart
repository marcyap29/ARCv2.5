// lib/arc/chat/prompt_optimization/ui/provider_settings_section.dart
// UI section for choosing AI provider (Universal 80/20 optimization).

import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/prompt_optimization/provider_manager.dart';
import 'package:my_app/arc/chat/config/api_config.dart';

/// Description and cost estimate per provider (for display).
String getProviderDescription(String provider) {
  return switch (provider.toLowerCase()) {
    'groq' => 'Fastest responses, lower cost. Great for everyday use.',
    'openai' => 'GPT-4 powered. Excellent quality, higher cost.',
    'claude' => 'Claude Sonnet. Balanced quality and speed.',
    _ => '',
  };
}

String getProviderCostEstimate(String provider) {
  return switch (provider.toLowerCase()) {
    'groq' => r'$5–10',
    'openai' => r'$20–40',
    'claude' => r'$15–25',
    _ => 'Unknown',
  };
}

/// Section widget showing available providers and current selection.
/// Integrates with [ProviderManager] and [LumaraAPIConfig] for persistence.
class ProviderSettingsSection extends StatefulWidget {
  const ProviderSettingsSection({
    super.key,
    required this.providerManager,
    required this.apiConfig,
    this.onProviderChanged,
  });

  final ProviderManager providerManager;
  final LumaraAPIConfig apiConfig;
  final void Function(String provider)? onProviderChanged;

  @override
  State<ProviderSettingsSection> createState() => _ProviderSettingsSectionState();
}

class _ProviderSettingsSectionState extends State<ProviderSettingsSection> {
  List<String> _providers = [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final names = widget.providerManager.getAvailableProviderNames();
    final best = widget.apiConfig.getBestProvider();
    String? current;
    if (best != null) {
      current = switch (best.provider) {
        LLMProvider.groq => 'groq',
        LLMProvider.openai => 'openai',
        LLMProvider.anthropic => 'claude',
        _ => null,
      };
    }
    setState(() {
      _providers = names;
      _selected = current ?? (names.isNotEmpty ? names.first : null);
    });
  }

  Future<void> _select(String provider) async {
    await widget.providerManager.setPrimaryProvider(provider);
    setState(() => _selected = provider);
    widget.onProviderChanged?.call(provider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now using ${provider.toUpperCase()} for AI responses'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Provider',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose which AI service powers LUMARA\'s responses. Universal optimization works with any provider.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ..._providers.map((provider) {
          final isSelected = _selected == provider;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
              child: InkWell(
                onTap: () => _select(provider),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider.toUpperCase(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Text(
                              '✓ Selected',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getProviderDescription(provider),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Est. cost: ${getProviderCostEstimate(provider)}/month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        Text(
          'LUMARA automatically switches to a backup provider if your primary choice is unavailable.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
