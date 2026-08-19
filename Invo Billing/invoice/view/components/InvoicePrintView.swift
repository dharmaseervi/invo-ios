import SwiftUI
import PDFKit

struct InvoicePrintView: View {
    let invoiceDetail: InvoiceDetailResponse
    @Environment(\.dismiss) var dismiss
    @State private var pdfURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
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
                                    .font(.system(size: 14, weight: .light, design: .default))
                            }
                            .foregroundColor(.black)
                        }
                        Spacer()
                        Text("PRINT INVOICE")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        Spacer()
                        Menu {
                            Button(action: { downloadPDF() }) {
                                Label("Download PDF", systemImage: "arrow.down.doc")
                            }
                            Button(action: { sharePDF() }) {
                                Label("Share PDF", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .disabled(pdfURL == nil)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // MARK: - Print Document Preview
                            VStack(alignment: .leading, spacing: 0) {
                                // Header Section with Title and Invoice Number
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("INVOICE")
                                        .font(.system(size: 36, weight: .light, design: .default))
                                        .tracking(0.8)
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Invoice Number")
                                                .font(.system(size: 9, weight: .semibold, design: .default))
                                                .foregroundColor(.gray)
                                                .tracking(0.5)
                                            Text(invoiceDetail.invoice_number)
                                                .font(.system(size: 14, weight: .semibold, design: .default))
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(24)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.12))
                                
                                // From / Bill To / Invoice Details
                                VStack(spacing: 20) {
                                    HStack(alignment: .top, spacing: 40) {
                                        // FROM Section
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("FROM")
                                                .font(.system(size: 9, weight: .semibold, design: .default))
                                                .foregroundColor(.gray)
                                                .tracking(0.5)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Your Company")
                                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                                Text("123 Business Street")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                                Text("City, State 123456")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        // BILL TO Section
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("BILL TO")
                                                .font(.system(size: 9, weight: .semibold, design: .default))
                                                .foregroundColor(.gray)
                                                .tracking(0.5)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Client Name")
                                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                                Text("123 Client Street")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                                Text("City, State 123456")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Invoice Info (Right side)
                                        VStack(alignment: .trailing, spacing: 12) {
                                            InvoiceDetailItem(label: "Invoice Date", value: invoiceDetail.invoice_date)
                                            InvoiceDetailItem(label: "Due Date", value: invoiceDetail.due_date)
                                        }
                                    }
                                }
                                .padding(24)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                
                                // Items Table Header
                                HStack(spacing: 0) {
                                    Text("DESCRIPTION")
                                        .font(.system(size: 9, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("QTY")
                                        .font(.system(size: 9, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .foregroundColor(.black)
                                        .frame(width: 50, alignment: .center)
                                    
                                    Text("RATE")
                                        .font(.system(size: 9, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .foregroundColor(.black)
                                        .frame(width: 80, alignment: .trailing)
                                    
                                    Text("AMOUNT")
                                        .font(.system(size: 9, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .foregroundColor(.black)
                                        .frame(width: 100, alignment: .trailing)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Color.black.opacity(0.03))
                                
                                // Items Table Rows
                                VStack(spacing: 0) {
                                    ForEach(invoiceDetail.items.indices, id: \.self) { index in
                                        let item = invoiceDetail.items[index]
                                        VStack(spacing: 0) {
                                            HStack(spacing: 0) {
                                                Text(item.item_id > 0 ? "Item #\(item.item_id)" : "Service")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                                Text("\(item.qty)")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                                    .frame(width: 50, alignment: .center)
                                                
                                                Text("₹\(String(format: "%.2f", item.rate))")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                                    .frame(width: 80, alignment: .trailing)
                                                
                                                Text("₹\(String(format: "%.2f", item.total))")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                                    .frame(width: 100, alignment: .trailing)
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            
                                            if index != invoiceDetail.items.indices.last {
                                                Divider()
                                                    .frame(height: 0.5)
                                                    .background(Color.black.opacity(0.05))
                                                    .padding(.horizontal, 24)
                                            }
                                        }
                                    }
                                }
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.black.opacity(0.08))
                                
                                // Summary Section
                                VStack(alignment: .trailing, spacing: 0) {
                                    HStack {
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 12) {
                                            HStack(spacing: 20) {
                                                Text("Subtotal")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                                Text("₹\(String(format: "%.2f", invoiceDetail.subtotal))")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                            }
                                            
                                            HStack(spacing: 20) {
                                                Text("Tax")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                                Text("₹\(String(format: "%.2f", invoiceDetail.tax))")
                                                    .font(.system(size: 10, weight: .light, design: .default))
                                                    .foregroundColor(.black)
                                            }
                                            
                                            Divider()
                                                .frame(height: 1)
                                                .background(Color.black.opacity(0.3))
                                            
                                            HStack(spacing: 20) {
                                                Text("TOTAL DUE")
                                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                                    .foregroundColor(.black)
                                                Text("₹\(String(format: "%.2f", invoiceDetail.total))")
                                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .frame(width: 220, alignment: .trailing)
                                    }
                                }
                                .padding(24)
                                
                                // Footer
                                VStack(alignment: .center, spacing: 8) {
                                    Text("Thank you for your business")
                                        .font(.system(size: 11, weight: .light, design: .default))
                                        .foregroundColor(.gray)
                                    Text("Please make payment by the due date")
                                        .font(.system(size: 10, weight: .light, design: .default))
                                        .foregroundColor(.gray.opacity(0.6))
                                        .tracking(0.2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 32)
                            }
                            .background(Color.white)
                            .border(Color.black, width: 1)
                            .padding(20)
                            .padding(.bottom, 24)
                        }
                    }
                    
                    // MARK: - Action Buttons
                    VStack(spacing: 12) {
                        Button(action: { printInvoice() }) {
                            HStack {
                                Image(systemName: "printer.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("PRINT")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .foregroundColor(.white)
                        }
                        .disabled(pdfURL == nil)
                        .opacity(pdfURL == nil ? 0.5 : 1.0)
                        
                        Button(action: { downloadPDF() }) {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("DOWNLOAD PDF")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                        }
                        .disabled(pdfURL == nil)
                        .opacity(pdfURL == nil ? 0.5 : 1.0)
                        
                        Button(action: { dismiss() }) {
                            Text("CLOSE")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .tracking(0.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.black.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                generatePDF()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - PDF Generation
    private func generatePDF() {
        
        
        
        
        
        
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let pdfData = pdfRenderer.pdfData { context in
            context.beginPage()
            let pageWidth = 595.0
            let margin = 40.0
            var yPosition = margin
            
            // Title
            let titleFont = UIFont.systemFont(ofSize: 36, weight: .light)
            let titleAttributes = [NSAttributedString.Key.font: titleFont]
            let titleStr = "INVOICE"
            let titleSize = titleStr.size(withAttributes: titleAttributes)
            titleStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += titleSize.height + 12
            
            // Invoice Number Label and Value
            let labelFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let labelAttributes = [NSAttributedString.Key.font: labelFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
            "Invoice Number".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
            yPosition += 14
            
            let numFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let numAttributes = [NSAttributedString.Key.font: numFont]
            invoiceDetail.invoice_number.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: numAttributes)
            yPosition += 20
            
            // Divider Line
            UIColor.black.setStroke()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: yPosition))
            linePath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            linePath.lineWidth = 1
            linePath.stroke()
            yPosition += 20
            
            // From & Bill To & Invoice Info (3 columns)
            let fromLabelFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let fromLabelAttributes = [NSAttributedString.Key.font: fromLabelFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
            
            let fromContentFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let fromContentAttributes = [NSAttributedString.Key.font: fromContentFont]
            
            let detailFont = UIFont.systemFont(ofSize: 10, weight: .light)
            let detailAttributes = [NSAttributedString.Key.font: detailFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
            
            // FROM Column
            "FROM".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: fromLabelAttributes)
            yPosition += 14
            "Your Company".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: fromContentAttributes)
            yPosition += 14
            "123 Business Street".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: detailAttributes)
            yPosition += 12
            "City, State 123456".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: detailAttributes)
            
            // Reset for BILL TO
            yPosition -= 26
            
            // BILL TO Column
            let billToX = margin + 200
            "BILL TO".draw(at: CGPoint(x: billToX, y: yPosition), withAttributes: fromLabelAttributes)
            yPosition += 14
            "Client Name".draw(at: CGPoint(x: billToX, y: yPosition), withAttributes: fromContentAttributes)
            yPosition += 14
            "123 Client Street".draw(at: CGPoint(x: billToX, y: yPosition), withAttributes: detailAttributes)
            yPosition += 12
            "City, State 123456".draw(at: CGPoint(x: billToX, y: yPosition), withAttributes: detailAttributes)
            
            // Reset for Invoice Info (right side)
            yPosition -= 26
            
            // Invoice Info - Right side
            let infoLabelFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let infoLabelAttributes = [NSAttributedString.Key.font: infoLabelFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
            
            let infoValueFont = UIFont.systemFont(ofSize: 10, weight: .light)
            let infoValueAttributes = [NSAttributedString.Key.font: infoValueFont]
            
            let infoX = pageWidth - margin - 150
            
            "Invoice Date".draw(at: CGPoint(x: infoX, y: yPosition), withAttributes: infoLabelAttributes)
            yPosition += 12
            invoiceDetail.invoice_date.draw(at: CGPoint(x: infoX, y: yPosition), withAttributes: infoValueAttributes)
            yPosition += 16
            
            "Due Date".draw(at: CGPoint(x: infoX, y: yPosition), withAttributes: infoLabelAttributes)
            yPosition += 12
            invoiceDetail.due_date.draw(at: CGPoint(x: infoX, y: yPosition), withAttributes: infoValueAttributes)
            
            yPosition += 30
            
            // Divider Line
            UIColor.black.setStroke()
            let linePath2 = UIBezierPath()
            linePath2.move(to: CGPoint(x: margin, y: yPosition))
            linePath2.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            linePath2.lineWidth = 0.5
            linePath2.stroke()
            yPosition += 20
            
            // Items Table Header
            UIColor(white: 0, alpha: 0.03).setFill()
            let headerRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2*margin, height: 22)
            
            
            let headerFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let headerAttributes = [NSAttributedString.Key.font: headerFont]
            "DESCRIPTION".draw(at: CGPoint(x: margin + 10, y: yPosition + 4), withAttributes: headerAttributes)
            "QTY".draw(at: CGPoint(x: pageWidth - margin - 200, y: yPosition + 4), withAttributes: headerAttributes)
            "RATE".draw(at: CGPoint(x: pageWidth - margin - 120, y: yPosition + 4), withAttributes: headerAttributes)
            "AMOUNT".draw(at: CGPoint(x: pageWidth - margin - 60, y: yPosition + 4), withAttributes: headerAttributes)
            yPosition += 28
            
            // Items
            let itemFont = UIFont.systemFont(ofSize: 10, weight: .light)
            let itemAttributes = [NSAttributedString.Key.font: itemFont]
            for item in invoiceDetail.items {
                "Item #\(item.item_id)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: itemAttributes)
                "\(item.qty)".draw(at: CGPoint(x: pageWidth - margin - 200, y: yPosition), withAttributes: itemAttributes)
                String(format: "₹%.2f", item.rate).draw(at: CGPoint(x: pageWidth - margin - 120, y: yPosition), withAttributes: itemAttributes)
                String(format: "₹%.2f", item.total).draw(at: CGPoint(x: pageWidth - margin - 60, y: yPosition), withAttributes: itemAttributes)
                yPosition += 18
            }
            yPosition += 10
            
            // Divider Line
            UIColor.black.setStroke()
            let linePath3 = UIBezierPath()
            linePath3.move(to: CGPoint(x: margin, y: yPosition))
            linePath3.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            linePath3.lineWidth = 0.5
            linePath3.stroke()
            yPosition += 20
            
            // Summary
            let summaryLabelFont = UIFont.systemFont(ofSize: 10, weight: .light)
            let summaryLabelAttributes = [NSAttributedString.Key.font: summaryLabelFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
            
            let summaryValueFont = UIFont.systemFont(ofSize: 10, weight: .light)
            let summaryValueAttributes = [NSAttributedString.Key.font: summaryValueFont]
            
            let summaryX = pageWidth - margin - 150
            
            "Subtotal".draw(at: CGPoint(x: summaryX, y: yPosition), withAttributes: summaryLabelAttributes)
            String(format: "₹%.2f", invoiceDetail.subtotal).draw(at: CGPoint(x: pageWidth - margin - 50, y: yPosition), withAttributes: summaryValueAttributes)
            yPosition += 18
            
            "Tax".draw(at: CGPoint(x: summaryX, y: yPosition), withAttributes: summaryLabelAttributes)
            String(format: "₹%.2f", invoiceDetail.tax).draw(at: CGPoint(x: pageWidth - margin - 50, y: yPosition), withAttributes: summaryValueAttributes)
            yPosition += 20
            
            let totalFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let totalAttributes = [NSAttributedString.Key.font: totalFont]
            "TOTAL DUE".draw(at: CGPoint(x: summaryX, y: yPosition), withAttributes: totalAttributes)
            String(format: "₹%.2f", invoiceDetail.total).draw(at: CGPoint(x: pageWidth - margin - 50, y: yPosition), withAttributes: totalAttributes)
        }
        
        // Save PDF
        let filename = "Invoice_\(invoiceDetail.invoice_number)_\(Date().formatted(date: .abbreviated, time: .omitted)).pdf"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        do {
            try pdfData.write(to: fileURL)
            self.pdfURL = fileURL
        } catch {
            errorMessage = "Failed to generate PDF: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func printInvoice() {
        guard let pdfURL = pdfURL else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Invoice_\(invoiceDetail.invoice_number)"
        printInfo.orientation = .portrait
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printingItem = pdfURL
        printController.present(animated: true) { controller, completed, error in
            if completed {
                print("Print completed successfully")
            } else if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Print failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func downloadPDF() {
        guard let pdfURL = pdfURL else { return }
        let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .print
        ]
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func sharePDF() {
        downloadPDF()
    }
}

// MARK: - Invoice Detail Item Component
struct InvoiceDetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .default))
                .foregroundColor(.gray)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 10, weight: .light, design: .default))
                .foregroundColor(.black)
        }
    }
}
