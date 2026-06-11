import SwiftUI

struct CellView: View {
    let cell: Cell
    let hideShips: Bool
    var isPreview: Bool = false
    var isValidPreview: Bool = true

    @State private var revealed = false

    private static let shipColors: [Color] = [
        Color(red: 0.28, green: 0.52, blue: 0.78),  // Carrier – steel blue
        Color(red: 0.22, green: 0.64, blue: 0.56),  // Battleship – teal
        Color(red: 0.60, green: 0.42, blue: 0.78),  // Destroyer – purple
        Color(red: 0.78, green: 0.52, blue: 0.22),  // Submarine – amber
        Color(red: 0.35, green: 0.72, blue: 0.42),  // Patrol – green
    ]

    var body: some View {
        ZStack {
            backgroundFill
            overlay
        }
        .animation(.easeOut(duration: 0.25), value: cell.status)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPreview)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundFill: some View {
        if isPreview {
            (isValidPreview ? Color.green : Color.red)
                .opacity(0.55)
                .overlay(
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(isValidPreview ? Color.green : Color.red, lineWidth: 1)
                )
        } else {
            switch cell.status {
            case .water:
                oceanTile
            case .ship:
                if hideShips { oceanTile } else { shipTile }
            case .hit:
                Color(red: 0.80, green: 0.12, blue: 0.12)
            case .miss:
                Color(red: 0.06, green: 0.18, blue: 0.35)
            }
        }
    }

    private var oceanTile: some View {
        let dark = (cell.row + cell.col) % 2 == 0
        return (dark
            ? Color(red: 0.05, green: 0.16, blue: 0.34)
            : Color(red: 0.07, green: 0.20, blue: 0.40)
        )
        .overlay(Color.white.opacity(0.03))
    }

    private var shipTile: some View {
        let idx = max(0, min(cell.shipIndex, Self.shipColors.count - 1))
        let base = cell.shipIndex >= 0 ? Self.shipColors[idx] : Color.gray.opacity(0.6)
        return base
            .overlay(Color.white.opacity(0.12))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
    }

    // MARK: - Overlay content

    @ViewBuilder
    private var overlay: some View {
        switch cell.status {
        case .hit:
            GeometryReader { g in
                Text("💥")
                    .font(.system(size: min(g.size.width, g.size.height) * 0.7))
                    .frame(width: g.size.width, height: g.size.height)
                    .contentShape(Rectangle())
            }
            .transition(.scale(scale: 0.3).combined(with: .opacity))
        case .miss:
            GeometryReader { g in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(
                        width: min(g.size.width, g.size.height) * 0.45,
                        height: min(g.size.width, g.size.height) * 0.45
                    )
                    .frame(width: g.size.width, height: g.size.height)
            }
            .transition(.scale(scale: 0.3).combined(with: .opacity))
        default:
            EmptyView()
        }
    }
}
