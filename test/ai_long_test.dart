import 'package:chess_app/games/core/game_core.dart';
import 'package:chess_app/games/impl/draughts_game.dart';
import 'package:chess_app/games/impl/go_game.dart';
import 'package:chess_app/games/impl/gomoku_game.dart';
import 'package:chess_app/games/impl/jungle_game.dart';
import 'package:chess_app/games/impl/junqi_game.dart';
import 'package:chess_app/games/impl/snakes_game.dart';
import 'package:chess_app/games/impl/xiangqi_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final games = <String, TurnGame Function()>{
    'gomoku': () => GomokuGame(),
    'go': () => GoGame(size: 9),
    'draughts': () => DraughtsGame(),
    'xiangqi': () => XiangqiGame(),
    'jungle': () => JungleGame(),
    'junqi': () => JunqiGame(),
    'snakes': () => SnakesGame(),
  };

  for (final entry in games.entries) {
    test('${entry.key}: AI can play a long game', () {
      final game = entry.value();
      var plies = 0;
      while (!game.isOver && plies < 40) {
        final move = game.aiMove(1);
        if (move == null) break;
        expect(game.isLegal(move), isTrue,
            reason: '${entry.key} illegal at ply $plies: $move');
        game.apply(move);
        plies++;
      }
      expect(plies, greaterThan(0), reason: '${entry.key} made no moves');
    });
  }
}
