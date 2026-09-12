import SwiftUI

struct TabViewMain: View {
    @State private var selectedTab: Int = TabViewMain.initialTab

    /// Debug builds accept `-startTab N` so a screen can be opened directly for a
    /// screenshot pass — checking every tab at an accessibility text size otherwise
    /// means driving the UI by hand. Compiled out of release entirely.
    private static var initialTab: Int {
        #if DEBUG
        let requested = UserDefaults.standard.integer(forKey: "startTab")
        return (0...4).contains(requested) ? requested : 0
        #else
        return 0
        #endif
    }
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(session)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            InvoiceView()
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
                .tag(1)
            
            ClientView()
                .tabItem {
                    Label("Clients", systemImage: "person")
                }
                .tag(2)
            
            ItemsView()
                .tabItem {
                    Label("Items", systemImage: "square.grid.2x2")
                }
                .tag(3)
            
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(4)
        }
        .tint(Color.sAccent) // ← violet accent
    }
}

#Preview {
    TabViewMain()
        .environmentObject(SessionManager.shared)
}
