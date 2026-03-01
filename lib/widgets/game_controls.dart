import 'package:flutter/material.dart';
import '../models/piece.dart';
import '../models/game_state.dart';

/// Bottom control bar with countdown timers and action buttons.
class GameControls extends StatelessWidget {
  final GameState gameState;
  final VoidCallback onUndo;
  final VoidCallback onReset;

  const GameControls({
    super.key,
    required this.gameState,
    required this.onUndo,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF1A0D0D),
        border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TurnIndicator(gameState: gameState),
          const SizedBox(height: 12),
          _TimerBar(gameState: gameState),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.undo,
                  label: 'Undo',
                  onTap: onUndo,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionButton(
                  icon: Icons.restart_alt,
                  label: 'Reset',
                  onTap: onReset,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  final GameState gameState;
  const _TurnIndicator({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final isBlack = gameState.currentPlayer == PlayerColor.black;
    final phaseText = gameState.turnPhase == TurnPhase.moveOwn
        ? 'Move ${gameState.currentPlayer.displayName}'
        : 'Move Red';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1818),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBlack ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border.all(
                color: isBlack
                    ? const Color(0xFF444444)
                    : const Color(0xFF999999),
              ),
              boxShadow: [
                if (!isBlack)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "${gameState.currentPlayer.displayName}'s Turn",
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: gameState.turnPhase == TurnPhase.moveRed
                  ? const Color(0xFFEC1313).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              phaseText,
              style: TextStyle(
                color: gameState.turnPhase == TurnPhase.moveRed
                    ? const Color(0xFFEC1313)
                    : const Color(0xFFE2E8F0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  final GameState gameState;
  const _TimerBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Black timer
        _PlayerTimer(
          label: '⚫',
          remaining: gameState.currentPlayer == PlayerColor.black
              ? gameState.currentPlayerTimeRemaining
              : gameState.otherPlayerTimeRemaining,
          isActive: gameState.currentPlayer == PlayerColor.black,
        ),
        // Move count
        Text(
          'Move ${gameState.moveCount + 1}',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        // White timer
        _PlayerTimer(
          label: '⚪',
          remaining: gameState.currentPlayer == PlayerColor.white
              ? gameState.currentPlayerTimeRemaining
              : gameState.otherPlayerTimeRemaining,
          isActive: gameState.currentPlayer == PlayerColor.white,
        ),
      ],
    );
  }
}

class _PlayerTimer extends StatelessWidget {
  final String label;
  final Duration remaining;
  final bool isActive;

  const _PlayerTimer({
    required this.label,
    required this.remaining,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isLow = remaining.inSeconds < 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? (isLow ? const Color(0x33EC1313) : const Color(0x1AFFFFFF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(
                color:
                    isLow ? const Color(0xFFEC1313) : const Color(0x33FFFFFF))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
              color: isLow && isActive
                  ? const Color(0xFFEC1313)
                  : const Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? const Color(0xFFEC1313) : const Color(0xFF2C1C1C),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: isPrimary
                ? null
                : Border.all(color: const Color(0x0DFFFFFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isPrimary ? Colors.white : const Color(0xFFE2E8F0),
                  size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : const Color(0xFFE2E8F0),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
