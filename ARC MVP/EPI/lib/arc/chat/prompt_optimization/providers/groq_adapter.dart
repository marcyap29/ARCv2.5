// lib/arc/chat/prompt_optimization/providers/groq_adapter.dart
// Groq adapter for universal prompt optimization.

import '../prompt_optimization_types.dart';
import 'provider_adapter.dart';
import '../../services/groq_service.dart';

class GroqAdapter implements ProviderAdapter {
  GroqAdapter({required String apiKey}) : _service = GroqService(apiKey: apiKey);

  final GroqService _service;

  @override
  String get name => 'groq';

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    final stopwatch = Stopwatch()..start();
    final model = _modelForUseCase(request.useCase);
    final content = await _service.generateContent(
      prompt: request.user,
      systemPrompt: request.system.isNotEmpty ? request.system : null,
      model: model,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      fallbackToMixtral: true,
    );
    stopwatch.stop();
    final promptTokens = _estimateTokens(request.system + request.user);
    final completionTokens = _estimateTokens(content);
    return CompletionResponse(
      content: content,
      tokensUsed: TokenUsage(
        prompt: promptTokens,
        completion: completionTokens,
        total: promptTokens + completionTokens,
      ),
      cost: _cost(promptTokens + completionTokens),
      latencyMs: stopwatch.elapsedMilliseconds,
      model: model.id,
    );
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _service.generateContent(
        prompt: 'test',
        maxTokens: 5,
        fallbackToMixtral: false,
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  double estimateCost(CompletionRequest request) {
    final tokens = _estimateTokens(request.system + request.user) + request.maxTokens;
    return _cost(tokens);
  }

  GroqModel _modelForUseCase(PromptUseCase useCase) {
    switch (useCase) {
      case PromptUseCase.gapClassification:
      case PromptUseCase.seekingDetection:
        return GroqModel.mixtral_8x7b; // faster for simple tasks
      default:
        return GroqModel.llama33_70b;
    }
  }

  int _estimateTokens(String text) => (text.length / 4).ceil();
  double _cost(int totalTokens) => (totalTokens / 1000) * 0.0005;
}
