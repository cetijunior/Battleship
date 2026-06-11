import Foundation

enum MoveType: String, Codable {
    case ready, fire, fireResponse
}

struct GameMove: Codable {
    let type: MoveType
    let row: Int
    let col: Int
    var isHit: Bool = false
    var sunkShipName: String? = nil
    var gameOver: Bool = false
}
