import '../model_adapter.dart';

/// Cloud model adapter - for future implementation
class CloudAdapter implements ModelAdapter {
  @override
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) async* {
    // TODO: Implement cloud model calls
    yield 'CloudAdapter not yet implemented';
  }
}

