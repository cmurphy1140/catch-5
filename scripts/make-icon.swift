// Renders the app icon: a card showing the five of hearts on the felt. Run with
// `swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset/icon-1024.png`.
import AppKit

let size = 1024
let output = URL(fileURLWithPath: CommandLine.arguments[1])
// Core Graphics needs an alpha channel to draw into; the App Store master must not have one,
// so the pixels are copied into an opaque bitmap at the end.
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext

let felt = NSColor(red: 0.035, green: 0.16, blue: 0.13, alpha: 1)
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [felt.cgColor, NSColor(red: 0.01, green: 0.05, blue: 0.04, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])

let cardRect = NSRect(x: 262, y: 176, width: 500, height: 672)
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: NSColor.black.withAlphaComponent(0.5).cgColor)
NSColor(red: 0.98, green: 0.96, blue: 0.89, alpha: 1).setFill()
NSBezierPath(roundedRect: cardRect, xRadius: 60, yRadius: 60).fill()
context.setShadow(offset: .zero, blur: 0, color: nil)

let red = NSColor(red: 0.7, green: 0.12, blue: 0.18, alpha: 1)
let centred = NSMutableParagraphStyle()
centred.alignment = .center
let rank = NSAttributedString(string: "5", attributes: [
    .font: NSFont(name: "Georgia-Bold", size: 400) ?? NSFont.boldSystemFont(ofSize: 400),
    .foregroundColor: red, .paragraphStyle: centred])
rank.draw(in: NSRect(x: cardRect.minX, y: 430, width: cardRect.width, height: 440))
let suit = NSAttributedString(string: "♥", attributes: [
    .font: NSFont.systemFont(ofSize: 300), .foregroundColor: red, .paragraphStyle: centred])
suit.draw(in: NSRect(x: cardRect.minX, y: 130, width: cardRect.width, height: 360))

NSGraphicsContext.restoreGraphicsState()

let opaque = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                              samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
for y in 0..<size {
    for x in 0..<size {
        opaque.setColor(rep.colorAt(x: x, y: y)!.withAlphaComponent(1), atX: x, y: y)
    }
}
try opaque.representation(using: .png, properties: [:])!.write(to: output)
print(output.path)
