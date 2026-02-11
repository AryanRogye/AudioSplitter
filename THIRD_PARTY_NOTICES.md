# Third-Party Notices

This project includes third-party components. Licenses listed here apply to those components and do not override the app's own license.

## Components

| Component | Version | Source | License |
| --- | --- | --- | --- |
| FFmpeg-iOS-Lame | 0.0.6-b20230730-000000 (`1808fa5a1263c5e216646cd8421fc7dcb70520cc`) | https://github.com/kewlbear/FFmpeg-iOS-Lame | LGPL-2.1+ |
| FFmpeg-iOS-Support | 0.0.2 (`be3bd9149ac53760e8725652eee99c405b2be47a`) | https://github.com/kewlbear/FFmpeg-iOS-Support | LGPL-2.1+ |
| YoutubeDL-iOS | 0.0.9 (`64d9072cc33d2698b555d68cecf3d71f2f49b8dd`) | https://github.com/kewlbear/YoutubeDL-iOS | MIT |
| Python-iOS | 0.1.1-b20230423-090254 (`4f3ca2bc0cff1ef2511555eb6114f9eb12e50412`) | https://github.com/kewlbear/Python-iOS | PSF-2.0 |
| PythonKit | 0.5.1 (`6fee7617cfa910fbac7035276e295ba967adbbb4`) | https://github.com/pvieito/PythonKit | MIT |

Versions/revisions are sourced from `AudioSplitter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## LGPL Materials

- Full LGPL text is included in `LICENSE`.
- FFmpeg legal guidance: https://ffmpeg.org/legal.html

## Rebuilding with Modified FFmpeg

The app can be rebuilt with modified FFmpeg binaries:

1. Clone/build from upstream FFmpeg-iOS tooling:
   - https://github.com/kewlbear/FFmpeg-iOS-Lame
   - https://github.com/kewlbear/FFmpeg-iOS-Support
2. Build replacement libraries as documented by upstream (`swift run ffmpeg-ios ...` in the FFmpeg-iOS tooling repo).
3. Point the app to rebuilt artifacts by updating SwiftPM dependencies or package revisions.
4. Rebuild `AudioSplitter` from source with Xcode or `xcodebuild`.

## Disclaimer

This notice file is provided for developer convenience and should not be treated as legal advice.
