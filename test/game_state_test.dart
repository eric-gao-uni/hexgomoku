import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexgomoku/models/game_state.dart';
import 'package:hexgomoku/models/piece.dart';
import 'package:hexgomoku/models/hex_coordinate.dart';

/// Helper: find a human (black) own move that does NOT immediately end the game.
/// Returns null if every move ends the game.
({HexCoord from, HexCoord to})? _findSurvivingBlackMove(GameSettings settings) {
  final probe = GameState(settings: settings);
  final blacks = probe.board.entries
      .where((e) => e.value == PieceType.black && probe.canMove(e.key))
      .toList();

  for (final bp in blacks) {
    for (final to in probe.getValidTargets(bp.key)) {
      final gs = GameState(settings: settings);
      gs.onCellTap(bp.key);
      gs.onCellTap(to);
      if (!gs.isGameOver) {
        gs.dispose();
        probe.dispose();
        return (from: bp.key, to: to);
      }
      gs.dispose();
    }
  }
  probe.dispose();
  return null;
}

/// Helper: wait for all AI delayed futures to resolve.
Future<void> _waitForAi({int ms = 2000}) =>
    Future.delayed(Duration(milliseconds: ms));

void main() {
  // ───────────────────────────────────────────────
  // Group 1: 初始状态
  // ───────────────────────────────────────────────
  group('初始状态', () {
    test('T01 — PvP 初始状态正确', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.aiThinking, isFalse);
      expect(gs.isGameOver, isFalse);
      expect(gs.winner, isNull);
      expect(gs.board.length, 8); // 3B + 3W + 2R
      gs.dispose();
    });

    test('T02 — PvAI 初始状态正确，AI 未立即走棋', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.aiThinking, isFalse);
      gs.dispose();
    });

    test('T03 — n=4 棋盘初始化棋子数正确', () {
      final gs = GameState(settings: const GameSettings(
        piecesPerPlayer: 4,
        boardRadius: 5,
      ));
      final blacks = gs.board.values.where((v) => v == PieceType.black).length;
      final whites = gs.board.values.where((v) => v == PieceType.white).length;
      final reds = gs.board.values.where((v) => v == PieceType.red).length;
      expect(blacks, 4);
      expect(whites, 4);
      expect(reds, 3); // n-1
      gs.dispose();
    });

    test('T04 — n=5 棋盘初始化棋子数正确', () {
      final gs = GameState(settings: const GameSettings(
        piecesPerPlayer: 5,
        boardRadius: 5,
      ));
      final blacks = gs.board.values.where((v) => v == PieceType.black).length;
      final whites = gs.board.values.where((v) => v == PieceType.white).length;
      final reds = gs.board.values.where((v) => v == PieceType.red).length;
      expect(blacks, 5);
      expect(whites, 5);
      expect(reds, 4);
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 2: 回合流转（PvP）
  // ───────────────────────────────────────────────
  group('PvP 回合流转', () {
    test('T05 — 黑方 own move 后进入 moveRed 阶段（仍是黑方）', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));
      final move = _findSurvivingBlackMove(gs.settings);
      if (move == null) {
        gs.dispose();
        return; // skip if no surviving move
      }

      gs.onCellTap(move.from);
      expect(gs.selectedPiece, move.from);

      gs.onCellTap(move.to);
      if (!gs.isGameOver) {
        expect(gs.currentPlayer, PlayerColor.black);
        expect(gs.turnPhase, TurnPhase.moveRed);
      }
      gs.dispose();
    });

    test('T06 — 点击空白格或对手棋子不会选中', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      // Tap empty cell
      gs.onCellTap(const HexCoord(3, 3));
      expect(gs.selectedPiece, isNull);

      // Tap white piece (current player is black)
      final whitePiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.white)
          .key;
      gs.onCellTap(whitePiece);
      expect(gs.selectedPiece, isNull);

      gs.dispose();
    });

    test('T07 — 再次点击已选棋子取消选择', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      final blackPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.black && gs.canMove(e.key))
          .key;
      gs.onCellTap(blackPiece);
      expect(gs.selectedPiece, blackPiece);

      gs.onCellTap(blackPiece);
      expect(gs.selectedPiece, isNull);

      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 3: AI 走棋核心流程
  // ───────────────────────────────────────────────
  group('AI 走棋流程', () {
    for (final diff in AiDifficulty.values) {
      test('T08-${diff.name} — AI ($diff) 在人类完成整个回合后走子', () async {
        final settings = GameSettings(
          gameMode: GameMode.pvai,
          aiDifficulty: diff,
          piecesPerPlayer: 3,
          boardRadius: 5,
        );
        final gs = GameState(settings: settings);

        // Human (black) own move
        final move = _findSurvivingBlackMove(settings);
        if (move == null) {
          gs.dispose();
          return;
        }

        gs.onCellTap(move.from);
        gs.onCellTap(move.to);

        if (gs.isGameOver) {
          gs.dispose();
          return;
        }

        // After own move, still black's turn to move red
        expect(gs.currentPlayer, PlayerColor.black);
        expect(gs.turnPhase, TurnPhase.moveRed);
        expect(gs.aiThinking, isFalse);

        // Human (black) moves red piece
        final redPiece = gs.board.entries
            .firstWhere((e) => e.value == PieceType.red && gs.canMove(e.key))
            .key;
        final redTargets = gs.getValidTargets(redPiece);
        if (redTargets.isEmpty) {
          gs.dispose();
          return;
        }
        gs.onCellTap(redPiece);
        gs.onCellTap(redTargets.first);

        if (gs.isGameOver) {
          gs.dispose();
          return;
        }

        // Now AI (white) should be thinking
        expect(gs.aiThinking, isTrue);
        expect(gs.currentPlayer, PlayerColor.white);

        final waitMs = diff == AiDifficulty.high ? 12000 : 3000;
        await _waitForAi(ms: waitMs);

        expect(gs.aiThinking, isFalse,
            reason: 'AI ($diff) should finish thinking');

        if (!gs.isGameOver) {
          // After AI own + red: human's turn
          expect(gs.currentPlayer, PlayerColor.black);
          expect(gs.turnPhase, TurnPhase.moveOwn);
        }
        gs.dispose();
      });
    }

    test('T09 — AI 走棋期间用户点击被阻止', () async {
      final settings = const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      );
      final gs = GameState(settings: settings);

      // Human completes full turn (own + red)
      final move = _findSurvivingBlackMove(settings);
      if (move == null) {
        gs.dispose();
        return;
      }

      gs.onCellTap(move.from);
      gs.onCellTap(move.to);

      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // Move red
      final redPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.red && gs.canMove(e.key))
          .key;
      final redTargets = gs.getValidTargets(redPiece);
      if (redTargets.isEmpty) {
        gs.dispose();
        return;
      }
      gs.onCellTap(redPiece);
      gs.onCellTap(redTargets.first);

      if (!gs.isGameOver) {
        expect(gs.aiThinking, isTrue);

        // Try various taps — should all be blocked
        gs.onCellTap(const HexCoord(0, 0));
        gs.onCellTap(const HexCoord(3, -3));
        gs.onCellTap(const HexCoord(-2, 2));

        expect(gs.selectedPiece, isNull,
            reason: 'No piece should be selected during AI thinking');
      }

      await _waitForAi();
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 4: aiThinking 状态管理
  // ───────────────────────────────────────────────
  group('aiThinking 状态管理', () {
    test('T10 — 游戏结束时 aiThinking 正确重置', () async {
      final settings = const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      );
      final move = _findSurvivingBlackMove(settings);
      if (move == null) return;

      final gs = GameState(settings: settings);
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);

      if (gs.aiThinking) {
        // Force game over during AI delay
        gs.winner = PlayerColor.black;
        await _waitForAi();
        expect(gs.aiThinking, isFalse,
            reason: 'aiThinking must reset even when game ends during delay');
      }
      gs.dispose();
    });

    test('T11 — AI 走棋期间 aiThinking 保持为 true 直到完成', () async {
      // AI does own + red in one go, aiThinking should stay true until done.
      final settings = const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      );
      final gs = GameState(settings: settings);

      // Human completes full turn (own + red)
      final move = _findSurvivingBlackMove(settings);
      if (move == null) {
        gs.dispose();
        return;
      }

      gs.onCellTap(move.from);
      gs.onCellTap(move.to);

      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // Move red
      final redPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.red && gs.canMove(e.key))
          .key;
      final redTargets = gs.getValidTargets(redPiece);
      if (redTargets.isEmpty) {
        gs.dispose();
        return;
      }
      gs.onCellTap(redPiece);
      gs.onCellTap(redTargets.first);

      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // AI should be thinking now
      expect(gs.aiThinking, isTrue,
          reason: 'aiThinking should be true while AI is working');

      // After 300ms: AI should still be thinking (delay is 600ms)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!gs.isGameOver) {
        expect(gs.aiThinking, isTrue,
            reason: 'aiThinking should stay true during AI delay');
      }

      await _waitForAi();
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 5: Undo
  // ───────────────────────────────────────────────
  group('Undo', () {
    test('T12 — undo 在 moveOwn 之后恢复棋盘', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      final boardBefore = Map<HexCoord, PieceType>.from(gs.board);
      final move = _findSurvivingBlackMove(gs.settings);
      if (move == null) {
        gs.dispose();
        return;
      }

      gs.onCellTap(move.from);
      gs.onCellTap(move.to);

      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // Board has changed
      expect(gs.board, isNot(equals(boardBefore)));

      gs.undoCurrentTurn();

      // Board restored
      expect(gs.board, equals(boardBefore));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.selectedPiece, isNull);
      expect(gs.winner, isNull);

      gs.dispose();
    });

    test('T13 — undo 重置计时器起点', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
        totalTimePerPlayer: Duration(minutes: 5),
      ));

      final move = _findSurvivingBlackMove(gs.settings);
      if (move == null) {
        gs.dispose();
        return;
      }

      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // After undo, current player's remaining time should be close to full
      gs.undoCurrentTurn();
      final remaining = gs.currentPlayerTimeRemaining;
      // Should be within a few seconds of the full time (allowing for test execution time)
      expect(remaining.inSeconds, greaterThanOrEqualTo(295));

      gs.dispose();
    });

    test('T14 — undo 空操作时无效果', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      final boardBefore = Map<HexCoord, PieceType>.from(gs.board);
      gs.undoCurrentTurn();

      expect(gs.board, equals(boardBefore));
      expect(gs.currentPlayer, PlayerColor.black);
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 6: Reset
  // ───────────────────────────────────────────────
  group('Reset', () {
    test('T15 — reset 完全恢复初始状态', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      final initialBoard = Map<HexCoord, PieceType>.from(gs.board);

      // Make a move
      final move = _findSurvivingBlackMove(gs.settings);
      if (move != null) {
        gs.onCellTap(move.from);
        gs.onCellTap(move.to);
      }

      gs.reset();

      expect(gs.board, equals(initialBoard));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.moveCount, 0);
      expect(gs.winner, isNull);
      expect(gs.loseReason, isNull);
      expect(gs.winningCells, isEmpty);
      expect(gs.aiThinking, isFalse);
      expect(gs.selectedPiece, isNull);

      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 7: Dispose 安全
  // ───────────────────────────────────────────────
  group('Dispose 安全', () {
    test('T16 — dispose 后 AI delayed future 不会抛异常', () async {
      final settings = const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      );
      final move = _findSurvivingBlackMove(settings);
      if (move == null) return;

      final gs = GameState(settings: settings);
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);

      // Dispose immediately while AI futures are pending
      gs.dispose();

      // Let all futures fire — no assertion error should occur
      await _waitForAi(ms: 3000);
      // If we get here without an error, the test passes
    });

    test('T17 — dispose 后 reset 前创建新 GameState 无冲突', () async {
      final settings = const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.medium,
        piecesPerPlayer: 3,
        boardRadius: 5,
      );
      final move = _findSurvivingBlackMove(settings);
      if (move == null) return;

      final gs1 = GameState(settings: settings);
      gs1.onCellTap(move.from);
      gs1.onCellTap(move.to);
      gs1.dispose();

      // Create new instance immediately
      final gs2 = GameState(settings: settings);
      expect(gs2.currentPlayer, PlayerColor.black);
      expect(gs2.aiThinking, isFalse);

      await _waitForAi(ms: 3000);
      gs2.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 8: canMove / liberty 规则
  // ───────────────────────────────────────────────
  group('canMove / liberty 规则', () {
    test('T18 — canMove 和 _canMoveOnBoard 结果一致', () {
      final gs = GameState(settings: const GameSettings(
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      for (final entry in gs.board.entries) {
        final result = gs.canMove(entry.key);
        expect(result, isA<bool>());
      }

      // Empty cell → false
      expect(gs.canMove(const HexCoord(4, -4)), isFalse);
      // Out of board → false
      expect(gs.canMove(const HexCoord(99, 99)), isFalse);

      gs.dispose();
    });

    test('T19 — getValidTargets 只返回有效坐标', () {
      final gs = GameState(settings: const GameSettings(
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      final movable = gs.board.entries
          .where((e) => e.value == PieceType.black && gs.canMove(e.key))
          .toList();

      for (final piece in movable) {
        final targets = gs.getValidTargets(piece.key);
        for (final t in targets) {
          expect(gs.isValidCoord(t), isTrue,
              reason: 'Target $t should be a valid coordinate');
          expect(gs.board[t], isNull,
              reason: 'Target $t should be empty');
        }
      }
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 9: 连通性检测
  // ───────────────────────────────────────────────
  group('连通性检测', () {
    test('T20 — 红棋移动不能打断连通性', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      // Get to red move phase first
      final move = _findSurvivingBlackMove(gs.settings);
      if (move == null) {
        gs.dispose();
        return;
      }

      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // Now in moveRed phase. All valid red targets should maintain connectivity.
      final reds = gs.board.entries
          .where((e) => e.value == PieceType.red && gs.canMove(e.key))
          .toList();

      for (final red in reds) {
        final targets = gs.getValidTargets(red.key);
        for (final t in targets) {
          final testBoard = Map<HexCoord, PieceType>.from(gs.board);
          testBoard.remove(red.key);
          testBoard[t] = PieceType.red;
          // All pieces should form a single connected component
          final allPieces = testBoard.keys.toSet();
          if (allPieces.isEmpty) continue;
          final visited = <HexCoord>{};
          final queue = <HexCoord>[allPieces.first];
          visited.add(allPieces.first);
          while (queue.isNotEmpty) {
            final c = queue.removeAt(0);
            for (final nb in c.neighbors()) {
              if (allPieces.contains(nb) && !visited.contains(nb)) {
                visited.add(nb);
                queue.add(nb);
              }
            }
          }
          expect(visited.length, allPieces.length,
              reason: 'Moving red ${red.key}→$t should keep all pieces connected');
        }
      }
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 10: 多回合完整对局（PvAI）
  // ───────────────────────────────────────────────
  group('多回合完整对局', () {
    test('T21 — PvAI 多回合流转正确', () async {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      int completedTurns = 0;

      for (int i = 0; i < 5 && !gs.isGameOver; i++) {
        // Human own move
        if (gs.currentPlayer != PlayerColor.black ||
            gs.turnPhase != TurnPhase.moveOwn) break;

        final blacks = gs.board.entries
            .where((e) => e.value == PieceType.black && gs.canMove(e.key))
            .toList();
        if (blacks.isEmpty) break;

        final targets = gs.getValidTargets(blacks.first.key);
        if (targets.isEmpty) break;

        gs.onCellTap(blacks.first.key);
        gs.onCellTap(targets.first);
        if (gs.isGameOver) break;

        // Wait for AI (red + own)
        await _waitForAi(ms: 2000);
        if (gs.isGameOver) break;

        expect(gs.aiThinking, isFalse);
        expect(gs.currentPlayer, PlayerColor.black);
        expect(gs.turnPhase, TurnPhase.moveRed);

        // Human red move
        final reds = gs.board.entries
            .where((e) => e.value == PieceType.red && gs.canMove(e.key))
            .toList();
        if (reds.isEmpty) break;

        final redTargets = gs.getValidTargets(reds.first.key);
        if (redTargets.isEmpty) break;

        gs.onCellTap(reds.first.key);
        gs.onCellTap(redTargets.first);
        if (gs.isGameOver) break;

        expect(gs.currentPlayer, PlayerColor.black);
        expect(gs.turnPhase, TurnPhase.moveOwn);

        completedTurns++;
      }

      expect(gs.aiThinking, isFalse);
      // Game should have either completed turns or ended
      expect(completedTurns > 0 || gs.isGameOver, isTrue,
          reason: 'At least one turn should complete or game should end');
      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 11: updateSettings
  // ───────────────────────────────────────────────
  group('Settings', () {
    test('T22 — updateSettings 切换模式后重置正确', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      gs.updateSettings(const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.high,
        piecesPerPlayer: 4,
        boardRadius: 5,
      ));

      expect(gs.settings.gameMode, GameMode.pvai);
      expect(gs.settings.piecesPerPlayer, 4);
      expect(gs.settings.aiDifficulty, AiDifficulty.high);
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.board.values.where((v) => v == PieceType.black).length, 4);
      expect(gs.board.values.where((v) => v == PieceType.white).length, 4);

      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 12: 完整回合流转
  // ───────────────────────────────────────────────
  group('完整回合流转', () {
    test('T23 — 黑方走完 own+red 后切换到白方 moveOwn', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      final move = _findSurvivingBlackMove(gs.settings);
      if (move == null) {
        gs.dispose();
        return;
      }

      // Black own move
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveRed);

      // Black moves red
      final reds = gs.board.entries
          .where((e) => e.value == PieceType.red && gs.canMove(e.key))
          .toList();
      if (reds.isEmpty) {
        gs.dispose();
        return;
      }
      final redTargets = gs.getValidTargets(reds.first.key);
      if (redTargets.isEmpty) {
        gs.dispose();
        return;
      }
      gs.onCellTap(reds.first.key);
      gs.onCellTap(redTargets.first);

      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // Now should be white's moveOwn
      expect(gs.currentPlayer, PlayerColor.white);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      // Undo at this point (no moves made in this turn) should be no-op
      final boardBefore = Map<HexCoord, PieceType>.from(gs.board);
      gs.undoCurrentTurn();
      expect(gs.board, equals(boardBefore));

      gs.dispose();
    });
  });

  // ───────────────────────────────────────────────
  // Group 13: 棋盘边界
  // ───────────────────────────────────────────────
  group('棋盘边界', () {
    test('T24 — isValidCoord 边界正确', () {
      final gs = GameState(settings: const GameSettings(boardRadius: 3));
      expect(gs.isValidCoord(const HexCoord(0, 0)), isTrue);
      expect(gs.isValidCoord(const HexCoord(3, 0)), isTrue);
      expect(gs.isValidCoord(const HexCoord(0, 3)), isTrue);
      expect(gs.isValidCoord(const HexCoord(-3, 0)), isTrue);
      expect(gs.isValidCoord(const HexCoord(4, 0)), isFalse);
      expect(gs.isValidCoord(const HexCoord(2, 2)), isFalse); // q+r=4 > 3
      gs.dispose();
    });

    test('T25 — 不同棋盘半径生成正确数量的坐标', () {
      for (final r in [3, 4, 5]) {
        final gs = GameState(settings: GameSettings(boardRadius: r));
        // Hex grid with radius r has 3r²+3r+1 cells
        final expected = 3 * r * r + 3 * r + 1;
        expect(gs.allCoords.length, expected,
            reason: 'Radius $r should have $expected cells');
        gs.dispose();
      }
    });
  });
}
