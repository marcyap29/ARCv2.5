// lib/services/ollama_send.dart
// Ollama Cloud API via Firebase proxy (3rd fallback: Gemini → Groq → Ollama).
// See https://docs.ollama.com/cloud

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/lumara_usage_calendar.dart';

const _proxyOllamaUrl = 'https://us-central1-arc-epi.cloudfunctions.net/proxyOllama';

/// Calls Ollama Cloud (ollama.com) via Firebase Cloud Function.
/// Uses the same callable protocol as proxyGroq: body = { "data": payload }, response = { "result": { "response": text } }.
Future<String> ollamaSend({
  required String user,
  String? system,
  double temperature = 0.7,
  int? maxTokens,
}) async {
  final requestData = <String, dynamic>{
    'user': user,
    'localCalendarDate': lumaraLocalCalendarDate(),
    if (system != null && system.isNotEmpty) 'system': system,
    if (temperature != 0.7) 'temperature': temperature,
    if (maxTokens != null) 'maxTokens': maxTokens,
  };

  final firebaseUser = FirebaseAuthService.instance.currentUser;
  if (firebaseUser == null) {
    throw Exception('Not authenticated. Sign in to use LUMARA.');
  }
  final idToken = await firebaseUser.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw Exception('Could not obtain auth token. Try signing out and back in.');
  }

  const maxAttempts = 2;
  Object? lastError;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    final client = HttpClient();
    try {
      final uri = Uri.parse(_proxyOllamaUrl);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.write(jsonEncode({'data': requestData}));

      final httpResponse = await request.close().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw const SocketException('proxyOllama request timed out after 90s');
        },
      );

      final body = await httpResponse.transform(utf8.decoder).join();

      if (httpResponse.statusCode != 200) {
        String errorMsg = 'proxyOllama HTTP ${httpResponse.statusCode}';
        try {
          final errData = jsonDecode(body) as Map<String, dynamic>;
          final errObj = errData['error'] as Map<String, dynamic>?;
          errorMsg = errObj?['message'] as String? ?? errorMsg;
        } catch (_) {}
        lastError = Exception(errorMsg);
        if (kDebugMode) print('ollamaSend: attempt $attempt failed: $errorMsg');
        continue;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final result = (data['result'] as Map<String, dynamic>?) ?? data;
      final response = result['response'] as String?;
      if (response != null && response.isNotEmpty) {
        return response;
      }
      lastError = Exception('proxyOllama returned no response');
    } on SocketException catch (e) {
      lastError = e;
      if (kDebugMode) print('ollamaSend: attempt $attempt network error: $e');
    } catch (e) {
      lastError = e;
      if (kDebugMode) print('ollamaSend: attempt $attempt error: $e');
    } finally {
      client.close();
    }
  }

  throw lastError is Exception
      ? lastError
      : Exception(lastError != null ? 'Ollama failed: $lastError' : 'Ollama failed');
}
