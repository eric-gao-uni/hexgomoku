# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HexGomoku is a strategic board game played on a hexagonal grid, invented by a child and implemented as a Flutter app. Two players (Black and White) take turns moving their own pieces and a shared Red piece. Win by aligning all your pieces in a straight line, or when your opponent has no valid moves / runs out of time.

## Build Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build ios        # Build iOS (requires macOS + Xcode)
flutter test             # Run tests (currently only a stub)
flutter analyze          # Run static analysis (flutter_lints)
```

## Architecture

**State management**: `ChangeNotifier` pattern — `GameState` is the single source of truth, consumed by widgets via `ListenableBuilder`.

### Key modules

- **`lib/models/game_state.dart`** — Core game engine (~1000 lines). Contains `GameState` (board state, turn logic, timer, AI, win detection, undo) and `GameSettings` (mode, difficulty, board radius, pieces count, time limit). This is the most important file.
- **`lib/models/hex_coordinate.dart`** — Axial hex coordinate system (`q`, `r`, derived `s = -q - r`). Provides `neighbors()` and `lineDirections` for the three hex axes.
- **`lib/models/piece.dart`** — Enums: `PieceType`, `PlayerColor`, `TurnPhase`, `GameMode`, `AiDifficulty`.

### Game rules encoded in code

- **Two-phase turns**: Each turn has `moveOwn` (move your piece) then `moveRed` (move shared red piece).
- **Liberties (Qi)**: A destination must have ≥2 non-adjacent empty neighbors.
- **Connectivity**: After moving red, all pieces on the board must remain a single connected component (BFS check).
- **Board representation**: Sparse `Map<HexCoord, PieceType>` — efficient for variable-radius boards (3–8).
- **Initial placement**: Hardcoded for n=3, generated programmatically for n=4–5.

### AI

Three difficulty levels in `_aiMove()`:
- **Low**: Greedy — pick highest-scoring move with no lookahead.
- **Medium**: Top-15 pruning + evaluate all red moves.
- **High**: Depth-2 minimax — simulates opponent's best response.

Evaluation heuristic scores line formations (3/4/5-in-a-row with open/semi-open modifiers) and red blocking bonuses.

### UI layers

- **`lib/screens/`** — `GameScreen` (main), `SettingsScreen`, `VictoryScreen` (transparent overlay).
- **`lib/widgets/`** — `HexBoard` (renders hex grid via `CustomPaint` + `InteractiveViewer` for zoom/pan), `GameControls` (turn indicator, timers, undo/reset), `RulesDialog`.

## Platform

Primary targets: iOS and Android. Portrait-only. Dark theme with maroon background (`0xFF1A0D0D`) and red accent (`0xFFEC1313`), Spline Sans font via `google_fonts`.

## Dependencies

Minimal: `google_fonts` for typography, `upgrader` for in-app update prompts. No state management packages — uses built-in `ChangeNotifier`.
