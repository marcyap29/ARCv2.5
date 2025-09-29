// lib/lumara/ui/lumara_settings_screen.dart
// LUMARA settings and API key management screen

import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/enhanced_lumara_api.dart';
import '../../telemetry/analytics.dart';

/// LUMARA settings screen for API key management and provider selection
class LumaraSettingsScreen extends StatefulWidget {
  const LumaraSettingsScreen({super.key});

  @override
  State<LumaraSettingsScreen> createState() => _LumaraSettingsScreenState();
}

class _LumaraSettingsScreenState extends State<LumaraSettingsScreen> {
  final LumaraAPIConfig _apiConfig = LumaraAPIConfig.instance;
  final EnhancedLumaraApi _lumaraApi = EnhancedLumaraApi(Analytics());
  final Map<LLMProvider, TextEditingController> _apiKeyControllers = {};
  LLMProvider? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

    // Get current best provider
    final bestProvider = _apiConfig.getBestProvider();
    setState(() {
      _selectedProvider = bestProvider?.provider;
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Overview
            _buildStatusCard(theme),
            const SizedBox(height: 24),
            
            // Provider Selection
            _buildProviderSelection(theme),
            const SizedBox(height: 24),
            
            // Internal Models Section (Priority for ARC's security focus)
            _buildInternalModelsSection(theme),
            const SizedBox(height: 24),
            
            // API Keys Card (Prominent placement)
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
    final status = _lumaraApi.getStatus();
    final availableProviders = _apiConfig.getAvailableProviders();
    
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
            Text('Current Provider: ${status['currentProvider']}'),
            Text('Available Providers: ${availableProviders.length}'),
            const SizedBox(height: 8),
            Text(
              'LUMARA is ready to provide intelligent reflections on your journal entries.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelection(ThemeData theme) {
    final availableProviders = _apiConfig.getAvailableProviders();
    
    // Sort providers to prioritize internal models
    final sortedProviders = List<LLMProviderConfig>.from(availableProviders)
      ..sort((a, b) {
        if (a.isInternal && !b.isInternal) return -1;
        if (!a.isInternal && b.isInternal) return 1;
        return 0;
      });
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Provider Selection',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred AI provider. Internal models are recommended for privacy.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedProviders.map((config) => RadioListTile<LLMProvider>(
              title: Row(
                children: [
                  Text(config.name),
                  const SizedBox(width: 8),
                  if (config.isInternal)
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
              subtitle: Text(
                config.isInternal 
                  ? 'Local Model - Privacy First' 
                  : 'Cloud API - Fallback Option',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: config.isInternal 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: config.provider,
              groupValue: _selectedProvider,
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value;
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySection(ThemeData theme) {
    final externalProviders = LLMProvider.values
        .where((p) => p != LLMProvider.ruleBased && p != LLMProvider.llama && p != LLMProvider.qwen)
        .toList();
    
    return Card(
      elevation: 3, // More prominent elevation
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.api, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'API Keys (Recommended)',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Configure your API keys to enable AI-powered reflections',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Internal models are not yet available. Add your API keys below to start using LUMARA\'s AI features.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...externalProviders.map((provider) => _buildApiKeyField(provider, theme)),
            const SizedBox(height: 24),
            // Save button for API Keys section
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveApiKeys,
                icon: const Icon(Icons.save),
                label: const Text('Save API Keys'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyField(LLMProvider provider, ThemeData theme) {
    final controller = _apiKeyControllers[provider]!;
    final config = _apiConfig.getConfig(provider);
    final isConfigured = config?.apiKey?.isNotEmpty == true;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.name,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter ${provider.name} API key',
              suffixIcon: isConfigured
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : Icon(Icons.help_outline, color: theme.colorScheme.onSurfaceVariant),
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
            onChanged: (value) => _updateApiKey(provider, value),
          ),
        ],
      ),
    );
  }

  Widget _buildInternalModelsSection(ThemeData theme) {
    return Card(
      elevation: 2, // Slightly elevated to show priority
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Internal Models (Recommended)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 8),
            Text(
              'Privacy-first AI models that run entirely on your device. No data leaves your phone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildInternalModelCard(
              'Llama 2', 
              'Meta\'s open-source model for private conversations', 
              '2-4GB RAM required',
              Icons.psychology,
              theme,
            ),
            const SizedBox(height: 8),
            _buildInternalModelCard(
              'Qwen', 
              'Alibaba\'s multilingual model with excellent performance', 
              '1-3GB RAM required',
              Icons.language,
              theme,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ARC prioritizes internal models for maximum privacy and security.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
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
  }

  Widget _buildInternalModelCard(String name, String description, String requirements, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.primary.withOpacity(0.02),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name, 
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  requirements,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_outline, 
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeysCard(ThemeData theme) {
    final externalProviders = LLMProvider.values
        .where((p) => p != LLMProvider.ruleBased && p != LLMProvider.llama && p != LLMProvider.qwen)
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
    return Row(
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
    );
  }

  void _updateApiKey(LLMProvider provider, String apiKey) {
    _apiConfig.updateApiKey(provider, apiKey);
  }

  Future<void> _saveApiKeys() async {
    try {
      // Save all API keys that have been entered
      for (final provider in LLMProvider.values) {
        final controller = _apiKeyControllers[provider];
        if (controller != null && controller.text.isNotEmpty) {
          await _apiConfig.updateApiKey(provider, controller.text.trim());
        }
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API keys saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving API keys: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

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
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
