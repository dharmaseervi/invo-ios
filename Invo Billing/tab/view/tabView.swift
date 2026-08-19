import SwiftUI

struct TabViewMain: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView() {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(0)
            
            InvoiceView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Invoices")
                }
                .tag(1)
            
            clientView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Clients")
                }
                .tag(2)
            
            itemsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Items")
                }
                .tag(3)
            
            MoreView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("More")
                }
                .tag(4)
        }
        .tint(.black)
    }
}

#Preview {
    TabViewMain()
}
