import 'package:chess_app/games/core/game_core.dart';
import 'package:chess_app/games/impl/connect_four_game.dart';
import 'package:chess_app/games/impl/connect_six_game.dart';
import 'package:chess_app/games/impl/draughts_game.dart';
import 'package:chess_app/games/impl/reversi_game.dart';
import 'package:chess_app/games/impl/nine_mens_morris_game.dart';
import 'package:chess_app/games/impl/amazons_game.dart';
import 'package:chess_app/games/impl/tiger_game.dart';
import 'package:chess_app/games/impl/chinese_checkers_game.dart';
import 'package:chess_app/games/impl/flying_chess_game.dart';
import 'package:chess_app/games/impl/backgammon_game.dart';
import 'package:chess_app/games/impl/shogi_game.dart';
import 'package:chess_app/games/impl/tycoon_game.dart';
import 'package:chess_app/games/impl/tic_tac_toe_game.dart';
import 'package:chess_app/games/impl/five_field_kono_game.dart';
import 'package:chess_app/games/impl/hex_game.dart';
import 'package:chess_app/games/impl/dots_boxes_game.dart';
import 'package:chess_app/games/impl/mancala_game.dart';
import 'package:chess_app/games/impl/oware_game.dart';
import 'package:chess_app/games/impl/hare_hounds_game.dart';
import 'package:chess_app/games/impl/fox_geese_game.dart';
import 'package:chess_app/games/impl/quoridor_game.dart';
import 'package:chess_app/games/impl/doudizhu_game.dart';
import 'package:chess_app/games/impl/mahjong_game.dart';
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
    'reversi': () => ReversiGame(),
    'connect4': () => ConnectFourGame(),
    'connect6': () => ConnectSixGame(),
    'nineMensMorris': () => NineMensMorrisGame(),
    'amazons': () => AmazonsGame(),
    'tiger': () => TigerGame(),
    'chineseCheckers': () => ChineseCheckersGame(),
    'flyingChess': () => FlyingChessGame(),
    'backgammon': () => BackgammonGame(),
    'shogi': () => ShogiGame(),
    'tycoon': () => TycoonGame(),
    'doudizhu': () => DouDizhuGame(),
    'mahjong': () => MahjongGame(),
    'ticTacToe': () => TicTacToeGame(),
    'fiveFieldKono': () => FiveFieldKonoGame(),
    'hex': () => HexGame(),
    'dotsBoxes': () => DotsBoxesGame(),
    'mancala': () => MancalaGame(),
    'oware': () => OwareGame(),
    'hareHounds': () => HareHoundsGame(),
    'foxGeese': () => FoxGeeseGame(),
    'quoridor': () => QuoridorGame(),
    'twelveMensMorris': () => TwelveMensMorrisGame(),
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
