import SwiftUI

public struct ExportShareView: View {
    @EnvironmentObject private var appState: AppState
    @State private var exportURL: URL? = nil
    @State private var errorMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Export Inventory Archive")
                .font(.title2)
                .fontWeight(.bold)

            Text("Generate a self-contained ZIP archive containing books.csv, books.json, manifest.json, and all physical photos.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if let url = exportURL {
                Text("Ready: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.green)

                ExportShareExportActivityView(activityItems: [url])
                    .frame(height: 50)
                    .accessibilityIdentifier("ShareActivityView")
            } else {
                Button(action: {
                    do {
                        let photosDir = appState.photoStorage.baseDirectory
                        let url = try appState.exportService.exportCollection(books: appState.books, photosDirectoryURL: photosDir)
                        exportURL = url
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }) {
                    Text("Generate ZIP Archive")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .accessibilityIdentifier("GenerateZipButton")
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}
