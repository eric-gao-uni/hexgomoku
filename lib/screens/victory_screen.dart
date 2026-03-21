import 'package:flutter/material.dart';
import '../models/piece.dart';

/// Victory screen matching the design mockup (gold theme).
class VictoryScreen extends StatelessWidget {
  final PlayerColor winner;
  final int moveCount;
  final Duration elapsedTime;
  final String? loseReason;
  final VoidCallback onNewGame;
  final VoidCallback onViewBoard;

  const VictoryScreen({
    super.key,
    required this.winner,
    required this.moveCount,
    required this.elapsedTime,
    this.loseReason,
    required this.onNewGame,
    required this.onViewBoard,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = elapsedTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsedTime.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: _DotPatternPainter(),
              ),
            ),
          ),
          // Decorative elements
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.05,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x0DFFFFFF)),
              ),
              transform: Matrix4.rotationZ(0.785),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
                        onPressed: onViewBoard,
                      ),
                      Container(
                        height: 4,
                        width: 64,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Color(0xFF94A3B8)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                // Victory content - fixed single screen layout
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        // Trophy with diamond frame
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: 0.785,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFF4C025).withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.emoji_events,
                              color: Color(0xFFF4C025),
                              size: 40,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'VICTORY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'WINNER',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF262626),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x0DFFFFFF)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: winner == PlayerColor.black
                                      ? const Color(0xFF1A1A1A) : Colors.white,
                                  border: Border.all(
                                    color: winner == PlayerColor.black
                                        ? const Color(0xFF555555) : const Color(0xFF999999),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${winner.displayName} Player',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (loseReason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            loseReason!,
                            style: TextStyle(
                              color: const Color(0xFFF4C025).withValues(alpha: 0.7),
                              fontSize: 12, fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(flex: 1),
                        // Stats cards
                        Row(
                          children: [
                            Expanded(child: _StatCard(icon: Icons.grid_view, label: 'MOVES', value: '$moveCount')),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(icon: Icons.schedule, label: 'TIME', value: '$minutes:$seconds')),
                          ],
                        ),
                        const Spacer(flex: 1),
                        // Buttons
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: Transform(
                            transform: Matrix4.skewX(-0.15),
                            child: ElevatedButton(
                              onPressed: onNewGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4C025),
                                foregroundColor: const Color(0xFF1A1A1A),
                                shape: const RoundedRectangleBorder(),
                                elevation: 0,
                              ),
                              child: Transform(
                                transform: Matrix4.skewX(0.15),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.replay, size: 18),
                                    SizedBox(width: 8),
                                    Text('New Game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: Transform(
                            transform: Matrix4.skewX(-0.15),
                            child: OutlinedButton(
                              onPressed: onViewBoard,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFCBD5E1),
                                side: const BorderSide(color: Color(0x1AFFFFFF)),
                                shape: const RoundedRectangleBorder(),
                              ),
                              child: Transform(
                                transform: Matrix4.skewX(0.15),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.visibility, size: 18),
                                    SizedBox(width: 8),
                                    Text('View Board', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        children: [
          // Corner accents
          Stack(
            children: [
              Icon(icon, color: const Color(0xFFF4C025).withValues(alpha: 0.8), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF666666)
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
