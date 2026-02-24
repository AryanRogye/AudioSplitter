import Foundation

/**
 High-level API for creating and preparing page-scoped file stores.

 Use this protocol in feature/view-model code so those layers depend on an abstraction,
 not a concrete `AudioFileManager` implementation.
 */
public protocol AudioFileManaging {
    /**
     Global configuration that controls where files are stored.
     */
    var configuration: AudioFileManagerConfiguration { get }

    /**
     Returns a file store for a page/feature namespace.

     - Parameters:
       - namespace: Logical page name (for example: `StemSeparation`, `Library`, `Editor`).
       - location: Optional override for storage location. Pass `nil` to use `configuration.defaultLocation`.
     */
    func page(_ namespace: AudioFileNamespace, location: AudioFileLocation?) -> any AudioPageFileStoring

    /**
     Creates page directories ahead of time.

     Call this during app startup if you want known folders to exist before first use.

     - Parameters:
       - namespaces: Page namespaces to create.
       - location: Optional override for storage location. Pass `nil` to use `configuration.defaultLocation`.
     */
    func preparePages(_ namespaces: [AudioFileNamespace], location: AudioFileLocation?) throws
}

public extension AudioFileManaging {
    /**
     Convenience overload for `page(_:location:)` that uses the manager default location.
     */
    func page(_ namespace: AudioFileNamespace) -> any AudioPageFileStoring {
        page(namespace, location: nil)
    }

    /**
     Convenience overload for `preparePages(_:location:)` that uses the manager default location.
     */
    func preparePages(_ namespaces: [AudioFileNamespace]) throws {
        try preparePages(namespaces, location: nil)
    }
}
