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

        let canvas = size.canvasSize
        let renderer = UIGraphicsImageRenderer(size: canvas)

        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvas))

            let titleFont = UIFont.boldSystemFont(ofSize: size.titleFontSize)
            let bodyFont = UIFont.systemFont(ofSize: size.bodyFontSize)

            // Product name
            item.name.draw(
                in: CGRect(x: 12, y: 12, width: canvas.width - 140, height: 24),
                withAttributes: [.font: titleFont]
            )

            // Price
            let price = "₹\(String(format: "%.2f", item.price))"
            price.draw(
                in: CGRect(x: 12, y: 40, width: canvas.width - 140, height: 20),
                withAttributes: [.font: bodyFont]
            )

            // ID
            let idText = "ID: \(item.id)"
            idText.draw(
                in: CGRect(x: 12, y: 62, width: canvas.width - 140, height: 18),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: size.bodyFontSize - 2),
                    .foregroundColor: UIColor.gray,
                ]
            )

            // QR Code
            let qrData = "ITEM_ID:\(item.id)"



            if let qr = generateQRCode(from: qrData, scale: scale) {
                let qrFrame = CGRect(
                    x: canvas.width - size.qrSize.width - 12,
                    y: 20,
                    width: size.qrSize.width,
                    height: size.qrSize.height
                )
                qr.draw(in: qrFrame)
            }
        }
    }

}

enum LabelSize {
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
}
