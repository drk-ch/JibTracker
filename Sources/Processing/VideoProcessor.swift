import AVFoundation
import UIKit
import Photos

class VideoProcessor {
    static func saveVideoToPhotoLibrary(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "JibTracker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
    
    static func processVideo(inputURL: URL, outputURL: URL, boundingBoxes: [CGRect], completion: @escaping (Bool, Error?) -> Void) {
        // Create asset
        let asset = AVAsset(url: inputURL)
        
        // Create composition
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(false, NSError(domain: "JibTracker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"]))
            return
        }
        
        // Get video track
        guard let assetTrack = asset.tracks(withMediaType: .video).first else {
            completion(false, NSError(domain: "JibTracker", code: 3, userInfo: [NSLocalizedDescriptionKey: "No video track found"]))
            return
        }
        
        // Insert video track into composition
        do {
            try compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: assetTrack, at: .zero)
        } catch {
            completion(false, error)
            return
        }
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = assetTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        // Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        
        // Apply transformations based on bounding boxes
        // This is a simplified version - in a real app, you would apply more complex transformations
        if let firstBoundingBox = boundingBoxes.first {
            let scale = 1.0 / firstBoundingBox.width
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            layerInstruction.setTransform(transform, at: .zero)
        }
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(false, NSError(domain: "JibTracker", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
            return
        }
        
        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        // Export
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                completion(exportSession.status == .completed, exportSession.error)
            }
        }
    }
} 