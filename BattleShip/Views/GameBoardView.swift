import SwiftUI

struct GameBoardView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFleet = false

    var body: some View {
        GeometryReader { geo in
            // 32px horizontal padding + 16px row labels + 9px grid gaps = 57px total non-cell width
            let cellSize = floor((geo.size.width - 57) / 10)

            ZStack(alignment: .top) {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.10, blue: 0.22),
                        Color(red: 0.02, green: 0.06, blue: 0.14),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        headerBar
                            .padding(.top, 8)

                        switch viewModel.phase {
                        case .lobby:
                            Text("Return to menu").foregroundColor(.gray).padding(.top, 40)

                        case .localSetup:
                            let grid = viewModel.activePlayer == .playerOne ? viewModel.p1Fleet : viewModel.p2Fleet
                            placementView(cellSize: cellSize, grid: grid)
                                .padding(.top, 16)

                        case .networkSetup:
                            placementView(cellSize: cellSize, grid: viewModel.p1Fleet)
                                .padding(.top, 16)

                        case .waitingForOpponent:
                            waitingView(cellSize: cellSize)
                                .padding(.top, 16)

                        case .activeGame:
                            activeGameView(cellSize: cellSize, geo: geo)
                                .padding(.top, 12)

                        case .gameOver:
                            Color.clear.frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }

                // Overlays
                if viewModel.isShowingTransition {
                    transitionOverlay
                        .transition(.opacity)
                        .zIndex(5)
                }
                if viewModel.phase == .gameOver {
                    gameOverOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.isShowingTransition)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.phase == .gameOver)
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("⚓ BATTLESHIP")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(3)
                Spacer()
                Button(action: {
                    viewModel.returnToMenu()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.title3)
                }
            }

            // Status banner
            Text(viewModel.statusMessage)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundColor(.cyan)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
        }
    }

    // MARK: - Placement

    @ViewBuilder
    private func placementView(cellSize: CGFloat, grid: [[Cell]]) -> some View {
        VStack(spacing: 12) {
            // Controls row
            HStack {
                if let ship = viewModel.currentDeployingShip {
                    // Ship queue
                    HStack(spacing: 4) {
                        ForEach(0..<ship.size, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cyan.opacity(0.7))
                                .frame(width: 12, height: 12)
                        }
                        Text(ship.name)
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                    }
                }
                Spacer()
                Button(action: { viewModel.isHorizontalPlacement.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isHorizontalPlacement ? "arrow.left.and.right" : "arrow.up.and.down")
                        Text(viewModel.isHorizontalPlacement ? "Horizontal" : "Vertical")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.white.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal, 4)

            boardGrid(
                cells: grid,
                cellSize: cellSize,
                hideShips: false,
                previewCoords: viewModel.placementPreviewCoords,
                previewIsValid: viewModel.placementIsValid,
                onTap: { row, col in viewModel.handleSetupTap(row: row, col: col) },
                onHover: { row, col in viewModel.updatePlacementPreview(row: row, col: col) }
            )

            // Already-placed ship list
            if !viewModel.p1Ships.isEmpty || !viewModel.p2Ships.isEmpty {
                let ships = viewModel.gameMode == .network ? viewModel.p1Ships :
                    (viewModel.activePlayer == .playerOne ? viewModel.p1Ships : viewModel.p2Ships)
                ShipStatusView(ships: ships, title: "DEPLOYED")
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Waiting (network)

    @ViewBuilder
    private func waitingView(cellSize: CGFloat) -> some View {
        let myName  = viewModel.localNetworkName.isEmpty ? "YOU" : viewModel.localNetworkName.uppercased()
        let oppName = viewModel.networkOpponentName
        VStack(spacing: 16) {
            sectionLabel("YOUR FLEET — \(myName)")
            boardGrid(cells: viewModel.p1Fleet, cellSize: cellSize, hideShips: false, onTap: nil)
            ShipStatusView(ships: viewModel.p1Ships, title: "FLEET STATUS")
                .padding(.horizontal, 4)
            HStack(spacing: 10) {
                ProgressView().tint(.cyan)
                Text("Waiting for \(oppName) to deploy...")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Active Game

    @ViewBuilder
    private func activeGameView(cellSize: CGFloat, geo: GeometryProxy) -> some View {
        // Both modes now show two boards — cap cell size so they fit without scrolling
        let heightCapped = floor((geo.size.height - 252) / 20)
        let twoBoards = min(cellSize, max(heightCapped, 22))
        if viewModel.gameMode == .network {
            networkGameLayout(cellSize: twoBoards)
        } else {
            localGameLayout(cellSize: twoBoards)
        }
    }

    @ViewBuilder
    private func localGameLayout(cellSize: CGFloat) -> some View {
        let radarGrid = viewModel.activePlayer == .playerOne ? viewModel.p1Radar : viewModel.p2Radar
        let fleetGrid = viewModel.activePlayer == .playerOne ? viewModel.p1Fleet : viewModel.p2Fleet
        let myShips   = viewModel.activePlayer == .playerOne ? viewModel.p1Ships : viewModel.p2Ships
        let myName    = viewModel.playerName(viewModel.activePlayer).uppercased()
        let oppName   = viewModel.playerName(viewModel.activePlayer.opponent).uppercased()

        VStack(spacing: 16) {
            // Radar (attack)
            VStack(spacing: 8) {
                HStack {
                    sectionLabel("RADAR — \(oppName)")
                    Spacer()
                    let hits = radarGrid.flatMap { $0 }.filter { $0.status == .hit }.count
                    Text("HITS: \(hits)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                }
                boardGrid(cells: radarGrid, cellSize: cellSize, hideShips: true) { row, col in
                    viewModel.handleGameplayTap(row: row, col: col)
                }
            }

            divider

            // Fleet (defense status)
            VStack(spacing: 8) {
                HStack {
                    sectionLabel("YOUR FLEET — \(myName)")
                    Spacer()
                    Button(action: { showFleet.toggle() }) {
                        Text(showFleet ? "HIDE" : "SHOW")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    }
                    ShipStatusView(ships: myShips, compact: true)
                }
                if showFleet {
                    boardGrid(cells: fleetGrid, cellSize: cellSize, hideShips: false, onTap: nil)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showFleet)
        }
        .onChange(of: viewModel.activePlayer) { _ in showFleet = false }
    }

    @ViewBuilder
    private func networkGameLayout(cellSize: CGFloat) -> some View {
        let isMyTurn  = viewModel.activePlayer == .playerOne
        let oppName   = viewModel.networkOpponentName.uppercased()
        let myName    = (viewModel.localNetworkName.isEmpty ? "YOU" : viewModel.localNetworkName).uppercased()
        let hits      = viewModel.p1Radar.flatMap { $0 }.filter { $0.status == .hit }.count

        VStack(spacing: 16) {
            // Radar (attack)
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    sectionLabel(isMyTurn ? "RADAR — TAP TO FIRE" : "RADAR — \(oppName)'S TURN")
                    if !isMyTurn { ProgressView().tint(.orange).scaleEffect(0.6) }
                    Spacer()
                    Text("HITS: \(hits)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                }
                boardGrid(cells: viewModel.p1Radar, cellSize: cellSize, hideShips: true) { row, col in
                    viewModel.handleGameplayTap(row: row, col: col)
                }
                .opacity(isMyTurn ? 1.0 : 0.45)
            }

            divider

            // Fleet (defense)
            VStack(spacing: 8) {
                HStack {
                    sectionLabel("YOUR FLEET — \(myName)")
                    Spacer()
                    Button(action: { showFleet.toggle() }) {
                        Text(showFleet ? "HIDE" : "SHOW")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    }
                    ShipStatusView(ships: viewModel.p1Ships, compact: true)
                }
                if showFleet {
                    boardGrid(cells: viewModel.p1Fleet, cellSize: cellSize, hideShips: false, onTap: nil)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showFleet)
        }
        .onChange(of: viewModel.activePlayer) { _ in showFleet = false }
    }

    // MARK: - Grid Renderer

    private func boardGrid(
        cells: [[Cell]],
        cellSize: CGFloat,
        hideShips: Bool,
        previewCoords: [(row: Int, col: Int)] = [],
        previewIsValid: Bool = true,
        onTap: ((Int, Int) -> Void)?,
        onHover: ((Int, Int) -> Void)? = nil
    ) -> some View {
        let flat: [(id: String, row: Int, col: Int, cell: Cell)] = cells.enumerated().flatMap { r, rowArr in
            rowArr.enumerated().map { c, cell in (id: "\(r)-\(c)", row: r, col: c, cell: cell) }
        }
        let previewSet = Set(previewCoords.map { "\($0.row)-\($0.col)" })
        let gridPx = cellSize * 10 + 9

        return VStack(spacing: 0) {
            // Column labels A-J
            HStack(spacing: 1) {
                Color.clear.frame(width: 16, height: 14)
                ForEach(0..<10, id: \.self) { c in
                    Text(String(UnicodeScalar(65 + c)!))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: cellSize, height: 14)
                }
            }

            HStack(alignment: .top, spacing: 0) {
                // Row labels 1-10
                VStack(spacing: 1) {
                    ForEach(0..<10, id: \.self) { r in
                        Text("\(r + 1)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 16, height: cellSize)
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(cellSize), spacing: 1), count: 10),
                    spacing: 1
                ) {
                    ForEach(flat, id: \.id) { item in
                        let inPreview = previewSet.contains(item.id)
                        CellView(cell: item.cell, hideShips: hideShips, isPreview: inPreview, isValidPreview: previewIsValid)
                            .frame(width: cellSize, height: cellSize)
                            .onTapGesture {
                                onTap?(item.row, item.col)
                            }
                            .onHover { hovering in
                                if hovering { onHover?(item.row, item.col) }
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in onHover?(item.row, item.col) }
                            )
                    }
                }
                .frame(width: gridPx, height: gridPx)
                .background(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                )
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.gray)
            .tracking(1.5)
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Transition Overlay

    private var transitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)

                Text("PASS THE DEVICE")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundColor(.yellow)
                    .tracking(3)

                Text(transitionMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: { viewModel.progressTransition() }) {
                    Text("READY")
                        .font(.headline.bold())
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.yellow)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
    }

    private var transitionMessage: String {
        switch viewModel.phase {
        case .localSetup:
            return viewModel.activePlayer == .playerOne
                ? "\(viewModel.p2Name): time to deploy your fleet."
                : "Fleet deployed! \(viewModel.p1Name) goes first."
        case .activeGame:
            let shooter = viewModel.playerName(viewModel.activePlayer)
            let nextUp  = viewModel.playerName(viewModel.activePlayer.opponent)
            return "\(shooter) took their shot.\n\(nextUp), it's your turn."
        default:
            return ""
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        // In network mode .playerOne = you, .playerTwo = opponent
        let iWon: Bool = viewModel.gameMode == .local || viewModel.winnerPlayer == .playerOne

        return ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            VStack(spacing: 28) {
                Text(iWon ? "🏆" : "💀")
                    .font(.system(size: 72))

                Text("GAME OVER")
                    .font(.system(.largeTitle, design: .monospaced).bold())
                    .foregroundColor(.yellow)
                    .tracking(4)

                Text(viewModel.statusMessage)
                    .font(.title3.bold())
                    .foregroundColor(.white)

                // Surviving fleet — local: winning player's ships; network: your ships when you won
                if viewModel.gameMode == .local, let winner = viewModel.winnerPlayer {
                    let survivingShips = winner == .playerOne ? viewModel.p1Ships : viewModel.p2Ships
                    ShipStatusView(ships: survivingShips, title: "SURVIVING FLEET")
                        .padding(.horizontal, 40)
                } else if viewModel.gameMode == .network && iWon {
                    ShipStatusView(ships: viewModel.p1Ships, title: "YOUR SURVIVING FLEET")
                        .padding(.horizontal, 40)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.returnToMenu()
                        dismiss()
                    }) {
                        Text("MAIN MENU")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(width: 220, height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    if viewModel.gameMode == .local {
                        Button(action: { viewModel.startLocalGame() }) {
                            Text("PLAY AGAIN")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 220, height: 44)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}
