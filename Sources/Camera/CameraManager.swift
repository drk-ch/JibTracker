import AVFoundation
import SwiftUI
import CoreML
import Vision
import Metal

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let personDetector = PersonDetector()
    private let metalRenderer: MetalRenderer?
    
    private var videoFileOutput: AVCaptureMovieFileOutput?
    private var currentBoundingBox: CGRect?
    private var boundingBoxHistory: [CGRect] = []
    
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRecording = false
    @Published var isTracking = false
    
    override init() {
        metalRenderer = MetalRenderer()
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        // Try to get the ultra-wide camera first
        if let ultraWideCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            configureCamera(ultraWideCamera)
        } else if let wideCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            configureCamera(wideCamera)
        } else {
            print("No suitable camera found")
            return
        }
        
        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            } catch {
                print("Error adding audio input: \(error)")
            }
        }
        
        // Setup video output
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Setup audio output
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }
        
        // Setup movie file output
        let movieFileOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
            videoFileOutput = movieFileOutput
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
    }
    
    private func configureCamera(_ device: AVCaptureDevice) {
        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Error configuring camera: \(error)")
        }
    }
    
    func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func startRecording() {
        guard let videoFileOutput = videoFileOutput else { return }
        
        // Clear bounding box history
        boundingBoxHistory.removeAll()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoPath = documentsPath.appendingPathComponent("jibtracker_\(Date().timeIntervalSince1970).mov")
        
        videoFileOutput.startRecording(to: videoPath, recordingDelegate: this)
        isRecording = true
    }
    
    func stopRecording() {
        videoFileOutput?.stopRecording()
        isRecording = false
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Detect and track person
        personDetector.detectPerson(in: pixelBuffer) { [weak self] boundingBox in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentBoundingBox = boundingBox
                self.isTracking = boundingBox != nil
                
                // Store bounding box for video processing
                if let boundingBox = boundingBox, self.isRecording {
                    self.boundingBoxHistory.append(boundingBox)
                }
            }
            
            // Process frame with Metal if we have a bounding box
            if let boundingBox = boundingBox, let metalRenderer = self.metalRenderer {
                _ = metalRenderer.processFrame(sampleBuffer: sampleBuffer, boundingBox: boundingBox)
            }
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error)")
        } else {
            print("Video saved to: \(outputFileURL)")
            
            // Process the video with the bounding box history
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let processedVideoPath = documentsPath.appendingPathComponent("processed_\(Date().timeIntervalSince1970).mov")
            
            VideoProcessor.processVideo(inputURL: outputFileURL, outputURL: processedVideoPath, boundingBoxes: boundingBoxHistory) { success, error in
                if success {
                    // Save to photo library
                    VideoProcessor.saveVideoToPhotoLibrary(url: processedVideoPath) { success, error in
                        if success {
                            print("Video saved to photo library")
                        } else if let error = error {
                            print("Error saving to photo library: \(error)")
                        }
                    }
                } else if let error = error {
                    print("Error processing video: \(error)")
                }
            }
        }
    }
} 