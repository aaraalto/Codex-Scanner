# Codex Scanner

A modern, native macOS document scanner app built with SwiftUI. Designed for scanning books and documents using your Mac's camera or iPhone via Continuity Camera.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Continuity Camera Support** - Use your iPhone as a high-quality camera for scanning
- **Automatic Document Detection** - AI-powered edge detection with real-time bounds overlay
- **Auto-Capture** - Automatically captures when document is stable
- **Digital Zoom** - Scroll wheel zoom with 1x/2x presets (iOS Camera-style controls)
- **Bounds Locking** - Lock the scanning area for consistent multi-page scanning
- **Live Preview** - Edit document bounds before finalizing
- **Multiple Filter Presets** - Original, grayscale, high contrast, and more
- **Book Organization** - Organize scanned pages into books
- **PDF Export** - Export books as PDF documents
- **SwiftData Persistence** - Modern data persistence with SwiftData
- **Beautiful UI** - Clean, Notion-inspired design language

## Screenshots

<!-- Add screenshots here -->

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Camera access (built-in or iPhone via Continuity Camera)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/codex-scanner.git
   cd codex-scanner
   ```

2. Open the project in Xcode:
   ```bash
   open "Codex Scanner.xcodeproj"
   ```

3. Configure signing:
   - Select the project in the navigator
   - Go to **Signing & Capabilities**
   - Select your **Team** from the dropdown
   - Optionally change the **Bundle Identifier**

4. Build and run (⌘R)

## Usage

### Scanning Documents

1. **Connect a Camera** - Use your Mac's built-in camera or connect an iPhone via Continuity Camera for better quality
2. **Position Document** - Place your document in view; the app will automatically detect edges
3. **Capture** - Press the red record button or wait for auto-capture when the document is stable
4. **Review** - Tap captured pages to review and adjust bounds if needed

### Keyboard Shortcuts

- **Space** - Capture photo (when in manual mode)
- **⌘S** - Save current book

### Tips

- For best results with books, use the **Lock** feature to maintain consistent bounds across pages
- Use **2x zoom** to get closer to the document without moving physically
- The **Auto** mode works best for single documents; use **Manual** for rapid page turning

## Architecture

```
Codex Scanner/
├── Models/           # SwiftData models (Book, Page, CapturedPage)
├── Views/            # SwiftUI views
│   ├── Components/   # Reusable UI components
│   └── Extensions/   # View extensions
├── ViewModels/       # MVVM view models
├── Services/         # Camera, image processing, PDF generation
└── Shaders/          # Metal shaders for effects
```

## Technologies

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Data persistence
- **AVFoundation** - Camera capture and Continuity Camera
- **Vision** - Document detection
- **Core Image** - Image processing and filters
- **Metal** - Custom shaders for visual effects

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the iOS Camera app zoom controls
- UI design influenced by Notion's clean aesthetic
- Built with Apple's latest frameworks and best practices
