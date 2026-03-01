import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'piece.dart';

/// Game settings.
class GameSettings {
  final int piecesPerPlayer;
  final Duration totalTimePerPlayer;
  final int boardRadius;
  final GameMode gameMode;

  const GameSettings({
    this.piecesPerPlayer = 3,
    this.totalTimePerPlayer = const Duration(minutes: 10),
    this.boardRadius = 5,
    this.gameMode = GameMode.pvp,
  });

  GameSettings copyWith({
    int? piecesPerPlayer,
    Duration? totalTimePerPlayer,
    int? boardRadius,
    GameMode? gameMode,
  }) {
    return GameSettings(
      piecesPerPlayer: piecesPerPlayer ?? this.piecesPerPlayer,
      totalTimePerPlayer: totalTimePerPlayer ?? this.totalTimePerPlayer,
      boardRadius: boardRadius ?? this.boardRadius,
      gameMode: gameMode ?? this.gameMode,
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
    // BFS spiral from center, interleave colors for fair layout
    final spiral = <HexCoord>[const HexCoord(0, 0)];
    final visited = <HexCoord>{const HexCoord(0, 0)};
    final queue = <HexCoord>[const HexCoord(0, 0)];

    final totalNeeded = n * 2 + 2; // n black + n white + 2 red
    while (queue.isNotEmpty && spiral.length < totalNeeded) {
      final curr = queue.removeAt(0);
      for (final nb in curr.neighbors()) {
        if (isValidCoord(nb) && !visited.contains(nb)) {
          visited.add(nb);
          spiral.add(nb);
          queue.add(nb);
          if (spiral.length >= totalNeeded) break;
        }
      }
    }

    // Assign: first 2 = red (center), then alternate black/white
    for (int i = 0; i < spiral.length; i++) {
      if (i < 2) {
        board[spiral[i]] = PieceType.red;
      } else {
        final playerIndex = i - 2;
        board[spiral[i]] = playerIndex.isEven ? PieceType.black : PieceType.white;
      }
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

      notifyListeners();

      // Trigger AI if it's AI's turn
      _maybeDoAiMove();
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
    final rng = math.Random();

    // Step 1: Move own piece
    final ownPieces = board.entries
        .where((e) => e.value == currentPlayer.pieceType && canMove(e.key))
        .map((e) => e.key)
        .toList();

    if (ownPieces.isEmpty) return;

    // Try to find a winning move
    HexCoord? bestFrom;
    HexCoord? bestTo;
    int bestScore = -1000;

    for (final from in ownPieces) {
      final targets = allCoords.where((c) => board[c] == null).toList();
      for (final to in targets) {
        // Check qi at destination
        final simBoard = Map<HexCoord, PieceType>.from(board);
        final pt = simBoard.remove(from);
        simBoard[to] = pt!;
        if (!_canExistAt(to, simBoard)) continue;

        final score = _evaluateOwnMove(from, to);
        if (score > bestScore) {
          bestScore = score;
          bestFrom = from;
          bestTo = to;
        }
      }
    }

    if (bestFrom == null || bestTo == null) {
      // Random fallback
      bestFrom = ownPieces[rng.nextInt(ownPieces.length)];
      final targets = allCoords.where((c) => board[c] == null).toList();
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
    int bestRedScore = -1000;

    for (final from in redPieces) {
      for (final to in allCoords) {
        if (board[to] != null) continue;
        final testBoard = Map<HexCoord, PieceType>.from(board);
        testBoard.remove(from);
        testBoard[to] = PieceType.red;
        if (!_isConnected(testBoard)) continue;
        if (!_canExistAt(to, testBoard)) continue;

        final score = _evaluateRedMove(from, to);
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
  }

  int _evaluateOwnMove(HexCoord from, HexCoord to) {
    int score = 0;
    final myType = currentPlayer.pieceType;
    final opType = currentPlayer.opponent.pieceType;

    // Simulate
    final testBoard = Map<HexCoord, PieceType>.from(board);
    testBoard.remove(from);
    testBoard[to] = myType;

    final myPositions = testBoard.entries
        .where((e) => e.value == myType)
        .map((e) => e.key)
        .toList();

    // Check if this creates a winning line
    for (final dir in HexCoord.lineDirections) {
      final line = _findLineInBoard(myPositions, dir);
      if (line != null && line.length >= settings.piecesPerPlayer) {
        return 1000; // Winning move!
      }
      if (line != null) score += line.length * 10;
    }

    // Prefer moves toward other own pieces (alignment potential)
    for (final pos in myPositions) {
      if (pos == to) continue;
      for (final dir in HexCoord.lineDirections) {
        final (dq, dr) = dir;
        if (to.q - pos.q == dq && to.r - pos.r == dr) score += 5;
        if (to.q - pos.q == -dq && to.r - pos.r == -dr) score += 5;
      }
    }

    // Slightly discourage being near opponent
    final opPositions = testBoard.entries
        .where((e) => e.value == opType)
        .map((e) => e.key)
        .toList();
    for (final dir in HexCoord.lineDirections) {
      final opLine = _findLineInBoard(opPositions, dir);
      if (opLine != null && opLine.length >= 2) {
        // Try to block by being in the way
        score += 3;
      }
    }

    return score;
  }

  int _evaluateRedMove(HexCoord from, HexCoord to) {
    int score = 0;
    final opType = currentPlayer.opponent.pieceType;

    // Prefer moves that block opponent's lines
    final testBoard = Map<HexCoord, PieceType>.from(board);
    testBoard.remove(from);
    testBoard[to] = PieceType.red;

    final opPositions = testBoard.entries
        .where((e) => e.value == opType)
        .map((e) => e.key)
        .toList();

    // Place red between opponent pieces to disrupt alignment
    for (final dir in HexCoord.lineDirections) {
      final (dq, dr) = dir;
      // Check if red at `to` is between two opponent pieces
      final prev = HexCoord(to.q - dq, to.r - dr);
      final next = HexCoord(to.q + dq, to.r + dr);
      if (testBoard[prev] == opType && testBoard[next] == opType) {
        score += 20; // Great blocking move
      }
      if (testBoard[prev] == opType || testBoard[next] == opType) {
        score += 5;
      }
    }

    // Slight randomness to avoid predictability
    score += math.Random().nextInt(3);

    return score;
  }

  List<HexCoord>? _findLineInBoard(List<HexCoord> positions, (int, int) dir) {
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
      if (line.length >= 2) return line;
    }
    return null;
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

class _MoveRecord {
  final HexCoord from;
  final HexCoord to;
  final PieceType pieceType;
  _MoveRecord(this.from, this.to, this.pieceType);
}
