import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/piece.dart';

/// Settings screen for configuring game parameters.
class SettingsScreen extends StatefulWidget {
  final GameSettings currentSettings;

  const SettingsScreen({super.key, required this.currentSettings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _piecesPerPlayer;
  late int _totalMinutes;
  late int _boardRadius;
  late GameMode _gameMode;
  late AiDifficulty _aiDifficulty;

  @override
  void initState() {
    super.initState();
    _piecesPerPlayer = widget.currentSettings.piecesPerPlayer.clamp(3, 5);
    _totalMinutes = widget.currentSettings.totalTimePerPlayer.inMinutes;
    _boardRadius = widget.currentSettings.boardRadius;
    _gameMode = widget.currentSettings.gameMode;
    _aiDifficulty = widget.currentSettings.aiDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0D0D),
        foregroundColor: Colors.white,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game mode
            _SettingCard(
              icon: Icons.people,
              title: 'Game Mode',
              subtitle: 'Choose your opponent',
              child: Row(
                children: [
                  _ModeChip(
                    label: 'PvP',
                    icon: Icons.people,
                    isSelected: _gameMode == GameMode.pvp,
                    onTap: () => setState(() => _gameMode = GameMode.pvp),
                  ),
                  const SizedBox(width: 12),
                  _ModeChip(
                    label: 'vs AI',
                    icon: Icons.smart_toy,
                    isSelected: _gameMode == GameMode.pvai,
                    onTap: () => setState(() => _gameMode = GameMode.pvai),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Board size
            _SettingCard(
              icon: Icons.grid_on,
              title: 'Board Size',
              subtitle: 'Radius of the hexagonal board (${_boardRadius * 2 + 1} cells wide)',
              child: Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onTap: _boardRadius > 3
                        ? () => setState(() => _boardRadius--)
                        : null,
                  ),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        '$_boardRadius',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: _boardRadius < 8
                        ? () => setState(() => _boardRadius++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Pieces per player
            _SettingCard(
              icon: Icons.hexagon,
              title: 'Pieces per Player',
              subtitle: 'Number of pieces each player starts with',
              child: Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onTap: _piecesPerPlayer > 3
                        ? () => setState(() => _piecesPerPlayer--)
                        : null,
                  ),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        '$_piecesPerPlayer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: _piecesPerPlayer < 5
                        ? () => setState(() => _piecesPerPlayer++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Time per player
            _SettingCard(
              icon: Icons.timer,
              title: 'Time per Player',
              subtitle: 'Total time in minutes for each player',
              child: Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onTap: _totalMinutes > 1
                        ? () => setState(() => _totalMinutes--)
                        : null,
                  ),
                  SizedBox(
                    width: 64,
                    child: Center(
                      child: Text(
                        '$_totalMinutes min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: _totalMinutes < 30
                        ? () => setState(() => _totalMinutes++)
                        : null,
                  ),
                ],
              ),
            ),
            if (_gameMode == GameMode.pvai) ...[
              const SizedBox(height: 16),
              // AI Difficulty
              _SettingCard(
                icon: Icons.psychology,
                title: 'AI Difficulty',
                subtitle: 'Select the AI strength',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ModeChip(
                      label: 'Low',
                      icon: Icons.signal_cellular_alt_1_bar,
                      isSelected: _aiDifficulty == AiDifficulty.low,
                      onTap: () => setState(() => _aiDifficulty = AiDifficulty.low),
                    ),
                    _ModeChip(
                      label: 'Medium',
                      icon: Icons.signal_cellular_alt_2_bar,
                      isSelected: _aiDifficulty == AiDifficulty.medium,
                      onTap: () => setState(() => _aiDifficulty = AiDifficulty.medium),
                    ),
                    _ModeChip(
                      label: 'High',
                      icon: Icons.signal_cellular_alt,
                      isSelected: _aiDifficulty == AiDifficulty.high,
                      onTap: () => setState(() => _aiDifficulty = AiDifficulty.high),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Apply button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final newSettings = GameSettings(
                    piecesPerPlayer: _piecesPerPlayer,
                    totalTimePerPlayer: Duration(minutes: _totalMinutes),
                    boardRadius: _boardRadius,
                    gameMode: _gameMode,
                    aiDifficulty: _aiDifficulty,
                  );
                  Navigator.pop(context, newSettings);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC1313),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Apply & New Game',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEC1313).withValues(alpha: 0.15)
              : const Color(0xFF1E1010),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEC1313)
                : const Color(0x0DFFFFFF),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFFEC1313)
                    : const Color(0xFF94A3B8),
                size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? const Color(0xFFEC1313) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: const Color(0xFFEC1313).withValues(alpha: 0.8),
                  size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 16),
          Center(child: child),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? const Color(0xFF3D2222)
              : const Color(0xFF1E1010),
          border: Border.all(
              color: onTap != null
                  ? const Color(0x33FFFFFF)
                  : const Color(0x0DFFFFFF)),
        ),
        child: Icon(icon,
            color: onTap != null
                ? const Color(0xFFE2E8F0)
                : const Color(0xFF555555),
            size: 20),
      ),
    );
  }
}
