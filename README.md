# JibTracker

A snowboard follow cam app that uses computer vision to track and follow riders, providing a stabilized video feed that simulates a professional follow cam setup.

## Features

- 🎥 Ultra-wide camera support (0.5x) for capturing more of the scene
- 👤 Real-time person detection and tracking
- 🎬 Video recording with audio
- 🎨 Metal-based video processing for smooth performance
- 📱 Modern SwiftUI interface
- 💾 Automatic video saving to photo library

## Requirements

- iOS 15.0+
- Xcode 13.0+
- iPhone with ultra-wide camera (for best results)
- Swift 5.5+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/drk-ch/JibTracker.git
```

2. Open the project in Xcode:
```bash
cd JibTracker
open JibTracker.xcodeproj
```

3. Build and run the project on your device (not simulator)

## Usage

1. **Starting the App**
   - Launch the app
   - Grant camera and photo library permissions when prompted

2. **Recording Setup**
   - Position your phone to capture the rider
   - The app will automatically detect and track people in the frame
   - A green box indicates successful tracking

3. **Recording**
   - Tap the record button to start recording
   - The app will track the rider and stabilize the video
   - Tap stop to end recording
   - The processed video will automatically save to your photo library

4. **Settings**
   - Access settings through the gear icon
   - Adjust tracking sensitivity
   - Configure video quality settings
   - Toggle audio recording

## Project Structure

```
JibTracker/
├── Sources/
│   ├── Camera/         # Camera setup and management
│   ├── Detection/      # Person detection and tracking
│   ├── Processing/     # Video processing and Metal rendering
│   ├── UI/            # User interface components
│   └── Utils/         # Utility files and configurations
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Vision framework for person detection
- Metal framework for video processing
- AVFoundation for camera handling
