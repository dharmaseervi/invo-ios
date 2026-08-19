import SwiftUI

struct ClientDetailedView: View {
    let client: ClientModel
    @Environment(\.dismiss) var dismiss
    
    var avatarLetter: String {
        String(client.name.prefix(1)).uppercased()
    }
    @StateObject private var vm = ClientViewModel()
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // MARK: - Header with Back Button
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .light, design: .default))
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("CLIENT DETAILS")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    VStack(spacing: 0) {
                        
                        // MARK: - Profile Header
                        VStack(spacing: 20) {
                            // Avatar
                            Text(avatarLetter)
                                .font(.system(size: 48, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .background(Color.black)
                                .cornerRadius(8)
                            
                            // Name
                            Text(client.name)
                                .font(.system(size: 24, weight: .thin, design: .default))
                                .tracking(0.3)
                                .foregroundColor(.black)
                            
                            // Divider
                            Divider()
                                .frame(height: 1)
                                .background(Color.black.opacity(0.1))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 28)
                        
                        // MARK: - Contact Information Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CONTACT INFORMATION")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .tracking(1)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(
                                    icon: "envelope",
                                    title: "Email",
                                    value: client.email
                                )
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                DetailInfoRow(
                                    icon: "phone",
                                    title: "Phone",
                                    value: client.phone
                                )
                            }
                        }
                        .padding(.bottom, 32)
                        
                        // MARK: - Address Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ADDRESS")
                                .font(.system(size: 11, weight: .semibold, design: .default))
                                .tracking(1)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(
                                    icon: "house",
                                    title: "Street",
                                    value: client.address
                                )
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                HStack(spacing: 0) {
                                    DetailInfoRowHalf(
                                        icon: "building.2",
                                        title: "City",
                                        value: client.city
                                    )
                                    
                                    Divider()
                                        .frame(width: 1)
                                        .background(Color.black.opacity(0.08))
                                    
                                    DetailInfoRowHalf(
                                        icon: "map",
                                        title: "State",
                                        value: client.state
                                    )
                                }
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                    .padding(.horizontal, 24)
                                
                                DetailInfoRow(
                                    icon: "number",
                                    title: "Pincode",
                                    value: client.pincode
                                )
                            }
                        }
                        .padding(.bottom, 32)
                        
                        // MARK: - Invoices Section
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("INVOICES")
                                    .font(.system(size: 11, weight: .semibold, design: .default))
                                    .tracking(1)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Text("View All")
                                    .font(.system(size: 11, weight: .light, design: .default))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                            
                            if vm.invoices.isEmpty {
                                VStack(spacing: 16) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "document.text")
                                            .font(.system(size: 32, weight: .thin))
                                            .foregroundColor(.black.opacity(0.2))
                                        
                                        Text("No invoices yet")
                                            .font(.system(size: 13, weight: .light, design: .default))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.black.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                            }else {
                                VStack(spacing: 12) {
                                    ForEach(vm.invoices.prefix(3), id: \.id) { (invoice: InvoiceResponse) in
                                        HStack {
                                            Text(invoice.invoice_number)
                                                .font(.system(size: 13))
                                            
                                            Spacer()
                                            
                                            Text("₹\(invoice.total, specifier: "%.2f")")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                            }
                            // MARK: - Financial Actions
                            VStack(spacing: 12) {
                                
                                NavigationLink {
                                    LedgerListView(clientID: client.id)
                                } label: {
                                    HStack {
                                        Image(systemName: "book")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("VIEW LEDGER")
                                            .font(.system(size: 12, weight: .semibold))
                                            .tracking(0.5)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                }
                                
                                NavigationLink {
                                    RecordPaymentView(
                                        vm: RecordPaymentViewModel(
                                            companyID: SessionManager.shared.selectedCompanyId ?? 0,
                                            clientID: client.id, context: PaymentContext.client
                                        )
                                    )
                                } label: {
                                    HStack {
                                        Image(systemName: "creditcard")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("RECORD PAYMENT")
                                            .font(.system(size: 12, weight: .semibold))
                                            .tracking(0.5)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundColor(.black)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                }

                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 65)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await vm.load(clientID: client.id) }
            }
            
        }
    }
    
    // MARK: - Detail Info Row
    struct DetailInfoRow: View {
        let icon: String
        let title: String
        let value: String
        
        var body: some View {
            if !value.isEmpty {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.black.opacity(0.4))
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 10, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.3)
                        
                        Text(value)
                            .font(.system(size: 13, weight: .light, design: .default))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
        }
    }
    
    // MARK: - Detail Info Row Half Width
    struct DetailInfoRowHalf: View {
        let icon: String
        let title: String
        let value: String
        
        var body: some View {
            if !value.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.black.opacity(0.4))
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 10, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.3)
                        
                        Text(value)
                            .font(.system(size: 13, weight: .light, design: .default))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
    }
}

