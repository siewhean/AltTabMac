import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset", isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconDefinitions: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (64, "icon_64x64.png"),
    (128, "icon_64x64@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, filename) in iconDefinitions {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        continue
    }

    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(in: NSRect(x: 0, y: 0, width: size, height: size))
    context?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
        continue
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(filename))
}

func drawIcon(in rect: NSRect) {
    let scale = min(rect.width, rect.height) / 1024.0
    let roundedRect = NSBezierPath(roundedRect: rect.insetBy(dx: 46 * scale, dy: 46 * scale), xRadius: 240 * scale, yRadius: 240 * scale)

    NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.09, alpha: 1.0).setFill()
    roundedRect.fill()

    let backdropGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.09, green: 0.15, blue: 0.28, alpha: 1.0),
        NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.20, alpha: 1.0),
        NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.08, alpha: 1.0)
    ])!
    backdropGradient.draw(in: roundedRect, angle: 315)

    let glowCenter = NSPoint(x: rect.midX, y: rect.midY + 64 * scale)
    let glowRect = NSRect(x: glowCenter.x - 280 * scale, y: glowCenter.y - 280 * scale, width: 560 * scale, height: 560 * scale)
    let glowPath = NSBezierPath(ovalIn: glowRect)
    NSGraphicsContext.saveGraphicsState()
    glowPath.addClip()
    let glowGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.45, green: 0.79, blue: 1.0, alpha: 0.52),
        NSColor(calibratedRed: 0.28, green: 0.58, blue: 1.0, alpha: 0.18),
        .clear
    ])!
    glowGradient.draw(in: glowPath, relativeCenterPosition: .zero)
    NSGraphicsContext.restoreGraphicsState()

    let glassRect = NSRect(x: 140 * scale, y: 146 * scale, width: 744 * scale, height: 620 * scale)
    let glassPath = NSBezierPath(roundedRect: glassRect, xRadius: 172 * scale, yRadius: 172 * scale)

    NSColor.white.withAlphaComponent(0.14).setFill()
    glassPath.fill()

    let glassGradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.42),
        NSColor(calibratedRed: 0.72, green: 0.86, blue: 1.0, alpha: 0.14),
        NSColor.white.withAlphaComponent(0.08)
    ])!
    glassGradient.draw(in: glassPath, angle: 300)

    NSColor.white.withAlphaComponent(0.34).setStroke()
    glassPath.lineWidth = 14 * scale
    glassPath.stroke()

    let innerHighlight = NSBezierPath(roundedRect: glassRect.insetBy(dx: 26 * scale, dy: 26 * scale), xRadius: 146 * scale, yRadius: 146 * scale)
    NSColor.white.withAlphaComponent(0.15).setStroke()
    innerHighlight.lineWidth = 6 * scale
    innerHighlight.stroke()

    let cardSpecs: [(NSRect, CGFloat)] = [
        (NSRect(x: 234 * scale, y: 410 * scale, width: 300 * scale, height: 180 * scale), -7 * scale),
        (NSRect(x: 420 * scale, y: 292 * scale, width: 360 * scale, height: 222 * scale), 7 * scale)
    ]

    for (cardRect, shadowOffset) in cardSpecs {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.36, green: 0.71, blue: 1.0, alpha: 0.26)
        shadow.shadowBlurRadius = 40 * scale
        shadow.shadowOffset = NSSize(width: 0, height: shadowOffset)
        shadow.set()

        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 42 * scale, yRadius: 42 * scale)
        NSColor.white.withAlphaComponent(0.18).setFill()
        cardPath.fill()

        let cardGradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.38),
            NSColor(calibratedRed: 0.58, green: 0.78, blue: 1.0, alpha: 0.18),
            NSColor.white.withAlphaComponent(0.07)
        ])!
        cardGradient.draw(in: cardPath, angle: 300)

        NSColor.white.withAlphaComponent(0.34).setStroke()
        cardPath.lineWidth = 5 * scale
        cardPath.stroke()

        let headerRect = NSRect(x: cardRect.minX + 20 * scale, y: cardRect.maxY - 34 * scale, width: cardRect.width * 0.48, height: 14 * scale)
        let bodyRect = NSRect(x: cardRect.minX + 20 * scale, y: cardRect.minY + 28 * scale, width: cardRect.width - 40 * scale, height: cardRect.height - 78 * scale)
        let headerPath = NSBezierPath(roundedRect: headerRect, xRadius: 7 * scale, yRadius: 7 * scale)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 20 * scale, yRadius: 20 * scale)

        NSColor.white.withAlphaComponent(0.26).setFill()
        headerPath.fill()
        NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.14, alpha: 0.34).setFill()
        bodyPath.fill()
    }

    let accentPath = NSBezierPath()
    accentPath.lineWidth = 30 * scale
    accentPath.lineCapStyle = .round
    accentPath.move(to: NSPoint(x: 290 * scale, y: 286 * scale))
    accentPath.curve(
        to: NSPoint(x: 726 * scale, y: 620 * scale),
        controlPoint1: NSPoint(x: 420 * scale, y: 280 * scale),
        controlPoint2: NSPoint(x: 612 * scale, y: 612 * scale)
    )
    NSColor(calibratedRed: 0.43, green: 0.76, blue: 1.0, alpha: 0.92).setStroke()
    accentPath.stroke()
}
