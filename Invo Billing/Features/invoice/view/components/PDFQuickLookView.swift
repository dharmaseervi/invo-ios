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
                HStack(spacing: 16) {
                    
                    // Back
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Share
                    Button {
                        sharePDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Download
                    Button {
                        saveToFiles()
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Print
                    Button {
                        printPDF()
                    } label: {
                        Image(systemName: "printer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
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

