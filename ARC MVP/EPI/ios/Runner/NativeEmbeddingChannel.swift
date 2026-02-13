import Flutter
import NaturalLanguage

/// Handles on-device text embeddings via Apple Natural Language framework.
/// Uses NLEmbedding.sentenceEmbedding (512-dim) so embeddings work on physical iOS devices
/// without TensorFlow Lite.
final class NativeEmbeddingChannel {
  static let channelName = "com.epi.arcmvp/embedding"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      handle(call: call, result: result)
    }
  }

  private static func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(isEmbeddingAvailable())
    case "embed":
      guard let text = call.arguments as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected string argument", details: nil))
        return
      }
      embed(text: text, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func isEmbeddingAvailable() -> Bool {
    return NLEmbedding.sentenceEmbedding(for: .english) != nil
  }

  private static func embed(text: String, result: @escaping FlutterResult) {
    guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
      result(FlutterError(code: "UNAVAILABLE", message: "Sentence embedding not available", details: nil))
      return
    }
    guard let raw = embedding.vector(for: text) else {
      result(FlutterError(code: "EMBED_FAILED", message: "Could not compute embedding for text", details: nil))
      return
    }
    // Normalize to unit length (match TFLite USE behavior for cosine similarity)
    let magnitude = sqrt(raw.reduce(0) { $0 + $1 * $1 })
    let normalized: [Double]
    if magnitude > 0 {
      normalized = raw.map { $0 / magnitude }
    } else {
      normalized = raw
    }
    result(normalized)
  }
}
