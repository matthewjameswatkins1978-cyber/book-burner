import SwiftUI

public struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isTorchOn: Bool = false
    @State private var showingLocationPicker: Bool = false
    @State private var lastUndoneBookMessage: String? = nil
    @State private var showingSimulateScanAlert: Bool = false
    @State private var manualISBNInput: String = ""
    @State private var isAwaitingPhoto: Bool = false
    @State private var currentAssignedBBID: String = "BB-000001"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Active Location selector & Torch & Export Share
            HStack {
                Button(action: {
                    showingLocationPicker = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(appState.activeLocation.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .accessibilityIdentifier("ActiveLocationButton")

                Spacer()

                Button(action: {
                    isTorchOn.toggle()
                }) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                        .padding(8)
                    }
                .accessibilityIdentifier("TorchButton")
                .accessibilityLabel("Toggle Torch")
            }
            .padding()

            // Scanner Seam / Viewfinder Area
            ZStack {
                Color.black
                    .ignoresSafeArea(edges: .horizontal)

                VStack {
                    Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.8))
                    .accessibilityIdentifier("BarcodeScannerSeam")

                    Text(isAwaitingPhoto ? "Flip to Front & Capture Photo (\(currentAssignedBBID))" : "Align Barcode in Viewfinder")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 16)
                        .accessibilityIdentifier("FlipToFrontPrompt")
                }

                // Shutter / Capture Action button when awaiting photo or manual scan
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        // No-ISBN Escape button
                        Button(action: {
                            Task {
                                let bbid = await appState.captureStateMachine.handleNoISBN()
                                currentAssignedBBID = bbid.description
                                isAwaitingPhoto = true
                            }
                        }) {
                            Text("No ISBN")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                        .accessibilityIdentifier("NoISBNButton")

                        // Shutter button
                        Button(action: {
                            Task {
                                let samplePhotoData = "simulatedPhotoData".data(using: .utf8)!
                                if !isAwaitingPhoto {
                                    // Simulate scan
                                    _ = await appState.captureStateMachine.handleBarcodeScanned(rawISBN: "9780306406157")
                                    if let last = await appState.captureStateMachine.getLastCapturedBook() {
                                        currentAssignedBBID = last.bbidString
                                    }
                                    isAwaitingPhoto = true
                                } else {
                                    do {
                                        let book = try await appState.captureStateMachine.capturePhotoAndSave(imageData: samplePhotoData)
                                        appState.addBook(book)
                                        isAwaitingPhoto = false
                                    } catch {
                                        // Handle error
                                    }
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .stroke(Color.gray, lineWidth: 4)
                                    .frame(width: 82, height: 82)
                            }
                        }
                        .accessibilityIdentifier("ShutterButton")
                        .accessibilityLabel("Capture Shutter")

                        // Undo Last Book action
                        Button(action: {
                            Task {
                                do {
                                    let undone = try await appState.captureStateMachine.undoLastBook()
                                    if let undoneBook = undone {
                                        appState.deleteBook(id: undoneBook.id)
                                        lastUndoneBookMessage = "Undone \(undoneBook.bbidString)"
                                    }
                                } catch {
                                    lastUndoneBookMessage = "Undo failed"
                                }
                            }
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .accessibilityIdentifier("UndoLastBookButton")
                        .accessibilityLabel("Undo Last Book")
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView()
                .environmentObject(appState)
        }
        .overlay(
            Group {
                if let msg = lastUndoneBookMessage {
                    Text(msg)
                        .font(.caption)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                lastUndoneBookMessage = nil
                            }
                        }
                }
            }
        )
    }
}
