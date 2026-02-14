//
//  ConverterView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

#if !NO_DOWNLOAD
import SwiftUI
import FFmpegSupport

struct ConverterView: View {
    let inputURL: URL
    var onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss // To close the sheet manually
    @State private var isConverting = false
    @State private var status = "Ready to convert"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source File:")
                        .font(.headline)
                    Text(inputURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                if isConverting {
                    ProgressView("Converting to MP3...")
                } else {
                    Button(action: startConversion) {
                        Text("Convert & Save to Files")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Audio Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func startConversion() {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = docs.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + ".mp3")
        
        isConverting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Ensure no duplicate exists
            try? fileManager.removeItem(at: outputURL)
            
            let args = ["ffmpeg", "-i", inputURL.path, "-vn", "-acodec", "libmp3lame", "-b:a", "192k", outputURL.path]
            let result = ffmpeg(args)
            
            DispatchQueue.main.async {
                if result == 0 {
                    // Optional: Delete webm after success
                    try? fileManager.removeItem(at: inputURL)
                    onComplete()
                } else {
                    isConverting = false
                    status = "Error during conversion."
                }
            }
        }
    }
}

#endif
