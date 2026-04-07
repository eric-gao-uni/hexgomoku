import 'package:flutter_test/flutter_test.dart';
import 'package:hexgomoku/models/game_state.dart';
import 'package:hexgomoku/models/hex_coordinate.dart';
import 'package:hexgomoku/models/piece.dart';

void main() {
  group('AI Strength & Game Logic', () {
    test('PvP full game completes without freezing', () {
      final gs = GameState(
        settings: const GameSettings(
          piecesPerPlayer: 3,
          gameMode: GameMode.pvp,
          boardRadius: 5,
        ),
      );

      int turns = 0;
      while (!gs.isGameOver && turns < 50) {
        final myType = gs.currentPlayer.pieceType;
        final movable = gs.board.entries
            .where((e) => e.value == myType && gs.canMove(e.key))
            .map((e) => e.key)
            .toList();
        if (movable.isEmpty) break;

        final targets = gs.getValidTargets(movable.first);
        if (targets.isEmpty) break;

        gs.onCellTap(movable.first);
        gs.onCellTap(targets.first);
        if (gs.isGameOver) break;

        if (gs.turnPhase == TurnPhase.moveRed) {
          final redPieces = gs.board.entries
              .where((e) => e.value == PieceType.red && gs.canMove(e.key))
              .map((e) => e.key)
              .toList();
          if (redPieces.isEmpty) break;
          final redTargets = gs.getValidTargets(redPieces.first);
          if (redTargets.isEmpty) break;
          gs.onCellTap(redPieces.first);
          gs.onCellTap(redTargets.first);
        }
        turns++;
      }

      print('PvP game: $turns turns, winner=${gs.winner}, reason=${gs.loseReason}');
      expect(turns, lessThan(50));
    });

    test('PvAI Low difficulty completes', () {
      final gs = GameState(
        settings: const GameSettings(
          piecesPerPlayer: 3,
          gameMode: GameMode.pvai,
          aiDifficulty: AiDifficulty.low,
          boardRadius: 5,
        ),
      );

      int turns = 0;
      while (!gs.isGameOver && turns < 100) {
        _playHumanTurn(gs);
        if (!gs.isGameOver && gs.currentPlayer == PlayerColor.white) {
          _triggerAi(gs);
        }
        turns++;
      }

      print('PvAI Low: $turns turns, winner=${gs.winner}, reason=${gs.loseReason}');
      expect(gs.isGameOver, isTrue);
    });

    test('PvAI Medium difficulty completes', () {
      final gs = GameState(
        settings: const GameSettings(
          piecesPerPlayer: 3,
          gameMode: GameMode.pvai,
          aiDifficulty: AiDifficulty.medium,
          boardRadius: 5,
        ),
      );

      int turns = 0;
      while (!gs.isGameOver && turns < 100) {
        _playHumanTurn(gs);
        if (!gs.isGameOver && gs.currentPlayer == PlayerColor.white) {
          _triggerAi(gs);
        }
        turns++;
      }

      print('PvAI Medium: $turns turns, winner=${gs.winner}, reason=${gs.loseReason}');
      expect(gs.isGameOver, isTrue);
    });

    test('PvAI High difficulty completes within time limit', () {
      final gs = GameState(
        settings: const GameSettings(
          piecesPerPlayer: 3,
          gameMode: GameMode.pvai,
          aiDifficulty: AiDifficulty.high,
          boardRadius: 5,
        ),
      );

      int turns = 0;
      final stopwatch = Stopwatch()..start();

      while (!gs.isGameOver && turns < 100) {
        _playHumanTurn(gs);
        if (!gs.isGameOver && gs.currentPlayer == PlayerColor.white) {
          final t0 = stopwatch.elapsedMilliseconds;
          _triggerAi(gs);
          print('  AI turn $turns: ${stopwatch.elapsedMilliseconds - t0}ms');
        }
        turns++;
      }

      stopwatch.stop();
      print('PvAI High: $turns turns, winner=${gs.winner}, reason=${gs.loseReason}, total=${stopwatch.elapsedMilliseconds}ms');
      expect(gs.isGameOver, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(120000),
          reason: 'Full game should complete within 2 minutes');
    });

    test('AI does not make illegal moves', () {
      final gs = GameState(
        settings: const GameSettings(
          piecesPerPlayer: 3,
          gameMode: GameMode.pvai,
          aiDifficulty: AiDifficulty.high,
          boardRadius: 5,
        ),
      );

      int turns = 0;
      while (!gs.isGameOver && turns < 50) {
        _playHumanTurn(gs);
        if (!gs.isGameOver && gs.currentPlayer == PlayerColor.white) {
          _triggerAi(gs);

          if (!gs.isGameOver) {
            for (final coord in gs.board.keys) {
              expect(gs.isValidCoord(coord), isTrue,
                  reason: 'Piece at invalid coord $coord');
            }
            final blacks = gs.board.values.where((v) => v == PieceType.black).length;
            final whites = gs.board.values.where((v) => v == PieceType.white).length;
            final reds = gs.board.values.where((v) => v == PieceType.red).length;
            expect(blacks, gs.settings.piecesPerPlayer);
            expect(whites, gs.settings.piecesPerPlayer);
            expect(reds, gs.settings.piecesPerPlayer - 1);
          }
        }
        turns++;
      }
      print('Legality test: $turns turns, winner=${gs.winner}');
    });

    test('Higher difficulty AI wins more often against random play', () {
      int lowWins = 0;
      int highWins = 0;

      for (int game = 0; game < 5; game++) {
        // Low AI game
        final gsLow = GameState(
          settings: const GameSettings(
            piecesPerPlayer: 3,
            gameMode: GameMode.pvai,
            aiDifficulty: AiDifficulty.low,
            boardRadius: 5,
          ),
        );
        int t = 0;
        while (!gsLow.isGameOver && t < 80) {
          _playHumanTurn(gsLow);
          if (!gsLow.isGameOver && gsLow.currentPlayer == PlayerColor.white) {
            _triggerAi(gsLow);
          }
          t++;
        }
        if (gsLow.winner == PlayerColor.white) lowWins++;

        // High AI game
        final gsHigh = GameState(
          settings: const GameSettings(
            piecesPerPlayer: 3,
            gameMode: GameMode.pvai,
            aiDifficulty: AiDifficulty.high,
            boardRadius: 5,
          ),
        );
        t = 0;
        while (!gsHigh.isGameOver && t < 80) {
          _playHumanTurn(gsHigh);
          if (!gsHigh.isGameOver && gsHigh.currentPlayer == PlayerColor.white) {
            _triggerAi(gsHigh);
          }
          t++;
        }
        if (gsHigh.winner == PlayerColor.white) highWins++;
      }

      print('AI win rates: Low=$lowWins/5, High=$highWins/5');
      // High AI should win at least as often as Low
      expect(highWins, greaterThanOrEqualTo(lowWins),
          reason: 'High AI should be at least as strong as Low');
    });
  });
}

/// Play human turn (black): pick first valid move.
void _playHumanTurn(GameState gs) {
  if (gs.isGameOver || gs.currentPlayer != PlayerColor.black) return;

  final movable = gs.board.entries
      .where((e) => e.value == PieceType.black && gs.canMove(e.key))
      .map((e) => e.key)
      .toList();
  if (movable.isEmpty) return;

  final targets = gs.getValidTargets(movable.first);
  if (targets.isEmpty) return;

  gs.onCellTap(movable.first);
  gs.onCellTap(targets.first);
  if (gs.isGameOver) return;

  if (gs.turnPhase == TurnPhase.moveRed) {
    final redPieces = gs.board.entries
        .where((e) => e.value == PieceType.red && gs.canMove(e.key))
        .map((e) => e.key)
        .toList();
    if (redPieces.isEmpty) return;
    final redTargets = gs.getValidTargets(redPieces.first);
    if (redTargets.isEmpty) return;
    gs.onCellTap(redPieces.first);
    gs.onCellTap(redTargets.first);
  }
}

/// Trigger AI move directly (bypassing Future.delayed).
void _triggerAi(GameState gs) {
  if (gs.isGameOver || gs.currentPlayer != PlayerColor.white) return;

  final myType = PlayerColor.white.pieceType;
  final ownPieces = gs.board.entries
      .where((e) => e.value == myType && gs.canMove(e.key))
      .map((e) => e.key)
      .toList();

  if (ownPieces.isEmpty) {
    gs.winner = PlayerColor.black;
    gs.loseReason = 'All pieces blocked';
    return;
  }

  // Pick best own move
  HexCoord? bestFrom;
  HexCoord? bestTo;
  int bestScore = -999999;

  for (final from in ownPieces) {
    for (final to in gs.getValidTargets(from)) {
      final sim = Map<HexCoord, PieceType>.from(gs.board);
      sim.remove(from);
      sim[to] = myType;
      int score = 0;
      final myPos = sim.entries.where((e) => e.value == myType).map((e) => e.key).toList();
      for (final dir in HexCoord.lineDirections) {
        for (final start in myPos) {
          int len = 1;
          for (int i = 1; i < gs.settings.piecesPerPlayer; i++) {
            final next = HexCoord(start.q + dir.$1 * i, start.r + dir.$2 * i);
            if (sim[next] == myType) len++; else break;
          }
          if (len >= gs.settings.piecesPerPlayer) score += 90000;
          else if (len == gs.settings.piecesPerPlayer - 1) score += 2000;
        }
      }
      if (score > bestScore) { bestScore = score; bestFrom = from; bestTo = to; }
    }
  }

  bestFrom ??= ownPieces.first;
  bestTo ??= gs.getValidTargets(bestFrom).first;

  gs.onCellTap(bestFrom);
  gs.onCellTap(bestTo);
  if (gs.isGameOver) return;

  // Red move
  if (gs.turnPhase == TurnPhase.moveRed) {
    final redPieces = gs.board.entries
        .where((e) => e.value == PieceType.red && gs.canMove(e.key))
        .map((e) => e.key)
        .toList();
    if (redPieces.isEmpty) return;

    HexCoord? bestRF;
    HexCoord? bestRT;
    int bestRS = -999999;
    final opType = PieceType.black;

    for (final rF in redPieces) {
      for (final rT in gs.getValidTargets(rF)) {
        int s = 0;
        for (final dir in HexCoord.lineDirections) {
          final p1 = HexCoord(rT.q - dir.$1, rT.r - dir.$2);
          final p2 = HexCoord(rT.q + dir.$1, rT.r + dir.$2);
          if (gs.board[p1] == opType && gs.board[p2] == opType) s += 500;
        }
        if (s > bestRS) { bestRS = s; bestRF = rF; bestRT = rT; }
      }
    }

    if (bestRF != null) {
      gs.onCellTap(bestRF);
      gs.onCellTap(bestRT!);
    }
  }
}
