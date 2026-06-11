# Battleship ⚓️

The classic game of **Battleship**, built as a native iOS app in Swift & SwiftUI.

Place your fleet on a 10×10 grid, take turns calling shots, and sink your
opponent's ships before they sink yours — on one device or two.

## Features

- **Local Pass & Play** — two players share one device, with a hand-off screen
  between turns so nobody sees the other's board
- **Nearby Multiplayer** — play against a friend on another iPhone over the local
  network (MultipeerConnectivity), no internet required
- Drag-to-place fleet setup with horizontal/vertical rotation
- Live ship-status tracking and hit/miss feedback
- Clean SwiftUI board and lobby

## Tech

- **Swift** + **SwiftUI** (iOS)
- **MultipeerConnectivity** for peer-to-peer matches
- **Combine** for reactive game state
- Architecture: a `GameViewModel` drives a phase machine
  (`lobby → setup → active → gameOver`); moves are exchanged between devices as
  `GameMove` messages through a `ConnectionManager`.

## Project layout

```
BattleShip/
├── Models/          GameMove, Cell, Ship
├── ViewModels/      GameViewModel (phases, turns, win detection)
├── Networking/      ConnectionManager (MultipeerConnectivity)
└── Views/           Lobby, GameBoard, Cell, ShipStatus
```

## Running it

1. Open `BattleShip.xcodeproj` in Xcode.
2. Local pass & play runs in the simulator; nearby multiplayer needs two physical
   devices on the same network.
3. Build & run.

## Status

Local pass & play is playable. Nearby (MultipeerConnectivity) multiplayer is in
active development.

---

Built by [CJ (cetijunior)](https://github.com/cetijunior) · [CA Web Services](https://www.ca-webservices.com/)
