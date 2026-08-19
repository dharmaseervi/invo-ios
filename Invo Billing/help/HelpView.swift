//
//  HelpView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 3/31/26.
//


import SwiftUI

struct HelpView: View {
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: Header
            VStack(alignment: .leading, spacing: 16) {
                Text("HELP")
                    .font(.system(size: 28, weight: .thin))
                    .tracking(0.5)
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            ScrollView {
                VStack(spacing: 0) {
                    
                    // MARK: Contact
                    sectionHeader("CONTACT")
                    
                    VStack(spacing: 0) {
                        
                        Button {
                            openEmail()
                        } label: {
                            row("Email Support")
                        }
                        
                        divider()
                        
                        Button {
                            openWhatsApp()
                        } label: {
                            row("WhatsApp Support")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                
                    
                    // MARK: About
                    sectionHeader("ABOUT")
                    
                    VStack(spacing: 0) {
                        row("Version 1.0.0")
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .navigationBarHidden(false)
    }
    
    // MARK: Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func row(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .light))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.3))
        }
        .padding(.vertical, 12)
    }
    
    private func divider() -> some View {
        Divider()
            .background(Color.black.opacity(0.08))
    }
    
    // MARK: Actions
    
    func openEmail() {
        let email = "dharmarvi.dev@gmail.com"
        let urlString = "mailto:\(email)"
        
        guard let url = URL(string: urlString) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            print("No email app available")
            // Optional: show alert to user
        }
    }
    private func openWhatsApp() {
        let phone = "919902464181"
        if let url = URL(string: "https://wa.me/\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}
