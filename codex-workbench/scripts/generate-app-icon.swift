import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift <output.png>\n", stderr)
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("unable to create graphics context\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let tile = NSBezierPath(
    roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
    xRadius: 220,
    yRadius: 220
)
NSGraphicsContext.saveGraphicsState()
tile.addClip()
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.15, alpha: 1),
    NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.36, alpha: 1),
])!
background.draw(in: tile, angle: -34)

let halo = NSGradient(starting: NSColor(calibratedRed: 0.43, green: 0.39, blue: 0.95, alpha: 0.22),
                      ending: NSColor(calibratedWhite: 1, alpha: 0))!
halo.draw(fromCenter: NSPoint(x: 670, y: 690), radius: 20,
          toCenter: NSPoint(x: 670, y: 690), radius: 430,
          options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
NSGraphicsContext.restoreGraphicsState()

NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
tile.lineWidth = 5
tile.stroke()

let orbit = NSBezierPath()
orbit.appendArc(
    withCenter: NSPoint(x: 490, y: 512),
    radius: 276,
    startAngle: 48,
    endAngle: 312,
    clockwise: false
)
orbit.lineCapStyle = .round
orbit.lineWidth = 76
NSColor(calibratedRed: 0.86, green: 0.88, blue: 0.98, alpha: 0.95).setStroke()
orbit.stroke()

let innerOrbit = NSBezierPath()
innerOrbit.appendArc(
    withCenter: NSPoint(x: 490, y: 512),
    radius: 276,
    startAngle: 48,
    endAngle: 312,
    clockwise: false
)
innerOrbit.lineCapStyle = .round
innerOrbit.lineWidth = 20
NSColor(calibratedRed: 0.55, green: 0.51, blue: 1, alpha: 0.76).setStroke()
innerOrbit.stroke()

let timeline = NSBezierPath()
timeline.move(to: NSPoint(x: 690, y: 330))
timeline.line(to: NSPoint(x: 690, y: 694))
timeline.lineCapStyle = .round
timeline.lineWidth = 18
NSColor(calibratedRed: 0.82, green: 0.82, blue: 1, alpha: 0.74).setStroke()
timeline.stroke()

let nodeYs: [CGFloat] = [350, 512, 674]
for (index, y) in nodeYs.enumerated() {
    let diameter: CGFloat = index == 1 ? 74 : 62
    let nodeRect = NSRect(
        x: 690 - diameter / 2,
        y: y - diameter / 2,
        width: diameter,
        height: diameter
    )
    let node = NSBezierPath(ovalIn: nodeRect)
    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.20, alpha: 1).setFill()
    node.fill()
    (index == 1
        ? NSColor(calibratedRed: 0.98, green: 0.64, blue: 0.28, alpha: 1)
        : NSColor(calibratedRed: 0.91, green: 0.92, blue: 1, alpha: 1)
    ).setStroke()
    node.lineWidth = index == 1 ? 15 : 12
    node.stroke()
}

image.unlockFocus()
guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("unable to encode icon\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
