import 'dart:io';
import '../../telemetry/analytics.dart';
import '../../lumara/llm/bridge.pigeon.dart';

/// Abstract OCR service interface for text extraction from images
abstract class OcrService {
  Future<String> extractText(File imageFile);
  Future<String> extractTextFromBytes(List<int> imageBytes);
}

/// Stub OCR service implementation for MVP
class StubOcrService implements OcrService {
  final Analytics analytics;
  
  StubOcrService(this.analytics);

  @override
  Future<String> extractText(File imageFile) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'file'});
    
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return mock text for MVP
    final mockText = _generateMockText();
    
    analytics.logScanEvent('ocr_completed', data: {
      'source': 'file',
      'text_length': mockText.length,
    });
    
    return mockText;
  }

  @override
  Future<String> extractTextFromBytes(List<int> imageBytes) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'bytes'});
    
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return mock text for MVP
    final mockText = _generateMockText();
    
    analytics.logScanEvent('ocr_completed', data: {
      'source': 'bytes',
      'text_length': mockText.length,
    });
    
    return mockText;
  }

  String _generateMockText() {
    final mockTexts = [
      "Today I feel grateful for the small moments of peace I found in my morning routine. The way the light filtered through my window reminded me that even in difficult times, beauty persists.",
      "I'm struggling with self-doubt today. Part of me wants to give up, but another part knows I need to keep going. What would I tell a friend in this situation?",
      "Had an interesting conversation with Sarah about our future plans. It made me realize how much I've been avoiding thinking about what I really want. Time to be more honest with myself.",
      "Feeling overwhelmed by all the changes happening at work. Need to take it one day at a time and remember that I'm capable of adapting to new challenges.",
      "Went for a walk in the park and noticed how the trees are starting to change color. There's something comforting about the natural cycles of growth and change.",
    ];
    
    return mockTexts[DateTime.now().millisecondsSinceEpoch % mockTexts.length];
  }
}

/// Apple Vision OCR service implementation (iOS)
class AppleVisionOcrService implements OcrService {
  final Analytics analytics;
  
  AppleVisionOcrService(this.analytics);

  @override
  Future<String> extractText(File imageFile) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'file', 'platform': 'ios'});
    
    try {
      // TODO: Implement native OCR bridge method
      // For now, use fallback to stub service
      analytics.logScanEvent('ocr_fallback', data: {
        'source': 'file',
        'platform': 'ios',
        'reason': 'native_ocr_not_implemented',
      });
      
      // Fallback to stub service until native OCR is implemented
      final stubService = StubOcrService(analytics);
      return await stubService.extractText(imageFile);
    } catch (e) {
      analytics.logScanEvent('ocr_failed', data: {
        'source': 'file',
        'platform': 'ios',
        'error': e.toString(),
      });
      
      // Final fallback
      return 'OCR service temporarily unavailable. Please try again later.';
    }
  }

  @override
  Future<String> extractTextFromBytes(List<int> imageBytes) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'bytes', 'platform': 'ios'});
    
    try {
      // Save bytes to temporary file and use file-based OCR
      final tempFile = File('${Directory.systemTemp.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      final result = await extractText(tempFile);
      
      // Clean up temp file
      await tempFile.delete();
      
      return result;
    } catch (e) {
      analytics.logScanEvent('ocr_failed', data: {
        'source': 'bytes',
        'platform': 'ios',
        'error': e.toString(),
      });
      
      // Fallback to stub if native OCR fails
      final stubService = StubOcrService(analytics);
      return await stubService.extractTextFromBytes(imageBytes);
    }
  }
}

/// Google ML Kit OCR service implementation (Android)
class GoogleMlKitOcrService implements OcrService {
  final Analytics analytics;
  
  GoogleMlKitOcrService(this.analytics);

  @override
  Future<String> extractText(File imageFile) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'file', 'platform': 'android'});
    
    try {
      // TODO: Implement native OCR bridge method
      // For now, use fallback to stub service
      analytics.logScanEvent('ocr_fallback', data: {
        'source': 'file',
        'platform': 'android',
        'reason': 'native_ocr_not_implemented',
      });
      
      // Fallback to stub service until native OCR is implemented
      final stubService = StubOcrService(analytics);
      return await stubService.extractText(imageFile);
    } catch (e) {
      analytics.logScanEvent('ocr_failed', data: {
        'source': 'file',
        'platform': 'android',
        'error': e.toString(),
      });
      
      // Final fallback
      return 'OCR service temporarily unavailable. Please try again later.';
    }
  }

  @override
  Future<String> extractTextFromBytes(List<int> imageBytes) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'bytes', 'platform': 'android'});
    
    try {
      // Save bytes to temporary file and use file-based OCR
      final tempFile = File('${Directory.systemTemp.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      final result = await extractText(tempFile);
      
      // Clean up temp file
      await tempFile.delete();
      
      return result;
    } catch (e) {
      analytics.logScanEvent('ocr_failed', data: {
        'source': 'bytes',
        'platform': 'android',
        'error': e.toString(),
      });
      
      // Fallback to stub if native OCR fails
      final stubService = StubOcrService(analytics);
      return await stubService.extractTextFromBytes(imageBytes);
    }
  }
}
