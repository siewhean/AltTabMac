#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
 guard arguments.count == 2 else {
    fputs("Usage: render-dmg-background.swift /path/to/background.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)
image.lockFocus()

defer { image.unlockFocus() }

let canvas = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.065, alpha: 1),
    NSColor(calibratedRed: 0.055, green: 0.095, blue: 0.16, alpha: 1),
])!
gradient.draw(in: canvas, angle: -18)

let glow = NSBezierPath(ovalIn: NSRect(x: 120, y: 160, width: 420, height: 260))
NSColor(calibratedRed: 0.16, green: 0.48, blue: 0.95, alpha: 0.12).setFill()
glow.fill()

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: titleStyle,
    .kern: -0.6,
]
("Install CmdTab" as NSString).draw(
    in: NSRect(x: 80, y: 338, width: 500, height: 44),
    withAttributes: titleAttributes
)

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.68),
    .paragraphStyle: titleStyle,
]
("Drag CmdTab into Applications" as NSString).draw(
    in: NSRect(x: 80, y: 307, width: 500, height: 28),
    withAttributes: subtitleAttributes
)

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 4
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 270, y: 185))
arrowPath.line(to: NSPoint(x: 390, y: 185))
arrowPath.move(to: NSPoint(x: 370, y: 204))
arrowPath.line(to: NSPoint(x: 390, y: 185))
arrowPath.line(to: NSPoint(x: 370, y: 166))
NSColor(calibratedRed: 0.48, green: 0.72, blue: 1, alpha: 0.9).setStroke()
arrowPath.stroke()

let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor.white.withAlphaComponent(0.48),
    .paragraphStyle: titleStyle,
]
("Window-level switching for macOS" as NSString).draw(
    in: NSRect(x: 80, y: 30, width: 500, height: 24),
    withAttributes: footerAttributes
)

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode DMG background PNG.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
