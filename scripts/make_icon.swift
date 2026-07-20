// Gera Resources/AppIcon.icns a partir de formas desenhadas em código
// (squircle com gradiente azul->roxo e um glifo de "gauge", no estilo dos
// icones nativos do macOS, com uma referencia visual ao grafico do Task
// Manager do Windows).
import AppKit
import CoreGraphics

let size = 1024
let rep = NSBitmapImageRep(
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
)!

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// macOS squircle (approximated with a very rounded rect, masked by the OS anyway)
let cornerRadius = CGFloat(size) * 0.225
let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
cg.addPath(path)
cg.clip()

let colors = [
    NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.32, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.25, green: 0.33, blue: 0.85, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.85, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.55, 1])!
cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// Draw a gauge/activity glyph (SF Symbol) centered, in white
let symbolConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.5, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let imgRect = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: imgRect)
    imgRect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let drawSize = symbol.size
    let origin = CGPoint(x: (CGFloat(size) - drawSize.width) / 2, y: (CGFloat(size) - drawSize.height) / 2 - CGFloat(size) * 0.03)
    tinted.draw(in: CGRect(origin: origin, size: drawSize))
}

NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try! pngData.write(to: outputURL)
print("wrote \(outputURL.path)")
