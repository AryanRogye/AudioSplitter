//
//  EditorFile.swift
//  AudioUI
//
//  Created by Aryan Rogye on 2/12/26.
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let track = UTType(exportedAs: "com.aryanrogye.processedTrack")
}


public enum SongType: String, Codable {
    case vocal
    case instrumental
    case all
}

/// This helps us translate whatever spagetti the ml had us doing to something clean the UI can use
public struct EditorFile: Identifiable, Codable, Hashable, Transferable, Equatable {
    
    public let id: UUID
    let displayName: String
    let url: URL
    let type: SongType
    let createdAt: Date
    
    public init(_ url: URL, id: UUID = UUID(), name: String, created: Date, type: SongType) {
        self.id = id
        self.url = url
        self.displayName = name
        self.type = type
        self.createdAt = created
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .track)
    }
}
