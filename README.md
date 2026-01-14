# ShutterSpeed

A Mac-native, privacy-first photo management and RAW editing app for enthusiast photographers.

## Vision

Resurrect Apple Aperture's soul for 2026 - filling the gap between "Photos is too simple" and "Lightroom requires a subscription."

## Features (Phase 1 MVP)

- **Library Management**: Bundle-based library (.shutterspeed) with managed/referenced file support
- **Fast Browsing**: 60fps grid scrolling with multi-resolution thumbnail cache
- **RAW Processing**: Core Image + Metal GPU acceleration, LibRaw fallback
- **Non-Destructive Editing**: Master + versions model, adjustment stacking
- **Organization**: Star ratings, flags, color labels, keywords, smart albums
- **Export**: JPEG, TIFF, HEIC, PNG with XMP sidecar support

## Technical Stack

- SwiftUI + macOS 14+
- SQLite (WAL mode) + XMP sidecars
- Core Image + Metal for GPU-accelerated RAW processing
- Vision framework for on-device AI (faces, scenes)
- Core ML for AI features (denoise, super-res)

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.2+

## Building

```bash
open ShutterSpeed.xcodeproj
# Build and run (Cmd+R)
```

## Roadmap

- **Phase 1** (Current): Library + Basic Editing - MVP
- **Phase 2**: Versions, Light Table, Local Adjustments
- **Phase 3**: AI Features (Face detection, Scene classification, AI Denoise)
- **Phase 4**: iOS companion, Sync, Plugin API

## License

Copyright 2026 Will Sigmon. All rights reserved.
