import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'model_adapter.dart';

/// Ollama adapter for local model inference
class OllamaAdapter implements ModelAdapter {
  static const String _defaultHost = 'http://localhost:11434';
  static String _host = _defaultHost;
  static String _model = 'llama3.2:3b';
  static bool _isInitialized = false;

  /// Initialize the Ollama adapter
  static Future<bool> initialize({
    String? host,
    String? model,
  }) async {
    try {
      _host = host ?? _defaultHost;
      _model = model ?? 'llama3.2:3b';
      
      // Test connection to Ollama
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$_host/api/tags'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        _isInitialized = true;
        print('OllamaAdapter: Connected to Ollama at $_host with model $_model');
        return true;
      } else {
        print('OllamaAdapter: Failed to connect to Ollama - Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('OllamaAdapter: Failed to initialize - $e');
      return false;
    }
  }

  @override
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) async* {
    if (!_isInitialized) {
      yield 'OllamaAdapter not initialized';
      return;
    }

    try {
      // Build prompt for the specific task
      final prompt = _buildPrompt(task, facts, snippets, chat);
      
      // Call Ollama API
      final response = await _callOllama(prompt);
      
      // Stream the response word by word
      final words = response.split(' ');
      for (int i = 0; i < words.length; i++) {
        yield words[i] + (i < words.length - 1 ? ' ' : '');
        await Future.delayed(const Duration(milliseconds: 30));
      }
    } catch (e) {
      yield 'Error generating response: $e';
    }
  }

  /// Call Ollama API
  Future<String> _callOllama(String prompt) async {
    final client = HttpClient();
    
    try {
      final request = await client.postUrl(Uri.parse('$_host/api/generate'));
      request.headers.set('Content-Type', 'application/json');
      
      final requestBody = {
        'model': _model,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': 0.7,
          'top_p': 0.9,
          'max_tokens': 500,
        }
      };
      
      request.write(jsonEncode(requestBody));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonResponse = jsonDecode(responseBody);
        return jsonResponse['response'] as String? ?? 'No response generated';
      } else {
        throw Exception('Ollama API error: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Build prompt for the specific task
  String _buildPrompt(String task, Map<String, dynamic> facts, List<String> snippets, List<Map<String, String>> chat) {
    final buffer = StringBuffer();
    
    // System prompt
    buffer.writeln('You are LUMARA, a supportive AI companion for personal reflection and growth.');
    buffer.writeln('You help users understand their patterns, emotions, and life phases.');
    buffer.writeln('Be empathetic, insightful, and encouraging in your responses.');
    buffer.writeln();
    
    // Task-specific prompt
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
}
