import 'package:logger/logger.dart';
import 'model_adapter.dart';
import 'qwen_adapter.dart';
import '../../core/app_flags.dart';

/// Service for LUMARA AI inference using Qwen models
/// Supports chat, vision, and embedding models with runtime switching
class QwenService {
  static final Logger _logger = Logger();
  static bool _isInitialized = false;
  static QwenModel? _currentModel;
  static ModelAdapter _adapter = RuleBasedAdapter(); // Default fallback
  static LlmRuntime _runtime = activeRuntime;

  /// Available Qwen models for LUMARA
  static Map<String, String> get availableModels => {
    for (final entry in modelConfigs.entries)
      entry.key.name: '${entry.value.displayName} - ${entry.value.description} (~${entry.value.estimatedSizeMB}MB)',
    'rule_based': 'Rule-Based Responses - No AI model required',
  };

  /// Initialize the Qwen service
  static Future<bool> initialize({
    QwenModel? preferredModel,
    LlmRuntime? runtime,
    Map<String, dynamic>? options,
  }) async {
    try {
      _logger.i('Initializing Qwen service');
      
      // Set runtime if specified
      if (runtime != null && runtime != _runtime) {
        _runtime = runtime;
        _logger.i('Switching to runtime: ${_runtime.name}');
      }

      // Check if already initialized with same model
      if (_isInitialized && 
          _currentModel == preferredModel && 
          _adapter is QwenAdapter) {
        _logger.i('Qwen service already initialized with ${_currentModel?.name}');
        return true;
      }

      // Try to initialize Qwen adapter
      print('QwenService: Attempting to initialize QwenAdapter...');
      final qwenSuccess = await QwenAdapter.initialize();
      print('QwenService: QwenAdapter.initialize() returned: $qwenSuccess');
      print('QwenService: QwenAdapter.isReady: ${QwenAdapter.isReady}');
      print('QwenService: QwenAdapter.loadedModel: ${QwenAdapter.loadedModel}');
      
      if (qwenSuccess && QwenAdapter.isReady) {
        _adapter = QwenAdapter();
        _isInitialized = true;
        _currentModel = QwenAdapter.loadedModel;
        _logger.i('Successfully initialized Qwen adapter with ${_currentModel?.name}');
        print('QwenService: Successfully initialized Qwen adapter with ${_currentModel?.name}');
        return true;
      } else {
        // Fallback to rule-based adapter
        _logger.w('Qwen adapter not available (no model files found), using rule-based responses');
        print('QwenService: Qwen adapter not available, using rule-based responses');
        print('QwenService: qwenSuccess: $qwenSuccess, isReady: ${QwenAdapter.isReady}');
        _adapter = RuleBasedAdapter();
        _isInitialized = true;
        _currentModel = null;
        return true; // Still successful, just using fallback
      }
    } catch (e) {
      _logger.e('Failed to initialize Qwen service: $e');
      
      // Always ensure rule-based fallback works
      _adapter = RuleBasedAdapter();
      _isInitialized = true;
      _currentModel = null;
      return true;
    }
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;
  
  /// Check if using AI model (not rule-based)
  static bool get isAiEnabled => _adapter is QwenAdapter && QwenAdapter.isReady;
  
  /// Get current model information
  static QwenModel? get currentModel => _currentModel;
  
  /// Get current runtime
  static LlmRuntime get currentRuntime => _runtime;

  /// Generate AI response using current adapter
  static Stream<String> generateResponse({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) {
    print('QwenService: generateResponse called');
    print('  Task: $task');
    print('  Facts: $facts');
    print('  Snippets: $snippets');
    print('  Chat: $chat');
    print('  Is initialized: $_isInitialized');
    print('  Adapter type: ${_adapter.runtimeType}');
    print('  Is AI enabled: $isAiEnabled');
    print('  Current model: $_currentModel');
    print('  Using QwenAdapter: ${_adapter is QwenAdapter}');
    print('  Using RuleBasedAdapter: ${_adapter is RuleBasedAdapter}');
    
    if (!_isInitialized) {
      _logger.w('Service not initialized, initializing now');
      print('QwenService: Service not initialized, initializing now');
      // Try to initialize on-demand
      initialize().then((success) {
        if (!success) {
          _logger.e('Failed to initialize service');
          print('QwenService: Failed to initialize service');
        } else {
          print('QwenService: Service initialized successfully');
        }
      });
      
      return Stream.value('LUMARA is initializing. Please wait a moment and try again.');
    }

    _logger.d('Generating response for task: $task');
    _logger.d('Context: ${snippets.length} snippets, ${chat.length} chat messages');
    print('QwenService: Calling adapter.realize()');

    return _adapter.realize(
      task: task,
      facts: facts,
      snippets: snippets,
      chat: chat,
    );
  }

  /// Switch between different runtimes (llama.cpp vs MLC)
  static Future<bool> switchRuntime(LlmRuntime newRuntime) async {
    if (newRuntime == _runtime) {
      _logger.i('Already using runtime: ${newRuntime.name}');
      return true;
    }

    try {
      _logger.i('Switching from ${_runtime.name} to ${newRuntime.name}');
      
      // Dispose current adapter if it's Qwen
      if (_adapter is QwenAdapter) {
        await QwenAdapter.dispose();
      }
      
      _runtime = newRuntime;
      _isInitialized = false;
      
      // Reinitialize with new runtime
      return await initialize(runtime: newRuntime);
    } catch (e) {
      _logger.e('Failed to switch runtime: $e');
      return false;
    }
  }

  /// Get service status and model information
  static Map<String, dynamic> getStatus() {
    final deviceCaps = QwenAdapter.deviceCapabilities;
    
    return {
      'initialized': _isInitialized,
      'runtime': _runtime.name,
      'aiInferenceEnabled': _isInitialized && _adapter is QwenAdapter && QwenAdapter.isReady,
      'currentModel': _currentModel?.name,
      'adapterType': _adapter.runtimeType.toString(),
      'deviceCapabilities': deviceCaps != null ? {
        'totalRamGB': deviceCaps.totalRamGB,
        'canRun4BModels': deviceCaps.canRun4BModels,
        'canRun3BVLM': deviceCaps.canRun3BVLM,
        'recommendedChatModel': deviceCaps.recommendedChatModel.name,
        'recommendedVlmModel': deviceCaps.recommendedVlmModel.name,
      } : null,
      'note': _adapter is QwenAdapter 
          ? 'Using on-device Qwen model for AI inference'
          : 'Using rule-based responses (no AI model loaded)',
    };
  }

  /// Check if specific model is available and loaded
  static Future<bool> isModelReady(String modelType) async {
    if (!_isInitialized || _adapter is! QwenAdapter) {
      return false;
    }

    try {
      return QwenAdapter.isReady;
    } catch (e) {
      _logger.e('Error checking model readiness: $e');
      return false;
    }
  }

  /// Dispose of service and free resources
  static Future<void> dispose() async {
    try {
      _logger.i('Disposing Qwen service');
      
      if (_adapter is QwenAdapter) {
        await QwenAdapter.dispose();
      }
      
      _isInitialized = false;
      _currentModel = null;
      _adapter = RuleBasedAdapter(); // Reset to rule-based
      
      _logger.i('Qwen service disposed');
    } catch (e) {
      _logger.e('Error disposing service: $e');
    }
  }

  /// Get available device memory and model recommendations
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (_adapter is QwenAdapter) {
        final deviceCaps = QwenAdapter.deviceCapabilities;
        if (deviceCaps != null) {
          return {
            'totalRamGB': deviceCaps.totalRamGB,
            'availableRamGB': deviceCaps.availableRamGB,
            'recommendedChatModel': deviceCaps.recommendedChatModel.name,
            'recommendedVlmModel': deviceCaps.recommendedVlmModel.name,
            'canRunEmbeddings': deviceCaps.canRunEmbeddings,
            'canRun4BModels': deviceCaps.canRun4BModels,
            'canRun3BVLM': deviceCaps.canRun3BVLM,
          };
        }
      }
      
      // Fallback device info
      return {
        'totalRamGB': 4.0,
        'availableRamGB': 2.0,
        'recommendedChatModel': QwenModel.qwen2p5_1p5b_instruct.name,
        'recommendedVlmModel': QwenModel.qwen2_vl_2b_instruct.name,
        'canRunEmbeddings': true,
        'canRun4BModels': false,
        'canRun3BVLM': false,
      };
    } catch (e) {
      _logger.e('Error getting device info: $e');
      return {};
    }
  }
}