import '../impl/go_game.dart';
import '../impl/connect_four_game.dart';
import '../impl/connect_six_game.dart';
import '../impl/draughts_game.dart';
import '../impl/jungle_game.dart';
import '../impl/junqi_game.dart';
import '../impl/reversi_game.dart';
import '../impl/snakes_game.dart';
import '../impl/xiangqi_game.dart';
import '../impl/gomoku_game.dart';
import 'game_core.dart';

class GameRegistry {
  static TurnGame create(GameKind kind, {int boardSize = 0}) {
    switch (kind) {
      case GameKind.gomoku:
        return GomokuGame();
      case GameKind.reversi:
        return ReversiGame();
      case GameKind.connect4:
        return ConnectFourGame();
      case GameKind.connect6:
        return ConnectSixGame();
      case GameKind.go:
        return GoGame(size: boardSize == 13 ? 13 : 9);
      case GameKind.xiangqi:
        return XiangqiGame();
      case GameKind.draughts:
        return DraughtsGame();
      case GameKind.jungle:
        return JungleGame();
      case GameKind.junqi:
        return JunqiGame();
      case GameKind.snakes:
        return SnakesGame();
      default:
        throw UnsupportedError('Game $kind is not wired yet');
    }
  }
}
