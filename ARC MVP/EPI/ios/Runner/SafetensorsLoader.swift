import Foundation
import MLX
import os.log

/// Safetensors format parser for MLX models
/// Reference: https://github.com/huggingface/safetensors
class SafetensorsLoader {
    
    private let logger = Logger(subsystem: "EPI", category: "SafetensorsLoader")
    
    /// Load safetensors file and convert to MLXArrays
    static func load(from url: URL) throws -> [String: MLXArray] {
        let loader = SafetensorsLoader()
        return try loader.loadSafetensors(from: url)
    }
    
    private func loadSafetensors(from url: URL) throws -> [String: MLXArray] {
        logger.info("Loading safetensors from: \(url.path)")
        
        let data = try Data(contentsOf: url)
        logger.info("Safetensors file size: \(data.count) bytes")
        
        // Parse header (first 8 bytes contain header length)
        let headerLength = data.prefix(8).withUnsafeBytes { bytes in
            bytes.load(as: UInt64.self)
        }
        
        logger.info("Header length: \(headerLength) bytes")
        
        // Extract header JSON
        let headerData = data.subdata(in: 8..<Int(8 + headerLength))
        guard let headerJson = try JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
            throw NSError(domain: "SafetensorsLoader", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse safetensors header JSON"
            ])
        }
        
        logger.info("Found \(headerJson.count) tensors in safetensors file")
        
        // Calculate data offset (after header)
        let dataOffset = 8 + Int(headerLength)
        
        var tensors: [String: MLXArray] = [:]
        
        // Parse each tensor
        for (name, tensorInfo) in headerJson {
            guard let info = tensorInfo as? [String: Any],
                  let dtype = info["dtype"] as? String,
                  let shape = info["shape"] as? [Int],
                  let dataOffsets = info["data_offsets"] as? [Int],
                  dataOffsets.count == 2 else {
                logger.warning("Skipping malformed tensor: \(name)")
                continue
            }
            
            let startOffset = dataOffsets[0] + dataOffset
            let endOffset = dataOffsets[1] + dataOffset
            
            // Extract tensor data
            let tensorData = data.subdata(in: startOffset..<endOffset)
            
            // Convert to MLXArray based on dtype
            let mlxArray = try convertToMLXArray(data: tensorData, dtype: dtype, shape: shape)
            tensors[name] = mlxArray
            
            logger.debug("Loaded tensor '\(name)': \(shape) (\(dtype))")
        }
        
        logger.info("Successfully loaded \(tensors.count) tensors")
        return tensors
    }
    
    private func convertToMLXArray(data: Data, dtype: String, shape: [Int]) throws -> MLXArray {
        let elementCount = shape.reduce(1, *)
        let expectedSize = elementCount * getElementSize(for: dtype)
        
        guard data.count == expectedSize else {
            throw NSError(domain: "SafetensorsLoader", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Tensor data size mismatch. Expected: \(expectedSize), Got: \(data.count)"
            ])
        }
        
        switch dtype {
        case "F32":
            return try convertFloat32(data: data, shape: shape)
        case "F16":
            return try convertFloat16(data: data, shape: shape)
        case "BF16":
            return try convertBFloat16(data: data, shape: shape)
        case "I32":
            return try convertInt32(data: data, shape: shape)
        case "I16":
            return try convertInt16(data: data, shape: shape)
        case "I8":
            return try convertInt8(data: data, shape: shape)
        default:
            throw NSError(domain: "SafetensorsLoader", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported dtype: \(dtype)"
            ])
        }
    }
    
    private func getElementSize(for dtype: String) -> Int {
        switch dtype {
        case "F32": return 4
        case "F16": return 2
        case "BF16": return 2
        case "I32": return 4
        case "I16": return 2
        case "I8": return 1
        default: return 4
        }
    }
    
    private func convertFloat32(data: Data, shape: [Int]) throws -> MLXArray {
        let floatArray = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float32.self))
        }
        return MLXArray(floatArray, shape)
    }
    
    private func convertFloat16(data: Data, shape: [Int]) throws -> MLXArray {
        // Convert F16 to F32 for MLX compatibility
        let float16Array = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: UInt16.self))
        }
        
        // Convert F16 to F32
        let float32Array = float16Array.map { half in
            // Simple F16 to F32 conversion (simplified)
            let sign: Float = (half & 0x8000) != 0 ? -1.0 : 1.0
            let exponent = (half & 0x7C00) >> 10
            let mantissa = half & 0x03FF
            
            if exponent == 0 {
                return sign * Float(mantissa) / 1024.0
            } else if exponent == 31 {
                return sign * (mantissa == 0 ? Float.infinity : Float.nan)
            } else {
                let bias: Float = 15.0
                let exp = Float(exponent) - bias
                let frac = 1.0 + Float(mantissa) / 1024.0
                return sign * frac * powf(2.0, exp)
            }
        }
        
        return MLXArray(float32Array, shape)
    }
    
    private func convertBFloat16(data: Data, shape: [Int]) throws -> MLXArray {
        // Convert BF16 to F32
        let bfloat16Array = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: UInt16.self))
        }
        
        let float32Array = bfloat16Array.map { bf16 in
            // BF16 to F32: just pad with zeros
            return Float(bitPattern: UInt32(bf16) << 16)
        }
        
        return MLXArray(float32Array, shape)
    }
    
    private func convertInt32(data: Data, shape: [Int]) throws -> MLXArray {
        let intArray = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int32.self))
        }
        return MLXArray(intArray.map { Float($0) }, shape)
    }
    
    private func convertInt16(data: Data, shape: [Int]) throws -> MLXArray {
        let intArray = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int16.self))
        }
        return MLXArray(intArray.map { Float($0) }, shape)
    }
    
    private func convertInt8(data: Data, shape: [Int]) throws -> MLXArray {
        let intArray = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int8.self))
        }
        return MLXArray(intArray.map { Float($0) }, shape)
    }
}
