// Reproducible, original ContainerDesk artwork. Run from the repository root.
import AppKit
import Foundation

func render(width: Int, height: Int, draw: (CGContext) -> Void) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    draw(context)
    let image = NSBitmapImageRep(cgImage: context.makeImage()!)
    return image.representation(using: .png, properties: [:])!
}

func gradient(_ context: CGContext, colors: [CGColor], start: CGPoint, end: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(g, start: start, end: end, options: [])
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func icon(_ size: Int) -> Data {
    render(width: size, height: size) { context in
        context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        let tile = CGPath(roundedRect: CGRect(x: 70, y: 70, width: 884, height: 884), cornerWidth: 222, cornerHeight: 222, transform: nil)
        context.saveGState()
        context.addPath(tile)
        context.clip()
        gradient(context, colors: [color(0.025, 0.28, 0.30), color(0.035, 0.56, 0.55)], start: CGPoint(x: 100, y: 70), end: CGPoint(x: 910, y: 954))
        context.restoreGState()
        // Three offset container silhouettes form a compact, legible stack.
        for (x, y, width) in [(220, 245, 584), (260, 410, 544), (300, 575, 504)] {
            let box = CGRect(x: x, y: y, width: width, height: 132)
            context.setFillColor(color(0.96, 1, 0.98))
            context.addPath(CGPath(roundedRect: box, cornerWidth: 38, cornerHeight: 38, transform: nil))
            context.fillPath()
            context.setFillColor(color(0.04, 0.40, 0.40, 0.68))
            for line in 0..<3 {
                let groove = CGRect(x: x + 44 + line * 42, y: y + 39, width: 13, height: 54)
                context.addPath(CGPath(roundedRect: groove, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil))
                context.fillPath()
            }
        }
    }
}

func dmgBackground(scale: Int) -> Data {
    render(width: 660 * scale, height: 400 * scale) { context in
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        gradient(context, colors: [color(0.90, 0.97, 0.96), color(0.97, 0.99, 0.98)], start: CGPoint(x: 0, y: 0), end: CGPoint(x: 660, y: 400))
        context.setStrokeColor(color(0.09, 0.43, 0.42, 0.55))
        context.setLineWidth(4)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 287, y: 206))
        context.addLine(to: CGPoint(x: 373, y: 206))
        context.move(to: CGPoint(x: 356, y: 222))
        context.addLine(to: CGPoint(x: 373, y: 206))
        context.addLine(to: CGPoint(x: 356, y: 190))
        context.strokePath()
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let iconDir = root.appendingPathComponent("Orchard/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let specs: [(String, Int)] = [("icon_16x16.png",16),("icon_16x16@2x.png",32),("icon_32x32.png",32),("icon_32x32@2x.png",64),("icon_128x128.png",128),("icon_128x128@2x.png",256),("icon_256x256.png",256),("icon_256x256@2x.png",512),("icon_512x512.png",512),("icon_512x512@2x.png",1024)]
for (name, pixels) in specs { try icon(pixels).write(to: iconDir.appendingPathComponent(name)) }
let dmgDir = root.appendingPathComponent("assets/containerdesk-dmg", isDirectory: true)
try FileManager.default.createDirectory(at: dmgDir, withIntermediateDirectories: true)
try dmgBackground(scale: 1).write(to: dmgDir.appendingPathComponent("background.png"))
try dmgBackground(scale: 2).write(to: dmgDir.appendingPathComponent("background@2x.png"))
