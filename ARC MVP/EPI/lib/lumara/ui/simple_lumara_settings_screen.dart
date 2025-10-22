// lib/lumara/ui/simple_lumara_settings_screen.dart
// Simplified LUMARA settings screen

import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../llm/bridge.pigeon.dart';
import '../services/download_state_service.dart';

/// Simplified LUMARA settings screen
class SimpleLumaraSettingsScreen extends StatefulWidget {
  const SimpleLumaraSettingsScreen({super.key});

  @override
  State<SimpleLumaraSettingsScreen> createState() => _SimpleLumaraSettingsScreenState();
}

class _SimpleLumaraSettingsScreenState extends State<SimpleLumaraSettingsScreen> {
  final LumaraAPIConfig _apiConfig = LumaraAPIConfig.instance;
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _openaiController = TextEditingController();
  final TextEditingController _anthropicController = TextEditingController();
  final LumaraNative _bridge = LumaraNative();
  final DownloadStateService _downloadStateService = DownloadStateService.instance;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentKeys();
    _downloadStateService.addListener(_onDownloadStateChanged);
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openaiController.dispose();
    _anthropicController.dispose();
    _downloadStateService.removeListener(_onDownloadStateChanged);
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCurrentKeys() async {
    await _apiConfig.initialize();
    
    setState(() {
      _geminiController.text = _apiConfig.getApiKey(LLMProvider.gemini) ?? '';
      _openaiController.text = _apiConfig.getApiKey(LLMProvider.openai) ?? '';
      _anthropicController.text = _apiConfig.getApiKey(LLMProvider.anthropic) ?? '';
    });
  }

  Future<void> _saveApiKey(LLMProvider provider, String key) async {
    if (key.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _apiConfig.updateApiKey(provider, key.trim());
      await _apiConfig.refreshProviderAvailability();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.name} API key saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startDownload(String modelId, String modelName, String modelUrl) async {
    setState(() => _isLoading = true);
    
    try {
      _downloadStateService.startDownload(modelId, modelName: modelName);
      final success = await _bridge.downloadModel(modelId, modelUrl);
      
      if (!success) {
        _downloadStateService.failDownload(modelId, 'Download failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download $modelName'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _downloadStateService.failDownload(modelId, e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteModel(String modelId, String modelName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $modelName?'),
        content: Text('This will permanently delete the downloaded model. You can download it again later if needed.'),
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

    setState(() => _isLoading = true);
    
    try {
      await _bridge.deleteModel(modelId);
      _downloadStateService.updateAvailability(modelId, false);
      await _apiConfig.refreshModelAvailability();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$modelName deleted successfully'),
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bestProvider = _apiConfig.getBestProvider();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
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
                          'Current AI Provider',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bestProvider != null
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: bestProvider != null ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            bestProvider != null ? Icons.check_circle : Icons.warning,
                            color: bestProvider != null ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bestProvider?.name ?? 'No AI provider configured',
                              style: TextStyle(
                                color: bestProvider != null ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bestProvider != null
                          ? 'LUMARA is ready to provide intelligent reflections'
                          : 'Add an API key below to enable AI features',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // API Keys Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'API Keys',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add your API key for any of these providers:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Gemini API Key
                    _buildApiKeyField(
                      'Google Gemini',
                      'Get your key from Google AI Studio',
                      _geminiController,
                      () => _saveApiKey(LLMProvider.gemini, _geminiController.text),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // OpenAI API Key
                    _buildApiKeyField(
                      'OpenAI GPT',
                      'Get your key from OpenAI Platform',
                      _openaiController,
                      () => _saveApiKey(LLMProvider.openai, _openaiController.text),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Anthropic API Key
                    _buildApiKeyField(
                      'Anthropic Claude',
                      'Get your key from Anthropic Console',
                      _anthropicController,
                      () => _saveApiKey(LLMProvider.anthropic, _anthropicController.text),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Internal Models Section
            _buildInternalModelsCard(theme),
            
            const SizedBox(height: 24),
            
            // Help Text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'How to get API keys:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Gemini: Visit Google AI Studio (aistudio.google.com)\n'
                    '• OpenAI: Visit OpenAI Platform (platform.openai.com)\n'
                    '• Anthropic: Visit Anthropic Console (console.anthropic.com)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildInternalModelsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Internal Models',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PRIVACY-FIRST',
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
              'Download models to your device for complete privacy. No data leaves your device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            
            // Qwen Model
            _buildInternalModelCard(
              theme,
              'Qwen3 4B Instruct',
              'Qwen3-4B-Instruct-2507-Q4_K_S.gguf',
              '~2.5 GB',
              'https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_S.gguf?download=true',
            ),
            
            const SizedBox(height: 12),
            
            // Llama Model
            _buildInternalModelCard(
              theme,
              'Llama 3.2 3B Instruct',
              'Llama-3.2-3b-Instruct-Q4_K_M.gguf',
              '~1.9 GB',
              'https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-3b-instruct-q4_k_m.gguf?download=true',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalModelCard(
    ThemeData theme,
    String name,
    String modelId,
    String size,
    String url,
  ) {
    final downloadState = _downloadStateService.getState(modelId);
    final isDownloaded = downloadState?.isDownloaded ?? false;
    final isDownloading = downloadState?.isDownloading ?? false;
    final progress = downloadState?.progress ?? 0.0;
    final statusMessage = downloadState?.statusMessage ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDownloaded 
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
        color: isDownloaded 
            ? Colors.green.withOpacity(0.05)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDownloading 
                      ? Colors.blue
                      : isDownloaded 
                          ? Colors.green 
                          : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Size: $size',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDownloaded)
                IconButton(
                  onPressed: () => _deleteModel(modelId, name),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete Model',
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                )
              else if (!isDownloading)
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _startDownload(modelId, name, url),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: () {
                    // TODO: Implement cancel download
                  },
                  child: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
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
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ],
          
          // Download complete message
          if (isDownloaded && !isDownloading) ...[
            const SizedBox(height: 8),
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
    );
  }

  Widget _buildApiKeyField(
    String title,
    String hint,
    TextEditingController controller,
    VoidCallback onSave,
  ) {
    final theme = Theme.of(context);
    final hasKey = controller.text.trim().isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (hasKey)
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
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                obscureText: true,
                onChanged: (value) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: hasKey && !_isLoading ? onSave : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasKey ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
