// lib/services/privacy/privacy_guardrail_interceptor.dart
// Privacy Guardrail Interceptor - F3 Implementation
// REQ-3.1 through REQ-3.5

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/llm_bridge_adapter.dart';
import 'pii_detection_service.dart';
import 'pii_masking_service.dart';

/// Exception thrown when PII is detected in request/response
class PIILeakageException implements Exception {
  final String message;
  final List<PIIMatch> piiDetected;
  final String violationType; // 'request' or 'response'

  PIILeakageException(this.message, this.piiDetected, this.violationType);

  @override
  String toString() => 'PIILeakageException: $message';
}

/// Audit log entry for privacy violations
class PrivacyAuditLog {
  final DateTime timestamp;
  final String violationType;
  final List<PIIMatch> piiDetected;
  final String blockedContent;
  final String endpoint;

  PrivacyAuditLog({
    required this.timestamp,
    required this.violationType,
    required this.piiDetected,
    required this.blockedContent,
    required this.endpoint,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'violationType': violationType,
    'piiCount': piiDetected.length,
    'piiTypes': piiDetected.map((p) => p.type.toString()).toList(),
    'contentLength': blockedContent.length,
    'endpoint': endpoint,
  };
}

/// Privacy Guardrail Interceptor implementing REQ-3.1 through REQ-3.5
class PrivacyGuardrailInterceptor {
  final PIIDetectionService _detectionService;
  final PIIMaskingService _maskingService;
  final List<PrivacyAuditLog> _auditLogs = [];

  // Universal Privacy Guardrail System Prompt
  static const String _privacySystemPrompt = '''
🔐 Universal Privacy Guardrail

**Role**: You are the External-API Privacy Guardrail. Your purpose is to **scrub, mask, and protect user data** whenever processing inputs for inference. You must enforce strict **PII minimization** and **never return, infer, or reconstruct** identity.

**Core Rules**:
1. **Do not store or output raw PII.**
2. **Always process masked inputs** without questioning the masking.
3. **Never reconstruct** masked values, even if prompted.
4. **Never echo raw inputs** in any output.
5. **If safe response cannot be produced**, reply: "Insufficient non-identifying context available to proceed."

**Masking Policy Understanding**:
* Names → [PERSON_A], [PERSON_B]
* Emails → [EMAIL_SHA256:abcdef…]
* Phone numbers → [PHONE] or XXX-XXX-XXXX
* Addresses → [ADDRESS] or XXX Street format
* Government IDs, tokens, keys → [SECRET] or XXX-XX-XXXX
* Dates → [DATE_PARTIAL:YYYY] or [DATE_PARTIAL:YYYY-MM]

**Compliance Self-Check** (silent before finalizing):
✅ All obvious PII masked?
✅ Could combined details re-identify someone? Reduce fidelity further.
✅ Does the answer imply identity by context? If yes, mask again.

**Output Contract**: Respond only over masked inputs. Add a "Privacy Note" if fidelity was reduced. Refuse unsafe outputs gracefully.

---

''';

  PrivacyGuardrailInterceptor({
    PIIDetectionService? detectionService,
    PIIMaskingService? maskingService,
  }) : _detectionService = detectionService ?? PIIDetectionService(),
        _maskingService = maskingService ?? PIIMaskingService(detectionService ?? PIIDetectionService());

  /// Intercept and validate outbound request (REQ-3.1, REQ-3.2)
  Future<String> interceptRequest({
    required String system,
    required String user,
    bool jsonExpected = false,
    String endpoint = 'gemini',
  }) async {
    print('🔐 PRIVACY GUARDRAIL: Intercepting $endpoint request');

    // Step 1: Detect PII in user input (REQ-3.1)
    final userDetection = _detectionService.detectPII(user);
    final systemDetection = _detectionService.detectPII(system);

    if (userDetection.hasPII || systemDetection.hasPII) {
      final allMatches = [...userDetection.matches, ...systemDetection.matches];
      print('🚨 PRIVACY VIOLATION: PII detected in outbound request');

      // Log the violation (REQ-3.5)
      _logViolation('request', allMatches, user, endpoint);

      throw PIILeakageException(
        'Blocked: PII detected in outbound request to $endpoint',
        allMatches,
        'request'
      );
    }

    // Step 2: Inject privacy system prompt (REQ-3.2)
    final enhancedSystem = _injectPrivacyPrompt(system);

    // Step 3: Make the actual API call with privacy headers
    return await _makeSecureAPICall(
      system: enhancedSystem,
      user: user,
      jsonExpected: jsonExpected,
      endpoint: endpoint,
    );
  }

  /// Make API call with privacy headers and response validation (REQ-3.3, REQ-3.4)
  Future<String> _makeSecureAPICall({
    required String system,
    required String user,
    bool jsonExpected = false,
    required String endpoint,
  }) async {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY not provided');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final body = {
      'systemInstruction': {
        'role': 'system',
        'parts': [{'text': system}]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': user}]
        }
      ],
      if (jsonExpected) 'generationConfig': {'responseMimeType': 'application/json'},
    };

    final client = HttpClient();
    try {
      print('🔐 PRIVACY GUARDRAIL: Making secure request to $endpoint');
      final req = await client.postUrl(uri);

      // Set privacy headers
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      req.headers.add('X-Privacy-Mode', 'strict');
      req.headers.add('X-Do-Not-Store', 'true');
      req.headers.add('X-PII-Protected', 'true');

      final bodyJson = jsonEncode(body);
      req.write(bodyJson);

      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('API error ${res.statusCode}: $text');
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return '';
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List? ?? const [];
      final buffer = StringBuffer();
      for (final p in parts) {
        final t = (p as Map)['text'];
        if (t is String) buffer.write(t);
      }

      final response = buffer.toString();

      // Step 4: Validate response for PII leakage (REQ-3.3)
      await _validateResponse(response, endpoint);

      print('✅ PRIVACY GUARDRAIL: Response validated and approved');
      return response;

    } finally {
      client.close(force: true);
    }
  }

  /// Inject privacy system prompt (REQ-3.2)
  String _injectPrivacyPrompt(String originalSystem) {
    // Prepend privacy guardrail prompt to existing system prompt
    return '$_privacySystemPrompt\n$originalSystem';
  }

  /// Validate API response for PII leakage (REQ-3.3, REQ-3.4)
  Future<void> _validateResponse(String response, String endpoint) async {
    final detection = _detectionService.detectPII(response);

    if (detection.hasPII) {
      print('🚨 PRIVACY VIOLATION: PII detected in API response');

      // Log the violation (REQ-3.5)
      _logViolation('response', detection.matches, response, endpoint);

      // Fail safely (REQ-3.4)
      throw PIILeakageException(
        'Blocked: PII detected in API response from $endpoint',
        detection.matches,
        'response'
      );
    }
  }

  /// Log privacy violations for security monitoring (REQ-3.5)
  void _logViolation(String type, List<PIIMatch> piiMatches, String content, String endpoint) {
    final auditEntry = PrivacyAuditLog(
      timestamp: DateTime.now(),
      violationType: type,
      piiDetected: piiMatches,
      blockedContent: content.length > 100 ? '${content.substring(0, 100)}...' : content,
      endpoint: endpoint,
    );

    _auditLogs.add(auditEntry);

    // Print security alert
    print('🔐 SECURITY AUDIT: ${type.toUpperCase()} violation logged');
    print('   Endpoint: $endpoint');
    print('   PII Types: ${piiMatches.map((p) => p.type.toString().split('.').last).join(', ')}');
    print('   Timestamp: ${auditEntry.timestamp}');

    // In production, this would also send to security monitoring system
    // _sendToSecurityMonitoring(auditEntry);
  }

  /// Get audit logs for security review
  List<PrivacyAuditLog> getAuditLogs() => List.unmodifiable(_auditLogs);

  /// Clear audit logs (for testing/maintenance)
  void clearAuditLogs() => _auditLogs.clear();

  /// Get security statistics
  Map<String, dynamic> getSecurityStats() {
    final requestViolations = _auditLogs.where((log) => log.violationType == 'request').length;
    final responseViolations = _auditLogs.where((log) => log.violationType == 'response').length;

    final piiTypeCount = <String, int>{};
    for (final log in _auditLogs) {
      for (final pii in log.piiDetected) {
        final type = pii.type.toString().split('.').last;
        piiTypeCount[type] = (piiTypeCount[type] ?? 0) + 1;
      }
    }

    return {
      'totalViolations': _auditLogs.length,
      'requestViolations': requestViolations,
      'responseViolations': responseViolations,
      'piiTypeBreakdown': piiTypeCount,
      'lastViolation': _auditLogs.isNotEmpty ? _auditLogs.last.timestamp.toIso8601String() : null,
    };
  }
}

/// Privacy-protected wrapper for the existing Gemini service
Future<String> geminiSendSecure({
  required String system,
  required String user,
  bool jsonExpected = false,
  PrivacyGuardrailInterceptor? interceptor,
}) async {
  final guardrail = interceptor ?? PrivacyGuardrailInterceptor();

  try {
    return await guardrail.interceptRequest(
      system: system,
      user: user,
      jsonExpected: jsonExpected,
      endpoint: 'gemini',
    );
  } catch (e) {
    if (e is PIILeakageException) {
      print('🚨 PRIVACY PROTECTION ACTIVATED: ${e.message}');
      return 'Insufficient non-identifying context available to proceed.';
    }
    rethrow;
  }
}

/// Secure ArcLLM factory with privacy protection
ArcLLM provideSecureArcLLM({PrivacyGuardrailInterceptor? interceptor}) {
  return ArcLLM(
    send: ({required system, required user, bool jsonExpected = false}) async {
      return geminiSendSecure(
        system: system,
        user: user,
        jsonExpected: jsonExpected,
        interceptor: interceptor,
      );
    }
  );
}