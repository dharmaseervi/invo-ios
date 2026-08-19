import Combine
import SwiftUI

struct ItemFormView: View {
    @StateObject var vm = ItemViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .light))
                        }
                        .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text("NEW ITEM")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "box.2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                
                // MARK: - Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ItemDetailsSection(vm: vm)
                        PricingStockSection(vm: vm)
                    }
                    .padding(.bottom, 20)
                }
                
                // MARK: - Fixed Bottom Buttons (OUTSIDE ScrollView)
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            let success = await vm.createItem()
                            if success {
                                vm.resetForm()
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("CREATE ITEM")
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(0.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .foregroundColor(.white)
                    }
                    .disabled(vm.isLoading)
                    
                    Button(action: {
                        vm.resetForm()
                    }) {
                        Text("CLEAR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                    .disabled(vm.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 60) // Extra padding for tab bar
                .background(Color.white) // Solid background so content doesn't show through
            }
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }
}

