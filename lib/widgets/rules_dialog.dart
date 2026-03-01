import 'package:flutter/material.dart';

/// Rules dialog with updated game rules.
class RulesDialog extends StatelessWidget {
  const RulesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const RulesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1818),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 32,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEC1313).withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.menu_book,
                      color: Color(0xFFEC1313), size: 28),
                ),
                const SizedBox(height: 12),
                const Text('Game Rules',
                    style: TextStyle(color: Colors.white, fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _rule('1', 'Goal',
                    'Align all 3 pieces of your color in a straight line to win.'),
                const SizedBox(height: 12),
                _rule('2', 'Turn',
                    'Each turn: first move YOUR piece, then move a RED piece.'),
                const SizedBox(height: 12),
                _rule('3', 'Movement',
                    'Pieces can jump to any empty cell on the board.'),
                const SizedBox(height: 12),
                _rule('4', 'Liberties',
                    'A piece needs ≥2 adjacent empty neighbors to slide out. If blocked on 5 sides, it cannot move.'),
                const SizedBox(height: 12),
                _rule('5', 'Connectivity',
                    'After moving the red piece, all pieces must remain connected. No islands allowed.'),
                const SizedBox(height: 12),
                _rule('6', 'Losing',
                    'You lose if: all your pieces are blocked, no valid red move exists, or your time runs out.'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC1313),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Got it', style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _rule(String number, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEC1313).withValues(alpha: 0.1),
          ),
          child: Center(child: Text(number,
              style: const TextStyle(color: Color(0xFFEC1313),
                  fontSize: 12, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFFE2E8F0),
                  fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: Color(0xFF94A3B8),
                  fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
