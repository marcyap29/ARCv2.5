// lib/arc/chat/prompt_optimization/providers/openai_adapter.dart
// OpenAI adapter for universal prompt optimization.

import 'dart:convert';
import 'dart:io';
import '../prompt_optimization_types.dart';
import 'provider_adapter.dart';

class OpenAIAdapter implements ProviderAdapter {
  OpenAIAdapter({required this.apiKey});

  final String apiKey;
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';

  @override
  String get name => 'openai';

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    final stopwatch = Stopwatch()..start();
    final model = _modelForUseCase(request.useCase);
    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': request.system},
        {'role': 'user', 'content': request.user},
      ],
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
    };

    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(_baseUrl));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $apiKey');
      req.write(jsonEncode(body));
      final response = await req.close();
      final responseBody = await response.transform(utf8.decoder).join();

      stopwatch.stop();

      if (response.statusCode != 200) {
        throw Exception('OpenAI API error: ${response.statusCode} - $responseBody');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      String content = '';
      if (choices != null && choices.isNotEmpty) {
        final msg = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
        content = msg?['content'] as String? ?? '';
      }
      final usage = data['usage'] as Map<String, dynamic>?;
      final promptTokens = (usage?['prompt_tokens'] as num?)?.toInt() ?? _estimateTokens(request.system + request.user);
      final completionTokens = (usage?['completion_tokens'] as num?)?.toInt() ?? _estimateTokens(content);

      return CompletionResponse(
        content: content,
        tokensUsed: TokenUsage(prompt: promptTokens, completion: completionTokens, total: promptTokens + completionTokens),
        cost: _cost(model, promptTokens, completionTokens),
        latencyMs: stopwatch.elapsedMilliseconds,
        model: model,
      );
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      final r = CompletionRequest(system: 'You are helpful.', user: 'Say "ok"', maxTokens: 5, useCase: PromptUseCase.gapClassification);
      await complete(r);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  double estimateCost(CompletionRequest request) {
    final pt = _estimateTokens(request.system + request.user);
    final ct = request.maxTokens;
    return _cost(_modelForUseCase(request.useCase), pt, ct);
  }

  String _modelForUseCase(PromptUseCase useCase) {
    switch (useCase) {
      case PromptUseCase.gapClassification:
      case PromptUseCase.seekingDetection:
        return 'gpt-3.5-turbo';
      default:
        return 'gpt-4o-mini';
    }
  }

  int _estimateTokens(String text) => (text.length / 4).ceil();
  double _cost(String model, int promptTokens, int completionTokens) {
    const prices = {
      'gpt-4o-mini': (0.00015, 0.0006),
      'gpt-3.5-turbo': (0.0005, 0.0015),
    };
    final p = prices[model] ?? prices['gpt-4o-mini']!;
    return (promptTokens / 1000) * p.$1 + (completionTokens / 1000) * p.$2;
  }
}
