#if DEBUG
final class LLMQuickSmoke {
    func run() {
        // Resolve a known small model in app storage. Replace with your real path.
        guard let modelPath = Bundle.main.path(forResource: "Llama-3.2-3b-Instruct-Q4_K_M", ofType: "gguf") else {
            print("Smoke: missing model in bundle")
            return
        }
        let okInit = LLMBridge.shared.initialize(modelPath: modelPath, ctxTokens: 1024, nGpuLayers: 16)
        print("Smoke init:", okInit)
        guard okInit else { return }

        let okStart = LLMBridge.shared.start(prompt: "Hello, my name is")
        print("Smoke start:", okStart)
        guard okStart else { return }

        var collected = ""
        let obs = NotificationCenter.default.addObserver(forName: .llmToken, object: nil, queue: .main) { note in
            if let piece = note.object as? String {
                collected += piece
                if collected.count > 120 {
                    LLMBridge.shared.stop()
                    print("Smoke partial:", collected)
                }
            }
        }

        LLMBridge.shared.stream {
            NotificationCenter.default.removeObserver(obs)
            print("Smoke done")
        }
    }
}
#endif
