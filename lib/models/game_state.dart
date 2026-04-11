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

  /// Current player (who is acting right now).
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

  /// Whether this GameState has been disposed.
  bool _disposed = false;

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
    int startR = -(redCount - 1) ~/ 2;
    if (n == 5) {
      startR -= 1;
    }
    for (int i = 0; i < redCount; i++) {
        board[HexCoord(0, startR + i)] = PieceType.red;
    }

    // Left column (q=-1): alternate W and B.
    int leftStartR = -(n - 1) ~/ 2;
    for (int i = 0; i < n; i++) {
        board[HexCoord(-1, leftStartR + i)] = (i % 2 == 0) ? PieceType.white : PieceType.black;
    }

    // Right column (q=1): alternate B and W.
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
    return _canMoveOnBoard(coord, board);
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

      _checkWin(currentPlayer);
      if (isGameOver) {
        notifyListeners();
        return;
      }

      if (!_hasValidRedMove()) {
        winner = currentPlayer.opponent;
        loseReason = 'No valid red move';
        _timer?.cancel();
        notifyListeners();
        return;
      }

      turnPhase = TurnPhase.moveRed;

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

      // Trigger AI if it's AI's turn to move own piece
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
      if (_disposed || isGameOver) {
        aiThinking = false;
        if (!_disposed) notifyListeners();
        return;
      }
      _performAiTurn();
      aiThinking = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _performAiTurn() {
    switch (settings.aiDifficulty) {
      case AiDifficulty.low:
        _performRandomAiTurn();
        break;
      case AiDifficulty.medium:
        _performGreedyAiTurn();
        break;
      case AiDifficulty.high:
        _performAdvancedAiTurn();
        break;
    }
  }

  /// Low: pick a random valid own move, then a random valid red move.
  /// Only avoids immediately losing (blocks opponent winning next turn).
  void _performRandomAiTurn() {
    final rng = math.Random();
    final myType = currentPlayer.pieceType;
    final opType = myType == PieceType.black ? PieceType.white : PieceType.black;

    final ownPieces = board.entries
        .where((e) => e.value == myType && canMove(e.key))
        .map((e) => e.key)
        .toList();
    if (ownPieces.isEmpty) {
      winner = currentPlayer.opponent;
      loseReason = 'All pieces blocked';
      _timer?.cancel();
      return;
    }

    // Collect all valid own moves
    final allOwnMoves = <({HexCoord from, HexCoord to})>[];
    for (final from in ownPieces) {
      for (final to in _getValidTargetsForBoard(from, board, myType)) {
        allOwnMoves.add((from: from, to: to));
      }
    }
    if (allOwnMoves.isEmpty) {
      winner = currentPlayer.opponent;
      loseReason = 'All pieces blocked';
      _timer?.cancel();
      return;
    }

    // Separate into "safe" (opponent can't win next) and "unsafe"
    final safeMoves = <({HexCoord from, HexCoord to})>[];
    for (final m in allOwnMoves) {
      final sim = Map<HexCoord, PieceType>.from(board);
      sim.remove(m.from);
      sim[m.to] = myType;
      // Check if opponent would win immediately
      if (!_hasWinner(sim, opType)) {
        safeMoves.add(m);
      }
    }

    // Prefer safe moves; fall back to any move if all are unsafe
    final candidates = safeMoves.isNotEmpty ? safeMoves : allOwnMoves;
    final chosen = candidates[rng.nextInt(candidates.length)];

    // Execute own move
    board.remove(chosen.from);
    board[chosen.to] = myType;
    _currentTurnMoves.add(_MoveRecord(chosen.from, chosen.to, myType));
    turnPhase = TurnPhase.moveRed;

    _checkWin(currentPlayer);
    if (isGameOver) return;

    if (!_hasValidRedMove()) {
      winner = currentPlayer.opponent;
      loseReason = 'No valid red move';
      _timer?.cancel();
      return;
    }

    // Pick a random red move
    final redPieces = board.entries
        .where((e) => e.value == PieceType.red && canMove(e.key))
        .map((e) => e.key)
        .toList();

    final allRedMoves = <({HexCoord from, HexCoord to})>[];
    for (final rFrom in redPieces) {
      for (final rTo in _getValidTargetsForBoard(rFrom, board, PieceType.red)) {
        allRedMoves.add((from: rFrom, to: rTo));
      }
    }
    if (allRedMoves.isEmpty) return;

    final redChosen = allRedMoves[rng.nextInt(allRedMoves.length)];
    board.remove(redChosen.from);
    board[redChosen.to] = PieceType.red;
    _currentTurnMoves.add(_MoveRecord(redChosen.from, redChosen.to, PieceType.red));

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

  /// Medium: evaluate all own+red combos, pick the best, add slight randomness
  /// among top candidates so it doesn't always play the same "opening book".
  void _performGreedyAiTurn() {
    final rng = math.Random();
    final myType = currentPlayer.pieceType;

    final ownPieces = board.entries
        .where((e) => e.value == myType && canMove(e.key))
        .map((e) => e.key)
        .toList();
    if (ownPieces.isEmpty) {
      winner = currentPlayer.opponent;
      loseReason = 'All pieces blocked';
      _timer?.cancel();
      return;
    }

    // Evaluate all own+red combos
    final combos = <({HexCoord ownFrom, HexCoord ownTo,
        HexCoord redFrom, HexCoord redTo, int score})>[];

    for (final from in ownPieces) {
      for (final to in _getValidTargetsForBoard(from, board, myType)) {
        final simOwn = Map<HexCoord, PieceType>.from(board);
        simOwn.remove(from);
        simOwn[to] = myType;

        if (_hasWinner(simOwn, myType)) {
          // Immediate win — find any red move and take it
          final rp = simOwn.entries
              .where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, simOwn))
              .map((e) => e.key).toList();
          if (rp.isNotEmpty) {
            final rTo = _getValidTargetsForBoard(rp.first, simOwn, PieceType.red).firstOrNull;
            if (rTo != null) {
              combos.add((ownFrom: from, ownTo: to,
                  redFrom: rp.first, redTo: rTo, score: 999999));
              break;
            }
          }
          continue;
        }

        final redPieces = simOwn.entries
            .where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, simOwn))
            .map((e) => e.key).toList();

        for (final rFrom in redPieces) {
          for (final rTo in _getValidTargetsForBoard(rFrom, simOwn, PieceType.red)) {
            final simRed = Map<HexCoord, PieceType>.from(simOwn);
            simRed.remove(rFrom);
            simRed[rTo] = PieceType.red;
            final score = _evaluateBoardState(simRed, myType);
            combos.add((ownFrom: from, ownTo: to,
                redFrom: rFrom, redTo: rTo, score: score));
          }
        }
      }
      // Break early if we found an instant win
      if (combos.isNotEmpty && combos.last.score == 999999) break;
    }

    if (combos.isEmpty) {
      // No valid own+red combo — AI loses (no valid red move after any own move)
      // Pick any own move to trigger the loss
      final anyFrom = ownPieces.first;
      final anyTo = _getValidTargetsForBoard(anyFrom, board, myType).firstOrNull;
      if (anyTo != null) {
        board.remove(anyFrom);
        board[anyTo] = myType;
        _currentTurnMoves.add(_MoveRecord(anyFrom, anyTo, myType));
      }
      turnPhase = TurnPhase.moveRed;
      if (!_hasValidRedMove()) {
        winner = currentPlayer.opponent;
        loseReason = 'No valid red move';
        _timer?.cancel();
      }
      return;
    }

    combos.sort((a, b) => b.score.compareTo(a.score));

    // Pick randomly from top 3 to avoid deterministic "opening book"
    final topN = combos.length < 3 ? combos.length : 3;
    final pick = combos[rng.nextInt(topN)];

    // Execute own move
    board.remove(pick.ownFrom);
    board[pick.ownTo] = myType;
    _currentTurnMoves.add(_MoveRecord(pick.ownFrom, pick.ownTo, myType));
    turnPhase = TurnPhase.moveRed;

    _checkWin(currentPlayer);
    if (isGameOver) return;

    // Execute red move
    board.remove(pick.redFrom);
    board[pick.redTo] = PieceType.red;
    _currentTurnMoves.add(_MoveRecord(pick.redFrom, pick.redTo, PieceType.red));

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

  /// High: minimax with opponent simulation. Evaluates all own+red combos,
  /// then for the top candidates simulates the opponent's best response
  /// (own move + red move) to find the most resilient play.
  void _performAdvancedAiTurn() {
    final myType = currentPlayer.pieceType;

    int bestScore = -999999;
    HexCoord? bestOwnFrom;
    HexCoord? bestOwnTo;
    HexCoord? bestRedFrom;
    HexCoord? bestRedTo;

    final ownPieces = board.entries
        .where((e) => e.value == myType && canMove(e.key))
        .map((e) => e.key).toList();
    if (ownPieces.isEmpty) {
      winner = currentPlayer.opponent;
      loseReason = 'All pieces blocked';
      _timer?.cancel();
      return;
    }

    // Step 1: Score all own moves and keep top 15
    final ownMoves = <_ScoredAction>[];
    for (final from in ownPieces) {
      for (final to in _getValidTargetsForBoard(from, board, myType)) {
        final simBoard = Map<HexCoord, PieceType>.from(board);
        simBoard.remove(from);
        simBoard[to] = myType;
        final tempScore = _evaluateBoardState(simBoard, myType);
        ownMoves.add(_ScoredAction(from, to, tempScore));
      }
    }

    ownMoves.sort((a, b) => b.score.compareTo(a.score));
    final topOwnMoves = ownMoves.take(15).toList();

    for (final ownMove in topOwnMoves) {
      final simBoardAfterOwn = Map<HexCoord, PieceType>.from(board);
      simBoardAfterOwn.remove(ownMove.from);
      simBoardAfterOwn[ownMove.to] = myType;

      // Immediate win
      if (_hasWinner(simBoardAfterOwn, myType)) {
        bestOwnFrom = ownMove.from;
        bestOwnTo = ownMove.to;
        bestScore = 999999;
        final redPieces = simBoardAfterOwn.entries
            .where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, simBoardAfterOwn))
            .map((e) => e.key).toList();
        if (redPieces.isNotEmpty) {
          final rFrom = redPieces.first;
          final rTo = _getValidTargetsForBoard(rFrom, simBoardAfterOwn, PieceType.red).firstOrNull;
          if (rTo != null) {
            bestRedFrom = rFrom;
            bestRedTo = rTo;
          }
        }
        break;
      }

      // Step 2: For each own move, evaluate all red moves
      final redPieces = simBoardAfterOwn.entries
          .where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, simBoardAfterOwn))
          .map((e) => e.key).toList();

      for (final rFrom in redPieces) {
        for (final rTo in _getValidTargetsForBoard(rFrom, simBoardAfterOwn, PieceType.red)) {
          final simAfterRed = Map<HexCoord, PieceType>.from(simBoardAfterOwn);
          simAfterRed.remove(rFrom);
          simAfterRed[rTo] = PieceType.red;

          // Step 3: Simulate opponent's best response (minimax)
          final score = _simulateOpponentTurn(simAfterRed, myType);

          if (score > bestScore) {
            bestScore = score;
            bestOwnFrom = ownMove.from;
            bestOwnTo = ownMove.to;
            bestRedFrom = rFrom;
            bestRedTo = rTo;
          }
        }
      }
    }

    if (bestOwnFrom == null || bestRedFrom == null) {
      _performGreedyAiTurn();
      return;
    }

    // Execute the best combination
    board.remove(bestOwnFrom);
    board[bestOwnTo!] = myType;
    _currentTurnMoves.add(_MoveRecord(bestOwnFrom, bestOwnTo, myType));
    turnPhase = TurnPhase.moveRed;
    _checkWin(currentPlayer);
    if (!isGameOver) {
      board.remove(bestRedFrom);
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

  /// Simulate opponent's best full turn (own + red) to find worst-case score.
  int _simulateOpponentTurn(Map<HexCoord, PieceType> simBoard, PieceType myType) {
    final opType = myType == PieceType.black ? PieceType.white : PieceType.black;
    final opPieces = simBoard.entries
        .where((e) => e.value == opType && _canMoveOnBoard(e.key, simBoard))
        .map((e) => e.key).toList();

    if (opPieces.isEmpty) return _evaluateBoardState(simBoard, myType) + 5000;

    int worstScoreForMe = 999999;

    // Evaluate opponent own moves, keep top 10
    final opOwnMoves = <_ScoredAction>[];
    for (final from in opPieces) {
      for (final to in _getValidTargetsForBoard(from, simBoard, opType)) {
        final b2 = Map<HexCoord, PieceType>.from(simBoard);
        b2.remove(from);
        b2[to] = opType;

        if (_hasWinner(b2, opType)) {
          return -999999; // Opponent can win immediately
        }

        final s = _evaluateBoardState(b2, myType);
        opOwnMoves.add(_ScoredAction(from, to, s));
      }
    }

    // Opponent minimizes our score, so sort ascending
    opOwnMoves.sort((a, b) => a.score.compareTo(b.score));
    final topOpMoves = opOwnMoves.take(10).toList();

    for (final opMove in topOpMoves) {
      final boardAfterOpOwn = Map<HexCoord, PieceType>.from(simBoard);
      boardAfterOpOwn.remove(opMove.from);
      boardAfterOpOwn[opMove.to] = opType;

      // Opponent also picks best red move (worst for us)
      int bestOpRedScore = opMove.score;
      final redPieces = boardAfterOpOwn.entries
          .where((e) => e.value == PieceType.red && _canMoveOnBoard(e.key, boardAfterOpOwn))
          .map((e) => e.key).toList();

      for (final rFrom in redPieces) {
        for (final rTo in _getValidTargetsForBoard(rFrom, boardAfterOpOwn, PieceType.red)) {
          final b3 = Map<HexCoord, PieceType>.from(boardAfterOpOwn);
          b3.remove(rFrom);
          b3[rTo] = PieceType.red;
          final s = _evaluateBoardState(b3, myType);
          if (s < bestOpRedScore) {
            bestOpRedScore = s;
          }
        }
      }

      if (bestOpRedScore < worstScoreForMe) {
        worstScoreForMe = bestOpRedScore;
      }
    }
    return worstScoreForMe;
  }

  int _evaluateBoardState(Map<HexCoord, PieceType> testBoard, PieceType myType) {
    int score = 0;
    final opType = myType == PieceType.black ? PieceType.white : PieceType.black;

    final myPositions = testBoard.entries.where((e) => e.value == myType).map((e) => e.key).toList();
    final opPositions = testBoard.entries.where((e) => e.value == opType).map((e) => e.key).toList();
    final redPositions = testBoard.entries.where((e) => e.value == PieceType.red).map((e) => e.key).toList();

    // 1. Line formation scoring (most important)
    score += _evaluateLines(myPositions, testBoard, isMaximizing: true);
    score -= _evaluateLines(opPositions, testBoard, isMaximizing: false);

    // 2. Red pieces blocking opponent lines
    for (final rPos in redPositions) {
      for (final dir in HexCoord.lineDirections) {
        final (dq, dr) = dir;
        final p1 = HexCoord(rPos.q - dq, rPos.r - dr);
        final p2 = HexCoord(rPos.q + dq, rPos.r + dr);
        if (testBoard[p1] == opType && testBoard[p2] == opType) {
          score += 800; // Blocked opponent line
        }
        // Penalty if red blocks our own line
        if (testBoard[p1] == myType && testBoard[p2] == myType) {
          score -= 300;
        }
      }
    }

    // 3. Mobility: reward having more movable pieces than opponent
    int myMobility = 0;
    int opMobility = 0;
    for (final pos in myPositions) {
      if (_canMoveOnBoard(pos, testBoard)) myMobility++;
    }
    for (final pos in opPositions) {
      if (_canMoveOnBoard(pos, testBoard)) opMobility++;
    }
    score += (myMobility - opMobility) * 150;

    // 4. Penalize opponent being close to winning
    // If opponent has n-1 in a line with open end, heavy penalty
    // (already covered by _evaluateLines subtraction, but add extra urgency)

    // 5. Centrality bonus: pieces closer to center have more tactical options
    for (final pos in myPositions) {
      final dist = (pos.q.abs() + pos.r.abs() + pos.s.abs()) ~/ 2;
      score += math.max(0, (settings.boardRadius - dist) * 20);
    }
    for (final pos in opPositions) {
      final dist = (pos.q.abs() + pos.r.abs() + pos.s.abs()) ~/ 2;
      score -= math.max(0, (settings.boardRadius - dist) * 15);
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
    // Reset timer reference point so clock restarts from now
    _turnStartTime = DateTime.now();
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
    _disposed = true;
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
