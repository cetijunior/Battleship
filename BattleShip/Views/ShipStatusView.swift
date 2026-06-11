import SwiftUI

struct ShipStatusView: View {
    let ships: [Ship]
    let title: String
    let compact: Bool

    private static let shipColors: [Color] = [
        Color(red: 0.28, green: 0.52, blue: 0.78),
        Color(red: 0.22, green: 0.64, blue: 0.56),
        Color(red: 0.60, green: 0.42, blue: 0.78),
        Color(red: 0.78, green: 0.52, blue: 0.22),
        Color(red: 0.35, green: 0.72, blue: 0.42),
    ]

    init(ships: [Ship], title: String = "", compact: Bool = false) {
        self.ships = ships
        self.title = title
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1.5)
            }
            ForEach(ships.indices, id: \.self) { i in
                HStack(spacing: 3) {
                    // Ship health bar
                    HStack(spacing: 1.5) {
                        ForEach(0..<ships[i].size, id: \.self) { seg in
                            let alive = seg < ships[i].health
                            RoundedRectangle(cornerRadius: 1)
                                .fill(alive
                                    ? Self.shipColors[min(i, Self.shipColors.count - 1)]
                                    : Color.red.opacity(0.4)
                                )
                                .frame(width: compact ? 7 : 10, height: compact ? 7 : 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 1)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                    }
                    if !compact {
                        Text(ships[i].name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(ships[i].isSunk ? Color.red.opacity(0.6) : .white.opacity(0.7))
                            .strikethrough(ships[i].isSunk, color: .red.opacity(0.5))
                    }
                }
                .opacity(ships[i].isSunk ? 0.5 : 1.0)
            }
        }
    }
}
