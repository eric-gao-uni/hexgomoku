import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'piece.dart';

enum AiDifficulty { low, medium, high }

/// Game settings.
class GameSettings {
  final int piecesPerPlayer;
  final Duration totalTimePerPlayer;
  final int boardRadius;
  final GameMode gameMode;
  final AiDifficulty aiDifficulty;

  const GameSettings({
    this.piecesPerPlayer = 3,
    this.totalTimePerPlayer = const Duration(minutes: 10),
    this.boardRadius = 5,
    this.gameMode = GameMode.pvp,
    this.aiDifficulty = AiDifficulty.medium,
  });

  GameSettings copyWith({
    int? piecesPerPlayer,
    Duration? totalTimePerPlayer,
    int? boardRadius,
    GameMode? gameMode,
    AiDifficulty? aiDifficulty,
  }) {
    return GameSettings(
      piecesPerPlayer: piecesPerPlayer ?? this.piecesPerPlayer,
      totalTimePerPlayer: totalTimePerPlayer ?? this.totalTimePerPlayer,
      boardRadius: boardRadius ?? this.boardRadius,
      gameMode: gameMode ?? this.gameMode,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    );
  }
}

/// Core game state for HexGomoku.
class GameState extends ChangeNotifier {
  /// All valid coordinates on the hex-shaped board.
  List<HexCoord> allCoords = [];

  /// Game settings.
  GameSettings settings;

  /// Board: coord → piece type.
  Map<HexCoord, PieceType> board = {};

  /// Current player.
  PlayerColor currentPlayer = PlayerColor.black;

  /// Turn phase.
  TurnPhase turnPhase = TurnPhase.moveOwn;

  /// Selected piece source coord.
  HexCoord? selectedPiece;

  /// Moves in current turn (for undo within turn).
  final List<_MoveRecord> _currentTurnMoves = [];

  /// Completed turn count.
  int moveCount = 0;

  /// Timers.
  Duration blackTimeRemaining;
  Duration whiteTimeRemaining;
  DateTime? _turnStartTime;
  Timer? _timer;

  /// Win/lose state.
  PlayerColor? winner;
  List<HexCoord> winningCells = [];
  String? loseReason;

  bool get isGameOver => winner != null;

  /// Whether AI is currently "thinking".
  bool aiThinking = false;

  /// Callback when the board is logic-recentered. UI can use this to adjust pan smoothly.
  void Function(Offset)? onBoardRecentered;

  GameState({this.settings = const GameSettings()})
      : blackTimeRemaining = Duration.zero,
        whiteTimeRemaining = Duration.zero {
    blackTimeRemaining = settings.totalTimePerPlayer;
    whiteTimeRemaining = settings.totalTimePerPlayer;
    allCoords = _generateHexCoords(settings.boardRadius);
    _initBoard();
    _startTimer();
  }

  // ── Board generation ──

  static List<HexCoord> _generateHexCoords(int radius) {
    final coords = <HexCoord>[];
    for (int q = -radius; q <= radius; q++) {
      for (int r = -radius; r <= radius; r++) {
        if ((q + r).abs() <= radius) {
          coords.add(HexCoord(q, r));
        }
      }
    }
    return coords;
  }

  bool isValidCoord(HexCoord coord) {
    return coord.q.abs() <= settings.boardRadius &&
        coord.r.abs() <= settings.boardRadius &&
        (coord.q + coord.r).abs() <= settings.boardRadius;
  }

  // ── Initial layout ──

  void _initBoard() {
    board.clear();
    final n = settings.piecesPerPlayer;

    if (n == 3) {
      // Original layout: left col W/B/W, center R/R, right col B/W/B
      board[const HexCoord(-1, 0)] = PieceType.white;
      board[const HexCoord(-1, 1)] = PieceType.black;
      board[const HexCoord(-1, 2)] = PieceType.white;
      board[const HexCoord(0, 0)] = PieceType.red;
      board[const HexCoord(0, 1)] = PieceType.red;
      board[const HexCoord(1, -1)] = PieceType.black;
      board[const HexCoord(1, 0)] = PieceType.white;
      board[const HexCoord(1, 1)] = PieceType.black;
    } else {
      _generateLayout(n);
    }
  }

  void _generateLayout(int n) {
    int redCount = n - 1;

    // Center column (q=0): red pieces.
    // We want to center them around r=0.
    int startR = -(redCount - 1) ~/ 2;
    if (n == 5) {
      startR -= 1; // Shift red pieces up by one cell to align smoothly
    }
    for (int i = 0; i < redCount; i++) {
        board[HexCoord(0, startR + i)] = PieceType.red;
    }

    // Left column (q=-1): alternate W and B.
    // We want to align its center with the red pieces.
    int leftStartR = -(n - 1) ~/ 2;
    // Base color for left depends on whether we want W or B first. Let's use W first.
    for (int i = 0; i < n; i++) {
        board[HexCoord(-1, leftStartR + i)] = (i % 2 == 0) ? PieceType.white : PieceType.black;
    }

    // Right column (q=1): alternate B and W.
    // For flat-top hexes, if q is +1, the y coordinate shifts down by 0.5 relative to q=0.
    // To vertically align with q=0, starting r for q=1 should be slightly lower.
    // We'll use startR - 1 as a base, or just match leftStartR - 1.
    int rightStartR = leftStartR - 1;
    for (int i = 0; i < n; i++) {
        board[HexCoord(1, rightStartR + i)] = (i % 2 == 0) ? PieceType.black : PieceType.white;
    }
  }

  // ── Timer ──

  void _startTimer() {
    _turnStartTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (isGameOver) {
        _timer?.cancel();
        return;
      }
      _updateTime();
      notifyListeners();
    });
  }

  void _updateTime() {
    if (_turnStartTime == null) return;
    final elapsed = DateTime.now().difference(_turnStartTime!);
    if (currentPlayer == PlayerColor.black) {
      final remaining = blackTimeRemaining - elapsed;
      if (remaining.isNegative) {
        _timer?.cancel();
        winner = PlayerColor.white;
        loseReason = 'Time out';
      }
    } else {
      final remaining = whiteTimeRemaining - elapsed;
      if (remaining.isNegative) {
        _timer?.cancel();
        winner = PlayerColor.black;
        loseReason = 'Time out';
      }
    }
  }

  Duration get currentPlayerTimeRemaining {
    if (_turnStartTime == null) {
      return currentPlayer == PlayerColor.black
          ? blackTimeRemaining
          : whiteTimeRemaining;
    }
    final elapsed = DateTime.now().difference(_turnStartTime!);
    final base = currentPlayer == PlayerColor.black
        ? blackTimeRemaining
        : whiteTimeRemaining;
    final remaining = base - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get otherPlayerTimeRemaining {
    return currentPlayer == PlayerColor.black
        ? whiteTimeRemaining
        : blackTimeRemaining;
  }

  void _commitTimeForCurrentPlayer() {
    if (_turnStartTime == null) return;
    final elapsed = DateTime.now().difference(_turnStartTime!);
    if (currentPlayer == PlayerColor.black) {
      blackTimeRemaining -= elapsed;
    } else {
      whiteTimeRemaining -= elapsed;
    }
    _turnStartTime = DateTime.now();
  }

  // ── "Qi" (liberties) rule ──

  bool canMove(HexCoord coord) {
    if (board[coord] == null) return false;

    final neighbors = coord.neighbors();
    final emptyNeighbors = <HexCoord>[];
    for (final nb in neighbors) {
      if (isValidCoord(nb) && board[nb] == null) {
        emptyNeighbors.add(nb);
      }
    }

    if (emptyNeighbors.length < 2) return false;

    for (int i = 0; i < emptyNeighbors.length; i++) {
      for (int j = i + 1; j < emptyNeighbors.length; j++) {
        if (emptyNeighbors[i].neighbors().contains(emptyNeighbors[j])) {
          return true;
        }
      }
    }
    return false;
  }

  // ── Connectivity ──

  bool _isConnected(Map<HexCoord, PieceType> testBoard) {
    if (testBoard.isEmpty) return true;

    final all = testBoard.keys.toSet();
    final visited = <HexCoord>{};
    final queue = <HexCoord>[all.first];
    visited.add(all.first);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final nb in current.neighbors()) {
        if (all.contains(nb) && !visited.contains(nb)) {
          visited.add(nb);
          queue.add(nb);
        }
      }
    }

    return visited.length == all.length;
  }

  // ── Win check ──

  void _checkWin(PlayerColor player) {
    final pieceType = player.pieceType;
    final positions = board.entries
        .where((e) => e.value == pieceType)
        .map((e) => e.key)
        .toList();

    if (positions.length < settings.piecesPerPlayer) return;

    for (final dir in HexCoord.lineDirections) {
      final line = _findLine(positions, dir);
      if (line != null && line.length >= settings.piecesPerPlayer) {
        winner = player;
        winningCells = line;
        _timer?.cancel();
        return;
      }
    }
  }

  List<HexCoord>? _findLine(List<HexCoord> positions, (int, int) dir) {
    final posSet = positions.toSet();
    final (dq, dr) = dir;

    for (final start in positions) {
      final line = <HexCoord>[start];
      for (int i = 1; i < settings.piecesPerPlayer; i++) {
        final next = HexCoord(start.q + dq * i, start.r + dr * i);
        if (posSet.contains(next)) {
          line.add(next);
        } else {
          break;
        }
      }
      if (line.length >= settings.piecesPerPlayer) return line;
    }
    return null;
  }

  // ── Lose checks ──

  bool _hasMovablePiece(PlayerColor player) {
    final pieceType = player.pieceType;
    for (final entry in board.entries) {
      if (entry.value == pieceType && canMove(entry.key)) {
        return true;
      }
    }
    return false;
  }

  bool _hasValidRedMove() {
    for (final entry in board.entries) {
      if (entry.value != PieceType.red) continue;
      if (!canMove(entry.key)) continue;

      for (final target in allCoords) {
        if (board[target] != null) continue;
        final testBoard = Map<HexCoord, PieceType>.from(board);
        testBoard.remove(entry.key);
        testBoard[target] = PieceType.red;
        if (_isConnected(testBoard) && _canExistAt(target, testBoard)) {
          return true;
        }
      }
    }
    return false;
  }

  // ── Tap handling ──

  void onCellTap(HexCoord coord) {
    if (isGameOver || aiThinking) return;

    if (selectedPiece == null) {
      _trySelect(coord);
    } else if (selectedPiece == coord) {
      selectedPiece = null;
      notifyListeners();
    } else {
      _tryMove(selectedPiece!, coord);
    }
  }

  void _trySelect(HexCoord coord) {
    final piece = board[coord];
    if (piece == null) return;

    if (turnPhase == TurnPhase.moveOwn) {
      if (piece == currentPlayer.pieceType && canMove(coord)) {
        selectedPiece = coord;
        notifyListeners();
      }
    } else {
      if (piece == PieceType.red && canMove(coord)) {
        selectedPiece = coord;
        notifyListeners();
      }
    }
  }

  void _tryMove(HexCoord from, HexCoord to) {
    if (!isValidCoord(to) || board[to] != null) {
      selectedPiece = null;
      notifyListeners();
      return;
    }

    final pieceType = board[from]!;

    if (turnPhase == TurnPhase.moveOwn) {
      // Check qi at destination first
      final testBoard = Map<HexCoord, PieceType>.from(board);
      testBoard.remove(from);
      testBoard[to] = pieceType;
      if (!_canExistAt(to, testBoard)) {
        selectedPiece = null;
        notifyListeners();
        return;
      }

      board.remove(from);
      board[to] = pieceType;
      _currentTurnMoves.add(_MoveRecord(from, to, pieceType));
      selectedPiece = null;
      turnPhase = TurnPhase.moveRed;

      _checkWin(currentPlayer);
      if (isGameOver) {
        notifyListeners();
        return;
      }

      if (!_hasValidRedMove()) {
        winner = currentPlayer.opponent;
        loseReason = 'No valid red move';
        _timer?.cancel();
      }

      notifyListeners();
    } else {
      // Red move - must not create islands
      final testBoard = Map<HexCoord, PieceType>.from(board);
      testBoard.remove(from);
      testBoard[to] = PieceType.red;

      if (!_isConnected(testBoard) || !_canExistAt(to, testBoard)) {
        selectedPiece = null;
        notifyListeners();
        return;
      }

      board.remove(from);
      board[to] = PieceType.red;
      _currentTurnMoves.add(_MoveRecord(from, to, PieceType.red));
      selectedPiece = null;

      _commitTimeForCurrentPlayer();
      moveCount++;
      currentPlayer = currentPlayer.opponent;
      turnPhase = TurnPhase.moveOwn;
      _currentTurnMoves.clear();

      if (!_hasMovablePiece(currentPlayer)) {
        winner = currentPlayer.opponent;
        loseReason = 'All pieces blocked';
        _timer?.cancel();
      }

      _recenterBoard();

      notifyListeners();

      // Trigger AI if it's AI's turn
      _maybeDoAiMove();
    }
  }

  void _recenterBoard() {
    if (board.isEmpty) return;

    int sumQ = 0;
    int sumR = 0;
    for (final coord in board.keys) {
      sumQ += coord.q;
      sumR += coord.r;
    }

    final cq = (sumQ / board.length).round();
    final cr = (sumR / board.length).round();

    if (cq == 0 && cr == 0) return;

    final newBoard = <HexCoord, PieceType>{};
    for (final entry in board.entries) {
      newBoard[HexCoord(entry.key.q - cq, entry.key.r - cr)] = entry.value;
    }
    board = newBoard;

    // Shift winning cells if any
    winningCells = winningCells.map((c) => HexCoord(c.q - cq, c.r - cr)).toList();
    if (selectedPiece != null) {
      selectedPiece = HexCoord(selectedPiece!.q - cq, selectedPiece!.r - cr);
    }

    if (onBoardRecentered != null) {
      // Calculate pixel delta that this logical shift represents.
      // We are moving pieces logically by (-cq, -cr). Visually, this is moving them
      // by the pixel equivalent of (-cq, -cr) from origin.
      // So the camera needs to instantly pan by this pixel delta to keep them in place.
      double hexSize = 1.0; // Assume unit size, HexBoard will scale it.
      final dx = hexSize * (3.0 / 2 * cq);
      final dy = hexSize * (math.sqrt(3) / 2 * cq + math.sqrt(3) * cr);
      onBoardRecentered!(Offset(dx, dy));
    }
  }

  // ── AI ──

  void _maybeDoAiMove() {
    if (settings.gameMode != GameMode.pvai) return;
    if (currentPlayer != PlayerColor.white) return;
    if (isGameOver) return;

    aiThinking = true;
    notifyListeners();

    // Simulate thinking delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (isGameOver) return;
      _performAiTurn();
      aiThinking = false;
      notifyListeners();
    });
  }

  void _performAiTurn() {
    if (settings.aiDifficulty == AiDifficulty.low) {
      _performGreedyAiTurn();
    } else {
      _performAdvancedAiTurn(depth: settings.aiDifficulty == AiDifficulty.high ? 2 : 1);
    }
  }

  void _performGreedyAiTurn() {
    final rng = math.Random();

    // Step 1: Move own piece
    final ownPieces = board.entries
        .where((e) => e.value == currentPlayer.pieceType && canMove(e.key))
        .map((e) => e.key)
        .toList();

    if (ownPieces.isEmpty) return;

    HexCoord? bestFrom;
    HexCoord? bestTo;
    int bestScore = -10000;

    for (final from in ownPieces) {
      final targets = _getValidTargetsForBoard(from, board, currentPlayer.pieceType);
      for (final to in targets) {
        final score = _evaluateGreedyOwnMove(from, to);
        if (score > bestScore) {
          bestScore = score;
          bestFrom = from;
          bestTo = to;
        }
      }
    }

    if (bestFrom == null || bestTo == null) {
      bestFrom = ownPieces[rng.nextInt(ownPieces.length)];
      final targets = _getValidTargetsForBoard(bestFrom, board, currentPlayer.pieceType);
      if (targets.isEmpty) return; // Should not happen if canMove is true
      bestTo = targets[rng.nextInt(targets.length)];
    }

    // Execute own move
    final pieceType = board[bestFrom]!;
    board.remove(bestFrom);
    board[bestTo] = pieceType;
    _currentTurnMoves.add(_MoveRecord(bestFrom, bestTo, pieceType));
    turnPhase = TurnPhase.moveRed;

    _checkWin(currentPlayer);
    if (isGameOver) return;

    // Step 2: Move red piece
    final redPieces = board.entries
        .where((e) => e.value == PieceType.red && canMove(e.key))
        .map((e) => e.key)
        .toList();

    HexCoord? bestRedFrom;
    HexCoord? bestRedTo;
    int bestRedScore = -10000;

    for (final from in redPieces) {
      final targets = _getValidTargetsForBoard(from, board, PieceType.red);
      for (final to in targets) {
        final score = _evaluateGreedyRedMove(from, to);
        if (score > bestRedScore) {
          bestRedScore = score;
          bestRedFrom = from;
          bestRedTo = to;
        }
      }
    }

    if (bestRedFrom == null || bestRedTo == null) return;

    board.remove(bestRedFrom);
    board[bestRedTo] = PieceType.red;
    _currentTurnMoves.add(_MoveRecord(bestRedFrom, bestRedTo, PieceType.red));

    _commitTimeForCurrentPlayer();
    moveCount++;
    currentPlayer = currentPlayer.opponent;
    turnPhase = TurnPhase.moveOwn;
    _currentTurnMoves.clear();

    if (!_hasMovablePiece(currentPlayer)) {
      winner = currentPlayer.opponent;
      loseReason = 'All pieces blocked';
      _timer?.cancel();
    }

    _recenterBoard();
  }

  void _performAdvancedAiTurn({required int depth}) {
    // Advanced AI evaluates the combination of (OwnMove, RedMove).
    // If depth is 2, it assumes the opponent will make their best combination next turn.
    final myType = currentPlayer.pieceType;
    
    int bestScore = -999999;
    HexCoord? bestOwnFrom;
    HexCoord? bestOwnTo;
    HexCoord? bestRedFrom;
    HexCoord? bestRedTo;

    final ownPieces = board.entries.where((e) => e.value == myType && canMove(e.key)).map((e) => e.key).toList();
    if (ownPieces.isEmpty) return;

    // To prevent timeout, we use aggressive pruning and a fast heuristic.
    // We collect all valid pairs of (OwnMove) resulting boards, 
    // pick top 10 own moves, then find top red moves.
    
    // 1. Generate all OwnMoves
    final ownMoves = <_ScoredAction>[];
    for (final from in ownPieces) {
      for (final to in _getValidTargetsForBoard(from, board, myType)) {
        final simBoard = Map<HexCoord, PieceType>.from(board);
        simBoard.remove(from);
        simBoard[to] = myType;
        
        // Fast static evaluation of just this own move
        final tempScore = _evaluateBoardState(simBoard, myType);
        ownMoves.add(_ScoredAction(from, to, tempScore));
      }
    }
    
    // Sort and keep top N to reduce branching
    ownMoves.sort((a, b) => b.score.compareTo(a.score));
    final topOwnMoves = ownMoves.take(15).toList();

    for (final ownMove in topOwnMoves) {
      final simBoardAfterOwn = Map<HexCoord, PieceType>.from(board);
      simBoardAfterOwn.remove(ownMove.from);
      simBoardAfterOwn[ownMove.to] = myType;

      // Check win for own
      if (_hasWinner(simBoardAfterOwn, myType)) {
         // Immediate win, take it
         bestOwnFrom = ownMove.from; bestOwnTo = ownMove.to;
         bestScore = 999999;
         // Just find any valid red move
         final redPieces = simBoardAfterOwn.entries.where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, simBoardAfterOwn)).map((e) => e.key).toList();
         if (redPieces.isNotEmpty) {
           final rFrom = redPieces.first;
           final rTo = _getValidTargetsForBoard(rFrom, simBoardAfterOwn, PieceType.red).firstOrNull;
           if (rTo != null) {
             bestRedFrom = rFrom; bestRedTo = rTo;
           }
         }
         break;
      }

      final redPieces = simBoardAfterOwn.entries.where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, simBoardAfterOwn)).map((e) => e.key).toList();
      
      final redMoves = <_ScoredAction>[];
      for (final rFrom in redPieces) {
        for (final rTo in _getValidTargetsForBoard(rFrom, simBoardAfterOwn, PieceType.red)) {
          final simBoardAfterRed = Map<HexCoord, PieceType>.from(simBoardAfterOwn);
          simBoardAfterRed.remove(rFrom);
          simBoardAfterRed[rTo] = PieceType.red;
          
          int finalScore = _evaluateBoardState(simBoardAfterRed, myType);

          if (depth > 1) {
            // Opponent's turn simulation (very shallow to save time)
            finalScore = _simulateOpponentTurn(simBoardAfterRed, myType, finalScore);
          }

          redMoves.add(_ScoredAction(rFrom, rTo, finalScore));
        }
      }

      if (redMoves.isNotEmpty) {
        // Sort to find best red move for this own move
        redMoves.sort((a, b) => b.score.compareTo(a.score));
        final bestRedMove = redMoves.first;
        
        if (bestRedMove.score > bestScore) {
          bestScore = bestRedMove.score;
          bestOwnFrom = ownMove.from;
          bestOwnTo = ownMove.to;
          bestRedFrom = bestRedMove.from;
          bestRedTo = bestRedMove.to;
        }
      }
    }

    // Fallback if no moves evaluated properly
    if (bestOwnFrom == null || bestRedFrom == null) {
      _performGreedyAiTurn();
      return;
    }

    // Execute the best combination
    board.remove(bestOwnFrom!);
    board[bestOwnTo!] = myType;
    _currentTurnMoves.add(_MoveRecord(bestOwnFrom, bestOwnTo, myType));
    turnPhase = TurnPhase.moveRed;
    _checkWin(currentPlayer);
    if (!isGameOver) {
      board.remove(bestRedFrom!);
      board[bestRedTo!] = PieceType.red;
      _currentTurnMoves.add(_MoveRecord(bestRedFrom, bestRedTo, PieceType.red));
    }

    _commitTimeForCurrentPlayer();
    moveCount++;
    currentPlayer = currentPlayer.opponent;
    turnPhase = TurnPhase.moveOwn;
    _currentTurnMoves.clear();

    if (!_hasMovablePiece(currentPlayer) && !isGameOver) {
      winner = currentPlayer.opponent;
      loseReason = 'All pieces blocked';
      _timer?.cancel();
    }

    _recenterBoard();
  }

  int _simulateOpponentTurn(Map<HexCoord, PieceType> simBoard, PieceType myType, int baseScore) {
    // Find the opponent's best response and subtract it from our score.
    final opType = myType == PieceType.black ? PieceType.white : PieceType.black;
    final opPieces = simBoard.entries.where((e) => e.value == opType && _canMoveOnBoard(e.key, simBoard)).map((e) => e.key).toList();
    
    int worstScoreForMe = baseScore; // Minimax: opponent minimizes my score
    
    for (final from in opPieces) {
      for (final to in _getValidTargetsForBoard(from, simBoard, opType)) {
        final b2 = Map<HexCoord, PieceType>.from(simBoard);
        b2.remove(from);
        b2[to] = opType;

        if (_hasWinner(b2, opType)) {
          return -999999; // Opponent can win immediately!
        }

        final scoreAfterOpOwn = _evaluateBoardState(b2, myType);
        if (scoreAfterOpOwn < worstScoreForMe) {
          worstScoreForMe = scoreAfterOpOwn;
        }
      }
    }
    return worstScoreForMe;
  }

  int _evaluateBoardState(Map<HexCoord, PieceType> testBoard, PieceType myType) {
    int score = 0;
    final opType = myType == PieceType.black ? PieceType.white : PieceType.black;

    final myPositions = testBoard.entries.where((e) => e.value == myType).map((e) => e.key).toList();
    final opPositions = testBoard.entries.where((e) => e.value == opType).map((e) => e.key).toList();

    score += _evaluateLines(myPositions, testBoard, isMaximizing: true);
    score -= _evaluateLines(opPositions, testBoard, isMaximizing: false);

    // Bonus for red pieces blocking opponent lines
    final redPositions = testBoard.entries.where((e) => e.value == PieceType.red).map((e) => e.key).toList();
    for (final rPos in redPositions) {
      for (final dir in HexCoord.lineDirections) {
        final (dq, dr) = dir;
        final p1 = HexCoord(rPos.q - dq, rPos.r - dr);
        final p2 = HexCoord(rPos.q + dq, rPos.r + dr);
        if (testBoard[p1] == opType && testBoard[p2] == opType) {
          score += 500; // Blocked a line!
        }
      }
    }

    return score;
  }

  int _evaluateLines(List<HexCoord> positions, Map<HexCoord, PieceType> testBoard, {required bool isMaximizing}) {
    int score = 0;
    final posSet = positions.toSet();
    final targetLen = settings.piecesPerPlayer;

    for (final start in positions) {
      for (final dir in HexCoord.lineDirections) {
        final (dq, dr) = dir;
        int lineLen = 1;
        bool openStart = testBoard[HexCoord(start.q - dq, start.r - dr)] == null;

        for (int i = 1; i < targetLen; i++) {
          final next = HexCoord(start.q + dq * i, start.r + dr * i);
          if (posSet.contains(next)) {
            lineLen++;
          } else {
            break;
          }
        }

        bool openEnd = testBoard[HexCoord(start.q + dq * lineLen, start.r + dr * lineLen)] == null;
        
        if (lineLen >= targetLen) return 90000;
        
        if (lineLen == targetLen - 1) {
          if (openStart && openEnd) score += 2000;
          else if (openStart || openEnd) score += 500;
        } else if (lineLen == targetLen - 2 && lineLen > 0) {
          if (openStart && openEnd) score += 200;
          else if (openStart || openEnd) score += 50;
        }
      }
    }
    return score;
  }

  bool _hasWinner(Map<HexCoord, PieceType> testBoard, PieceType type) {
    final positions = testBoard.entries.where((e) => e.value == type).map((e) => e.key).toList();
    if (positions.length < settings.piecesPerPlayer) return false;

    for (final dir in HexCoord.lineDirections) {
      final line = _findLineInPositions(positions, dir);
      if (line != null && line.length >= settings.piecesPerPlayer) return true;
    }
    return false;
  }

  List<HexCoord>? _findLineInPositions(List<HexCoord> positions, (int, int) dir) {
    final posSet = positions.toSet();
    final (dq, dr) = dir;

    for (final start in positions) {
      final line = <HexCoord>[start];
      for (int i = 1; i < settings.piecesPerPlayer; i++) {
        final next = HexCoord(start.q + dq * i, start.r + dr * i);
        if (posSet.contains(next)) {
          line.add(next);
        } else {
          break;
        }
      }
      if (line.length >= settings.piecesPerPlayer) {
        return line;
      }
    }
    return null;
  }

  // AI helper: get valid targets on a simulated board
  List<HexCoord> _getValidTargetsForBoard(HexCoord from, Map<HexCoord, PieceType> testBoard, PieceType pType) {
    final targets = <HexCoord>[];
    for (final t in allCoords) {
      if (testBoard[t] != null) continue;
      final sim = Map<HexCoord, PieceType>.from(testBoard);
      sim.remove(from);
      sim[t] = pType;
      
      if (pType == PieceType.red && !_isConnected(sim)) continue;
      if (!_canExistAt(t, sim)) continue;
      
      targets.add(t);
    }
    return targets;
  }

  bool _canMoveOnBoard(HexCoord coord, Map<HexCoord, PieceType> testBoard) {
    final emptyNeighbors = coord.neighbors().where((nb) => isValidCoord(nb) && testBoard[nb] == null).toList();
    if (emptyNeighbors.length < 2) return false;
    for (int i = 0; i < emptyNeighbors.length; i++) {
      for (int j = i + 1; j < emptyNeighbors.length; j++) {
        if (emptyNeighbors[i].neighbors().contains(emptyNeighbors[j])) {
          return true;
        }
      }
    }
    return false;
  }

  // Legacy greedy evaluators for 'low' difficulty
  int _evaluateGreedyOwnMove(HexCoord from, HexCoord to) {
    final simBoard = Map<HexCoord, PieceType>.from(board);
    simBoard.remove(from);
    simBoard[to] = currentPlayer.pieceType;
    return _evaluateBoardState(simBoard, currentPlayer.pieceType);
  }

  int _evaluateGreedyRedMove(HexCoord from, HexCoord to) {
    final simBoard = Map<HexCoord, PieceType>.from(board);
    simBoard.remove(from);
    simBoard[to] = PieceType.red;
    return _evaluateBoardState(simBoard, currentPlayer.pieceType);
  }

  /// Check if a piece could exist at [coord] with sufficient liberties
  /// using the given board state.
  bool _canExistAt(HexCoord coord, Map<HexCoord, PieceType> testBoard) {
    final neighbors = coord.neighbors();
    final emptyNeighbors = <HexCoord>[];
    for (final nb in neighbors) {
      if (isValidCoord(nb) && testBoard[nb] == null) {
        emptyNeighbors.add(nb);
      }
    }
    if (emptyNeighbors.length < 2) return false;
    for (int i = 0; i < emptyNeighbors.length; i++) {
      for (int j = i + 1; j < emptyNeighbors.length; j++) {
        if (emptyNeighbors[i].neighbors().contains(emptyNeighbors[j])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get valid targets for selected piece.
  List<HexCoord> getValidTargets(HexCoord from) {
    if (turnPhase == TurnPhase.moveOwn) {
      final targets = <HexCoord>[];
      for (final c in allCoords) {
        if (board[c] != null) continue;
        // Simulate: remove from source, place at target
        final testBoard = Map<HexCoord, PieceType>.from(board);
        final pieceType = testBoard.remove(from);
        testBoard[c] = pieceType!;
        if (_canExistAt(c, testBoard)) {
          targets.add(c);
        }
      }
      return targets;
    } else {
      final targets = <HexCoord>[];
      for (final target in allCoords) {
        if (board[target] != null) continue;
        final testBoard = Map<HexCoord, PieceType>.from(board);
        testBoard.remove(from);
        testBoard[target] = PieceType.red;
        if (!_isConnected(testBoard)) continue;
        if (!_canExistAt(target, testBoard)) continue;
        targets.add(target);
      }
      return targets;
    }
  }

  // ── Undo ──

  void undoCurrentTurn() {
    if (_currentTurnMoves.isEmpty) return;

    for (final move in _currentTurnMoves.reversed) {
      board.remove(move.to);
      board[move.from] = move.pieceType;
    }
    _currentTurnMoves.clear();
    turnPhase = TurnPhase.moveOwn;
    selectedPiece = null;
    winner = null;
    loseReason = null;
    winningCells = [];
    notifyListeners();
  }

  // ── Reset ──

  void reset() {
    _timer?.cancel();
    allCoords = _generateHexCoords(settings.boardRadius);
    _initBoard();
    currentPlayer = PlayerColor.black;
    turnPhase = TurnPhase.moveOwn;
    selectedPiece = null;
    _currentTurnMoves.clear();
    moveCount = 0;
    blackTimeRemaining = settings.totalTimePerPlayer;
    whiteTimeRemaining = settings.totalTimePerPlayer;
    winner = null;
    winningCells = [];
    loseReason = null;
    aiThinking = false;
    _startTimer();
    notifyListeners();
  }

  void updateSettings(GameSettings newSettings) {
    settings = newSettings;
    reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _ScoredAction {
  final HexCoord from;
  final HexCoord to;
  final int score;
  _ScoredAction(this.from, this.to, this.score);
}

class _MoveRecord {
  final HexCoord from;
  final HexCoord to;
  final PieceType pieceType;
  _MoveRecord(this.from, this.to, this.pieceType);
}
