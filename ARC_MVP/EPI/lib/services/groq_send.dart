// lib/services/groq_send.dart
// Groq API via Firebase proxy - API key never touches the client
//
// Primary path: direct HTTP POST to proxyGroq (dart:io HttpClient).
// This bypasses the Firebase SDK's httpsCallable / GTMSessionFetcher which
// causes "already running" errors on iOS when the connection pool is stale.
// Mirrors the architecture that worked for Gemini (geminiSend had a direct
// HttpClient path as fallback).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Cloud Function URL — same region/project the SDK resolves to.
const _proxyGroqUrl = 'https://us-central1-arc-epi.cloudfunctions.net/proxyGroq';

/// Calls Groq (GPT-OSS 120B / 20B / Llama 3.3 70B) via Firebase Cloud Function.
///
/// Uses a **direct HTTP POST** (dart:io [HttpClient]) instead of the Firebase
/// SDK's `httpsCallable`, which on iOS goes through GTMSessionFetcher and is
/// prone to "already running" errors when the TCP connection pool is stale.
///
/// The Firebase Auth ID token is attached manually so `proxyGroq` still sees
/// `request.auth` exactly as it would with `httpsCallable`.
Future<String> groqSend({
  required String user,
  String? system,
  String model = 'openai/gpt-oss-120b',
  double temperature = 0.7,
  int? maxTokens,
  String? entryId,
  String? chatId,
}) async {
  final requestData = <String, dynamic>{
    'user': user,
    if (system != null && system.isNotEmpty) 'system': system,
    if (model != 'openai/gpt-oss-120b') 'model': model,
    if (temperature != 0.7) 'temperature': temperature,
    if (maxTokens != null) 'maxTokens': maxTokens,
    if (entryId != null) 'entryId': entryId,
    if (chatId != null) 'chatId': chatId,
  };

  // ── Get Firebase Auth ID token ──────────────────────────────────────
  final firebaseUser = FirebaseAuthService.instance.currentUser;
  if (firebaseUser == null) {
    throw Exception('Not authenticated. Sign in to use LUMARA.');
  }
  final idToken = await firebaseUser.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw Exception('Could not obtain auth token. Try signing out and back in.');
  }

  // ── Direct HTTP POST to proxyGroq ───────────────────────────────────
  // Callable protocol: body = { "data": <payload> }
  //                    response = { "result": <return-value> }
  const maxAttempts = 3;
  const retryDelays = [Duration(seconds: 3), Duration(seconds: 5)];

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    final client = HttpClient();
    try {
      final uri = Uri.parse(_proxyGroqUrl);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.write(jsonEncode({'data': requestData}));

      final httpResponse = await request.close().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw const SocketException('proxyGroq request timed out after 90s');
        },
      );

      final body = await httpResponse.transform(utf8.decoder).join();

      if (httpResponse.statusCode != 200) {
        // Parse Firebase callable error format if possible
        String errorMsg = 'proxyGroq HTTP ${httpResponse.statusCode}';
        try {
          final errData = jsonDecode(body) as Map<String, dynamic>;
          final errObj = errData['error'] as Map<String, dynamic>?;
          errorMsg = errObj?['message'] as String? ?? errorMsg;
          final status = errObj?['status'] as String? ?? '';

          // Non-retryable errors — surface immediately
          if (status == 'UNAUTHENTICATED' ||
              status == 'PERMISSION_DENIED' ||
              status == 'RESOURCE_EXHAUSTED' ||
              status == 'INVALID_ARGUMENT' ||
              errorMsg.contains('ANONYMOUS_TRIAL_EXPIRED') ||
              errorMsg.contains('free trial') ||
              errorMsg.contains('Invalid API Key') ||
              errorMsg.contains('invalid_api_key') ||
              errorMsg.contains('API key not configured')) {
            throw Exception(errorMsg);
          }
        } catch (e) {
          if (e is Exception &&
              (e.toString().contains('ANONYMOUS_TRIAL') ||
               e.toString().contains('Invalid API Key') ||
               e.toString().contains('invalid_api_key') ||
               e.toString().contains('API key not configured') ||
               e.toString().contains('RESOURCE_EXHAUSTED'))) {
            rethrow;
          }
          // Couldn't parse — use raw message
        }

        // Retryable server error
        if (attempt < maxAttempts) {
          final delay = retryDelays[attempt - 1];
          if (kDebugMode) {
            print('groqSend: HTTP ${httpResponse.statusCode} on attempt $attempt/$maxAttempts, '
                'waiting ${delay.inSeconds}s… ($errorMsg)');
          }
          await Future<void>.delayed(delay);
          continue;
        }
        throw Exception(errorMsg);
      }

      // ── Parse success response ──────────────────────────────────────
      final data = jsonDecode(body) as Map<String, dynamic>;
      // Callable protocol wraps in "result"; direct invocation may not
      final result = (data['result'] as Map<String, dynamic>?) ?? data;
      final response = result['response'] as String?;
      if (response == null) {
        throw Exception('proxyGroq returned no response');
      }
      return response;
    } on SocketException catch (e) {
      if (attempt < maxAttempts) {
        final delay = retryDelays[attempt - 1];
        if (kDebugMode) {
          print('groqSend: Network error on attempt $attempt/$maxAttempts, '
              'waiting ${delay.inSeconds}s… ($e)');
        }
        await Future<void>.delayed(delay);
        continue;
      }
      throw Exception(
        'Network error reaching LUMARA. Check your connection and try again.',
      );
    } catch (e) {
      final errStr = e.toString();
      final isRetryable = errStr.contains('INTERNAL') ||
          errStr.contains('already running') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Connection reset');

      if (isRetryable && attempt < maxAttempts) {
        final delay = retryDelays[attempt - 1];
        if (kDebugMode) {
          print('groqSend: Retryable error on attempt $attempt/$maxAttempts, '
              'waiting ${delay.inSeconds}s…');
        }
        await Future<void>.delayed(delay);
        continue;
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  throw StateError('groqSend: unreachable');
}
