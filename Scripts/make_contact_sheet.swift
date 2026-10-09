import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift make_contact_sheet.swift <screenshots-directory> <output.png>")
}

let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let files = (try? FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil)) ?? []
let images = files
    .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
    .compactMap { NSImage(contentsOf: $0) }

guard !images.isEmpty else { fatalError("No screenshots found in \(input.path)") }

let columns = 2
let cellWidth: CGFloat = 390
let cellHeight: CGFloat = 850
let gutter: CGFloat = 28
let rows = Int(ceil(Double(images.count) / Double(columns)))
let canvasSize = NSSize(width: gutter + CGFloat(columns) * (cellWidth + gutter), height: gutter + CGFloat(rows) * (cellHeight + gutter))
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()
NSColor(calibratedRed: 0.035, green: 0.18, blue: 0.13, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

for (index, image) in images.enumerated() {
    let column = index % columns
    let row = index / columns
    let x = gutter + CGFloat(column) * (cellWidth + gutter)
    let y = canvasSize.height - gutter - CGFloat(row + 1) * cellHeight - CGFloat(row) * gutter
    let target = NSRect(x: x, y: y, width: cellWidth, height: cellHeight)
    let source = image.size
    let factor = min(target.width / source.width, target.height / source.height)
    let fitted = NSSize(width: source.width * factor, height: source.height * factor)
    let rect = NSRect(x: target.midX - fitted.width / 2, y: target.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode contact sheet")
}
try data.write(to: output, options: .atomic)
print("Wrote \(images.count) screenshots to \(output.path)")
