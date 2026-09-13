//
//  PDFLookView.swift
//  Invo Billing
//
//  Full PDF Viewer using QuickLook
//

import SwiftUI
import QuickLook
import UIKit

// MARK: - SwiftUI Wrapper

struct PDFLookView: View {
    
    let pdfURL: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // PDF Preview
            PDFQuickLookViewer(url: pdfURL) {
                dismiss()
            }
            .ignoresSafeArea()
            
            // Top Action Bar
            VStack(spacing: 0) {
                // "Back" plus three icons in one row is the widest chrome in the app.
                // It fits a 440pt phone at the largest text size with little to spare,
                // and a 375pt phone — an SE or a mini, both of which run iOS 26 — is
                // 65pt narrower. Rather than pick a breakpoint, let the row measure
                // itself: the word "Back" is dropped only when it genuinely will not
                // fit, and the chevron alone still reads as a back button.
                ViewThatFits(in: .horizontal) {
                    actionBar(showsBackLabel: true)
                    actionBar(showsBackLabel: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.95))
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - QuickLook Controller

struct PDFQuickLookViewer: UIViewControllerRepresentable {
    
    let url: URL
    let onDismiss: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, onDismiss: onDismiss)
    }
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(
        _ uiViewController: QLPreviewController,
        context: Context
    ) {}
    
    // MARK: - Coordinator
    
    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        
        let url: URL
        let onDismiss: () -> Void
        
        init(url: URL, onDismiss: @escaping () -> Void) {
            self.url = url
            self.onDismiss = onDismiss
        }
        
        func numberOfPreviewItems(
            in controller: QLPreviewController
        ) -> Int {
            1
        }
        
        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as QLPreviewItem
        }
        
        func previewControllerWillDismiss(
            _ controller: QLPreviewController
        ) {
            onDismiss()
        }
    }
}

// MARK: - Actions

extension PDFLookView {
    

    private func actionBar(showsBackLabel: Bool) -> some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    if showsBackLabel {
                        Text("Back")
                    }
                }
                .font(.scaled(14, weight: .light))
                .foregroundColor(.white)
            }
            .accessibilityLabel("Back")

            Spacer()

            // Icon-only buttons need a spoken name; without one VoiceOver falls back to
            // guessing at the symbol and announces "square and arrow up".
            barButton("square.and.arrow.up", label: "Share PDF", action: sharePDF)
            barButton("arrow.down.doc", label: "Save to Files", action: saveToFiles)
            barButton("printer", label: "Print", action: printPDF)
        }
    }

    private func barButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.scaled(16, weight: .semibold))
                .foregroundColor(.white)
        }
        .accessibilityLabel(label)
    }

    private func sharePDF() {
        presentActivity(items: [pdfURL])
    }
    
    private func saveToFiles() {
        let picker = UIDocumentPickerViewController(
            forExporting: [pdfURL],
            asCopy: true
        )
        present(picker)
    }
    
    private func printPDF() {
        let controller = UIPrintInteractionController.shared
        controller.printingItem = pdfURL
        controller.present(animated: true)
    }
    
    private func presentActivity(items: [Any]) {
        let vc = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        present(vc)
    }
    
    private func present(_ vc: UIViewController) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
            var top = window.rootViewController
        else { return }

        // This view is itself shown inside a sheet, so the root controller is already
        // presenting something — asking it to present again does nothing at all, which is
        // why Share, Save to Files and Print were silently dead. Walk to whatever is
        // actually on top and present from there.
        while let presented = top.presentedViewController {
            top = presented
        }

        // On iPad an activity or document picker is a popover and needs an anchor.
        if let popover = vc.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        top.present(vc, animated: true)
    }
}

