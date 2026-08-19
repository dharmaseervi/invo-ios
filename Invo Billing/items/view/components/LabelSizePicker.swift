//
//  LabelSizePicker.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/18/25.
//


import SwiftUI

struct PrintLabelScreen: View {
    let item: ItemResponse
    @State private var selectedSize: LabelSize = .medium
    
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            
            // ✅ Preview
            if let previewImage = PrintImageBuilder.makeQRCodeLabelImage(
                item: item,
                size: selectedSize,
                scale: displayScale
            ) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 4)
            }
            
            // ✅ Size picker
            Picker("Label Size", selection: $selectedSize) {
                Text("Small").tag(LabelSize.small)
                Text("Medium").tag(LabelSize.medium)
                Text("Large").tag(LabelSize.large)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Spacer()
            
            // ✅ Print button
            Button {
                printLabel()
            } label: {
                HStack {
                    Image(systemName: "printer.fill")
                    Text("Print Label")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Print Label")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func printLabel() {
        guard let image = PrintImageBuilder.makeQRCodeLabelImage(
            item: item,
            size: selectedSize,
            scale: displayScale
        ) else { return }
        
        PrintManager.printImage(
            image,
            jobName: "QR-\(item.name)"
        )
    }
}
