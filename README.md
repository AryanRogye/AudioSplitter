# ComfyAudio

This repository hosts an on-device iOS audio ML stack focused on stem separation and local inference.

`ComfyAudio` is now the primary app target in this repo.

## Repository Layout

- `ComfyAudio/` primary iOS app project and UI.
- `AudioHelper/` shared Swift package (stem separation engine, downloader, TTS, file management, packaged model resources).
- `old/` archived legacy modules and app code.
  - `old/AudioSplitter/`
  - `old/AudioUI/`
  - `old/NO_DOWNLOAD/`
- `scripts/` tooling (including model conversion).

## Core Upstream Credits

This app relies heavily on the following upstream projects:

- `FluidAudio` by FluidInference:
  https://github.com/FluidInference/FluidAudio
  Provides core on-device audio/voice inference capabilities used by the app's `AudioHelper` package.
- `YoutubeDL-iOS` by kewlbear:
  https://github.com/kewlbear/YoutubeDL-iOS
  Powers the in-app YouTube download workflow used in `ComfyAudio` utilities.

## License

This repository's source code is licensed under LGPL-2.1-or-later.

- See `LICENSE`.
- Third-party software notices are in `THIRD_PARTY_NOTICES.md`.
- Third-party model licensing and attribution notes are in `THIRD_PARTY_MODELS.md`.

## Requirements

- macOS with Xcode installed
- Xcode Command Line Tools (`xcode-select --install`)
- iOS Simulator runtime supported by your Xcode version

## Quick Start (Primary App)

1. Open `ComfyAudio/ComfyAudio.xcodeproj` in Xcode.
2. Select scheme `ComfyAudio`.
3. Select an iOS Simulator device.
4. Build and run.

Command-line build:

```bash
xcodebuild \
  -project ComfyAudio/ComfyAudio.xcodeproj \
  -scheme ComfyAudio \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Model Setup (UVRMDXNet)

The runtime expects a Core ML model compatible with the UVR/MDX contract.

- Expected model names:
  - `UVRMDXNet`
  - `StemSeparator`
  - `AudioSeparator`
  - `DemucsSeparator`
- Expected input shape: `[1, 4, 2560, 256]` (multi-array)
- Expected output shape: `[1, 4, 2560, 256]` (multi-array)
- Pipeline reference:
  - `AudioHelper/Sources/AudioHelper/StemSeperation/Core/CoreMLStemSeparatorEngine.swift`

### 1. Get model weights

Official UVR model downloads are published from:

- `https://github.com/TRvlvr/model_repo/releases/tag/all_public_uvr_models`

Example source model:

- `UVR-MDX-NET-Inst_HQ_5.onnx`

### 2. Convert to Core ML package

Install conversion dependencies and convert:

```bash
python3 -m pip install -r scripts/requirements-model-conversion.txt
python3 scripts/convert_model_to_mlpackage.py \
  --source /path/to/UVR-MDX-NET-Inst_HQ_5.onnx \
  --output AudioHelper/Sources/AudioHelper/Resources/UVRMDXNet.mlpackage \
  --shape 1,4,2560,256 \
  --input-name input \
  --min-ios iOS17 \
  --precision float16
```

TorchScript input also works:

```bash
python3 scripts/convert_model_to_mlpackage.py \
  --source /path/to/model.ts \
  --output AudioHelper/Sources/AudioHelper/Resources/UVRMDXNet.mlpackage
```

### 3. Validate model metadata

```bash
xcrun coremlcompiler metadata AudioHelper/Sources/AudioHelper/Resources/UVRMDXNet.mlpackage
```

Confirm:

- One multi-array input with shape `[1, 4, 2560, 256]`
- One multi-array output with shape `[1, 4, 2560, 256]`

### 4. Build

Xcode compiles model resources during build. If the model is missing or incompatible, the stem separation layer reports runtime errors.

## Important Notes on Repository Hygiene

- Model artifacts are ignored in `.gitignore` (`*.mlpackage`, `*.onnx`, `*.pth`, `*.ckpt`, etc.).
- Keep large model binaries out of git history unless you intentionally use Git LFS.

## Attribution and Model License Notes

- App code is LGPL-2.1-or-later (`LICENSE`).
- Third-party software notices and package versions are listed in `THIRD_PARTY_NOTICES.md`.
- Model files are third-party assets and are not automatically covered by this repo's app code license.
- Verify model redistribution/commercial terms for the exact model you use.
- Include model attribution in public releases.
- See `THIRD_PARTY_MODELS.md` for a template and links.

## FFmpeg / LGPL Compliance Notes

This app depends on FFmpeg packages distributed under LGPL-2.1+:

- `FFmpeg-iOS-Lame`
- `FFmpeg-iOS-Support`

To rebuild with modified FFmpeg:

1. Follow upstream build docs in `FFmpeg-iOS-Lame` / `FFmpeg-iOS-Support`.
2. Produce replacement FFmpeg artifacts.
3. Update package references/revisions.
4. Rebuild this app from source.

See `THIRD_PARTY_NOTICES.md` for package versions and source links.

## Troubleshooting

- `No bundled Core ML model was found`:
  - Ensure `UVRMDXNet.mlpackage` exists under `AudioHelper/Sources/AudioHelper/Resources/`.
  - Rebuild clean (`Product > Clean Build Folder`).
- `Unsupported model input/output`:
  - Verify model input/output shapes are `[1, 4, 2560, 256]`.
  - Verify model uses multi-array IO.
