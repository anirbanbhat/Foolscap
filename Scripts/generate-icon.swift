// Renders the Foolscap app icon at every size .icns wants and writes them
// into <build>/AppIcon.iconset. Caller (build.sh) then runs `iconutil` to
// produce the .icns file.
//
// Compile + run as:
//   xcrun swiftc -framework AppKit -framework Foundation \
//       -o build/iconmaker Scripts/generate-icon.swift
//   build/iconmaker build/AppIcon.iconset

import AppKit
import Foundation

let sizes: [(String, Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",   128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",   256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",   512),
    ("icon_512x512@2x.png", 1024),
]

func renderIcon(pixelSize: Int) -> Data? {
    let size = CGFloat(pixelSize)

    // Render off-screen into a bitmap rep so this works headless.
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )
    guard let rep = rep else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22

    // 1. Rounded-rect background with vertical gradient (deep teal → near-black).
    let bgPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()
    let bg = NSGradient(colors: [
        NSColor(srgbRed: 0.12, green: 0.34, blue: 0.40, alpha: 1.0),
        NSColor(srgbRed: 0.04, green: 0.14, blue: 0.18, alpha: 1.0),
    ])
    bg?.draw(in: bounds, angle: 270)

    // 2. Paper sheet: cream rounded rect with a top-right corner fold.
    let inset = size * 0.18
    let paperRect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let foldSize = size * 0.18
    let paperPath = NSBezierPath()
    paperPath.move(to: NSPoint(x: paperRect.minX, y: paperRect.maxY))
    paperPath.line(to: NSPoint(x: paperRect.maxX - foldSize, y: paperRect.maxY))
    paperPath.line(to: NSPoint(x: paperRect.maxX, y: paperRect.maxY - foldSize))
    paperPath.line(to: NSPoint(x: paperRect.maxX, y: paperRect.minY))
    paperPath.line(to: NSPoint(x: paperRect.minX, y: paperRect.minY))
    paperPath.close()
    NSColor(srgbRed: 0.97, green: 0.96, blue: 0.91, alpha: 1.0).setFill()
    paperPath.fill()

    // 3. The folded corner — small triangle in a slightly darker shade.
    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: paperRect.maxX - foldSize, y: paperRect.maxY))
    foldPath.line(to: NSPoint(x: paperRect.maxX - foldSize, y: paperRect.maxY - foldSize))
    foldPath.line(to: NSPoint(x: paperRect.maxX, y: paperRect.maxY - foldSize))
    foldPath.close()
    NSColor(srgbRed: 0.83, green: 0.81, blue: 0.74, alpha: 1.0).setFill()
    foldPath.fill()

    // 4. Bold "F" centred on the paper, in the teal background colour.
    let fontSize = size * 0.50
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(srgbRed: 0.08, green: 0.27, blue: 0.33, alpha: 1.0),
    ]
    let attrText = NSAttributedString(string: "F", attributes: attrs)
    let textSize = attrText.size()
    let textOrigin = NSPoint(
        x: paperRect.midX - textSize.width / 2 - size * 0.02,
        y: paperRect.midY - textSize.height / 2 + size * 0.02
    )
    attrText.draw(at: textOrigin)

    // 5. A small caret bar after the F, suggesting a text editor cursor.
    let caretWidth = max(1.0, size * 0.015)
    let caretHeight = size * 0.30
    let caretX = textOrigin.x + textSize.width + size * 0.02
    let caretY = paperRect.midY - caretHeight / 2 + size * 0.02
    let caretRect = NSRect(x: caretX, y: caretY, width: caretWidth, height: caretHeight)
    NSColor(srgbRed: 0.08, green: 0.27, blue: 0.33, alpha: 1.0).setFill()
    NSBezierPath(rect: caretRect).fill()

    return rep.representation(using: .png, properties: [:])
}

// MARK: Entry point

let args = CommandLine.arguments
let outputDir: String
if args.count >= 2 {
    outputDir = args[1]
} else {
    outputDir = "build/AppIcon.iconset"
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)

var failed = 0
for (name, pixelSize) in sizes {
    if let data = renderIcon(pixelSize: pixelSize) {
        let path = (outputDir as NSString).appendingPathComponent(name)
        do {
            try data.write(to: URL(fileURLWithPath: path))
            FileHandle.standardOutput.write(Data("  \(name) (\(pixelSize)px)\n".utf8))
        } catch {
            failed += 1
            FileHandle.standardError.write(Data("Failed to write \(name): \(error)\n".utf8))
        }
    } else {
        failed += 1
        FileHandle.standardError.write(Data("Failed to render \(name)\n".utf8))
    }
}
exit(failed == 0 ? 0 : 1)
