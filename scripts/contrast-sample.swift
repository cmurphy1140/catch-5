// Measure the contrast of a rendered screen against ivory, by sampling actual pixels.
//
// The app draws its backgrounds in code: `WoodGrainView` lays a three-stop gradient, twenty-eight
// tonal bands, several hundred grain strokes and a vignette on top of each other, and `FeltView`
// stipples the felt. No pixel on screen is ever the bare colour literal from `Theme.swift`, so a
// contrast ratio computed from a literal can be wrong by several points in either direction. This
// reads a simulator screenshot instead and reports what is actually drawn.
//
//   swift scripts/contrast-sample.swift <screenshot.png> <x0> <y0> <x1> <y1> [label]
//
// Coordinates are pixels in the screenshot, origin top-left, so on a 3x device they are three times
// the point values. `xcrun simctl io <udid> screenshot out.png` produces a suitable file.
//
// Glyph pixels are excluded, because the question is what the background does behind the text, not
// what the text does. The trap: antialiased glyph edges are a blend of ivory and background, so a
// naive threshold leaves a fringe of mid-tone pixels that report absurdly low ratios (around
// 1.7:1) and look like a catastrophic failure. Those are text, not background. Prefer a region with
// no text in it at all when you want the true worst case; when that is impossible, read the
// percentiles rather than the single worst pixel.

import Foundation
import CoreGraphics
import ImageIO

/// The app's ivory, `Theme.ivory` / `#FAF5E3`: every body text and card face.
let ivory = (r: 250.0 / 255, g: 245.0 / 255, b: 227.0 / 255)
/// WCAG 2.1 relative luminance.
func linearise(_ channel: Double) -> Double {
    channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
}
func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
    0.2126 * linearise(r) + 0.7152 * linearise(g) + 0.0722 * linearise(b)
}
func contrast(_ a: Double, _ b: Double) -> Double {
    (max(a, b) + 0.05) / (min(a, b) + 0.05)
}

let arguments = CommandLine.arguments
guard arguments.count >= 6,
      let x0 = Int(arguments[2]), let y0 = Int(arguments[3]),
      let x1 = Int(arguments[4]), let y1 = Int(arguments[5]), x1 > x0, y1 > y0 else {
    print("usage: swift scripts/contrast-sample.swift <screenshot.png> <x0> <y0> <x1> <y1> [label]")
    exit(1)
}
let label = arguments.count > 6 ? arguments[6] : "region"

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("could not read \(arguments[1])")
    exit(1)
}

// Drawing the image into a bitmap context gives a buffer whose first row is the top of the image,
// so the y values below match what you measure off the screenshot in an image viewer.
let width = image.width, height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("could not create a bitmap context")
    exit(1)
}
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

let ivoryLuminance = luminance(ivory.r, ivory.g, ivory.b)
/// Anything brighter than this much of ivory's luminance is treated as a glyph, not a background.
let glyphThreshold = ivoryLuminance * 0.55

var ratios: [Double] = []
var brightest = (hex: "", ratio: Double.greatestFiniteMagnitude)
var glyphCount = 0

for y in y0..<min(y1, height) {
    for x in x0..<min(x1, width) {
        let i = (y * width + x) * 4
        let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
        let l = luminance(r, g, b)
        if l > glyphThreshold { glyphCount += 1; continue }
        let ratio = contrast(ivoryLuminance, l)
        ratios.append(ratio)
        if ratio < brightest.ratio {
            brightest = (String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255)), ratio)
        }
    }
}

guard !ratios.isEmpty else {
    print("--- \(label) --- no background pixels in that region (all of it read as glyph)")
    exit(0)
}
ratios.sort()
func percentile(_ p: Double) -> Double { ratios[Int(Double(ratios.count - 1) * p)] }
let failing = ratios.filter { $0 < 4.5 }.count

print("--- \(label)  x\(x0)-\(x1) y\(y0)-\(y1) ---")
print("  background pixels: \(ratios.count)  (excluded \(glyphCount) glyph pixels)")
print(String(format: "  brightest background: %.2f:1 at %@", brightest.ratio, brightest.hex))
print(String(format: "  1st percentile:  %.2f:1", percentile(0.01)))
print(String(format: "  5th percentile:  %.2f:1", percentile(0.05)))
print(String(format: "  median:          %.2f:1", percentile(0.50)))
print(String(format: "  95th percentile: %.2f:1", percentile(0.95)))
print(String(format: "  below 4.5:1:     %.1f%% of background pixels",
             Double(failing) / Double(ratios.count) * 100))
