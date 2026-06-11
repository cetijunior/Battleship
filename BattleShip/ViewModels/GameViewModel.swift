import SwiftUI
import Combine

enum GamePhase {
    case lobby, localSetup, networkSetup, waitingForOpponent, activeGame, gameOver
}

enum Player {
    case playerOne, playerTwo
    var name: String { self == .playerOne ? "Player 1" : "Player 2" }
    var opponent: Player { self == .playerOne ? .playerTwo : .playerOne }
}

enum GameMode {
    case local, network
}

class GameViewModel: ObservableObject {
    let gridSize = 10

    @Published var phase: GamePhase = .lobby
    @Published var activePlayer: Player = .playerOne
    @Published var isShowingTransition = false
    @Published var statusMessage = ""
    @Published var isHorizontalPlacement = true
    @Published var winnerName = ""
    @Published var winnerPlayer: Player? = nil
    @Published var gameMode: GameMode = .local
    @Published var p1Name: String = "Player 1"
    @Published var p2Name: String = "Player 2"
    @Published var localNetworkName: String = ""

    func playerName(_ player: Player) -> String {
        player == .playerOne ? p1Name : p2Name
    }

    var networkOpponentName: String {
        connectionManager?.opponentName ?? "Opponent"
    }
    @Published var placementPreviewCoords: [(row: Int, col: Int)] = []
    @Published var placementIsValid: Bool = true
    @Published var lastShotCoord: (row: Int, col: Int)? = nil
    @Published var lastShotWasHit: Bool = false

    private var isTurnLocked = false
    private var opponentReadyReceived = false

    @Published var p1Fleet = [[Cell]]()
    @Published var p1Radar = [[Cell]]()
    @Published var p2Fleet = [[Cell]]()
    @Published var p2Radar = [[Cell]]()

    private var p1ShipsToPlace = Ship.classicFleet()
    private var p2ShipsToPlace = Ship.classicFleet()
    @Published var p1Ships = [Ship]()
    @Published var p2Ships = [Ship]()

    var connectionManager: ConnectionManager?
    private var isNetworkHost = false
    private var cancellables = Set<AnyCancellable>()

    var currentDeployingShip: Ship? {
        if phase == .localSetup {
            return activePlayer == .playerOne ? p1ShipsToPlace.first : p2ShipsToPlace.first
        }
        if phase == .networkSetup { return p1ShipsToPlace.first }
        return nil
    }

    var shipsRemaining: Int {
        if gameMode == .network {
            return p1Ships.filter { !$0.isSunk }.count
        }
        return activePlayer == .playerOne
            ? p1Ships.filter { !$0.isSunk }.count
            : p2Ships.filter { !$0.isSunk }.count
    }

    init() { resetBoards() }

    func startLocalGame(p1Name: String = "", p2Name: String = "") {
        // Only update names if provided; preserves them across "Play Again"
        if !p1Name.isEmpty { self.p1Name = p1Name }
        if !p2Name.isEmpty { self.p2Name = p2Name }
        gameMode = .local
        resetBoards()
        phase = .localSetup
        activePlayer = .playerOne
        updateStatusText()
    }

    func startNetworkGame(connectionManager: ConnectionManager, isHost: Bool, playerName: String = "") {
        self.connectionManager = connectionManager
        self.isNetworkHost = isHost
        self.gameMode = .network
        self.localNetworkName = playerName
        resetBoards()
        phase = .networkSetup
        updateStatusText()
        subscribeToMoves()
    }

    private func subscribeToMoves() {
        connectionManager?.$receivedMove
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] move in self?.handleReceivedMove(move) }
            .store(in: &cancellables)
    }

    func resetBoards() {
        p1Fleet = createEmptyGrid()
        p1Radar = createEmptyGrid()
        p2Fleet = createEmptyGrid()
        p2Radar = createEmptyGrid()
        p1ShipsToPlace = Ship.classicFleet()
        p2ShipsToPlace = Ship.classicFleet()
        p1Ships.removeAll()
        p2Ships.removeAll()
        winnerName = ""
        winnerPlayer = nil
        isTurnLocked = false
        opponentReadyReceived = false
        placementPreviewCoords = []
        lastShotCoord = nil
    }

    func returnToMenu() {
        connectionManager?.stopNetworking()
        cancellables.removeAll()
        connectionManager = nil
        resetBoards()
        phase = .lobby
    }

    private func createEmptyGrid() -> [[Cell]] {
        (0..<gridSize).map { r in (0..<gridSize).map { c in Cell(row: r, col: c) } }
    }

    func updateStatusText() {
        switch phase {
        case .lobby: statusMessage = "Welcome"
        case .localSetup:
            if let ship = currentDeployingShip {
                let dir = isHorizontalPlacement ? "→" : "↓"
                statusMessage = "\(playerName(activePlayer)): Place \(ship.name) [\(ship.size)] \(dir)"
            }
        case .networkSetup:
            if let ship = currentDeployingShip {
                let dir = isHorizontalPlacement ? "→" : "↓"
                let name = localNetworkName.isEmpty ? "You" : localNetworkName
                statusMessage = "\(name): Deploy \(ship.name) [\(ship.size)] \(dir)"
            }
        case .waitingForOpponent:
            let opp = networkOpponentName
            statusMessage = "Fleet deployed — waiting for \(opp)..."
        case .activeGame:
            if gameMode == .local {
                statusMessage = "\(playerName(activePlayer)): Choose target"
            } else {
                let me  = localNetworkName.isEmpty ? "You" : localNetworkName
                let opp = networkOpponentName
                statusMessage = activePlayer == .playerOne ? "\(me): Choose target" : "\(opp) is targeting..."
            }
        case .gameOver:
            statusMessage = "\(winnerName) wins!"
        }
    }

    // MARK: - Placement Preview

    func updatePlacementPreview(row: Int, col: Int) {
        guard let ship = currentDeployingShip else { placementPreviewCoords = []; return }
        let isP1 = gameMode == .network || activePlayer == .playerOne
        let fleetGrid = isP1 ? p1Fleet : p2Fleet
        var coords: [(row: Int, col: Int)] = []
        var valid = true

        for i in 0..<ship.size {
            let r = isHorizontalPlacement ? row : row + i
            let c = isHorizontalPlacement ? col + i : col
            if r >= gridSize || c >= gridSize {
                valid = false
                coords.append((row: r, col: c))
                continue
            }
            if fleetGrid[r][c].status == .ship { valid = false }
            coords.append((row: r, col: c))
        }

        placementPreviewCoords = coords
        placementIsValid = valid
    }

    func clearPlacementPreview() { placementPreviewCoords = [] }

    // MARK: - Ship Placement

    func handleSetupTap(row: Int, col: Int) {
        guard let ship = currentDeployingShip else { return }
        let isP1 = gameMode == .network || activePlayer == .playerOne
        var fleetGrid = isP1 ? p1Fleet : p2Fleet
        var coords = [(row: Int, col: Int)]()

        for i in 0..<ship.size {
            let r = isHorizontalPlacement ? row : row + i
            let c = isHorizontalPlacement ? col + i : col
            guard r < gridSize, c < gridSize, fleetGrid[r][c].status != .ship else { return }
            coords.append((row: r, col: c))
        }

        let shipIdx = isP1 ? p1Ships.count : p2Ships.count
        for coord in coords {
            fleetGrid[coord.row][coord.col].status = .ship
            fleetGrid[coord.row][coord.col].shipIndex = shipIdx
        }
        var placedShip = ship
        placedShip.coordinates = coords

        if isP1 {
            p1Fleet = fleetGrid
            p1Ships.append(placedShip)
            p1ShipsToPlace.removeFirst()
            if p1ShipsToPlace.isEmpty { onP1PlacementComplete() }
        } else {
            p2Fleet = fleetGrid
            p2Ships.append(placedShip)
            p2ShipsToPlace.removeFirst()
            if p2ShipsToPlace.isEmpty { onP2PlacementComplete() }
        }
        placementPreviewCoords = []
        updateStatusText()
    }

    private func onP1PlacementComplete() {
        if gameMode == .network {
            connectionManager?.send(move: GameMove(type: .ready, row: 0, col: 0))
            if opponentReadyReceived {
                // Opponent already sent ready before us — start immediately
                startActiveGame()
            } else {
                phase = .waitingForOpponent
                updateStatusText()
            }
        } else {
            isShowingTransition = true
        }
    }

    private func onP2PlacementComplete() { isShowingTransition = true }

    // MARK: - Gameplay

    func handleGameplayTap(row: Int, col: Int) {
        guard phase == .activeGame, !isTurnLocked, !isShowingTransition else { return }

        if gameMode == .local {
            let radar = activePlayer == .playerOne ? p1Radar : p2Radar
            guard radar[row][col].status == .water else { return }
            isTurnLocked = true
            if activePlayer == .playerOne {
                processLocalShot(row: row, col: col, enemyFleet: &p2Fleet, myRadar: &p1Radar, enemyShips: &p2Ships, shooter: .playerOne)
            } else {
                processLocalShot(row: row, col: col, enemyFleet: &p1Fleet, myRadar: &p2Radar, enemyShips: &p1Ships, shooter: .playerTwo)
            }
        } else {
            guard activePlayer == .playerOne, p1Radar[row][col].status == .water else { return }
            isTurnLocked = true
            connectionManager?.send(move: GameMove(type: .fire, row: row, col: col))
            statusMessage = "Awaiting result..."
        }
    }

    private func processLocalShot(row: Int, col: Int, enemyFleet: inout [[Cell]], myRadar: inout [[Cell]], enemyShips: inout [Ship], shooter: Player) {
        let isHit = enemyFleet[row][col].status == .ship
        enemyFleet[row][col].status = isHit ? .hit : .miss
        myRadar[row][col].status = isHit ? .hit : .miss
        lastShotCoord = (row, col)
        lastShotWasHit = isHit

        if isHit {
            statusMessage = "DIRECT HIT!"
            for i in 0..<enemyShips.count {
                if enemyShips[i].coordinates.contains(where: { $0.row == row && $0.col == col }) {
                    enemyShips[i].health -= 1
                    if enemyShips[i].isSunk { statusMessage = "💥 \(enemyShips[i].name) SUNK!" }
                    break
                }
            }
            if enemyShips.allSatisfy({ $0.isSunk }) {
                winnerName = playerName(shooter)
                winnerPlayer = shooter
                phase = .gameOver
                updateStatusText()
                isTurnLocked = false
                return
            }
        } else {
            statusMessage = "MISS!"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.phase == .activeGame else { return }
            self.isShowingTransition = true
            self.isTurnLocked = false
        }
    }

    // MARK: - Network Move Handling

    private func handleReceivedMove(_ move: GameMove) {
        switch move.type {
        case .ready:
            // Opponent finished placing — start if we're already waiting, otherwise note it
            if phase == .waitingForOpponent {
                startActiveGame()
            } else {
                opponentReadyReceived = true
            }

        case .fire:
            // Opponent shot at our fleet
            let isHit = p1Fleet[move.row][move.col].status == .ship
            p1Fleet[move.row][move.col].status = isHit ? .hit : .miss
            lastShotCoord = (move.row, move.col)
            lastShotWasHit = isHit

            var sunkName: String? = nil
            if isHit {
                for i in 0..<p1Ships.count {
                    if p1Ships[i].coordinates.contains(where: { $0.row == move.row && $0.col == move.col }) {
                        p1Ships[i].health -= 1
                        if p1Ships[i].isSunk { sunkName = p1Ships[i].name }
                        break
                    }
                }
            }

            let allSunk = p1Ships.allSatisfy { $0.isSunk }
            let response = GameMove(type: .fireResponse, row: move.row, col: move.col, isHit: isHit, sunkShipName: sunkName, gameOver: allSunk)
            connectionManager?.send(move: response)

            if allSunk {
                winnerName = networkOpponentName
                winnerPlayer = .playerTwo
                phase = .gameOver
                updateStatusText()
                return
            }

            let oppDisplayName = networkOpponentName
            statusMessage = isHit
                ? (sunkName != nil ? "\(oppDisplayName) sunk your \(sunkName!)!" : "\(oppDisplayName) scored a HIT!")
                : "\(oppDisplayName) missed!"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                guard self.phase == .activeGame else { return }
                self.activePlayer = .playerOne
                self.isTurnLocked = false
                self.updateStatusText()
            }

        case .fireResponse:
            // Result of our shot
            p1Radar[move.row][move.col].status = move.isHit ? .hit : .miss
            lastShotCoord = (move.row, move.col)
            lastShotWasHit = move.isHit

            if move.gameOver {
                winnerName = localNetworkName.isEmpty ? "You" : localNetworkName
                winnerPlayer = .playerOne
                phase = .gameOver
                updateStatusText()
                return
            }

            let oppName = networkOpponentName
            statusMessage = move.isHit
                ? (move.sunkShipName != nil ? "💥 \(oppName)'s \(move.sunkShipName!) SUNK!" : "DIRECT HIT on \(oppName)!")
                : "MISS — \(oppName) dodged it!"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                guard self.phase == .activeGame else { return }
                self.activePlayer = .playerTwo
                self.isTurnLocked = false
                self.updateStatusText()
            }
        }
    }

    private func startActiveGame() {
        phase = .activeGame
        activePlayer = isNetworkHost ? .playerOne : .playerTwo
        isTurnLocked = false
        updateStatusText()
    }

    // MARK: - Transitions

    func progressTransition() {
        isTurnLocked = false
        isShowingTransition = false
        if phase == .localSetup {
            if activePlayer == .playerOne {
                activePlayer = .playerTwo
            } else {
                phase = .activeGame
                activePlayer = .playerOne
            }
        } else if phase == .activeGame {
            activePlayer = activePlayer.opponent
        }
        updateStatusText()
    }
}
