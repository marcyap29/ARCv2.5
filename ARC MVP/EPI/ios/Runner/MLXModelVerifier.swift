import Foundation

enum MLXModelCheck {
    case success(URL)
    case missing([String])
}

struct MLXModelVerifier {
    // Minimal set for MLX-style checkpoints; adjust if your loader expects more.
    static let requiredNames: [String] = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        // Accept either a single safetensors file or sharded files
        // We'll check presence of *either* "model.safetensors" OR any "model-*.safetensors"
    ]

    static func check(folder: URL) -> MLXModelCheck {
        var missing: [String] = []

        // Base required files
        for name in requiredNames {
            let path = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: path.path) {
                missing.append(name)
            }
        }

        // Safetensors: single or shards
        let single = folder.appendingPathComponent("model.safetensors")
        var hasModel = FileManager.default.fileExists(atPath: single.path)
        if !hasModel {
            if let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent.hasSuffix(".safetensors") {
                        hasModel = true; break
                    }
                }
            }
        }
        if !hasModel { missing.append("model.safetensors (single or shards)") }

        return missing.isEmpty ? .success(folder) : .missing(missing)
    }
}
