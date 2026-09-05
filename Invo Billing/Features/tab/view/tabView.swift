import SwiftUI

struct TabViewMain: View {
    @State private var selectedTab: Int = 0
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
