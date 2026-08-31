import SwiftUI

public struct LocationPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var newLocationName: String = ""
    @State private var showingAddAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Active Capture Location")) {
                    ForEach(appState.locations) { location in
                        HStack {
                            Text(location.name)
                                .fontWeight(appState.activeLocation.id == location.id ? .bold : .regular)
                            Spacer()
                            if appState.activeLocation.id == location.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.activeLocation = location
                            dismiss()
                        }
                        .accessibilityIdentifier("LocationRow-\(location.name)")
                    }
                }

                Section {
                    Button(action: {
                        showingAddAlert = true
                    }) {
                        Label("Add New Location", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("AddLocationButton")
                }
            }
            .navigationTitle("Storage Locations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("LocationPickerDoneButton")
                }
            }
            .alert("New Storage Location", isPresented: $showingAddAlert) {
                TextField("Location Name (e.g., Box 2)", text: $newLocationName)
                Button("Cancel", role: .cancel) {
                    newLocationName = ""
                }
                Button("Add") {
                    let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let newLoc = StorageLocation(name: trimmed)
                        appState.locations.append(newLoc)
                        appState.activeLocation = newLoc
                    }
                    newLocationName = ""
                    dismiss()
                }
            } message: {
                Text("Enter a name for the new physical storage location.")
            }
        }
    }
}
