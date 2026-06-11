import SwiftUI

struct LobbyView: View {
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var connectionManager = ConnectionManager()

    @State private var playerName: String = "Admiral \(Int.random(in: 100...999))"
    @State private var roomCode: String = ""
    @State private var isHosting = false
    @State private var isGameActive = false
    @State private var showNetworkPanel = false
    @State private var waveOffset: CGFloat = 0
    @State private var showNicknameSheet = false
    @State private var nicknameP1 = ""
    @State private var nicknameP2 = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated ocean background
                oceanBackground

                VStack(spacing: 0) {
                    // Title block
                    titleBlock
                        .padding(.top, 52)

                    Spacer()

                    // Action cards
                    VStack(spacing: 16) {
                        localPlayCard
                        networkCard
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Footer
                    Text("LOCAL NETWORK MULTIPLAYER VIA MULTIPEER")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .tracking(1)
                        .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $isGameActive) {
                GameBoardView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showNicknameSheet) { nicknameSheet }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                waveOffset = 1
            }
        }
        .onChange(of: connectionManager.lobbyState) { state in
            if state == .connected {
                viewModel.startNetworkGame(connectionManager: connectionManager, isHost: isHosting, playerName: playerName)
                isGameActive = true
            }
        }
    }

    // MARK: - Background

    private var oceanBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.08, blue: 0.20),
                    Color(red: 0.01, green: 0.04, blue: 0.12),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Grid overlay
            Canvas { ctx, size in
                let spacing: CGFloat = 32
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("⚓")
                    .font(.system(size: 36))
                Text("BATTLESHIP")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(6)
                Text("⚓")
                    .font(.system(size: 36))
            }

            Text("NAVAL COMBAT SIMULATOR")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.8))
                .tracking(3)

            // Decorative line
            HStack(spacing: 6) {
                Rectangle().fill(Color.cyan.opacity(0.3)).frame(height: 1)
                Circle().fill(Color.cyan.opacity(0.5)).frame(width: 4, height: 4)
                Rectangle().fill(Color.cyan.opacity(0.3)).frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
    }

    // MARK: - Local Play Card

    private var localPlayCard: some View {
        Button(action: {
            nicknameP1 = ""
            nicknameP2 = ""
            showNicknameSheet = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("PASS & PLAY")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundColor(.white)
                    Text("Two players, one device")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Network Card

    private var networkCard: some View {
        VStack(spacing: 0) {
            // Header toggle
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showNetworkPanel.toggle()
                    if !showNetworkPanel { connectionManager.stopNetworking() }
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "wifi")
                            .font(.title2)
                            .foregroundColor(.cyan)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LOCAL NETWORK")
                            .font(.system(.headline, design: .monospaced).bold())
                            .foregroundColor(.white)
                        Text("Two devices on the same Wi-Fi")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: showNetworkPanel ? "chevron.up" : "chevron.down")
                        .foregroundColor(.cyan.opacity(0.6))
                }
                .padding(18)
            }

            if showNetworkPanel {
                VStack(spacing: 14) {
                    Divider().background(Color.white.opacity(0.08))

                    VStack(spacing: 12) {
                        // Name field
                        fieldRow(icon: "person.fill", placeholder: "Your name", text: $playerName)

                        // Room code field
                        fieldRow(icon: "number", placeholder: "Room code (e.g. ALPHA)", text: $roomCode, allCaps: true)
                    }
                    .padding(.horizontal, 16)

                    // Connection status
                    statusIndicator

                    // Action buttons
                    HStack(spacing: 10) {
                        actionButton(
                            label: "HOST",
                            icon: "antenna.radiowaves.left.and.right",
                            color: .blue,
                            filled: true
                        ) {
                            guard !playerName.isEmpty, !roomCode.isEmpty else { return }
                            isHosting = true
                            connectionManager.stopNetworking()
                            connectionManager.startHosting(name: playerName, roomCode: roomCode)
                        }

                        actionButton(
                            label: "JOIN",
                            icon: "arrow.right.circle",
                            color: .cyan,
                            filled: false
                        ) {
                            guard !playerName.isEmpty, !roomCode.isEmpty else { return }
                            isHosting = false
                            connectionManager.stopNetworking()
                            connectionManager.startJoining(name: playerName, roomCode: roomCode)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cyan.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(showNetworkPanel ? 0.3 : 0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        switch connectionManager.lobbyState {
        case .searching:
            HStack(spacing: 10) {
                ProgressView().tint(.cyan).scaleEffect(0.8)
                Text(isHosting ? "Hosting — waiting for opponent..." : "Searching for host...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

        case .connected:
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("Connected to \(connectionManager.opponentName)!")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

        case .failed(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Text(msg)
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

        case .idle:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func fieldRow(icon: String, placeholder: String, text: Binding<String>, allCaps: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)
            TextField(placeholder, text: text)
                .foregroundColor(.white)
                .font(.system(.subheadline, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(allCaps ? .characters : .words)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Nickname Sheet

    private var nicknameSheet: some View {
        ZStack {
            Color(red: 0.04, green: 0.10, blue: 0.22).ignoresSafeArea()

            VStack(spacing: 28) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Text("CAPTAINS")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundColor(.white)
                        .tracking(4)
                    Text("Enter your names before battle")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                VStack(spacing: 14) {
                    nicknameField(label: "P1", placeholder: "Player 1 name", text: $nicknameP1)
                    nicknameField(label: "P2", placeholder: "Player 2 name", text: $nicknameP2)
                }
                .padding(.horizontal, 24)

                Button(action: {
                    showNicknameSheet = false
                    connectionManager.stopNetworking()
                    viewModel.startLocalGame(
                        p1Name: nicknameP1.trimmingCharacters(in: .whitespaces),
                        p2Name: nicknameP2.trimmingCharacters(in: .whitespaces)
                    )
                    isGameActive = true
                }) {
                    Text("DEPLOY FLEET")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func nicknameField(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(.cyan)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .foregroundColor(.white)
                .font(.system(.subheadline, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func actionButton(label: String, icon: String, color: Color, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(.subheadline, design: .monospaced).bold())
            }
            .foregroundColor(filled ? .white : color)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(filled ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color, lineWidth: filled ? 0 : 1.5)
                    )
            )
        }
    }
}
