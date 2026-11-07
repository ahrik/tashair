import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        let shape = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 205, yRadius: 205)
        NSGradient(starting: NSColor(srgbRed: 0.04, green: 0.28, blue: 0.25, alpha: 1), ending: NSColor(srgbRed: 0.17, green: 0.63, blue: 0.48, alpha: 1))!.draw(in: shape, angle: 55)
        NSColor(srgbRed: 0.95, green: 0.81, blue: 0.4, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 590, y: 588, width: 170, height: 170)).fill()
        for (y, width) in [(570.0, 310.0), (445.0, 470.0), (320.0, 350.0)] {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 255, y: y))
            path.line(to: NSPoint(x: 255 + width, y: y))
            path.lineWidth = 49; path.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.94).setStroke(); path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
