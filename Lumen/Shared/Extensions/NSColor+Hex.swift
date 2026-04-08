import AppKit
import SwiftUI

public extension NSColor {
    convenience init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr = String(hexStr.dropFirst()) }
        guard hexStr.count == 6,
              let value = UInt64(hexStr, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func withAlpha(_ alpha: CGFloat) -> NSColor {
        withAlphaComponent(alpha)
    }
}

public extension Color {
    init?(hex: String) {
        guard let nsColor = NSColor(hex: hex) else { return nil }
        self.init(nsColor)
    }
}
