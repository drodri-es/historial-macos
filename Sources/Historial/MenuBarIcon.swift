import AppKit

@MainActor
enum MenuBarIcon {
    static func make(accessibilityDescription: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let rearSheet = NSBezierPath()
            rearSheet.lineWidth = 1.35
            rearSheet.lineCapStyle = .round
            rearSheet.lineJoinStyle = .round
            rearSheet.move(to: NSPoint(x: 5.5, y: 15.2))
            rearSheet.line(to: NSPoint(x: 4.0, y: 15.2))
            rearSheet.curve(to: NSPoint(x: 1.8, y: 13.0), controlPoint1: NSPoint(x: 2.8, y: 15.2), controlPoint2: NSPoint(x: 1.8, y: 14.2))
            rearSheet.line(to: NSPoint(x: 1.8, y: 4.5))
            rearSheet.curve(to: NSPoint(x: 4.0, y: 2.3), controlPoint1: NSPoint(x: 1.8, y: 3.3), controlPoint2: NSPoint(x: 2.8, y: 2.3))
            rearSheet.stroke()

            let middleSheet = NSBezierPath()
            middleSheet.lineWidth = 1.35
            middleSheet.lineCapStyle = .round
            middleSheet.lineJoinStyle = .round
            middleSheet.move(to: NSPoint(x: 7.1, y: 14.1))
            middleSheet.line(to: NSPoint(x: 5.5, y: 14.1))
            middleSheet.curve(to: NSPoint(x: 3.4, y: 12.0), controlPoint1: NSPoint(x: 4.3, y: 14.1), controlPoint2: NSPoint(x: 3.4, y: 13.2))
            middleSheet.line(to: NSPoint(x: 3.4, y: 3.5))
            middleSheet.curve(to: NSPoint(x: 5.5, y: 1.4), controlPoint1: NSPoint(x: 3.4, y: 2.3), controlPoint2: NSPoint(x: 4.3, y: 1.4))
            middleSheet.stroke()

            let frontSheet = NSBezierPath(roundedRect: NSRect(x: 5.2, y: 1.7, width: 11.0, height: 12.1), xRadius: 1.7, yRadius: 1.7)
            frontSheet.lineWidth = 1.55
            frontSheet.stroke()

            let clip = NSBezierPath(roundedRect: NSRect(x: 8.2, y: 12.7, width: 5.0, height: 3.0), xRadius: 0.8, yRadius: 0.8)
            clip.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }
}
