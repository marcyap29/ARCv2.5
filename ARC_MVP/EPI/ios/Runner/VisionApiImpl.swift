import Foundation
import Vision
import UIKit

class VisionApiImpl: NSObject, VisionApi {
    
    // MARK: - Text Recognition
    func extractText(imagePath: String) throws -> VisionOcrResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw PigeonError(code: "INVALID_IMAGE", message: "Could not load image from path: \(imagePath)", details: nil)
        }
        
        var extractedText = ""
        var confidence: Double = 0.0
        var textBlocks: [VisionTextBlock] = []
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("Vision API Error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            var allText: [String] = []
            var totalConfidence: Double = 0.0
            var blockCount = 0
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                let text = topCandidate.string
                let conf = Double(topCandidate.confidence)
                
                allText.append(text)
                totalConfidence += conf
                blockCount += 1
                
                // Create bounding box
                let boundingBox = observation.boundingBox
                let visionRect = VisionRect(
                    x: Double(boundingBox.origin.x),
                    y: Double(boundingBox.origin.y),
                    width: Double(boundingBox.size.width),
                    height: Double(boundingBox.size.height)
                )
                
                let textBlock = VisionTextBlock(
                    text: text,
                    confidence: conf,
                    boundingBox: visionRect
                )
                textBlocks.append(textBlock)
            }
            
            extractedText = allText.joined(separator: " ")
            confidence = blockCount > 0 ? totalConfidence / Double(blockCount) : 0.0
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        return VisionOcrResult(
            text: extractedText,
            confidence: confidence,
            blocks: textBlocks
        )
    }
    
    // MARK: - Object Detection
    func detectObjects(imagePath: String) throws -> VisionObjectResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw PigeonError(code: "INVALID_IMAGE", message: "Could not load image from path: \(imagePath)", details: nil)
        }
        
        var detectedObjects: [VisionDetectedObject] = []
        
        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                print("Vision API Error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation] else {
                return
            }
            
            for observation in observations {
                let label = "Rectangle"
                let confidence = Double(observation.confidence)
                
                let boundingBox = observation.boundingBox
                let visionRect = VisionRect(
                    x: Double(boundingBox.origin.x),
                    y: Double(boundingBox.origin.y),
                    width: Double(boundingBox.size.width),
                    height: Double(boundingBox.size.height)
                )
                
                let detectedObject = VisionDetectedObject(
                    label: label,
                    confidence: confidence,
                    boundingBox: visionRect
                )
                detectedObjects.append(detectedObject)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        return VisionObjectResult(objects: detectedObjects)
    }
    
    // MARK: - Face Detection
    func detectFaces(imagePath: String) throws -> VisionFaceResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw PigeonError(code: "INVALID_IMAGE", message: "Could not load image from path: \(imagePath)", details: nil)
        }
        
        var detectedFaces: [VisionDetectedFace] = []
        
        let request = VNDetectFaceRectanglesRequest { request, error in
            if let error = error {
                print("Vision API Error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation] else {
                return
            }
            
            for observation in observations {
                let confidence = Double(observation.confidence)
                
                let boundingBox = observation.boundingBox
                let visionRect = VisionRect(
                    x: Double(boundingBox.origin.x),
                    y: Double(boundingBox.origin.y),
                    width: Double(boundingBox.size.width),
                    height: Double(boundingBox.size.height)
                )
                
                let detectedFace = VisionDetectedFace(
                    confidence: confidence,
                    boundingBox: visionRect
                )
                detectedFaces.append(detectedFace)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        return VisionFaceResult(faces: detectedFaces)
    }
    
    // MARK: - Image Classification
    func classifyImage(imagePath: String) throws -> VisionClassificationResult {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            throw PigeonError(code: "INVALID_IMAGE", message: "Could not load image from path: \(imagePath)", details: nil)
        }
        
        var classifications: [VisionClassification] = []
        
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                print("Vision API Error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                return
            }
            
            for observation in observations {
                let identifier = observation.identifier
                let confidence = Double(observation.confidence)
                
                let classification = VisionClassification(
                    identifier: identifier,
                    confidence: confidence
                )
                classifications.append(classification)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        return VisionClassificationResult(classifications: classifications)
    }
}
