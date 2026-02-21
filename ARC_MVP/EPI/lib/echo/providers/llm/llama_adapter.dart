import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import '../../../../core/llm/model_adapter.dart';

/// Llama.cpp adapter for on-device inference
class LlamaAdapter implements ModelAdapter {
  static bool _isInitialized = false;
  static String? _modelPath;
  static Process? _llamaProcess;
  static StreamController<String>? _responseController;

  /// Initialize the Llama.cpp adapter
  static Future<bool> initialize({
    String? modelPath,
    int contextSize = 2048,
    int threads = 4,
  }) async {
    try {
      _modelPath = modelPath ?? 'models/llama-3.2-3b-instruct.gguf';
      
      // Check if model file exists
      final modelFile = File(_modelPath!);
      if (!await modelFile.exists()) {
        print('LlamaAdapter: Model file not found at $_modelPath');
        return false;
      }

      // Initialize response controller
      _responseController = StreamController<String>.broadcast();
      
      _isInitialized = true;
      print('LlamaAdapter: Initialized with model at $_modelPath');
      return true;
    } catch (e) {
      print('LlamaAdapter: Failed to initialize - $e');
      return false;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _llamaProcess?.kill();
    await _responseController?.close();
    _isInitialized = false;
  }

  @override
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) async* {
    if (!_isInitialized) {
      yield 'LlamaAdapter not initialized';
      return;
    }

    try {
      // Build prompt for the specific task
      final prompt = _buildPrompt(task, facts, snippets, chat);
      
      // For now, return a placeholder response
      // In real implementation, this would call llama.cpp via method channel or process
      final response = await _generateResponse(prompt);
      
      // Stream the response word by word
      final words = response.split(' ');
      for (int i = 0; i < words.length; i++) {
        yield words[i] + (i < words.length - 1 ? ' ' : '');
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      yield 'Error generating response: $e';
    }
  }

  /// Build prompt for the specific task
  String _buildPrompt(String task, Map<String, dynamic> facts, List<String> snippets, List<Map<String, String>> chat) {
    final buffer = StringBuffer();
    
    // System prompt
    buffer.writeln('<|begin_of_text|><|start_header_id|>system<|end_header_id|>');
    buffer.writeln('You are LUMARA, a supportive AI companion for personal reflection and growth.');
    buffer.writeln('You help users understand their patterns, emotions, and life phases.');
    buffer.writeln('Be empathetic, insightful, and encouraging in your responses.');
    buffer.writeln('<|eot_id|>');
    
    // User prompt based on task
    buffer.writeln('<|start_header_id|>user<|end_header_id|>');
    
    switch (task) {
      case 'chat':
        _buildChatPrompt(buffer, facts, snippets, chat);
        break;
      case 'weekly_summary':
        _buildWeeklySummaryPrompt(buffer, facts, snippets);
        break;
      case 'rising_patterns':
        _buildRisingPatternsPrompt(buffer, facts, snippets);
        break;
      case 'phase_rationale':
        _buildPhaseRationalePrompt(buffer, facts, snippets);
        break;
      case 'prompt_suggestion':
        _buildPromptSuggestionPrompt(buffer, facts, snippets);
        break;
      default:
        _buildDefaultPrompt(buffer, facts, snippets);
    }
    
    buffer.writeln('<|eot_id|>');
    buffer.writeln('<|start_header_id|>assistant<|end_header_id|>');
    
    return buffer.toString();
  }

  /// Build chat prompt
  void _buildChatPrompt(StringBuffer buffer, Map<String, dynamic> facts, List<String> snippets, List<Map<String, String>> chat) {
    buffer.writeln('I\'m here to help you reflect on your thoughts and experiences.');
    
    if (chat.isNotEmpty) {
      buffer.writeln('Here\'s our conversation so far:');
      for (final message in chat.take(5)) {
        final role = message['role'] == 'user' ? 'You' : 'LUMARA';
        buffer.writeln('$role: ${message['content']}');
      }
    }
    
    if (facts.isNotEmpty) {
      buffer.writeln('Some context about your recent entries:');
      _formatFacts(buffer, facts);
    }
    
    if (snippets.isNotEmpty) {
      buffer.writeln('Here are some relevant quotes from your journal:');
      for (final snippet in snippets.take(3)) {
        buffer.writeln('"$snippet"');
      }
    }
    
    buffer.writeln('How can I help you today?');
  }

  /// Build weekly summary prompt
  void _buildWeeklySummaryPrompt(StringBuffer buffer, Map<String, dynamic> facts, List<String> snippets) {
    buffer.writeln('Please provide a supportive weekly summary based on this data:');
    _formatFacts(buffer, facts);
    
    if (snippets.isNotEmpty) {
      buffer.writeln('Key quotes from the week:');
      for (final snippet in snippets.take(5)) {
        buffer.writeln('"$snippet"');
      }
    }
  }

  /// Build rising patterns prompt
  void _buildRisingPatternsPrompt(StringBuffer buffer, Map<String, dynamic> facts, List<String> snippets) {
    buffer.writeln('Analyze these rising patterns in the user\'s data:');
    _formatFacts(buffer, facts);
    
    if (snippets.isNotEmpty) {
      buffer.writeln('Supporting evidence:');
      for (final snippet in snippets.take(5)) {
        buffer.writeln('"$snippet"');
      }
    }
  }

  /// Build phase rationale prompt
  void _buildPhaseRationalePrompt(StringBuffer buffer, Map<String, dynamic> facts, List<String> snippets) {
    buffer.writeln('Explain why the user is in their current life phase:');
    _formatFacts(buffer, facts);
    
    if (snippets.isNotEmpty) {
      buffer.writeln('Evidence from their entries:');
      for (final snippet in snippets.take(5)) {
        buffer.writeln('"$snippet"');
      }
    }
  }

  /// Build prompt suggestion prompt
  void _buildPromptSuggestionPrompt(StringBuffer buffer, Map<String, dynamic> facts, List<String> snippets) {
    buffer.writeln('Suggest helpful prompts for the user based on their current state:');
    _formatFacts(buffer, facts);
    
    if (snippets.isNotEmpty) {
      buffer.writeln('Recent themes:');
      for (final snippet in snippets.take(3)) {
        buffer.writeln('"$snippet"');
      }
    }
  }

  /// Build default prompt
  void _buildDefaultPrompt(StringBuffer buffer, Map<String, dynamic> facts, List<String> snippets) {
    buffer.writeln('Please provide helpful insights based on this data:');
    _formatFacts(buffer, facts);
    
    if (snippets.isNotEmpty) {
      buffer.writeln('Relevant quotes:');
      for (final snippet in snippets.take(3)) {
        buffer.writeln('"$snippet"');
      }
    }
  }

  /// Format facts for the prompt
  void _formatFacts(StringBuffer buffer, Map<String, dynamic> facts) {
    facts.forEach((key, value) {
      if (value is List) {
        buffer.writeln('$key: ${value.join(', ')}');
      } else {
        buffer.writeln('$key: $value');
      }
    });
  }

  /// Generate response using llama.cpp
  Future<String> _generateResponse(String prompt) async {
    // This is a placeholder implementation
    // In real implementation, this would:
    // 1. Start llama.cpp process with the model
    // 2. Send the prompt via stdin
    // 3. Read response from stdout
    // 4. Parse and return the response
    
    // For now, return a mock response
    return _generateMockResponse(prompt);
  }

  /// Generate mock response for testing
  String _generateMockResponse(String prompt) {
    if (prompt.contains('weekly summary')) {
      return 'Based on your recent entries, I can see you\'ve been reflecting deeply on your personal growth. '
             'Your journal shows a pattern of thoughtful self-examination and emerging insights. '
             'The themes of resilience and self-discovery are particularly strong this week. '
             'Keep up this meaningful work - you\'re making real progress in understanding yourself better.';
    } else if (prompt.contains('rising patterns')) {
      return 'I notice several interesting patterns emerging in your recent entries:\n\n'
             '• **Self-reflection**: You\'re developing deeper insights into your own thoughts and behaviors\n'
             '• **Growth mindset**: There\'s a clear focus on learning and personal development\n'
             '• **Emotional awareness**: You\'re becoming more attuned to your feelings and their sources\n\n'
             'These patterns suggest you\'re in a phase of significant personal growth and self-discovery.';
    } else if (prompt.contains('phase rationale')) {
      return 'You\'re currently in the **Discovery** phase of your journey. '
             'This phase is characterized by exploring new ideas, questioning assumptions, and seeking deeper understanding. '
             'Your recent entries show strong alignment with this developmental stage - you\'re asking important questions '
             'about yourself and your path forward. This is a natural and healthy part of personal growth.';
    } else {
      return 'I\'ve analyzed your data and found some meaningful insights. '
             'Your recent entries show thoughtful reflection and genuine growth. '
             'The patterns I see suggest you\'re developing greater self-awareness and emotional intelligence. '
             'Keep exploring these themes - they\'re leading you toward deeper understanding and personal fulfillment.';
    }
  }
}
