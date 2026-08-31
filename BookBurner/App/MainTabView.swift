import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "barcode.viewfinder")
                }
                .accessibilityIdentifier("CaptureTab")

            NavigationView {
                BooksListView()
            }
            .tabItem {
                Label("Books", systemImage: "books.vertical.fill")
            }
            .accessibilityIdentifier("BooksTab")
        }
    }
}
