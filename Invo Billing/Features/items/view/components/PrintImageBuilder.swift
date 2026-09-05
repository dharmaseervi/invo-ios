//
//  PrintImageBuilder.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/18/25.
//

//
//  PrintImageBuilder.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/18/25.
//

import UIKit

enum PrintImageBuilder {

    static func generateQRCode(from string: String, scale: CGFloat) -> UIImage?
    {
        guard let data = string.data(using: .utf8),
            let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }

        return UIImage(
            ciImage: output.transformed(by: .init(scaleX: scale, y: scale))
        )
    }

    static func generateBarcode(from string: String, scale: CGFloat) -> UIImage?
    {
        guard let data = string.data(using: .utf8),
            let filter = CIFilter(name: "CICode128BarcodeGenerator")
        else { return nil }

        filter.setValue(data, forKey: "inputMessage")

        guard let output = filter.outputImage else { return nil }

        return UIImage(
            ciImage: output.transformed(
                by: .init(scaleX: scale * 3, y: scale * 3)
            )
        )
    }

    static func makeQRCodeLabelImage(
        item: ItemResponse,
        size: LabelSize,
        scale: CGFloat
    ) -> UIImage? {
        makeLabelImage(item: item, size: size, codeType: .qr, scale: scale)
    }

    static func makeLabelImage(
        item: ItemResponse,
        size: LabelSize,
        codeType: LabelCodeType,
        scale: CGFloat
    ) -> UIImage? {

        let canvas = size.canvasSize
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let codeAreaWidth = codeType == .qr ? size.qrSize.width : size.canvasSize.width - 24

        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvas))

            let titleFont = UIFont.boldSystemFont(ofSize: size.titleFontSize)
            let bodyFont = UIFont.systemFont(ofSize: size.bodyFontSize)
            let textWidth = codeType == .qr ? canvas.width - codeAreaWidth - 36 : canvas.width - 24

            // Product name
            item.name.draw(
                in: CGRect(x: 12, y: 12, width: textWidth, height: 24),
                withAttributes: [.font: titleFont]
            )

            // Price
            let price = "₹\(String(format: "%.2f", item.price))"
            price.draw(
                in: CGRect(x: 12, y: 40, width: textWidth, height: 20),
                withAttributes: [.font: bodyFont]
            )

            // ID
            let idText = "ID: \(item.id)"
            idText.draw(
                in: CGRect(x: 12, y: 62, width: textWidth, height: 18),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: size.bodyFontSize - 2),
                    .foregroundColor: UIColor.gray,
                ]
            )

            let codeData = "ITEM_ID:\(item.id)"

            switch codeType {
            case .qr:
                if let qr = generateQRCode(from: codeData, scale: scale) {
                    let qrFrame = CGRect(
                        x: canvas.width - size.qrSize.width - 12,
                        y: 20,
                        width: size.qrSize.width,
                        height: size.qrSize.height
                    )
                    qr.draw(in: qrFrame)
                }
            case .barcode:
                if let barcode = generateBarcode(from: codeData, scale: scale) {
                    let barcodeFrame = CGRect(
                        x: 12,
                        y: canvas.height - size.barcodeHeight - 10,
                        width: canvas.width - 24,
                        height: size.barcodeHeight
                    )
                    barcode.draw(in: barcodeFrame)
                }
            }
        }
    }

}

enum LabelCodeType: String, CaseIterable {
    case qr = "QR Code"
    case barcode = "Barcode"
}

enum LabelSize: CaseIterable {
    case small
    case medium
    case large

    var canvasSize: CGSize {
        switch self {
        case .small:
            return CGSize(width: 200, height: 120)  // 58mm
        case .medium:
            return CGSize(width: 300, height: 180)  // default
        case .large:
            return CGSize(width: 400, height: 240)  // 80mm
        }
    }

    var qrSize: CGSize {
        switch self {
        case .small:
            return CGSize(width: 60, height: 60)
        case .medium:
            return CGSize(width: 90, height: 90)
        case .large:
            return CGSize(width: 120, height: 120)
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }

    var bodyFontSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 14
        case .large: return 18
        }
    }

    var barcodeHeight: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 50
        case .large: return 64
        }
    }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var subtitle: String {
        switch self {
        case .small: return "58mm"
        case .medium: return "Default"
        case .large: return "80mm"
        }
    }
}
