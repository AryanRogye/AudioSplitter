# AudioHelper

`AudioHelper` contains reusable audio utilities for iOS, including a protocol-first file-management layer for page/feature directories.

## File Manager Design

The file API is built around two protocols:

- `AudioFileManaging`: top-level manager that creates page stores.
- `AudioPageFileStoring`: page-scoped operations (`copyIn`, `importSecurityScoped`, `listFiles`, `clear`, etc.).

Concrete implementation:

- `AudioFileManager` conforms to `AudioFileManaging`.
- `AudioPageFileStore` conforms to `AudioPageFileStoring`.

This keeps feature code decoupled from implementation details.

## Package Layout

```text
Sources/AudioHelper/FileManagement/
  Models/
    AudioFileDuplicatePolicy.swift
    AudioFileLocation.swift
    AudioFileManagerConfiguration.swift
    AudioFileManagerError.swift
    AudioFileNamespace.swift
  Protocols/
    AudioFileManaging.swift
    AudioPageFileStoring.swift
  Core/
    AudioFileManager.swift
    AudioPageFileStore.swift
```

## Directory Model

Files are stored like:

`<location>/<containerFolderName>/<namespace>/...`

Where:

- `location` is one of `applicationSupport`, `caches`, `documents`, `temporary`.
- `containerFolderName` is configured once on manager init.
- `namespace` is your page/feature name (`AudioFileNamespace`).

## Quick Start

```swift
import AudioHelper

extension AudioFileNamespace {
    static let stemSeparation: Self = "StemSeparation"
    static let library: Self = "Library"
    static let editor: Self = "Editor"
}

let fileManager: AudioFileManaging = AudioFileManager(
    configuration: .init(
        containerFolderName: "AudioSplitterFiles",
        defaultLocation: .applicationSupport
    )
)

try fileManager.preparePages(
    [.stemSeparation, .library, .editor],
    location: .caches
)

let stemFiles = fileManager.page(.stemSeparation, location: .caches)
let imported = try stemFiles.importSecurityScoped(
    from: pickedURL,
    duplicatePolicy: .uniquify
)
```

## Common Operations

```swift
let libraryFiles = fileManager.page(.library, location: .applicationSupport)

let destination = try libraryFiles.copyIn(
    from: sourceURL,
    preferredName: "my-track.m4a",
    duplicatePolicy: .replace
)

let allFiles = try libraryFiles.listFiles()
let hasMix = try libraryFiles.containsFile(named: "my-track.m4a")
let existingMix = try libraryFiles.existingFileURL(named: "my-track.m4a")
let uniqueURL = try libraryFiles.uniqueFileURL(for: "mix.wav")

try libraryFiles.removeFile(named: "old-track.m4a")
try libraryFiles.clear()
```

## Duplicate Policies

- `.fail`: throw if file exists.
- `.replace`: remove existing file, then write.
- `.uniquify`: auto-generate `name-1.ext`, `name-2.ext`, etc.

## Best Practices

- Use `.caches` for temporary imports and intermediate renders.
- Use `.applicationSupport` for app-owned files you want to persist.
- Use `.documents` only for user-visible files you expect to expose via Files.
- Import file-picker URLs with `importSecurityScoped(from:)` to safely copy into sandbox storage.
- Keep namespace names stable per page/feature so paths remain predictable.
