import 'package:hexgomoku/models/game_state.dart';
import 'package:hexgomoku/models/hex_coordinate.dart';

void main() {
  final gs = GameState(
    settings: const GameSettings(
      piecesPerPlayer: 3,
      gameMode: GameMode.pvp,
      boardRadius: 5,
    ),
  );

  print('Initial board length: \${gs.board.length}');
  
  final movable = gs.board.entries
      .where((e) => e.value == gs.currentPlayer.pieceType && gs.canMove(e.key))
      .map((e) => e.key)
      .toList();
      
  print('Movable black pieces: \$movable');
  
  if (movable.isNotEmpty) {
    var from = movable.first;
    var targets = gs.getValidTargets(from);
    print('Targets for \$from: \$targets');
    if (targets.isNotEmpty) {
      gs.onCellTap(from);
      gs.onCellTap(targets.first);
      print('TurnPhase after move: \${gs.turnPhase}');
      print('Is game over: \${gs.isGameOver}');
      print('Winner: \${gs.winner}');
      print('Lose reason: \${gs.loseReason}');
    }
  }
}
