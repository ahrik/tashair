import AppKit
import CoreText
import SwiftUI
import TashAirCore

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

extension AirQualityLevel {
    var color: Color { Color(nsColor: NSColor(rgb: backgroundHex)) }
}

struct StatusBadgeStyle: Equatable, Sendable {
    var title: String
    var level: AirQualityLevel?
    var height: CGFloat
}

@MainActor enum StatusBadgeRenderer {
    static func image(_ style: StatusBadgeStyle) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let textSize = (style.title as NSString).size(withAttributes: [.font: font])
        let height = max(18, style.height)
        let size = NSSize(width: ceil(8 + 14 + 6 + textSize.width + 8), height: height)
        // AppKit renders the image at the destination display's pixel density.
        let image = NSImage(size: size, flipped: false) { bounds in
            let foreground = NSColor(rgb: style.level?.foregroundHex ?? 0xFFFFFF)
            let background = NSColor(rgb: style.level?.backgroundHex ?? 0x56616B)
            let text = NSAttributedString(string: style.title, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): foreground.cgColor
            ])
            let symbol = NSImage(systemSymbolName: "aqi.medium", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [foreground])))
            background.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: height / 2, yRadius: height / 2).fill()
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            symbol?.draw(in: NSRect(x: 8, y: (height - 14) / 2, width: 14, height: 14))
            context.restoreGState()
            context.saveGState()
            context.textMatrix = .identity
            let line = CTLineCreateWithAttributedString(text)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            _ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            context.textPosition = CGPoint(x: 28, y: floor((height - ascent - descent) / 2 + descent))
            CTLineDraw(line, context)
            context.restoreGState()
            return true
        }
        image.isTemplate = false
        return image
    }
}
