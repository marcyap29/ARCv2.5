#if DEBUG
final class LLMQuickSmoke {
    func run() {
        guard let modelPath = ModelDownloadService.shared.resolvedModelPath() else {
            print("Smoke: model not found")
            return
        }
        let okInit = LLMBridge.shared.initialize(modelPath: modelPath, ctxTokens: 1024, nGpuLayers: 99) // 99 = all layers on GPU
        print("Smoke init:", okInit); guard okInit else { return }

        let okStart = LLMBridge.shared.start(prompt: "Hello, my name is")
        print("Smoke start:", okStart); guard okStart else { return }

        var collected = ""
        let obs = NotificationCenter.default.addObserver(forName: .llmToken, object: nil, queue: .main) { note in
            if let piece = note.object as? String {
                collected += piece
                if collected.count > 100 {
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
