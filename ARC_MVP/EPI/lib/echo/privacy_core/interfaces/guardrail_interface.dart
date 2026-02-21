// Guardrail Interface
// Defines the contract for privacy guardrail services across all EPI modules

/// Interface for privacy guardrail services
abstract class PrivacyGuardrail {
  /// Intercepts and processes a request for privacy compliance
  /// 
  /// [system] - The system prompt to check
  /// [user] - The user input to check
  /// Returns the processed request with privacy guardrails applied
  Future<String> interceptRequest({required String system, required String user});
  
  /// Intercepts and processes a response for privacy compliance
  /// 
  /// [response] - The response to check
  /// Returns the processed response with privacy guardrails applied
  Future<String> interceptResponse(String response);
  
  /// Validates content for privacy compliance
  /// 
  /// [content] - The content to validate
  /// Returns true if the content passes privacy validation
  Future<bool> validateContent(String content);
  
  /// Logs a privacy violation
  /// 
  /// [violation] - Details of the privacy violation
  /// [context] - Additional context about the violation
  Future<void> logViolation(String violation, Map<String, dynamic> context);
}
