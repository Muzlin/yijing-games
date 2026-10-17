import 'package:chess_app/games/impl/draughts_game.dart';
import 'package:chess_app/games/impl/go_game.dart';
import 'package:chess_app/games/impl/gomoku_game.dart';
import 'package:chess_app/games/impl/jungle_game.dart';
import 'package:chess_app/games/impl/junqi_game.dart';
import 'package:chess_app/games/impl/snakes_game.dart';
import 'package:chess_app/games/impl/xiangqi_game.dart';
import 'package:chess_app/games/core/game_core.dart';
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
    test('${entry.key}: human move then AI responds', () {
      final game = entry.value();
      final startSide = game.side;
      final humanMove = game.aiMove(0);
      expect(humanMove, isNotNull, reason: '${entry.key} human move null');
      expect(game.isLegal(humanMove), isTrue,
          reason: '${entry.key} human move illegal');
      game.apply(humanMove);
      expect(game.side != startSide || game.isOver, isTrue,
          reason: '${entry.key} side did not switch after human move');

      if (!game.isOver) {
        final aiMove = game.aiMove(1);
        expect(aiMove, isNotNull, reason: '${entry.key} AI move null');
        expect(game.isLegal(aiMove), isTrue,
            reason: '${entry.key} AI move illegal: $aiMove');
        game.apply(aiMove);
        expect(game.isOver || game.side == startSide, isTrue,
            reason: '${entry.key} side did not switch back after AI move');
      }
    });
  }
}
