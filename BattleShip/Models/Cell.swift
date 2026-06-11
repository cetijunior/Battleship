import Foundation

enum CellStatus: Equatable {
    case water, ship, hit, miss
}

struct Cell: Identifiable {
    let id = UUID()
    let row: Int
    let col: Int
    var status: CellStatus = .water
    var shipIndex: Int = -1
}
