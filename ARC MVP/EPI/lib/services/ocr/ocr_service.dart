import 'dart:io';
import '../../telemetry/analytics.dart';

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
    
    // TODO: Implement Apple Vision framework integration
    // This would use the native iOS Vision framework for OCR
    
    // For now, fall back to stub implementation
    final stubService = StubOcrService(analytics);
    return await stubService.extractText(imageFile);
  }

  @override
  Future<String> extractTextFromBytes(List<int> imageBytes) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'bytes', 'platform': 'ios'});
    
    // TODO: Implement Apple Vision framework integration
    
    // For now, fall back to stub implementation
    final stubService = StubOcrService(analytics);
    return await stubService.extractTextFromBytes(imageBytes);
  }
}

/// Google ML Kit OCR service implementation (Android)
class GoogleMlKitOcrService implements OcrService {
  final Analytics analytics;
  
  GoogleMlKitOcrService(this.analytics);

  @override
  Future<String> extractText(File imageFile) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'file', 'platform': 'android'});
    
    // TODO: Implement Google ML Kit integration
    // This would use the ML Kit Text Recognition API
    
    // For now, fall back to stub implementation
    final stubService = StubOcrService(analytics);
    return await stubService.extractText(imageFile);
  }

  @override
  Future<String> extractTextFromBytes(List<int> imageBytes) async {
    analytics.logScanEvent('ocr_started', data: {'source': 'bytes', 'platform': 'android'});
    
    // TODO: Implement Google ML Kit integration
    
    // For now, fall back to stub implementation
    final stubService = StubOcrService(analytics);
    return await stubService.extractTextFromBytes(imageBytes);
  }
}
