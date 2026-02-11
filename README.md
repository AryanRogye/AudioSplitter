# AudioSplitter


AudioSplitter is an on-device audio **machine learning system** for iOS focused on **neural stem separation** and **local inference pipelines**.

The project explores deploying **UVR/MDX-style source separation networks** fully on device using **Core ML**, including **model conversion (ONNX → CoreML)**, **tensor preprocessing**, **streaming inference**, and **memory-aware audio reconstruction** all running locally on iPhone hardware with **no cloud dependency**.

It serves as both a functional app and a **reference implementation** for shipping **real-world ML audio pipelines** directly on iOS.

## License

This repository's source code is licensed under LGPL-2.1-or-later.

- See `LICENSE`.
- Third-party software notices are in `THIRD_PARTY_NOTICES.md`.
- Third-party model licensing and attribution notes are in `THIRD_PARTY_MODELS.md`.

## Requirements

- macOS with Xcode installed
- Xcode Command Line Tools (`xcode-select --install`)
- iOS Simulator runtime supported by your Xcode version

This project currently targets iOS `26.0` in `AudioSplitter.xcodeproj/project.pbxproj`.

## Quick Start

1. Open `AudioSplitter.xcodeproj` in Xcode.
2. Select scheme `AudioSplitter`.
3. Select an iOS Simulator device.
4. Build and run.

Command-line build (verified):

```bash
xcodebuild \
  -project AudioSplitter.xcodeproj \
  -scheme AudioSplitter \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Model Setup (UVRMDXNet)

The app expects a Core ML model compatible with the UVR MDX contract.

- Expected model names in bundle:
  - `UVRMDXNet`
  - `StemSeparator`
  - `AudioSeparator`
  - `DemucsSeparator`
- Expected input shape: `[1, 4, 2560, 256]` (multi-array)
- Expected output shape: `[1, 4, 2560, 256]` (multi-array)
- Pipeline reference: `UVR-MDX-NET-Inst_HQ_5` contract in `AudioSplitter/StemSeparation/Internal/CoreMLMDXStemSeparatorAdapter.swift`

### 1. Get model weights

Official UVR model downloads are published from:

- `https://github.com/TRvlvr/model_repo/releases/tag/all_public_uvr_models`

Example source model used for this app's contract:

- `UVR-MDX-NET-Inst_HQ_5.onnx`

### 2. Convert to Core ML package

This repo uses a Core ML package (`.mlpackage`) at runtime.

Use the conversion script:

```bash
python3 -m pip install -r scripts/requirements-model-conversion.txt
python3 scripts/convert_model_to_mlpackage.py \
  --source /path/to/UVR-MDX-NET-Inst_HQ_5.onnx \
  --output AudioSplitter/UVRMDXNet.mlpackage \
  --shape 1,4,2560,256 \
  --input-name input \
  --min-ios iOS17 \
  --precision float16
```

TorchScript input also works:

```bash
python3 scripts/convert_model_to_mlpackage.py \
  --source /path/to/model.ts \
  --output AudioSplitter/UVRMDXNet.mlpackage
```

The script attempts ONNX conversion through `onnx2torch` when source is `.onnx`.

After conversion, ensure you have:

- `UVRMDXNet.mlpackage`

Place it at:

- `AudioSplitter/UVRMDXNet.mlpackage`

### 3. Validate model metadata

Use:

```bash
xcrun coremlcompiler metadata AudioSplitter/UVRMDXNet.mlpackage
```

Confirm:

- One multi-array input with shape `[1, 4, 2560, 256]`
- One multi-array output with shape `[1, 4, 2560, 256]`

### 4. Build

When present, Xcode will compile the model into `.mlmodelc` during build.

If the model is missing or incompatible, the app reports errors from:

- `AudioSplitter/StemSeparation/StemSeparationAPI.swift`

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

This app currently depends on FFmpeg packages distributed under LGPL-2.1+.

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
  - Ensure `UVRMDXNet.mlpackage` exists under `AudioSplitter/`.
  - Rebuild clean (`Product > Clean Build Folder`).
- `Unsupported model input/output`:
  - Verify the model input/output shapes are `[1, 4, 2560, 256]`.
  - Verify model uses multi-array IO.

## Audio Splitter Lab (Debug Only)

The **Audio Splitter Lab** is a debug-only workspace for trying UI ideas without cluttering the main product flow.

- Purpose: prototype and compare loading animations, interaction patterns, and visual styles.
- Scope: experiments should live in the lab screens first, then be promoted to production UI only after validation.
- Rule: keep the main `Audio Splitter` screen stable and focused; do not ship unfinished experiments there.

Current lab entry point:

- Open the `Labs` button in the top-right toolbar.
- Use `Loading Lab` to test and select loading styles.
- Use `Library + Stage Styles` to swipe through five UI concept tabs for workflow experiments.
- Add future UI experiments as additional lab modules under the same hub.
