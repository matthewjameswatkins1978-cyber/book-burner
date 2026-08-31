import SwiftUI

public struct BookDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State public var book: BookCopy
    @State private var selectedLocationName: String

    public init(book: BookCopy) {
        self._book = State(initialValue: book)
        self._selectedLocationName = State(initialValue: book.locationName)
    }

    public var body: some View {
        Form {
            // Photo Preview Section
            Section(header: Text("Physical Copy Photo")) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 200)
                    VStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(book.photo?.relativePath ?? "No Photo Available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("BookPhotoPreview")
            }

            // Metadata & Provenance Section
            Section(header: Text("Book Details & Provenance")) {
                LabeledContent("BBID", value: book.bbidString)
                LabeledContent("ISBN", value: book.isbn ?? "None (No ISBN Path)")
                LabeledContent("Title", value: book.title ?? "Untitled")
                LabeledContent("Author", value: book.author ?? "Unknown")
                LabeledContent("Publisher", value: book.publisher ?? "Unknown")
                LabeledContent("Published Year", value: book.publishedYear.map { String($0) } ?? "Unknown")
                LabeledContent("Status", value: book.status.rawValue)
                LabeledContent("Provenance", value: book.metadataProvenance ?? "Manual")
            }

            // Location Editor Section
            Section(header: Text("Storage Location")) {
                Picker("Location", selection: $selectedLocationName) {
                    ForEach(appState.locations, id: \.id) { loc in
                        Text(loc.name).tag(loc.name)
                    }
                }
                .onChange(of: selectedLocationName) { newName in
                    book.locationName = newName
                    if let matched = appState.locations.first(where: { $0.name == newName }) {
                        book.locationID = matched.id
                    }
                    appState.updateBook(book)
                }
                .accessibilityIdentifier("BookLocationPicker")
            }

            // Mark Incorrect / Needs Review Action
            Section {
                Button(action: {
                    book.status = .needsReview
                    book.metadataProvenance = "Marked Incorrect by User"
                    appState.updateBook(book)
                }) {
                    Label("Mark as Incorrect / Needs Review", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                .accessibilityIdentifier("MarkIncorrectButton")
            }
        }
        .navigationTitle(book.bbidString)
    }
}
