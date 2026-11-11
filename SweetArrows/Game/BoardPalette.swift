import SweetArrowsCore
import UIKit

/// Counter colors for each board cosmetic.
struct BoardPalette {
    let fill: UIColor
    let edge: UIColor
    let tile: UIColor

    init(_ style: Cosmetic) {
        switch style {
        case .mintMarble:
            fill = UIColor(hex: 0xD6F5E8); edge = UIColor(hex: 0x9EDFC4); tile = UIColor(hex: 0xFFFFFF, alpha: 0.35)
        case .strawberryCheck:
            fill = UIColor(hex: 0xFFE1EA); edge = UIColor(hex: 0xFFB1C6); tile = UIColor(hex: 0xFF5C8A, alpha: 0.12)
        case .midnightCandy:
            fill = UIColor(hex: 0x3B2F5C); edge = UIColor(hex: 0x2A2145); tile = UIColor(hex: 0xFFFFFF, alpha: 0.08)
        default:
            fill = UIColor(hex: 0xF6D7B0); edge = UIColor(hex: 0xE9B98A); tile = UIColor(hex: 0xFFFFFF, alpha: 0.22)
        }
    }
}
