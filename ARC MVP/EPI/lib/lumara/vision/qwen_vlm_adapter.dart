import 'dart:typed_data';
import '../llm/lumara_native.dart';
import '../../core/app_flags.dart';

/// Qwen Vision-Language Model adapter for image understanding and captioning
class QwenVlmAdapter {
  static bool _isInitialized = false;
  static QwenModel? _loadedModel;
  static DeviceCapabilities? _deviceCaps;

  /// Initialize the Qwen VLM adapter
  static Future<bool> initialize() async {
    try {
      // Get device capabilities to choose appropriate VLM model
      _deviceCaps = await LumaraNative.getDeviceCapabilities();
      
      final recommendedModel = _deviceCaps!.recommendedVlmModel;
      final modelConfig = modelConfigs[recommendedModel]!;
      
      print('QwenVlmAdapter: Initializing ${modelConfig.displayName}');
      print('  Device RAM: ${_deviceCaps!.totalRamGB.toStringAsFixed(1)}GB');
      print('  Model size: ${modelConfig.estimatedSizeMB}MB');
      
      // Construct model path
      final modelPath = 'assets/models/qwen/${modelConfig.filename}';
      
      // Initialize the VLM model
      final success = await LumaraNative.initVisionModel(
        modelPath: modelPath,
        params: const GenParams(
          temperature: 0.7, // Slightly higher temperature for creative image descriptions
          maxTokens: 512,   // Longer responses for image analysis
        ),
      );
      
      if (success) {
        _loadedModel = recommendedModel;
        _isInitialized = true;
        print('QwenVlmAdapter: Successfully initialized ${modelConfig.displayName}');
        return true;
      } else {
        print('QwenVlmAdapter: Failed to initialize VLM model');
        return false;
      }
    } catch (e) {
      print('QwenVlmAdapter: Initialization error - $e');
      return false;
    }
  }
  
  /// Check if VLM adapter is ready
  static bool get isReady => _isInitialized && _loadedModel != null;
  
  /// Get loaded model information
  static QwenModel? get loadedModel => _loadedModel;

  /// Generate image caption
  static Future<String> captionImage(Uint8List imageJpeg, {String? context}) async {
    if (!isReady) {
      return 'Vision model is not initialized. Please wait for the model to load.';
    }

    try {
      final prompt = context != null 
          ? 'Describe this image in the context of: $context'
          : 'Describe what you see in this image in detail.';

      print('QwenVlmAdapter: Generating caption for image (${imageJpeg.length} bytes)');

      final response = await LumaraNative.qwenVision(
        prompt: prompt,
        imageJpeg: imageJpeg,
      );

      return response.isNotEmpty 
          ? response 
          : 'Unable to generate image description at this time.';
    } catch (e) {
      print('QwenVlmAdapter: Error generating caption - $e');
      return 'Error analyzing image. Please try again.';
    }
  }

  /// Answer questions about an image
  static Future<String> askAboutImage(
    Uint8List imageJpeg, 
    String question, {
    String? journalContext,
  }) async {
    if (!isReady) {
      return 'Vision model is not initialized. Please wait for the model to load.';
    }

    try {
      // Enhanced prompt with journal context
      String prompt = question;
      if (journalContext != null) {
        prompt = '''Based on this journal context: "$journalContext"

Please answer this question about the image: $question''';
      }

      print('QwenVlmAdapter: Analyzing image with question: ${question.substring(0, 50)}...');

      final response = await LumaraNative.qwenVision(
        prompt: prompt,
        imageJpeg: imageJpeg,
      );

      return response.isNotEmpty 
          ? response 
          : 'Unable to analyze the image for your question at this time.';
    } catch (e) {
      print('QwenVlmAdapter: Error answering about image - $e');
      return 'Error processing your question about the image. Please try again.';
    }
  }

  /// Analyze image for journal entry enhancement
  static Future<String> analyzeForJournal(
    Uint8List imageJpeg, {
    String? entryText,
    String? currentPhase,
  }) async {
    if (!isReady) {
      return 'Vision model is not initialized.';
    }

    try {
      final prompt = '''Analyze this image in the context of a personal journal entry.

${entryText != null ? 'Journal entry context: "$entryText"' : ''}
${currentPhase != null ? 'Current personal growth phase: $currentPhase' : ''}

Please provide insights about:
1. What emotions or themes does this image convey?
2. How might it relate to personal growth or daily experiences?
3. What questions might someone reflect on based on this image?

Keep your analysis thoughtful and supportive.''';

      print('QwenVlmAdapter: Analyzing image for journal enhancement');

      final response = await LumaraNative.qwenVision(
        prompt: prompt,
        imageJpeg: imageJpeg,
      );

      return response.isNotEmpty 
          ? response 
          : 'Unable to provide image analysis for your journal entry.';
    } catch (e) {
      print('QwenVlmAdapter: Error analyzing for journal - $e');
      return 'Error analyzing image for journal context.';
    }
  }

  /// Extract text from images (if supported by the model)
  static Future<String> extractText(Uint8List imageJpeg) async {
    if (!isReady) {
      return 'Vision model is not initialized.';
    }

    try {
      const prompt = '''Please extract and transcribe any text you can see in this image. 
If there is no text, respond with "No text found in image."
Present the text exactly as it appears, maintaining formatting where possible.''';

      print('QwenVlmAdapter: Extracting text from image');

      final response = await LumaraNative.qwenVision(
        prompt: prompt,
        imageJpeg: imageJpeg,
      );

      return response.isNotEmpty 
          ? response 
          : 'Unable to extract text from the image.';
    } catch (e) {
      print('QwenVlmAdapter: Error extracting text - $e');
      return 'Error extracting text from image.';
    }
  }

  /// Get model capabilities and status
  static Map<String, dynamic> getStatus() {
    final modelConfig = _loadedModel != null ? modelConfigs[_loadedModel!] : null;
    
    return {
      'initialized': _isInitialized,
      'loaded_model': _loadedModel?.name,
      'model_display_name': modelConfig?.displayName,
      'model_size_mb': modelConfig?.estimatedSizeMB,
      'device_ram_gb': _deviceCaps?.totalRamGB,
      'can_run_3b_vlm': _deviceCaps?.canRun3BVLM ?? false,
    };
  }
  
  /// Dispose of resources
  static Future<void> dispose() async {
    _isInitialized = false;
    _loadedModel = null;
    _deviceCaps = null;
    print('QwenVlmAdapter: Disposed');
  }
}