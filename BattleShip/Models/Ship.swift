//
//  Ship.swift
//  BattleShip
//
//  Created by Ceti Junior on 02.06.2026.
//

import Foundation

struct Ship {
    let name: String
    let size: Int
    var health: Int
    var coordinates: [(row: Int, col: Int)]
    
    var isSunk: Bool { health <= 0 }
    
    static func classicFleet() -> [Ship] {
        return [
            Ship(name: "Carrier", size: 5, health: 5, coordinates: []),
            Ship(name: "Battleship", size: 4, health: 4, coordinates: []),
            Ship(name: "Destroyer", size: 3, health: 3, coordinates: []),
            Ship(name: "Submarine", size: 3, health: 3, coordinates: []),
            Ship(name: "Patrol Boat", size: 2, health: 2, coordinates: [])
        ]
    }
}
