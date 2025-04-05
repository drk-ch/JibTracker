import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isRecording = false
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            CameraPreviewView(previewLayer: cameraManager.previewLayer)
                .ignoresSafeArea()
            
            // Tracking indicator
            if cameraManager.isTracking {
                VStack {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.green)
                        Text("Tracking Active")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.top, 50)
                    
                    Spacer()
                }
            }
            
            // Controls
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .padding(.trailing)
                }
                
                Spacer()
                
                HStack {
                    // Recording button
                    Button(action: {
                        isRecording.toggle()
                        if isRecording {
                            cameraManager.startRecording()
                        } else {
                            cameraManager.stopRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.system(size: 72))
                            .foregroundColor(isRecording ? .red : .white)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        if let previewLayer = previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Camera Settings")) {
                    Toggle("Use Ultra-Wide Camera", isOn: .constant(true))
                    Toggle("Enable Lens Correction", isOn: .constant(true))
                }
                
                Section(header: Text("Tracking Settings")) {
                    Toggle("Auto-Track People", isOn: .constant(true))
                    Toggle("Show Tracking Box", isOn: .constant(true))
                }
                
                Section(header: Text("Recording Settings")) {
                    Toggle("Record Audio", isOn: .constant(true))
                    Toggle("Save to Photo Library", isOn: .constant(true))
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
} 