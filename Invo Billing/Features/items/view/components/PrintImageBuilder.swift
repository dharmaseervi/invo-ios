//
//  PrintImageBuilder.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/18/25.
//

import UIKit

enum PrintImageBuilder {

    static func generateQRCode(from string: String, scale: CGFloat) -> UIImage? {
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

    static func generateBarcode(from string: String, scale: CGFloat) -> UIImage? {
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
        scale: CGFloat,
        style: LabelStyle = LabelStyle()
    ) -> UIImage? {
        switch style.template {
        case .standard: return drawStandard(item, size, codeType, scale, style)
        case .bordered: return drawBordered(item, size, codeType, scale, style)
        case .compact: return drawCompact(item, size, codeType, scale, style)
        case .centered: return drawCentered(item, size, codeType, scale, style)
        }
    }

    // MARK: - Shared layout math

    private struct Metrics {
        let canvas: CGSize
        let titleSize: CGFloat
        let bodySize: CGFloat
        let smallSize: CGFloat

        init(_ size: LabelSize, _ style: LabelStyle) {
            canvas = size.canvasSize
            let maxTitle = canvas.height * 0.32
            let maxBody = canvas.height * 0.2
            titleSize = min(size.titleFontSize * style.titleScale, maxTitle)
            bodySize = min(size.bodyFontSize * style.bodyScale, maxBody)
            smallSize = max(6, bodySize - 2)
        }
    }

    // MARK: - Standard (name, thin rule, details stacked left; code top-right or bottom strip)

    private static func drawStandard(
        _ item: ItemResponse, _ size: LabelSize, _ codeType: LabelCodeType,
        _ scale: CGFloat, _ style: LabelStyle
    ) -> UIImage? {
        let m = Metrics(size, style)
        let canvas = m.canvas
        let codeAreaWidth = codeType == .qr ? size.qrSize.width : canvas.width - 24
        let textWidth = codeType == .qr ? canvas.width - codeAreaWidth - 36 : canvas.width - 24
        let bottomReserved: CGFloat = codeType == .barcode ? size.barcodeHeight + 14 : 0
        let maxY = canvas.height - bottomReserved - 8

        return UIGraphicsImageRenderer(size: canvas).image { _ in
            fillWhite(canvas)

            var y: CGFloat = 12
            y += drawFittedText(
                item.name, x: 12, y: y, width: textWidth,
                maxHeight: min(m.titleSize * 2.5, maxY - y),
                baseFontSize: m.titleSize, minFontSize: max(7, m.titleSize * 0.55),
                bold: true, alignment: style.textAlignment.nsAlignment
            ) + 6

            if y < maxY - 4 {
                drawRule(x: 12, y: y, width: textWidth)
                y += 6
            }

            drawDetailFields(item, style, m, x: 12, y: &y, width: textWidth, maxY: maxY)

            drawCode(item, codeType, size, scale, canvas: canvas, position: codeType == .qr ? .topRight : .bottomStrip)
        }
    }

    // MARK: - Bordered (framed card, name on a reversed header bar)

    private static func drawBordered(
        _ item: ItemResponse, _ size: LabelSize, _ codeType: LabelCodeType,
        _ scale: CGFloat, _ style: LabelStyle
    ) -> UIImage? {
        let m = Metrics(size, style)
        let canvas = m.canvas
        let margin: CGFloat = 6
        let headerHeight = min(m.titleSize * 1.9, canvas.height * 0.28)
        let codeAreaWidth = codeType == .qr ? size.qrSize.width : canvas.width - margin * 2 - 12
        let textWidth = codeType == .qr ? canvas.width - codeAreaWidth - margin * 2 - 24 : canvas.width - margin * 2 - 12
        let bottomReserved: CGFloat = codeType == .barcode ? size.barcodeHeight + 12 : 0
        let maxY = canvas.height - margin - bottomReserved

        return UIGraphicsImageRenderer(size: canvas).image { ctx in
            fillWhite(canvas)

            // Outer frame — makes even a mostly-empty big label look intentional.
            let borderRect = CGRect(x: margin / 2, y: margin / 2, width: canvas.width - margin, height: canvas.height - margin)
            UIColor.black.setStroke()
            let border = UIBezierPath(roundedRect: borderRect, cornerRadius: 6)
            border.lineWidth = 1.5
            border.stroke()

            // Header bar — name reversed (white on black), like a shop shelf tag.
            let headerRect = CGRect(x: margin, y: margin, width: canvas.width - margin * 2, height: headerHeight)
            UIColor.black.setFill()
            UIRectFill(headerRect)
            _ = drawFittedText(
                item.name, x: headerRect.minX + 8, y: headerRect.minY, width: headerRect.width - 16,
                maxHeight: headerRect.height,
                baseFontSize: m.titleSize, minFontSize: max(7, m.titleSize * 0.5),
                bold: true, alignment: style.textAlignment.nsAlignment, color: .white,
                verticalCenterIn: headerRect.height
            )

            var y = headerRect.maxY + 10
            drawDetailFields(item, style, m, x: margin + 6, y: &y, width: textWidth, maxY: maxY)

            drawCode(item, codeType, size, scale, canvas: canvas, position: codeType == .qr ? .bottomRight : .bottomStrip, inset: margin + 4)
        }
    }

    // MARK: - Compact (essentials only, tight spacing — best for small labels)

    private static func drawCompact(
        _ item: ItemResponse, _ size: LabelSize, _ codeType: LabelCodeType,
        _ scale: CGFloat, _ style: LabelStyle
    ) -> UIImage? {
        let m = Metrics(size, style)
        let canvas = m.canvas
        let codeAreaWidth = codeType == .qr ? size.qrSize.width * 0.85 : canvas.width - 16
        let textWidth = codeType == .qr ? canvas.width - codeAreaWidth - 20 : canvas.width - 16
        let bottomReserved: CGFloat = codeType == .barcode ? size.barcodeHeight * 0.85 + 8 : 0
        let maxY = canvas.height - bottomReserved - 6

        return UIGraphicsImageRenderer(size: canvas).image { _ in
            fillWhite(canvas)

            var y: CGFloat = 8
            y += drawFittedText(
                item.name, x: 8, y: y, width: textWidth,
                maxHeight: min(m.titleSize * 1.3, maxY - y), // single line by design — compact means compact
                baseFontSize: m.titleSize, minFontSize: max(7, m.titleSize * 0.6),
                bold: true, alignment: style.textAlignment.nsAlignment
            ) + 3

            if style.showPrice {
                let remaining = max(0, maxY - y)
                let minNeeded = max(6, m.bodySize * 0.7)
                if remaining >= minNeeded {
                    let price = "₹\(String(format: "%.2f", item.price))"
                    y += drawFittedText(
                        price, x: 8, y: y, width: textWidth,
                        maxHeight: min(m.bodySize + 4, remaining),
                        baseFontSize: m.bodySize, minFontSize: minNeeded,
                        bold: true, alignment: style.textAlignment.nsAlignment
                    ) + 2
                }
            }
            // Compact deliberately skips ID/cost-code even if toggled on — the whole
            // point is fitting on the smallest labels without crowding.

            drawCode(
                item, codeType, size, scale, canvas: canvas,
                position: codeType == .qr ? .topRight : .bottomStrip,
                scaleFactor: 0.85
            )
        }
    }

    // MARK: - Centered (everything centered; code is the focal point at the bottom)

    private static func drawCentered(
        _ item: ItemResponse, _ size: LabelSize, _ codeType: LabelCodeType,
        _ scale: CGFloat, _ style: LabelStyle
    ) -> UIImage? {
        let m = Metrics(size, style)
        let canvas = m.canvas
        let textWidth = canvas.width - 24

        // Code sized generously and placed bottom-center — this template is built
        // around making full use of tall/large canvases instead of leaving them empty.
        let codeSide = min(canvas.width * 0.55, canvas.height * 0.5)
        let codeHeight = codeType == .qr ? codeSide : min(size.barcodeHeight * 1.3, canvas.height * 0.28)
        let codeTop = canvas.height - codeHeight - 14
        let maxY = codeTop - 8

        return UIGraphicsImageRenderer(size: canvas).image { _ in
            fillWhite(canvas)

            var y: CGFloat = 16
            y += drawFittedText(
                item.name, x: 12, y: y, width: textWidth,
                maxHeight: min(m.titleSize * 2.5, maxY - y),
                baseFontSize: m.titleSize, minFontSize: max(7, m.titleSize * 0.55),
                bold: true, alignment: .center
            ) + 8

            drawDetailFields(item, style, m, x: 12, y: &y, width: textWidth, maxY: maxY, forceCenter: true)

            switch codeType {
            case .qr:
                if let qr = generateQRCode(from: "ITEM_ID:\(item.id)", scale: scale) {
                    qr.draw(in: CGRect(x: (canvas.width - codeSide) / 2, y: codeTop, width: codeSide, height: codeSide))
                }
            case .barcode:
                if let barcode = generateBarcode(from: "ITEM_ID:\(item.id)", scale: scale) {
                    let width = canvas.width - 24
                    barcode.draw(in: CGRect(x: 12, y: codeTop, width: width, height: codeHeight))
                }
            }
        }
    }

    // MARK: - Shared field stack (price / ID / cost code)

    /// Draws price, ID, and cost code stacked below `y` (advancing it), skipping a field
    /// only when there's genuinely no room left — not based on a position check taken
    /// before knowing how much space that field actually needs.
    private static func drawDetailFields(
        _ item: ItemResponse, _ style: LabelStyle, _ m: Metrics,
        x: CGFloat, y: inout CGFloat, width: CGFloat, maxY: CGFloat,
        forceCenter: Bool = false
    ) {
        let alignment: NSTextAlignment = forceCenter ? .center : style.textAlignment.nsAlignment

        if style.showPrice {
            let remaining = max(0, maxY - y)
            let minNeeded = max(6, m.bodySize * 0.7)
            if remaining >= minNeeded {
                let price = "₹\(String(format: "%.2f", item.price))"
                y += drawFittedText(
                    price, x: x, y: y, width: width,
                    maxHeight: min(m.bodySize + 6, remaining),
                    baseFontSize: m.bodySize, minFontSize: minNeeded,
                    bold: true, alignment: alignment
                ) + 6
            }
        }

        // A human-meaningful SKU is far more useful on a physical label than the raw
        // database id — skip the line entirely if the item has no SKU set rather than
        // printing "SKU:" with nothing after it.
        if style.showID, let sku = item.sku, !sku.isEmpty {
            let remaining = max(0, maxY - y)
            let minNeeded = max(6, m.smallSize * 0.7)
            if remaining >= minNeeded {
                y += drawFittedText(
                    "SKU: \(sku)", x: x, y: y, width: width,
                    maxHeight: min(m.smallSize + 5, remaining),
                    baseFontSize: m.smallSize, minFontSize: minNeeded,
                    bold: false, alignment: alignment
                ) + 4
            }
        }

        if style.showCostCode, let cost = item.cost_price, cost > 0 {
            let remaining = max(0, maxY - y)
            let minNeeded = max(6, m.smallSize * 0.7)
            if remaining >= minNeeded {
                let codeText = CostPriceCoder.encode(cost)
                y += drawFittedText(
                    codeText, x: x, y: y, width: width,
                    maxHeight: min(m.smallSize + 5, remaining),
                    baseFontSize: m.smallSize, minFontSize: minNeeded,
                    bold: false, alignment: alignment
                )
            }
        }
    }

    // MARK: - Code placement

    private enum CodePosition {
        case topRight, bottomRight, bottomStrip
    }

    private static func drawCode(
        _ item: ItemResponse, _ codeType: LabelCodeType, _ size: LabelSize, _ scale: CGFloat,
        canvas: CGSize, position: CodePosition, inset: CGFloat = 12, scaleFactor: CGFloat = 1.0
    ) {
        let codeData = "ITEM_ID:\(item.id)"
        switch codeType {
        case .qr:
            guard let qr = generateQRCode(from: codeData, scale: scale) else { return }
            let side = size.qrSize.width * scaleFactor
            let frame: CGRect
            switch position {
            case .topRight, .bottomStrip:
                frame = CGRect(x: canvas.width - side - inset, y: 16, width: side, height: side)
            case .bottomRight:
                frame = CGRect(x: canvas.width - side - inset, y: canvas.height - side - inset, width: side, height: side)
            }
            qr.draw(in: frame)
        case .barcode:
            guard let barcode = generateBarcode(from: codeData, scale: scale) else { return }
            let height = size.barcodeHeight * scaleFactor
            let frame = CGRect(x: inset, y: canvas.height - height - inset, width: canvas.width - inset * 2, height: height)
            barcode.draw(in: frame)
        }
    }

    // MARK: - Small drawing helpers

    private static func fillWhite(_ size: CGSize) {
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
    }

    private static func drawRule(x: CGFloat, y: CGFloat, width: CGFloat) {
        UIColor.black.setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: 1))
    }

    /// Draws text wrapped within `width`, shrinking the font (down to `minFontSize`)
    /// rather than ever letting it get clipped or cut off mid-word. Returns the height
    /// actually used, so the caller can stack the next field directly beneath it.
    @discardableResult
    private static func drawFittedText(
        _ text: String,
        x: CGFloat, y: CGFloat, width: CGFloat, maxHeight: CGFloat,
        baseFontSize: CGFloat, minFontSize: CGFloat,
        bold: Bool, alignment: NSTextAlignment, color: UIColor = .black,
        verticalCenterIn totalHeight: CGFloat? = nil
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping

        let nsText = text as NSString
        var fontSize = max(baseFontSize, minFontSize)

        while true {
            let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .paragraphStyle: paragraph, .foregroundColor: color,
            ]
            let bounding = nsText.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs, context: nil
            )
            let fits = bounding.height <= maxHeight
            if fits || fontSize <= minFontSize {
                let drawHeight = min(bounding.height, maxHeight)
                let drawY = totalHeight.map { y + max(0, ($0 - drawHeight) / 2) } ?? y
                nsText.draw(
                    with: CGRect(x: x, y: drawY, width: width, height: drawHeight),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs, context: nil
                )
                return drawHeight
            }
            fontSize -= 1
        }
    }
}

enum LabelCodeType: String, CaseIterable {
    case qr = "QR Code"
    case barcode = "Barcode"
}

enum LabelSize: CaseIterable, Equatable {
    case small
    case medium
    case large
    case xlarge
    case jumbo
    case shipping

    var canvasSize: CGSize {
        switch self {
        case .small:    return CGSize(width: 200, height: 120)  // 58mm
        case .medium:   return CGSize(width: 300, height: 180)  // default
        case .large:    return CGSize(width: 400, height: 240)  // 80mm
        case .xlarge:   return CGSize(width: 400, height: 200)  // 4in x 2in @ 100pt/in
        case .jumbo:    return CGSize(width: 400, height: 300)  // 4in x 3in @ 100pt/in
        case .shipping: return CGSize(width: 400, height: 600)  // 4in x 6in @ 100pt/in
        }
    }

    var qrSize: CGSize {
        switch self {
        case .small:    return CGSize(width: 60, height: 60)
        case .medium:   return CGSize(width: 90, height: 90)
        case .large:    return CGSize(width: 120, height: 120)
        case .xlarge:   return CGSize(width: 140, height: 140)
        case .jumbo:    return CGSize(width: 160, height: 160)
        case .shipping: return CGSize(width: 180, height: 180)
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .xlarge: return 22
        case .jumbo: return 26
        case .shipping: return 28
        }
    }

    var bodyFontSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 14
        case .large: return 18
        case .xlarge: return 16
        case .jumbo: return 18
        case .shipping: return 20
        }
    }

    var barcodeHeight: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 50
        case .large: return 64
        case .xlarge: return 70
        case .jumbo: return 80
        case .shipping: return 100
        }
    }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xlarge: return "XL"
        case .jumbo: return "Jumbo"
        case .shipping: return "Shipping"
        }
    }

    var subtitle: String {
        switch self {
        case .small: return "58mm"
        case .medium: return "Default"
        case .large: return "80mm"
        case .xlarge: return "4×2in"
        case .jumbo: return "4×3in"
        case .shipping: return "4×6in"
        }
    }
}
