// lib/services/groq_send.dart
// Groq API via Firebase proxy - API key never touches the client

import 'package:my_app/services/firebase_service.dart';

/// Calls Groq (Llama 3.3 70B / Mixtral) via Firebase Cloud Function.
/// Requires the user to be authenticated; GROQ_API_KEY is stored in Firebase Secret Manager.
///
/// [entryId] and [chatId] can be passed for future per-entry/per-chat rate limiting.
Future<String> groqSend({
  required String user,
  String? system,
  String model = 'llama-3.3-70b-versatile',
  double temperature = 0.7,
  int? maxTokens,
  String? entryId,
  String? chatId,
}) async {
  final ready = await FirebaseService.instance.ensureReady();
  if (!ready) {
    throw Exception(
      'Firebase is not available. Check your network and that the app is configured correctly.',
    );
  }
  final functions = FirebaseService.instance.getFunctions();
  final callable = functions.httpsCallable('proxyGroq');

  final requestData = <String, dynamic>{
    'user': user,
    if (system != null && system.isNotEmpty) 'system': system,
    if (model != 'llama-3.3-70b-versatile') 'model': model,
    if (temperature != 0.7) 'temperature': temperature,
    if (maxTokens != null) 'maxTokens': maxTokens,
    if (entryId != null) 'entryId': entryId,
    if (chatId != null) 'chatId': chatId,
  };

  const timeout = Duration(seconds: 90);
  final result = await callable.call(requestData).timeout(timeout, onTimeout: () {
    throw Exception(
      'LUMARA request timed out after ${timeout.inSeconds}s. Check your connection or try again.',
    );
  });
  final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();

  final response = data['response'] as String?;
  if (response == null) {
    throw Exception('proxyGroq returned no response');
  }
  return response;
}
