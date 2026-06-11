//
//  ConnectionManager.swift
//  BattleShip
//
//  Created by Ceti Junior on 02.06.2026.
//


import Foundation
import MultipeerConnectivity
import Combine
import UIKit

enum ConnectionRole {
    case host, joiner
}

enum LobbyState: Equatable {
    case idle
    case searching
    case connected
    case failed(String)
}

class ConnectionManager: NSObject, ObservableObject {
    private let serviceType = "bs-mp-game"

    @Published var lobbyState: LobbyState = .idle
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMove: GameMove?
    @Published var opponentName: String = ""
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var isScanningLocalNetwork: Bool = false

    private var myPeerId: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var scanTimer: Timer?

    private var roomCode: String = ""
    private var myName: String = ""

    func startHosting(name: String, roomCode: String) {
        self.myName = name
        self.roomCode = roomCode.uppercased()
        setupSession(name: name)

        let info = ["room": self.roomCode, "name": name]
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: info, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        lobbyState = .searching
    }

    func startJoining(name: String, roomCode: String) {
        self.myName = name
        self.roomCode = roomCode.uppercased()
        setupSession(name: name)

        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        lobbyState = .searching
    }

    /// Begin scanning the local network for available hosts advertising the Battleship service.
    /// Optionally provide a duration to auto-stop scanning.
    func startLocalNetworkScan(duration: TimeInterval = 15) {
        setupSession(name: myName.isEmpty ? UIDevice.current.name : myName)
        discoveredPeers.removeAll()
        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        isScanningLocalNetwork = true
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopLocalNetworkScan()
        }
    }

    /// Stop scanning and clear any active timers.
    func stopLocalNetworkScan() {
        browser?.stopBrowsingForPeers()
        isScanningLocalNetwork = false
        scanTimer?.invalidate()
        scanTimer = nil
    }

    /// Invite a discovered peer manually (e.g., selected from a UI list)
    func invite(_ peer: MCPeerID) {
        guard let browser else { return }
        let context = try? JSONEncoder().encode(["room": roomCode, "name": myName])
        browser.invitePeer(peer, to: session, withContext: context, timeout: 15)
    }

    func stopNetworking() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        scanTimer?.invalidate()
        scanTimer = nil
        isScanningLocalNetwork = false
        discoveredPeers.removeAll()
        lobbyState = .idle
    }

    func send(move: GameMove) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(move)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Send error: \(error)")
        }
    }

    private func setupSession(name: String) {
        myPeerId = MCPeerID(displayName: name)
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
}

// MARK: - MCSessionDelegate
extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.discoveredPeers.removeAll { $0 == peerID }
            if state == .connected {
                self.opponentName = peerID.displayName
                self.lobbyState = .connected
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
            } else if state == .notConnected && self.lobbyState == .connected {
                self.lobbyState = .failed("Opponent disconnected")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let move = try? JSONDecoder().decode(GameMove.self, from: data) {
            DispatchQueue.main.async { self.receivedMove = move }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser (Host)
extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Verify the joiner sent the correct room code
        guard let context,
              let info = try? JSONDecoder().decode([String: String].self, from: context),
              info["room"] == roomCode else {
            invitationHandler(false, nil)
            return
        }
        if !discoveredPeers.contains(peerID) {
            DispatchQueue.main.async { self.discoveredPeers.append(peerID) }
        }
        invitationHandler(true, session)
    }
}

// MARK: - Browser (Joiner)
extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Track all discovered peers
        if !discoveredPeers.contains(peerID) {
            DispatchQueue.main.async { self.discoveredPeers.append(peerID) }
        }
        // Only auto-invite when the advertised room matches our target room
        guard info?["room"] == roomCode else { return }
        let context = try? JSONEncoder().encode(["room": roomCode, "name": myName])
        browser.invitePeer(peerID, to: session, withContext: context, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
}
