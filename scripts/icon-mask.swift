// Renders the square icon artwork onto the macOS app icon grid:
// a 1024 x 1024 transparent canvas, the artwork scaled into a centred
// 824 x 824 rounded rectangle (185 px corner radius) with a soft shadow.
// Usage: swift scripts/icon-mask.swift <source.png> <output-1024.png>
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write("usage: icon-mask.swift <source.png> <output.png>\n".data(using: .utf8)!)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    FileHandle.standardError.write("cannot read \(sourceURL.path)\n".data(using: .utf8)!)
    exit(1)
}

let canvas: CGFloat = 1024
let tile: CGFloat = 824
let radius: CGFloat = 185
let tileRect = CGRect(x: (canvas - tile) / 2, y: (canvas - tile) / 2, width: tile, height: tile)
    // The grid sits slightly above centre to leave room for the shadow.
    .offsetBy(dx: 0, dy: 10)

guard let context = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
context.interpolationQuality = .high

let tilePath = CGPath(roundedRect: tileRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

// Soft drop shadow under the tile.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
context.addPath(tilePath)
context.setFillColor(CGColor(gray: 0.1, alpha: 1))
context.fillPath()
context.restoreGState()

// Artwork clipped to the tile.
context.saveGState()
context.addPath(tilePath)
context.clip()
context.draw(artwork, in: tileRect)
context.restoreGState()

guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
