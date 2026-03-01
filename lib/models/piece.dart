/// Represents a piece type on the board.
enum PieceType {
  black,
  white,
  red,
}

/// Represents which player's turn it is.
enum PlayerColor {
  black,
  white,
}

extension PlayerColorExt on PlayerColor {
  PieceType get pieceType =>
      this == PlayerColor.black ? PieceType.black : PieceType.white;

  PlayerColor get opponent =>
      this == PlayerColor.black ? PlayerColor.white : PlayerColor.black;

  String get displayName =>
      this == PlayerColor.black ? 'Black' : 'White';
}

/// Phase of the current turn.
enum TurnPhase {
  moveOwn,
  moveRed,
}

/// Game mode.
enum GameMode {
  pvp,
  pvai,
}
