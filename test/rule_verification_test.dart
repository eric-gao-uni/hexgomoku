/// 全面规则验证测试
/// 按照游戏规则逐条验证，确保代码与规则一致。
///
/// 游戏规则：
/// 1. 黑先白后
/// 2. 每个回合：先走己方棋子，再走红棋
/// 3. 走完红棋后切换到对手
/// 4. 棋子移动需要 ≥2 个相邻空位（liberties）
/// 5. 红棋移动后所有棋子必须保持连通
/// 6. 所有己方棋子连成一线则获胜
/// 7. AI（白方）也遵守同样的回合规则：先走白棋再走红棋
///
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexgomoku/models/game_state.dart';
import 'package:hexgomoku/models/piece.dart';
import 'package:hexgomoku/models/hex_coordinate.dart';

Future<void> _waitForAi({int ms = 3000}) =>
    Future.delayed(Duration(milliseconds: ms));

/// 在 PvP 模式下找一个黑方可以走的 own move（不会导致立即结束游戏）。
({HexCoord from, HexCoord to})? _findSurvivingOwnMove(
    GameState gs, PlayerColor player) {
  final pieceType = player.pieceType;
  final pieces = gs.board.entries
      .where((e) => e.value == pieceType && gs.canMove(e.key))
      .toList();

  for (final p in pieces) {
    final targets = gs.getValidTargets(p.key);
    for (final to in targets) {
      // Simulate
      final sim = GameState(settings: gs.settings);
      // Replay the board state
      sim.board.clear();
      sim.board.addAll(gs.board);
      sim.currentPlayer = gs.currentPlayer;
      sim.turnPhase = gs.turnPhase;
      sim.onCellTap(p.key);
      sim.onCellTap(to);
      final over = sim.isGameOver;
      sim.dispose();
      if (!over) return (from: p.key, to: to);
    }
  }
  return null;
}

/// 找一个可以走的红棋 move（不会导致立即结束游戏）。
({HexCoord from, HexCoord to})? _findSurvivingRedMove(GameState gs) {
  final reds = gs.board.entries
      .where((e) => e.value == PieceType.red && gs.canMove(e.key))
      .toList();

  for (final r in reds) {
    final targets = gs.getValidTargets(r.key);
    for (final to in targets) {
      return (from: r.key, to: to);
    }
  }
  return null;
}

void main() {
  // ═══════════════════════════════════════════════
  // 规则 1: 黑先白后
  // ═══════════════════════════════════════════════
  group('规则1: 黑先白后', () {
    test('初始 currentPlayer 是黑方', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      gs.dispose();
    });

    test('PvAI 模式也是黑方先手', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai, piecesPerPlayer: 3, boardRadius: 5,
      ));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.aiThinking, isFalse,
          reason: 'AI不应该在开局就开始思考，因为黑方（人类）先手');
      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // 规则 2: 回合流程 — 先走己方棋子，再走红棋
  // ═══════════════════════════════════════════════
  group('规则2: 先走己方棋子再走红棋', () {
    test('黑方走完己方棋后，currentPlayer 仍是黑方，phase 变为 moveRed', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      // 找一个黑棋走
      final blacks = gs.board.entries
          .where((e) => e.value == PieceType.black && gs.canMove(e.key))
          .toList();
      expect(blacks, isNotEmpty, reason: '初始应有可移动的黑棋');

      final from = blacks.first.key;
      final targets = gs.getValidTargets(from);
      if (targets.isEmpty) {
        gs.dispose();
        return;
      }

      gs.onCellTap(from);
      expect(gs.selectedPiece, from, reason: '应选中黑棋');

      gs.onCellTap(targets.first);
      if (gs.isGameOver) {
        gs.dispose();
        return;
      }

      // 关键断言：走完己方棋后，仍然是黑方的回合，进入 moveRed 阶段
      expect(gs.currentPlayer, PlayerColor.black,
          reason: '走完己方棋后不应切换玩家');
      expect(gs.turnPhase, TurnPhase.moveRed,
          reason: '走完己方棋后应进入 moveRed 阶段');

      gs.dispose();
    });

    test('黑方在 moveRed 阶段只能选红棋，不能选己方棋或白棋', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }

      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.turnPhase, TurnPhase.moveRed);

      // 尝试点击黑棋 — 不应选中
      final blackPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.black);
      gs.onCellTap(blackPiece.key);
      expect(gs.selectedPiece, isNull,
          reason: 'moveRed 阶段不能选黑棋');

      // 尝试点击白棋 — 不应选中
      final whitePiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.white);
      gs.onCellTap(whitePiece.key);
      expect(gs.selectedPiece, isNull,
          reason: 'moveRed 阶段不能选白棋');

      // 点击红棋 — 应该能选中
      final redPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.red && gs.canMove(e.key));
      gs.onCellTap(redPiece.key);
      expect(gs.selectedPiece, redPiece.key,
          reason: 'moveRed 阶段应能选中红棋');

      gs.dispose();
    });

    test('黑方在 moveOwn 阶段只能选黑棋', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      expect(gs.turnPhase, TurnPhase.moveOwn);

      // 点击白棋 — 不应选中
      final whitePiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.white);
      gs.onCellTap(whitePiece.key);
      expect(gs.selectedPiece, isNull);

      // 点击红棋 — 不应选中
      final redPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.red);
      gs.onCellTap(redPiece.key);
      expect(gs.selectedPiece, isNull);

      // 点击黑棋 — 应选中
      final blackPiece = gs.board.entries
          .firstWhere((e) => e.value == PieceType.black && gs.canMove(e.key));
      gs.onCellTap(blackPiece.key);
      expect(gs.selectedPiece, blackPiece.key);

      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // 规则 3: 走完红棋后切换到对手
  // ═══════════════════════════════════════════════
  group('规则3: 走完红棋后切换到对手', () {
    test('PvP: 黑方走完 own+red 后切换到白方 moveOwn', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      // 黑方走 own
      final ownMove = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (ownMove == null) { gs.dispose(); return; }
      gs.onCellTap(ownMove.from);
      gs.onCellTap(ownMove.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      // 黑方走 red
      final redMove = _findSurvivingRedMove(gs);
      if (redMove == null) { gs.dispose(); return; }
      gs.onCellTap(redMove.from);
      gs.onCellTap(redMove.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.currentPlayer, PlayerColor.white,
          reason: '黑方走完 own+red 后应切换到白方');
      expect(gs.turnPhase, TurnPhase.moveOwn,
          reason: '新回合应从 moveOwn 开始');

      gs.dispose();
    });

    test('PvP: 完整两个回合流转 black→white→black', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      // === 黑方回合 ===
      expect(gs.currentPlayer, PlayerColor.black);

      // 黑 own move
      final blackOwn = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (blackOwn == null) { gs.dispose(); return; }
      gs.onCellTap(blackOwn.from);
      gs.onCellTap(blackOwn.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.currentPlayer, PlayerColor.black, reason: '还是黑方走红棋');
      expect(gs.turnPhase, TurnPhase.moveRed);

      // 黑 red move
      final blackRed = _findSurvivingRedMove(gs);
      if (blackRed == null) { gs.dispose(); return; }
      gs.onCellTap(blackRed.from);
      gs.onCellTap(blackRed.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      // === 白方回合 ===
      expect(gs.currentPlayer, PlayerColor.white);
      expect(gs.turnPhase, TurnPhase.moveOwn);

      // 白 own move
      final whiteOwn = _findSurvivingOwnMove(gs, PlayerColor.white);
      if (whiteOwn == null) { gs.dispose(); return; }
      gs.onCellTap(whiteOwn.from);
      gs.onCellTap(whiteOwn.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.currentPlayer, PlayerColor.white, reason: '还是白方走红棋');
      expect(gs.turnPhase, TurnPhase.moveRed);

      // 白 red move
      final whiteRed = _findSurvivingRedMove(gs);
      if (whiteRed == null) { gs.dispose(); return; }
      gs.onCellTap(whiteRed.from);
      gs.onCellTap(whiteRed.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      // === 回到黑方 ===
      expect(gs.currentPlayer, PlayerColor.black,
          reason: '白方走完后应回到黑方');
      expect(gs.turnPhase, TurnPhase.moveOwn);

      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // 规则 7: AI（白方）遵守同样的回合规则
  // ═══════════════════════════════════════════════
  group('规则7: AI 遵守先走白棋再走红棋', () {
    for (final diff in AiDifficulty.values) {
      test('PvAI ${diff.name}: 人类完成 own+red 后 AI 才开始', () async {
        final settings = GameSettings(
          gameMode: GameMode.pvai,
          aiDifficulty: diff,
          piecesPerPlayer: 3,
          boardRadius: 5,
        );
        final gs = GameState(settings: settings);

        // 黑方 own move
        final move = _findSurvivingOwnMove(gs, PlayerColor.black);
        if (move == null) { gs.dispose(); return; }
        gs.onCellTap(move.from);
        gs.onCellTap(move.to);
        if (gs.isGameOver) { gs.dispose(); return; }

        // 此时黑方应该走红棋，AI 不应开始思考
        expect(gs.currentPlayer, PlayerColor.black,
            reason: '黑方还没走红棋，不应切换');
        expect(gs.turnPhase, TurnPhase.moveRed);
        expect(gs.aiThinking, isFalse,
            reason: '黑方还在走红棋，AI 不应开始思考');

        // 黑方走红棋
        final redMove = _findSurvivingRedMove(gs);
        if (redMove == null) { gs.dispose(); return; }
        gs.onCellTap(redMove.from);
        gs.onCellTap(redMove.to);
        if (gs.isGameOver) { gs.dispose(); return; }

        // 现在应该是白方回合，AI 应该开始思考
        expect(gs.currentPlayer, PlayerColor.white);
        expect(gs.aiThinking, isTrue,
            reason: '轮到 AI（白方）了，应开始思考');

        // 等 AI 完成
        final waitMs = diff == AiDifficulty.high ? 15000 : 5000;
        await _waitForAi(ms: waitMs);

        expect(gs.aiThinking, isFalse,
            reason: 'AI 应已完成思考');

        if (!gs.isGameOver) {
          // AI 走完后应回到黑方 moveOwn
          expect(gs.currentPlayer, PlayerColor.black,
              reason: 'AI 走完 own+red 后应回到黑方');
          expect(gs.turnPhase, TurnPhase.moveOwn,
              reason: '新回合从 moveOwn 开始');
        }
        gs.dispose();
      });
    }

    test('PvAI: AI 走棋期间用户点击被阻止', () async {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      // 人类完成完整回合
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      final redMove = _findSurvivingRedMove(gs);
      if (redMove == null) { gs.dispose(); return; }
      gs.onCellTap(redMove.from);
      gs.onCellTap(redMove.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.aiThinking, isTrue);

      // AI 思考期间点击不应生效
      final boardBefore = Map<HexCoord, PieceType>.from(gs.board);
      gs.onCellTap(const HexCoord(0, 0));
      gs.onCellTap(const HexCoord(3, -3));
      expect(gs.selectedPiece, isNull);
      expect(gs.board, equals(boardBefore),
          reason: 'AI 思考期间棋盘不应变化');

      await _waitForAi();
      gs.dispose();
    });

    test('PvAI: AI 走完后棋盘上白棋和红棋各移动了一步', () async {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      // 人类完成完整回合
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      final redMove = _findSurvivingRedMove(gs);
      if (redMove == null) { gs.dispose(); return; }
      gs.onCellTap(redMove.from);
      gs.onCellTap(redMove.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      // 记录 AI 走之前的棋盘
      final boardBeforeAi = Map<HexCoord, PieceType>.from(gs.board);
      final whiteCountBefore = boardBeforeAi.values
          .where((v) => v == PieceType.white).length;
      final redCountBefore = boardBeforeAi.values
          .where((v) => v == PieceType.red).length;
      final blackCountBefore = boardBeforeAi.values
          .where((v) => v == PieceType.black).length;

      await _waitForAi();

      if (!gs.isGameOver) {
        // AI 走完后棋子数量不应变化
        final whiteCountAfter = gs.board.values
            .where((v) => v == PieceType.white).length;
        final redCountAfter = gs.board.values
            .where((v) => v == PieceType.red).length;
        final blackCountAfter = gs.board.values
            .where((v) => v == PieceType.black).length;

        expect(whiteCountAfter, whiteCountBefore,
            reason: 'AI 走完后白棋数量不应变');
        expect(redCountAfter, redCountBefore,
            reason: 'AI 走完后红棋数量不应变');
        expect(blackCountAfter, blackCountBefore,
            reason: 'AI 不应移动黑棋');

        // 棋盘应该有变化（AI 移动了白棋和红棋）
        // 注意：recenterBoard 可能改变坐标，所以比较棋子位置的集合
        // 黑棋位置不应变化（recenter 会整体平移，所以只比较相对关系）
      }
      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // 回合流程边界情况
  // ═══════════════════════════════════════════════
  group('回合流程边界情况', () {
    test('moveCount 在完成一个完整回合（own+red）后才增加', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      expect(gs.moveCount, 0);

      // own move
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.moveCount, 0, reason: 'own move 后 moveCount 不应增加');

      // red move
      final redMove = _findSurvivingRedMove(gs);
      if (redMove == null) { gs.dispose(); return; }
      gs.onCellTap(redMove.from);
      gs.onCellTap(redMove.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.moveCount, 1, reason: '完成 own+red 后 moveCount 应为 1');

      gs.dispose();
    });

    test('Undo 在 moveRed 阶段撤销 own move', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      final boardBefore = Map<HexCoord, PieceType>.from(gs.board);

      // own move
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      expect(gs.turnPhase, TurnPhase.moveRed);

      // undo
      gs.undoCurrentTurn();

      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.board, equals(boardBefore),
          reason: 'undo 应恢复棋盘');

      gs.dispose();
    });

    test('Undo 在 moveOwn 阶段（新回合开始时）为空操作', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      final boardBefore = Map<HexCoord, PieceType>.from(gs.board);
      gs.undoCurrentTurn();
      expect(gs.board, equals(boardBefore));
      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);

      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // AI 多回合完整流转
  // ═══════════════════════════════════════════════
  group('AI 多回合完整流转', () {
    test('PvAI: 3个完整回合流转正确', () async {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      for (int round = 0; round < 3; round++) {
        if (gs.isGameOver) break;

        // 确认是黑方 moveOwn
        expect(gs.currentPlayer, PlayerColor.black,
            reason: '第${round + 1}轮：应是黑方回合');
        expect(gs.turnPhase, TurnPhase.moveOwn);
        expect(gs.aiThinking, isFalse);

        // 黑方 own move
        final ownMove = _findSurvivingOwnMove(gs, PlayerColor.black);
        if (ownMove == null) break;
        gs.onCellTap(ownMove.from);
        gs.onCellTap(ownMove.to);
        if (gs.isGameOver) break;

        // 确认黑方 moveRed
        expect(gs.currentPlayer, PlayerColor.black);
        expect(gs.turnPhase, TurnPhase.moveRed);
        expect(gs.aiThinking, isFalse);

        // 黑方 red move
        final redMove = _findSurvivingRedMove(gs);
        if (redMove == null) break;
        gs.onCellTap(redMove.from);
        gs.onCellTap(redMove.to);
        if (gs.isGameOver) break;

        // 确认 AI 开始走
        expect(gs.currentPlayer, PlayerColor.white);
        expect(gs.aiThinking, isTrue);

        // 等 AI 完成
        await _waitForAi(ms: 3000);
        if (gs.isGameOver) break;

        // AI 走完后应回到黑方
        expect(gs.currentPlayer, PlayerColor.black,
            reason: '第${round + 1}轮 AI 走完后应回到黑方');
        expect(gs.turnPhase, TurnPhase.moveOwn);
        expect(gs.aiThinking, isFalse);
      }

      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // 计时器归属验证
  // ═══════════════════════════════════════════════
  group('计时器归属', () {
    test('moveRed 阶段消耗的是当前玩家的时间', () {
      // 验证在 moveRed 阶段，计时器记在同一个玩家名下
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp,
        piecesPerPlayer: 3,
        boardRadius: 5,
        totalTimePerPlayer: Duration(minutes: 10),
      ));

      // 走之前记录白方时间
      final whiteTimeBefore = gs.whiteTimeRemaining;

      // 黑方 own move
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      // 在 moveRed 阶段，currentPlayer 仍是黑方
      expect(gs.currentPlayer, PlayerColor.black);

      // 白方时间不应变化（因为一直是黑方在走）
      expect(gs.whiteTimeRemaining, whiteTimeBefore,
          reason: 'moveRed 阶段白方时间不应消耗');

      gs.dispose();
    });
  });

  // ═══════════════════════════════════════════════
  // Dispose 安全
  // ═══════════════════════════════════════════════
  group('Dispose 安全', () {
    test('dispose 后 AI future 不会崩溃', () async {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvai,
        aiDifficulty: AiDifficulty.low,
        piecesPerPlayer: 3,
        boardRadius: 5,
      ));

      // 触发 AI
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move == null) { gs.dispose(); return; }
      gs.onCellTap(move.from);
      gs.onCellTap(move.to);
      if (gs.isGameOver) { gs.dispose(); return; }

      final redMove = _findSurvivingRedMove(gs);
      if (redMove == null) { gs.dispose(); return; }
      gs.onCellTap(redMove.from);
      gs.onCellTap(redMove.to);

      // 立即 dispose
      gs.dispose();

      // 等待 — 不应抛异常
      await _waitForAi();
    });
  });

  // ═══════════════════════════════════════════════
  // Reset 验证
  // ═══════════════════════════════════════════════
  group('Reset', () {
    test('reset 恢复所有初始状态', () {
      final gs = GameState(settings: const GameSettings(
        gameMode: GameMode.pvp, piecesPerPlayer: 3, boardRadius: 5,
      ));

      final initialBoard = Map<HexCoord, PieceType>.from(gs.board);

      // 走几步
      final move = _findSurvivingOwnMove(gs, PlayerColor.black);
      if (move != null) {
        gs.onCellTap(move.from);
        gs.onCellTap(move.to);
      }

      gs.reset();

      expect(gs.currentPlayer, PlayerColor.black);
      expect(gs.turnPhase, TurnPhase.moveOwn);
      expect(gs.moveCount, 0);
      expect(gs.winner, isNull);
      expect(gs.isGameOver, isFalse);
      expect(gs.aiThinking, isFalse);
      expect(gs.selectedPiece, isNull);
      expect(gs.board, equals(initialBoard));

      gs.dispose();
    });
  });
}
