import Vision
import CoreML
import UIKit

class PersonDetector {
    private var detectionRequest: VNCoreMLRequest?
    private var trackingRequest: VNTrackObjectRequest?
    private var lastBoundingBox: CGRect?
    private var isTracking = false
    
    init() {
        setupDetectionModel()
    }
    
    private func setupDetectionModel() {
        // For now, we'll use Vision's built-in person detection
        // In a real app, you would convert YOLOv8 to CoreML and use that
        let config = MLModelConfiguration()
        
        // Create a request that uses Vision's built-in person detection
        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNHumanObservation] else { return }
            
            if let person = observations.first {
                self?.lastBoundingBox = person.boundingBox
                self?.startTracking(with: person.boundingBox)
            }
        }
        
        detectionRequest = request
    }
    
    private func startTracking(with boundingBox: CGRect) {
        // Create a tracking request for the detected person
        let request = VNTrackObjectRequest()
        request.inputObservation = VNDetectedObjectObservation(boundingBox: boundingBox)
        request.trackingLevel = .accurate
        
        trackingRequest = request
        isTracking = true
    }
    
    func detectPerson(in pixelBuffer: CVPixelBuffer, completion: @escaping (CGRect?) -> Void) {
        if isTracking, let trackingRequest = trackingRequest {
            // Continue tracking the person
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([trackingRequest])
            
            if let result = trackingRequest.results?.first as? VNDetectedObjectObservation {
                lastBoundingBox = result.boundingBox
                completion(result.boundingBox)
            } else {
                // Lost tracking, fall back to detection
                isTracking = false
                detectPerson(in: pixelBuffer, completion: completion)
            }
        } else {
            // Detect a new person
            guard let detectionRequest = detectionRequest else {
                completion(nil)
                return
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([detectionRequest])
            
            completion(lastBoundingBox)
        }
    }
    
    func resetTracking() {
        isTracking = false
        lastBoundingBox = nil
        trackingRequest = nil
    }
} 