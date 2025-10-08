import Foundation

final class MiraMemoryStore {
    static let shared = MiraMemoryStore()
    private init() {}

    private var lastSession: [String: Any] = [:]

    func put(key: String, value: Any) { 
        lastSession[key] = value 
    }
    
    func get(key: String) -> Any? { 
        return lastSession[key] 
    }
    
    func clear() { 
        lastSession.removeAll() 
    }
}
