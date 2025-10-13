import Foundation
import Vision
import UIKit

@objc class VisionApi: NSObject, VisionApiProtocol {
    
    // MARK: - Text Recognition
    func extractText(imagePath: String) throws -> VisionOcrResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw VisionPigeonError(code: "IMAGE_LOAD_ERROR", message: "Failed to load image", details: nil)
        }
        
        var result: VisionOcrResult?
        var error: Error?
        
        let request = VNRecognizeTextRequest { request, requestError in
            if let requestError = requestError {
                error = requestError
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                error = VisionPigeonError(code: "NO_TEXT_OBSERVATIONS", message: "No text observations found", details: nil)
                return
            }
            
            var allText = ""
            var totalConfidence: Float = 0.0
            var observationCount = 0
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                allText += topCandidate.string + "\n"
                totalConfidence += topCandidate.confidence
                observationCount += 1
            }
            
            let averageConfidence = observationCount > 0 ? Double(totalConfidence / Float(observationCount)) : 0.0
            
            result = VisionOcrResult(
                success: true,
                text: allText.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: averageConfidence,
                error: nil
            )
        }
        
        // Configure for better accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw error ?? VisionPigeonError(code: "VISION_ERROR", message: error?.localizedDescription, details: nil)
        }
        
        if let error = error {
            throw error
        }
        
        return result ?? VisionOcrResult(success: false, text: "", confidence: 0.0, error: "Unknown error")
    }
    
    // MARK: - Object Detection
    func detectObjects(imagePath: String) throws -> VisionObjectResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw VisionPigeonError(code: "IMAGE_LOAD_ERROR", message: "Failed to load image", details: nil)
        }
        
        var result: VisionObjectResult?
        var error: Error?
        
        let request = VNRecognizeObjectsRequest { request, requestError in
            if let requestError = requestError {
                error = requestError
                return
            }
            
            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                error = VisionPigeonError(code: "NO_OBJECT_OBSERVATIONS", message: "No object observations found", details: nil)
                return
            }
            
            var objects: [VisionObject] = []
            
            for observation in observations {
                let boundingBox = VisionRect(
                    x: Double(observation.boundingBox.origin.x),
                    y: Double(observation.boundingBox.origin.y),
                    width: Double(observation.boundingBox.size.width),
                    height: Double(observation.boundingBox.size.height)
                )
                
                let object = VisionObject(
                    label: observation.labels.first?.identifier ?? "Unknown",
                    confidence: Double(observation.confidence),
                    boundingBox: boundingBox
                )
                
                objects.append(object)
            }
            
            result = VisionObjectResult(success: true, objects: objects, error: nil)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw error ?? VisionPigeonError(code: "VISION_ERROR", message: error?.localizedDescription, details: nil)
        }
        
        if let error = error {
            throw error
        }
        
        return result ?? VisionObjectResult(success: false, objects: [], error: "Unknown error")
    }
    
    // MARK: - Face Detection
    func detectFaces(imagePath: String) throws -> VisionFaceResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw VisionPigeonError(code: "IMAGE_LOAD_ERROR", message: "Failed to load image", details: nil)
        }
        
        var result: VisionFaceResult?
        var error: Error?
        
        let request = VNDetectFaceRectanglesRequest { request, requestError in
            if let requestError = requestError {
                error = requestError
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation] else {
                error = VisionPigeonError(code: "NO_FACE_OBSERVATIONS", message: "No face observations found", details: nil)
                return
            }
            
            var faces: [VisionFace] = []
            
            for observation in observations {
                let boundingBox = VisionRect(
                    x: Double(observation.boundingBox.origin.x),
                    y: Double(observation.boundingBox.origin.y),
                    width: Double(observation.boundingBox.size.width),
                    height: Double(observation.boundingBox.size.height)
                )
                
                // Convert landmarks
                var landmarks: [VisionLandmark] = []
                if let faceLandmarks = observation.landmarks {
                    for (type, landmark) in faceLandmarks {
                        for point in landmark.normalizedPoints {
                            landmarks.append(VisionLandmark(
                                type: type.rawValue,
                                x: Double(point.x),
                                y: Double(point.y)
                            ))
                        }
                    }
                }
                
                // Convert contours
                var contours: [VisionContour] = []
                if let faceContours = observation.landmarks?.faceContour {
                    let points = faceContours.normalizedPoints.map { point in
                        VisionPoint(x: Double(point.x), y: Double(point.y))
                    }
                    contours.append(VisionContour(type: "faceContour", points: points))
                }
                
                let face = VisionFace(
                    boundingBox: boundingBox,
                    landmarks: landmarks,
                    contours: contours,
                    headEulerAngleY: Double(observation.roll ?? 0),
                    headEulerAngleZ: Double(observation.yaw ?? 0),
                    smilingProbability: 0.5, // Vision doesn't provide this directly
                    leftEyeOpenProbability: 0.5,
                    rightEyeOpenProbability: 0.5
                )
                
                faces.append(face)
            }
            
            result = VisionFaceResult(success: true, faces: faces, error: nil)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw error ?? VisionPigeonError(code: "VISION_ERROR", message: error?.localizedDescription, details: nil)
        }
        
        if let error = error {
            throw error
        }
        
        return result ?? VisionFaceResult(success: false, faces: [], error: "Unknown error")
    }
    
    // MARK: - Image Classification
    func classifyImage(imagePath: String) throws -> VisionClassificationResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw VisionPigeonError(code: "IMAGE_LOAD_ERROR", message: "Failed to load image", details: nil)
        }
        
        var result: VisionClassificationResult?
        var error: Error?
        
        let request = VNClassifyImageRequest { request, requestError in
            if let requestError = requestError {
                error = requestError
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                error = VisionPigeonError(code: "NO_CLASSIFICATION_OBSERVATIONS", message: "No classification observations found", details: nil)
                return
            }
            
            var labels: [VisionLabel] = []
            
            for observation in observations {
                let label = VisionLabel(
                    label: observation.identifier,
                    confidence: Double(observation.confidence)
                )
                labels.append(label)
            }
            
            result = VisionClassificationResult(success: true, labels: labels, error: nil)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw error ?? VisionPigeonError(code: "VISION_ERROR", message: error?.localizedDescription, details: nil)
        }
        
        if let error = error {
            throw error
        }
        
        return result ?? VisionClassificationResult(success: false, labels: [], error: "Unknown error")
    }
}
