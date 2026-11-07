import AppKit
import Foundation

// Keep every macOS icon size in sync with the project's original logo.
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let source = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "assets/branding/tashair-logo.png")
guard let image = NSImage(contentsOf: source) else {
    throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: source.path])
}
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        // macOS safe area and rounded tile; the artwork remains an unmodified square master.
        let inset = CGFloat(pixels) * 0.068
        let bounds = NSRect(x: inset, y: inset, width: CGFloat(pixels) - 2 * inset, height: CGFloat(pixels) - 2 * inset)
        let radius = CGFloat(pixels) * 0.2
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).addClip()
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
