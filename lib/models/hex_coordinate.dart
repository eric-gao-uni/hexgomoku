/// Axial coordinate system for hexagonal grid.
/// Uses (q, r) axial coordinates. The board is a regular hexagon
/// with radius R, containing cells where |q| <= R, |r| <= R, |q+r| <= R.
class HexCoord {
  final int q;
  final int r;

  const HexCoord(this.q, this.r);

  /// Third cube coordinate (derived).
  int get s => -q - r;

  /// Get all 6 neighbors in axial coordinates.
  List<HexCoord> neighbors() {
    return [
      HexCoord(q + 1, r),     // east
      HexCoord(q - 1, r),     // west
      HexCoord(q, r + 1),     // south-east
      HexCoord(q, r - 1),     // north-west
      HexCoord(q + 1, r - 1), // north-east
      HexCoord(q - 1, r + 1), // south-west
    ];
  }

  /// Cube coordinates for line detection: 3 axes.
  /// Axis 1: q direction (1, 0, -1)
  /// Axis 2: r direction (0, 1, -1)
  /// Axis 3: s direction (1, -1, 0)
  static const List<(int, int)> lineDirections = [
    (1, 0),   // along q axis
    (0, 1),   // along r axis
    (1, -1),  // along s axis
  ];

  @override
  bool operator ==(Object other) =>
      other is HexCoord && q == other.q && r == other.r;

  @override
  int get hashCode => q * 1000 + r;

  @override
  String toString() => 'HexCoord($q, $r)';
}
