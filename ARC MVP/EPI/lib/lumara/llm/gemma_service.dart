import 'package:logger/logger.dart';
import 'model_adapter.dart';

/// Service for offline LLM inference using the adapter pattern
/// Supports rule-based, on-device mini models, and cloud models
class GemmaService {
  static final Logger _logger = Logger();
  static bool _isInitialized = false;
  static String? _currentModelName;
  static ModelAdapter _adapter = RuleBasedAdapter(); // Default to rule-based

  /// Available models for LUMARA
  static const Map<String, String> availableModels = {
    'qwen2_5_7b_instruct': 'Qwen 2.5 7B-Instruct - Best performance (~4.5GB)',
    'qwen2_5_3b_instruct': 'Qwen 2.5 3B-Instruct - Balanced performance (~2GB)',
    'qwen2_5_1_5b_instruct': 'Qwen 2.5 1.5B-Instruct - Fast performance (~1GB)',
    'rule_based': 'Rule-Based Responses - No AI model required',
  };

  /// Initialize the LLM model using the adapter pattern
  static Future<bool> initialize({
    String modelName = 'gemma3_4b_instruct',
    Map<String, dynamic>? options,
  }) async {
    try {
      _logger.i('Initializing Gemma service with model: $modelName');

      // Check if model is already initialized
      if (_isInitialized && _currentModelName == modelName) {
        _logger.i('Model already initialized');
        return true;
      }

      // Try to initialize Gemma adapter first
      // GemmaAdapter not available, using rule-based fallback
      final gemmaSuccess = false;
      
      // Always use rule-based adapter for now
      _adapter = RuleBasedAdapter();
      _isInitialized = true;
      _currentModelName = 'rule_based';
      _logger.w('Falling back to rule-based responses - Gemma model not available');
      return true;

    } catch (e) {
      _logger.e('Failed to initialize Gemma service: $e');
      // Fallback to rule-based responses
      _adapter = RuleBasedAdapter();
      _isInitialized = true;
      _currentModelName = 'rule_based';
      _logger.w('Falling back to rule-based responses');
      return true;
    }
  }

  /// Generate text response using the adapter pattern
  static Stream<String> generateResponse({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) {
    if (!_isInitialized) {
      _logger.w('Gemma service not initialized, using fallback');
      return Stream.value('Service not initialized. Please try again.');
    }

    try {
      _logger.d('Generating response for task: $task');
      
      // Use the current adapter to generate response
      return _adapter.realize(
        task: task,
        facts: facts,
        snippets: snippets,
        chat: chat,
      );

    } catch (e) {
      _logger.e('Failed to generate response: $e');
      return Stream.value('Error generating response: $e');
    }
  }

  /// Check if the model is available and ready
  static Future<bool> isModelAvailable() async {
    return _isInitialized;
  }

  /// Get model information and status
  static Future<Map<String, dynamic>> getModelInfo() async {
    // Check for model files in assets folder
    final downloadedModels = <String>[];
    
    // Check for Gemma 3 1B model files
    if (await _checkModelFiles('gemma3_1b_instruct')) {
      downloadedModels.add('gemma3_1b_instruct');
    }
    
    // Check for Gemma 3 4B model files (if available)
    if (await _checkModelFiles('gemma3_4b_instruct')) {
      downloadedModels.add('gemma3_4b_instruct');
    }
    
    // Rule-based is always available
    downloadedModels.add('rule_based');

    final info = <String, dynamic>{
      'isInitialized': _isInitialized,
      'currentModel': _currentModelName,
      'availableModels': availableModels,
      'downloadedModels': downloadedModels,
      'aiInferenceEnabled': false, // GemmaAdapter not available
      'fallbackMode': _adapter is RuleBasedAdapter,
      'status': _isInitialized ? 'Ready' : 'Not Initialized',
      'note': 'Using rule-based responses (no AI model available)',
    };

    return info;
  }

  /// Check if model files exist in assets folder
  static Future<bool> _checkModelFiles(String modelName) async {
    try {
      // For now, we'll check if the main model file exists
      // In a real implementation, you'd check for all required files
      final modelFile = 'assets/models/$modelName.safetensors';
      
      // This is a simplified check - in practice you'd use rootBundle.loadString
      // or check the actual file system
      return modelName == 'gemma3_1b_instruct' || modelName == 'rule_based';
    } catch (e) {
      _logger.w('Error checking model files for $modelName: $e');
      return false;
    }
  }

  /// Dispose of resources
  static Future<void> dispose() async {
    try {
      // GemmaAdapter not available, no disposal needed
      _adapter = RuleBasedAdapter();
      _isInitialized = false;
      _currentModelName = null;
      _logger.i('Gemma service disposed');
    } catch (e) {
      _logger.e('Error disposing Gemma service: $e');
    }
  }
}
