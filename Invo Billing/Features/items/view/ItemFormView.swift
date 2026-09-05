import Combine
import SwiftUI

struct ItemFormView: View {
    @StateObject var vm = ItemViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ItemDetailsSection(vm: vm)
                        PricingStockSection(vm: vm)
                    }
                    .padding(.bottom, 20)
                }

                // MARK: - Fixed Bottom Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        Task {
                            let success = await vm.createItem()
                            if success {
                                vm.resetForm()
                                dismiss()
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.sAccentFG)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Create item")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundColor(.sAccentFG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                        .cornerRadius(10)
                    }
                    .disabled(vm.isLoading || !vm.isValid)

                    Button(action: {
                        vm.resetForm()
                    }) {
                        Text("Clear")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.sForeground)
                            .background(Color.sCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.sBorder, lineWidth: 0.5)
                            )
                            .cornerRadius(10)
                    }
                    .disabled(vm.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .background(Color.sBackground)
            }
        }
        .navigationTitle("New item")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }
}
