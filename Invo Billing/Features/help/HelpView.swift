//
//  HelpView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 3/31/26.
//


import SwiftUI

struct HelpView: View {

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {

                        // MARK: Contact
                        sectionHeader("Contact")

                        VStack(spacing: 0) {
                            Button {
                                openEmail()
                            } label: {
                                row("Email Support")
                            }

                            Rectangle().fill(Color.sBorder).frame(height: 0.5)

                            Button {
                                openWhatsApp()
                            } label: {
                                row("WhatsApp Support")
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(Color.sCard)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // MARK: About
                        sectionHeader("About")

                        VStack(spacing: 0) {
                            infoRow(appVersion)
                        }
                        .padding(.horizontal, 14)
                        .background(Color.sCard)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.sMutedFG)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.sForeground)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.sMutedFG)
        }
        .padding(.vertical, 12)
    }

    private func infoRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.sMutedFG)
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    // MARK: Actions

    func openEmail() {
        let email = "dharmarvi.dev@gmail.com"
        let urlString = "mailto:\(email)"

        guard let url = URL(string: urlString) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    private func openWhatsApp() {
        let phone = "919902464181"
        if let url = URL(string: "https://wa.me/\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}
