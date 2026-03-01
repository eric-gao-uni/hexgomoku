import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/hex_coordinate.dart';
import '../models/piece.dart';
import '../models/game_state.dart';

/// Renders the hexagonal board with hexagonal pieces.
/// Wrapped in InteractiveViewer for zoom & pan.
class HexBoard extends StatelessWidget {
  final GameState gameState;

  const HexBoard({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _HexMetrics.calculate(
          constraints.maxWidth,
          constraints.maxHeight,
          gameState.settings.boardRadius,
        );
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(80),
          child: GestureDetector(
            onTapDown: (details) {
              final coord = _hitTest(details.localPosition, metrics);
              if (coord != null && gameState.isValidCoord(coord)) {
                gameState.onCellTap(coord);
              }
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _HexBoardPainter(
                    gameState: gameState,
                    metrics: metrics,
                  ),
                ),
                // AI thinking overlay
                if (gameState.aiThinking)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.2),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32, height: 32,
                              child: CircularProgressIndicator(
                                color: Color(0xFFEC1313),
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text('AI Thinking...',
                                style: TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  HexCoord? _hitTest(Offset position, _HexMetrics metrics) {
    double minDist = double.infinity;
    HexCoord? closest;

    for (final coord in gameState.allCoords) {
      final center = metrics.axialToPixel(coord.q, coord.r);
      final dx = position.dx - center.dx;
      final dy = position.dy - center.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < metrics.hexSize * 0.85 && dist < minDist) {
        minDist = dist;
        closest = coord;
      }
    }
    return closest;
  }
}

class _HexMetrics {
  final double hexSize;
  final double centerX;
  final double centerY;

  _HexMetrics({
    required this.hexSize,
    required this.centerX,
    required this.centerY,
  });

  static _HexMetrics calculate(
      double canvasWidth, double canvasHeight, int radius) {
    final maxSizeByWidth = canvasWidth / (3.0 * radius + 2);
    final maxSizeByHeight =
        canvasHeight / (math.sqrt(3) * (2 * radius + 1));
    final hexSize = math.min(maxSizeByWidth, maxSizeByHeight) * 0.92;

    return _HexMetrics(
      hexSize: hexSize,
      centerX: canvasWidth / 2,
      centerY: canvasHeight / 2,
    );
  }

  Offset axialToPixel(int q, int r) {
    final x = hexSize * (3.0 / 2 * q);
    final y = hexSize * (math.sqrt(3) / 2 * q + math.sqrt(3) * r);
    return Offset(centerX + x, centerY + y);
  }
}

class _HexBoardPainter extends CustomPainter {
  final GameState gameState;
  final _HexMetrics metrics;

  _HexBoardPainter({required this.gameState, required this.metrics});

  @override
  void paint(Canvas canvas, Size size) {
    final validTargets = gameState.selectedPiece != null
        ? gameState.getValidTargets(gameState.selectedPiece!).toSet()
        : <HexCoord>{};

    for (final coord in gameState.allCoords) {
      final center = metrics.axialToPixel(coord.q, coord.r);
      _drawHexCell(canvas, center, metrics.hexSize, coord, validTargets);
    }

    for (final coord in gameState.allCoords) {
      final piece = gameState.board[coord];
      if (piece != null) {
        final center = metrics.axialToPixel(coord.q, coord.r);
        _drawHexPiece(canvas, center, metrics.hexSize, piece, coord);
      }
    }
  }

  void _drawHexCell(Canvas canvas, Offset center, double size,
      HexCoord coord, Set<HexCoord> validTargets) {
    final outerPath = _flatTopHexPath(center, size * 0.97);
    canvas.drawPath(
        outerPath,
        Paint()
          ..color = const Color(0xFF6D3B3B)
          ..style = PaintingStyle.fill);

    final innerPath = _flatTopHexPath(center, size * 0.90);
    Color fillColor = const Color(0xFF241212);

    if (gameState.winningCells.contains(coord)) {
      fillColor = const Color(0xFF4A3000);
    } else if (validTargets.contains(coord)) {
      fillColor = const Color(0xFF302020);
    } else if (gameState.selectedPiece == coord) {
      fillColor = const Color(0xFF4D2222);
    }

    canvas.drawPath(innerPath, Paint()..color = fillColor);

    if (validTargets.contains(coord)) {
      canvas.drawCircle(
        center,
        size * 0.12,
        Paint()..color = const Color(0x44FFFFFF),
      );
    }
  }

  void _drawHexPiece(Canvas canvas, Offset center, double hexSize,
      PieceType piece, HexCoord coord) {
    final pieceSize = hexSize * 0.82;
    final isSelected = gameState.selectedPiece == coord;
    final movable = gameState.canMove(coord);
    final isRelevant = _isPieceRelevant(piece);

    canvas.drawPath(
      _flatTopHexPath(center + const Offset(0, 2.5), pieceSize),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final (c1, c2, c3) = switch (piece) {
      PieceType.white => (
          const Color(0xFFFFFFFF),
          const Color(0xFFE0E0E0),
          const Color(0xFFB0B0B0)),
      PieceType.black => (
          const Color(0xFF555555),
          const Color(0xFF2A2A2A),
          const Color(0xFF000000)),
      PieceType.red => (
          const Color(0xFFFF4D4D),
          const Color(0xFFEC1313),
          const Color(0xFF990000)),
    };

    final piecePath = _flatTopHexPath(center, pieceSize);

    final gradient = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      radius: 1.2,
      colors: [c1, c2, c3],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: pieceSize));
    canvas.drawPath(piecePath, Paint()..shader = gradient);

    final borderColor = switch (piece) {
      PieceType.white => const Color(0xFF999999),
      PieceType.black => const Color(0xFF444444),
      PieceType.red => const Color(0xFF800000),
    };
    canvas.drawPath(
      piecePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final shineGradient = RadialGradient(
      center: const Alignment(-0.3, -0.5),
      radius: 0.7,
      colors: [
        Colors.white.withValues(alpha: 0.30),
        Colors.white.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: pieceSize));
    canvas.drawPath(
        _flatTopHexPath(center, pieceSize * 0.85), Paint()..shader = shineGradient);

    if (isRelevant && !movable && !gameState.isGameOver) {
      canvas.drawPath(
        piecePath,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
    }

    if (isSelected) {
      canvas.drawPath(
        _flatTopHexPath(center, pieceSize + 3),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  bool _isPieceRelevant(PieceType piece) {
    if (gameState.turnPhase == TurnPhase.moveOwn) {
      return piece == gameState.currentPlayer.pieceType;
    } else {
      return piece == PieceType.red;
    }
  }

  Path _flatTopHexPath(Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i) * math.pi / 180;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexBoardPainter oldDelegate) => true;
}
