import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../widgets/hex_board.dart';
import '../widgets/game_controls.dart';
import '../widgets/rules_dialog.dart';
import 'victory_screen.dart';
import 'settings_screen.dart';

/// Main game screen.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;
  bool _showedRules = false;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _gameState.addListener(_onGameStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_showedRules) {
      _showedRules = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        RulesDialog.show(context);
      });
    }
  }

  void _onGameStateChanged() {
    setState(() {});

    if (_gameState.isGameOver && _gameState.winner != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || !_gameState.isGameOver) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VictoryScreen(
              winner: _gameState.winner!,
              moveCount: _gameState.moveCount,
              elapsedTime: Duration(
                seconds: _gameState.settings.totalTimePerPlayer.inSeconds -
                    _gameState.currentPlayerTimeRemaining.inSeconds,
              ),
              loseReason: _gameState.loseReason,
              onNewGame: () {
                Navigator.of(context).pop();
                _gameState.reset();
              },
              onBackToHome: () {
                Navigator.of(context).pop();
                _gameState.reset();
              },
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _openSettings() async {
    final newSettings = await Navigator.of(context).push<GameSettings>(
      MaterialPageRoute(
        builder: (_) =>
            SettingsScreen(currentSettings: _gameState.settings),
      ),
    );
    if (newSettings != null) {
      _gameState.updateSettings(newSettings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0D0D),
      body: Column(
        children: [
          // App bar
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HexGomoku',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => RulesDialog.show(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.menu_book,
                              color: Color(0xFF94A3B8), size: 22),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openSettings,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.settings,
                              color: Color(0xFF94A3B8), size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Board
          Expanded(
            child: Stack(
              children: [
                Container(color: const Color(0xFF221010)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: HexBoard(gameState: _gameState),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF1A0505).withValues(alpha: 0.8),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Controls
          GameControls(
            gameState: _gameState,
            onUndo: _gameState.undoCurrentTurn,
            onReset: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2C1818),
                  title: const Text('Reset Game?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text('Start a new game?',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _gameState.reset();
                      },
                      child: const Text('Reset',
                          style: TextStyle(color: Color(0xFFEC1313))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
