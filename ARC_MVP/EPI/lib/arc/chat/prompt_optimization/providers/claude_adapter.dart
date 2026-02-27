// lib/arc/chat/prompt_optimization/providers/claude_adapter.dart
// Anthropic Claude adapter for universal prompt optimization.

import 'dart:convert';
import 'dart:io';
import '../prompt_optimization_types.dart';
import 'provider_adapter.dart';

class ClaudeAdapter implements ProviderAdapter {
  ClaudeAdapter({required this.apiKey});

  final String apiKey;
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';

  @override
  String get name => 'claude';

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    final stopwatch = Stopwatch()..start();
    final model = _modelForUseCase(request.useCase);
    final body = {
      'model': model,
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
      'system': request.system,
      'messages': [
        {'role': 'user', 'content': request.user},
      ],
    };

    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(_baseUrl));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('x-api-key', apiKey);
      req.headers.set('anthropic-version', '2023-06-01');
      req.write(jsonEncode(body));
      final response = await req.close();
      final responseBody = await response.transform(utf8.decoder).join();

      stopwatch.stop();

      if (response.statusCode != 200) {
        throw Exception('Anthropic API error: ${response.statusCode} - $responseBody');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final contentList = data['content'] as List?;
      final content = (contentList?.isNotEmpty == true && contentList!.first is Map)
          ? (contentList.first as Map<String, dynamic>)['text'] as String? ?? ''
          : '';
      final usage = data['usage'] as Map<String, dynamic>?;
      final inputTokens = (usage?['input_tokens'] as num?)?.toInt() ?? _estimateTokens(request.system + request.user);
      final outputTokens = (usage?['output_tokens'] as num?)?.toInt() ?? _estimateTokens(content);

      return CompletionResponse(
        content: content,
        tokensUsed: TokenUsage(prompt: inputTokens, completion: outputTokens, total: inputTokens + outputTokens),
        cost: _cost(model, inputTokens, outputTokens),
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
      const r = CompletionRequest(system: 'You are helpful.', user: 'Say "ok"', maxTokens: 5, useCase: PromptUseCase.gapClassification);
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
        return 'claude-3-haiku-20240307';
      default:
        return 'claude-3-5-sonnet-20241022';
    }
  }

  int _estimateTokens(String text) => (text.length / 4).ceil();
  double _cost(String model, int inputTokens, int outputTokens) {
    const prices = {
      'claude-3-5-sonnet-20241022': (0.003, 0.015),
      'claude-3-haiku-20240307': (0.00025, 0.00125),
    };
    final p = prices[model] ?? prices['claude-3-5-sonnet-20241022']!;
    return (inputTokens / 1000) * p.$1 + (outputTokens / 1000) * p.$2;
  }
}
