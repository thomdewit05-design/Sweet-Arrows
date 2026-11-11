import SweetArrowsCore
import UIKit

/// Paints the backdrops behind the board (unlocked by player level) with Core Graphics.
/// Images are cached per backdrop and size. If an image named like the backdrop (for example
/// "backdrop-iceCreamBay") is added to the asset catalog later, that artwork is used instead.
@MainActor
enum BackdropArt {
    private static var cache: [String: UIImage] = [:]

    static func image(for backdrop: Cosmetic, size: CGSize) -> UIImage {
        let key = "\(backdrop.rawValue)-\(Int(size.width))x\(Int(size.height))"
        if let cached = cache[key] { return cached }
        let image: UIImage
        if let artwork = UIImage(named: "backdrop-\(backdrop.rawValue)") {
            image = artwork
        } else {
            image = UIGraphicsImageRenderer(size: size).image { context in
                paint(backdrop, in: CGRect(origin: .zero, size: size), context: context.cgContext)
            }
        }
        if cache.count > 12 { cache.removeAll() }
        cache[key] = image
        return image
    }

    /// True for dark backdrops (text on top should be light or sit on a card).
    static func isDark(_ backdrop: Cosmetic) -> Bool { backdrop == .starryNight }

    // MARK: Painting

    private static func paint(_ backdrop: Cosmetic, in rect: CGRect, context: CGContext) {
        let colors: (UInt32, UInt32) = switch backdrop {
        case .iceCreamBay: (0xBDEFFF, 0xFFF6DC)
        case .chocolateRiver: (0xFFE6CC, 0xD9A47A)
        case .cottonSky: (0xFFC9E6, 0xC9D6FF)
        case .starryNight: (0x221A48, 0x5A3A8E)
        default: (0xBDE8FF, 0xFFE3F1)
        }
        gradient(context, rect, top: UIColor(hex: colors.0), bottom: UIColor(hex: colors.1))
        // A fixed seed per backdrop name keeps the layout the same on every launch.
        let seed = backdrop.rawValue.unicodeScalars.reduce(UInt64(7)) { $0 &* 31 &+ UInt64($1.value) }
        var rng = SeededRandom(seed: seed)
        switch backdrop {
        case .iceCreamBay: iceCreamBay(context, rect, &rng)
        case .chocolateRiver: chocolateRiver(context, rect, &rng)
        case .cottonSky: cottonSky(context, rect, &rng)
        case .starryNight: starryNight(context, rect, &rng)
        default: candyMeadow(context, rect, &rng)
        }
    }

    private static func gradient(_ context: CGContext, _ rect: CGRect, top: UIColor, bottom: UIColor) {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: space, colors: [top.cgColor, bottom.cgColor] as CFArray,
                                        locations: [0, 1]) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.minY), end: CGPoint(x: 0, y: rect.maxY),
                                   options: [])
    }

    private static func random(_ rng: inout SeededRandom, _ range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + CGFloat(rng.unit()) * (range.upperBound - range.lowerBound)
    }

    private static func candyMeadow(_ context: CGContext, _ rect: CGRect, _ rng: inout SeededRandom) {
        let w = rect.width, h = rect.height
        // Lollipops on sticks behind the hills.
        let lollies: [UInt32] = [0xFF5C8A, 0xFFD23F, 0xA259FF, 0x3DDC97]
        for i in 0..<5 {
            let x = w * (0.08 + CGFloat(i) * 0.21) + random(&rng, -10...10)
            let r = w * random(&rng, 0.045...0.07)
            let top = h * random(&rng, 0.7...0.78)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: x - r * 0.12, y: top, width: r * 0.24, height: h - top))
            context.setFillColor(UIColor(hex: lollies[i % lollies.count]).cgColor)
            context.fillEllipse(in: CGRect(x: x - r, y: top - r, width: r * 2, height: r * 2))
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(r * 0.18)
            context.addArc(center: CGPoint(x: x, y: top), radius: r * 0.55, startAngle: 0, endAngle: 4.5, clockwise: false)
            context.strokePath()
        }
        // Two mint hills.
        context.setFillColor(UIColor(hex: 0x9EEBC8).cgColor)
        context.fillEllipse(in: CGRect(x: -w * 0.3, y: h * 0.84, width: w * 1.0, height: h * 0.4))
        context.setFillColor(UIColor(hex: 0x7FDDB5).cgColor)
        context.fillEllipse(in: CGRect(x: w * 0.35, y: h * 0.87, width: w * 1.0, height: h * 0.4))
        sparkles(context, rect, &rng, count: 14, color: .white, area: 0...0.6)
    }

    private static func iceCreamBay(_ context: CGContext, _ rect: CGRect, _ rng: inout SeededRandom) {
        let w = rect.width, h = rect.height
        // Ice cream cones along the shore.
        let scoops: [UInt32] = [0xFFB3C7, 0xFFF1A8, 0xB8F0D6, 0xC9B8FF]
        for i in 0..<4 {
            let x = w * (0.12 + CGFloat(i) * 0.26)
            let base = h * 0.86
            let s = w * 0.07
            context.setFillColor(UIColor(hex: 0xF2B66D).cgColor)
            context.beginPath()
            context.move(to: CGPoint(x: x - s * 0.6, y: base - s * 1.4))
            context.addLine(to: CGPoint(x: x + s * 0.6, y: base - s * 1.4))
            context.addLine(to: CGPoint(x: x, y: base))
            context.closePath()
            context.fillPath()
            context.setFillColor(UIColor(hex: scoops[i]).cgColor)
            context.fillEllipse(in: CGRect(x: x - s * 0.7, y: base - s * 2.6, width: s * 1.4, height: s * 1.4))
        }
        // Waves.
        for (index, color) in [UInt32(0x8EDCF5), 0x5BC8EC].enumerated() {
            let top = h * (0.88 + CGFloat(index) * 0.04)
            context.setFillColor(UIColor(hex: color).cgColor)
            context.beginPath()
            context.move(to: CGPoint(x: 0, y: h))
            context.addLine(to: CGPoint(x: 0, y: top))
            var x: CGFloat = 0
            while x <= w {
                context.addLine(to: CGPoint(x: x, y: top + sin(x / w * .pi * 6 + CGFloat(index)) * h * 0.01))
                x += 4
            }
            context.addLine(to: CGPoint(x: w, y: h))
            context.closePath()
            context.fillPath()
        }
        sparkles(context, rect, &rng, count: 10, color: .white, area: 0...0.5)
    }

    private static func chocolateRiver(_ context: CGContext, _ rect: CGRect, _ rng: inout SeededRandom) {
        let w = rect.width, h = rect.height
        // Chocolate drips from the top.
        let chocolate = UIColor(hex: 0x7A4A2E)
        context.setFillColor(chocolate.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: w, height: h * 0.04))
        var x: CGFloat = 0
        while x < w {
            let width = w * random(&rng, 0.05...0.09)
            let length = h * random(&rng, 0.03...0.12)
            context.fill(CGRect(x: x, y: 0, width: width * 0.7, height: length))
            context.fillEllipse(in: CGRect(x: x - width * 0.05, y: length - width * 0.4, width: width * 0.8, height: width * 0.8))
            x += width
        }
        // River at the bottom with a light swirl.
        context.setFillColor(UIColor(hex: 0x8B5636).cgColor)
        context.fill(CGRect(x: 0, y: h * 0.88, width: w, height: h * 0.12))
        context.setStrokeColor(UIColor(hex: 0xB07A52).cgColor)
        context.setLineWidth(3)
        for row in 0..<2 {
            context.beginPath()
            let y = h * (0.91 + CGFloat(row) * 0.04)
            context.move(to: CGPoint(x: 0, y: y))
            var px: CGFloat = 0
            while px <= w {
                context.addLine(to: CGPoint(x: px, y: y + sin(px / w * .pi * 5 + CGFloat(row)) * 4))
                px += 4
            }
            context.strokePath()
        }
        // Little candy pieces.
        let pieces: [UInt32] = [0xFF5C8A, 0xFFD23F, 0x3DDC97, 0x5B6CFF]
        for i in 0..<8 {
            let r = w * random(&rng, 0.012...0.022)
            let p = CGPoint(x: w * random(&rng, 0.05...0.95), y: h * random(&rng, 0.15...0.8))
            context.setFillColor(UIColor(hex: pieces[i % pieces.count]).withAlphaComponent(0.55).cgColor)
            context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
    }

    private static func cottonSky(_ context: CGContext, _ rect: CGRect, _ rng: inout SeededRandom) {
        let w = rect.width, h = rect.height
        for i in 0..<7 {
            let center = CGPoint(x: w * random(&rng, 0...1), y: h * (0.08 + CGFloat(i) * 0.14))
            let size = w * random(&rng, 0.12...0.2)
            context.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            for k in 0..<4 {
                let dx = (CGFloat(k) - 1.5) * size * 0.55
                let r = size * (k == 1 || k == 2 ? 0.55 : 0.4)
                let lift: CGFloat = k == 1 ? 1.3 : 1
                context.fillEllipse(in: CGRect(x: center.x + dx - r, y: center.y - r * lift, width: r * 2, height: r * 2))
            }
        }
        sparkles(context, rect, &rng, count: 12, color: .white, area: 0...1)
    }

    private static func starryNight(_ context: CGContext, _ rect: CGRect, _ rng: inout SeededRandom) {
        let w = rect.width, h = rect.height
        // Moon.
        context.setFillColor(UIColor(hex: 0xFFF1B8).cgColor)
        context.fillEllipse(in: CGRect(x: w * 0.72, y: h * 0.06, width: w * 0.16, height: w * 0.16))
        context.setFillColor(UIColor(hex: 0x2B2156).cgColor)
        context.fillEllipse(in: CGRect(x: w * 0.76, y: h * 0.05, width: w * 0.15, height: w * 0.15))
        // Stars.
        for _ in 0..<40 {
            let r = random(&rng, 0.8...2.6)
            let p = CGPoint(x: w * random(&rng, 0...1), y: h * random(&rng, 0...1))
            context.setFillColor(UIColor.white.withAlphaComponent(random(&rng, 0.4...1)).cgColor)
            context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
        sparkles(context, rect, &rng, count: 6, color: UIColor(hex: 0xFFE27A), area: 0...1)
    }

    /// Four-point sparkles.
    private static func sparkles(
        _ context: CGContext, _ rect: CGRect, _ rng: inout SeededRandom, count: Int, color: UIColor,
        area: ClosedRange<CGFloat>
    ) {
        context.setFillColor(color.withAlphaComponent(0.85).cgColor)
        for _ in 0..<count {
            let p = CGPoint(x: rect.width * random(&rng, 0...1), y: rect.height * random(&rng, area))
            let s = rect.width * random(&rng, 0.01...0.022)
            context.beginPath()
            context.move(to: CGPoint(x: p.x, y: p.y - s))
            context.addLine(to: CGPoint(x: p.x + s * 0.3, y: p.y - s * 0.3))
            context.addLine(to: CGPoint(x: p.x + s, y: p.y))
            context.addLine(to: CGPoint(x: p.x + s * 0.3, y: p.y + s * 0.3))
            context.addLine(to: CGPoint(x: p.x, y: p.y + s))
            context.addLine(to: CGPoint(x: p.x - s * 0.3, y: p.y + s * 0.3))
            context.addLine(to: CGPoint(x: p.x - s, y: p.y))
            context.addLine(to: CGPoint(x: p.x - s * 0.3, y: p.y - s * 0.3))
            context.closePath()
            context.fillPath()
        }
    }
}
