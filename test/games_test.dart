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
  group('Gomoku', () {
    test('five in a row wins and undo restores', () {
      final game = GomokuGame();
      // Black plays along row 0, white answers on row 1.
      for (var i = 0; i < 5; i++) {
        game.apply(i); // black: (0,i)
        if (i < 4) game.apply(15 + i); // white
      }
      expect(game.winner, 0);
      expect(game.isOver, isTrue);
      game.undo();
      expect(game.isOver, isFalse);
      expect(game.side, 0);
    });

    test('AI returns a legal move', () {
      final game = GomokuGame();
      game.apply(112);
      game.apply(113);
      final move = game.aiMove(1);
      expect(move, isA<int>());
      expect(game.isLegal(move), isTrue);
    });
  });

  group('Go', () {
    test('captures a surrounded stone', () {
      final game = GoGame(size: 9);
      const center = 4 * 9 + 4;
      game.apply(center); // black
      game.apply(3 * 9 + 4); // white
      game.apply(-1); // black pass
      game.apply(4 * 9 + 3); // white
      game.apply(-1); // black pass
      game.apply(4 * 9 + 5); // white
      game.apply(-1); // black pass
      game.apply(5 * 9 + 4); // white captures
      expect(game.board[center], 0);
      expect(game.scoreText(1), contains('1'));
    });

    test('suicide is illegal', () {
      final game = GoGame(size: 9);
      const center = 4 * 9 + 4;
      game.board[center - 1] = 2;
      game.board[center + 1] = 2;
      game.board[center - 9] = 2;
      game.board[center + 9] = 2;
      expect(game.isLegal(center), isFalse);
    });

    test('two passes end the game', () {
      final game = GoGame(size: 9);
      game.apply(-1);
      game.apply(-1);
      expect(game.isOver, isTrue);
      expect(game.winner, isNotNull);
    });
  });

  group('Draughts', () {
    test('initial position and simple move', () {
      final game = DraughtsGame();
      expect(game.scoreText(0), contains('12'));
      final move = game.aiMove(0);
      expect(move, isA<List<int>>());
      expect(game.isLegal(move), isTrue);
      game.apply(move);
      expect(game.moveCount, 1);
      expect(game.side, 1);
      game.undo();
      expect(game.moveCount, 0);
      expect(game.side, 0);
    });
  });

  group('Draughts captures', () {
    test('a forced multi-capture that promotes cannot stop early', () {
      final game = DraughtsGame();
      game.board.fillRange(0, 64, 0);
      game.board[35] = 1; // white man at (4,3)
      game.board[26] = 2; // black man at (3,2)
      game.board[10] = 2; // black man at (1,2)
      expect(game.isLegal([35, 17, 3]), isTrue);
      expect(game.isLegal([35, 17]), isFalse);
      game.apply([35, 17, 3]);
      expect(game.board[26], 0);
      expect(game.board[10], 0);
      expect(game.board[3], 3); // promoted king
    });
  });

  group('Xiangqi', () {
    test('initial horse moves', () {
      final game = XiangqiGame();
      final targets = game.legalTargets(9 * 9 + 1);
      expect(targets, contains(7 * 9 + 0));
      expect(targets, contains(7 * 9 + 2));
    });

    test('horse check respects the leg', () {
      final game = XiangqiGame();
      game.board.fillRange(0, 90, 0);
      game.board[9 * 9 + 4] = 0 * 16 + 1; // red king
      game.board[7 * 9 + 5] = 1 * 16 + 4; // black horse
      expect(game.isInCheck(0), isTrue);
      game.board[8 * 9 + 5] = 0 * 16 + 7; // block the horse leg
      expect(game.isInCheck(0), isFalse);
    });

    test('flying general is check', () {
      final game = XiangqiGame();
      game.board.fillRange(0, 90, 0);
      game.board[9 * 9 + 4] = 0 * 16 + 1; // red king
      game.board[0 * 9 + 4] = 1 * 16 + 1; // black king
      expect(game.isInCheck(0), isTrue);
      expect(game.isInCheck(1), isTrue);
    });

    test('AI returns a legal move', () {
      final game = XiangqiGame();
      final move = game.aiMove(0);
      expect(move, isA<int>());
      expect(game.isLegal(move), isTrue);
    });
  });

  group('Jungle', () {
    test('rat can eat elephant', () {
      final game = JungleGame();
      game.board.fillRange(0, 63, 0);
      final rat = 4 * 7 + 4;
      final elephant = 4 * 7 + 5;
      game.board[rat] = 0 * 16 + 1;
      game.board[elephant] = 1 * 16 + 8;
      expect(game.legalTargets(rat), contains(elephant));
    });

    test('lion jumps the river and a rat blocks it', () {
      final game = JungleGame();
      game.board.fillRange(0, 63, 0);
      final lion = 4 * 7 + 0;
      game.board[lion] = 0 * 16 + 7;
      expect(game.legalTargets(lion), contains(4 * 7 + 3));
      game.board[4 * 7 + 1] = 1 * 16 + 1;
      expect(game.legalTargets(lion), isNot(contains(4 * 7 + 3)));
    });

    test('no draw after 100 quiet moves', () {
      final game = JungleGame();
      game.board.fillRange(0, 63, 0);
      game.board[8 * 7 + 0] = 0 * 16 + 7; // red lion
      game.board[8 * 7 + 6] = 1 * 16 + 7; // blue lion
      for (var i = 0; i < 60; i++) {
        game.apply([8 * 7 + 0, 8 * 7 + 1]);
        game.apply([8 * 7 + 6, 8 * 7 + 5]);
        game.apply([8 * 7 + 1, 8 * 7 + 0]);
        game.apply([8 * 7 + 5, 8 * 7 + 6]);
      }
      expect(game.isOver, isFalse);
      expect(game.winner, isNull);
    });

    test('entering the den wins', () {
      final game = JungleGame();
      game.board.fillRange(0, 63, 0);
      final lion = 1 * 7 + 3;
      game.board[lion] = 0 * 16 + 7;
      game.apply([lion, 0 * 7 + 3]);
      expect(game.winner, 0);
    });
  });

  group('Junqi', () {
    test('bomb removes both pieces', () {
      final game = JunqiGame();
      game.board.fillRange(0, 50, 0);
      final from = 4 * 5 + 3;
      final to = 4 * 5 + 4;
      game.board[from] = 0 * 16 + JunqiGame.bomb;
      game.board[to] = 1 * 16 + JunqiGame.commander;
      game.apply([from, to]);
      expect(game.board[from], 0);
      expect(game.board[to], 0);
    });

    test('flag capture wins', () {
      final game = JunqiGame();
      game.board.fillRange(0, 50, 0);
      final from = 1 * 5 + 3;
      final to = 0 * 5 + 3;
      game.board[from] = 0 * 16 + JunqiGame.commander;
      game.board[to] = 1 * 16 + JunqiGame.flag;
      game.apply([from, to]);
      expect(game.winner, 0);
    });
  });

  group('Reversi', () {
    test('initial legal moves and flipping', () {
      final game = ReversiGame();
      expect(game.llmMoves.length, 4);
      game.apply(3 * 8 + 5);
      expect(game.board[3 * 8 + 4], 1);
      expect(game.side, 1);
      expect(game.isLegal(-1), isFalse);
    });

    test('AI returns a legal move', () {
      final game = ReversiGame();
      final move = game.aiMove(1);
      expect(game.isLegal(move), isTrue);
    });
  });

  group('Connect Four', () {
    test('gravity drop and four in a row', () {
      final game = ConnectFourGame();
      game.board.fillRange(0, 42, 0);
      game.board[5 * 7 + 0] = 1;
      game.board[5 * 7 + 1] = 1;
      game.board[5 * 7 + 2] = 1;
      game.apply(3);
      expect(game.board[5 * 7 + 3], 1);
      expect(game.winner, 0);
      expect(game.isOver, isTrue);
    });

    test('AI returns a legal column', () {
      final game = ConnectFourGame();
      final column = game.aiMove(1);
      expect(game.isLegal(column), isTrue);
    });
  });

  group('Connect Six', () {
    test('black opens with one stone, then white gets two', () {
      final game = ConnectSixGame();
      game.apply(9 * 19 + 9);
      expect(game.side, 1);
      expect(game.llmMoves.length, 360);
      game.apply(9 * 19 + 10);
      expect(game.side, 1);
      game.apply(9 * 19 + 11);
      expect(game.side, 0);
    });

    test('six in a row wins', () {
      final game = ConnectSixGame();
      game.board.fillRange(0, 361, 0);
      for (var i = 0; i < 5; i++) {
        game.board[i] = 1;
      }
      game.apply(5);
      expect(game.winner, 0);
    });

    test('AI returns a legal move', () {
      final game = ConnectSixGame();
      game.apply(9 * 19 + 9);
      final move = game.aiMove(1);
      expect(game.isLegal(move), isTrue);
    });
  });

  group('Nine Men\'s Morris', () {
    test('placement, mill and removal', () {
      final game = NineMensMorrisGame();
      expect(game.llmMoves.length, 24);
      game.apply(const NineMove(-1, 0));
      game.apply(const NineMove(-1, 8));
      game.apply(const NineMove(-1, 1));
      game.apply(const NineMove(-1, 9));
      game.apply(const NineMove(-1, 2));
      expect(game.statusText, contains('取子'));
      expect(game.isLegal(const NineMove(-1, 0)), isFalse);
      final remove = game.llmMoves.first;
      expect(game.isLegal(remove), isTrue);
      game.apply(remove);
      expect(game.side, 1);
    });

    test('AI returns a legal move', () {
      final game = NineMensMorrisGame();
      final move = game.aiMove(1);
      expect(game.isLegal(move), isTrue);
    });
  });

  group('Amazons', () {
    test('a complete queen and arrow move is legal', () {
      final game = AmazonsGame();
      final move = game.aiMove(1);
      expect(move, isNotNull);
      expect(game.isLegal(move), isTrue);
      game.apply(move);
      expect(game.board.contains(AmazonsGame.arrowMark), isTrue);
      expect(game.side, 1);
    });

    test('AI returns a legal move', () {
      final game = AmazonsGame();
      expect(game.isLegal(game.aiMove(1)), isTrue);
    });
  });

  group('Tiger', () {
    test('tiger can jump a dog', () {
      final game = TigerGame();
      game.board.fillRange(0, 25, 0);
      game.board[2 * 5 + 2] = TigerGame.tiger;
      game.board[2 * 5 + 3] = TigerGame.dog;
      game.apply(2 * 5 + 4);
      expect(game.board[2 * 5 + 3], 0);
      expect(game.board[2 * 5 + 4], TigerGame.tiger);
      expect(game.winner, 0);
    });

    test('AI returns a legal move', () {
      final game = TigerGame();
      expect(game.isLegal(game.aiMove(1)), isTrue);
    });
  });

  group('Chinese Checkers', () {
    test('initial position and a legal move', () {
      final game = ChineseCheckersGame();
      expect(game.board.where((v) => v == 1).length, 10);
      expect(game.board.where((v) => v == 2).length, 10);
      final move = game.aiMove(1);
      expect(move, isNotNull);
      expect(game.isLegal(move), isTrue);
      game.apply(move);
      expect(game.side, 1);
    });

    test('AI returns a legal move', () {
      final game = ChineseCheckersGame();
      expect(game.isLegal(game.aiMove(1)), isTrue);
    });
  });

  group('Flying Chess', () {
    test('AI rolls and applies a turn', () {
      final game = FlyingChessGame();
      final turn = game.aiMove(1);
      expect(turn, isNotNull);
      expect(game.isLegal(turn), isTrue);
      game.apply(turn);
      expect(game.moveCount, 1);
    });

    test('roll action can be undone when it ends the turn', () {
      final game = FlyingChessGame();
      game.primaryAction();
      expect(game.canUndo, isTrue);
      game.undo();
      expect(game.moveCount, 0);
    });
  });

  group('Backgammon', () {
    test('AI rolls and makes a legal checker move', () {
      final game = BackgammonGame();
      final move = game.aiMove(1);
      expect(move, isNotNull);
      expect(game.isLegal(move), isTrue);
      game.apply(move);
      expect(game.moveCount, greaterThan(0));
    });

    test('AI returns a legal move', () {
      final game = BackgammonGame();
      expect(game.isLegal(game.aiMove(1)), isTrue);
    });
  });

  group('Shogi', () {
    test('initial position has legal moves and AI can move', () {
      final game = ShogiGame();
      expect(game.llmMoves, isNotEmpty);
      final move = game.aiMove(1);
      expect(move, isNotNull);
      expect(game.isLegal(move), isTrue);
      game.apply(move);
      expect(game.moveCount, 1);
      expect(game.side, 1);
    });

    test('pawn promotes on entering the promotion zone', () {
      final game = ShogiGame();
      game.board.fillRange(0, 81, 0);
      game.board[8 * 9 + 4] = ShogiGame.king;
      game.board[0 * 9 + 4] = -ShogiGame.king;
      game.board[3 * 9 + 0] = ShogiGame.pawn;
      game.apply(const ShogiMove(3 * 9 + 0, 2 * 9 + 0));
      expect(game.board[2 * 9 + 0], 9);
    });
  });

  group('Tycoon', () {
    test('AI takes a turn', () {
      final game = TycoonGame();
      final turn = game.aiMove(1);
      expect(turn, isNotNull);
      expect(game.isLegal(turn), isTrue);
      game.apply(turn);
      expect(game.moveCount, 1);
      expect(game.positions[0] + game.positions[1], greaterThan(0));
    });

    test('undo restores the previous turn', () {
      final game = TycoonGame();
      game.aiMove(1);
      game.undo();
      expect(game.moveCount, 0);
      expect(game.side, 0);
    });
  });

  group('Dou Dizhu', () {
    test('landlord has 20 cards and AI leads legally', () {
      final game = DouDizhuGame();
      expect(game.hands[0].length, 20);
      expect(game.hands[1].length, 17);
      final move = game.aiMove(1);
      expect(move, isNotNull);
      expect(game.isLegal(move), isTrue);
      game.apply(move);
      expect(game.side, 1);
    });

    test('pass is only legal when responding', () {
      final game = DouDizhuGame();
      expect(game.isLegal(const DoudizhuPass()), isFalse);
      final move = game.aiMove(1);
      game.apply(move);
      expect(game.isLegal(const DoudizhuPass()), isTrue);
    });
  });

  group('Mahjong', () {
    test('deals and discards with an automatic draw', () {
      final game = MahjongGame();
      expect(game.hands[0].length, 14);
      expect(game.hands[1].length, 13);
      final tile = game.aiMove(1);
      expect(tile, isNotNull);
      expect(game.isLegal(tile), isTrue);
      game.apply(tile);
      expect(game.hands[1].length, 14);
      expect(game.side, 1);
    });

    test('AI returns a legal tile', () {
      final game = MahjongGame();
      expect(game.isLegal(game.aiMove(1)), isTrue);
    });
  });

  group('AI sanity', () {
    test('every game returns a legal AI move', () {
      final gomoku = GomokuGame()..apply(112);
      expect(gomoku.isLegal(gomoku.aiMove(1)), isTrue);

      final go = GoGame(size: 9);
      final goMove = go.aiMove(1);
      expect(goMove, isNotNull);
      expect(go.isLegal(goMove), isTrue);

      final draughts = DraughtsGame();
      final draughtsMove = draughts.aiMove(1);
      expect(draughts.isLegal(draughtsMove), isTrue);

      final xiangqi = XiangqiGame();
      final xiangqiMove = xiangqi.aiMove(1);
      expect(xiangqi.isLegal(xiangqiMove), isTrue);

      final jungle = JungleGame();
      final jungleMove = jungle.aiMove(1);
      expect(jungle.isLegal(jungleMove), isTrue);

      final junqi = JunqiGame();
      final junqiMove = junqi.aiMove(1);
      expect(junqi.isLegal(junqiMove), isTrue);

      final snakes = SnakesGame();
      final die = snakes.aiMove(1);
      expect(snakes.isLegal(die), isTrue);

      final reversi = ReversiGame();
      expect(reversi.isLegal(reversi.aiMove(1)), isTrue);

      final connect4 = ConnectFourGame();
      expect(connect4.isLegal(connect4.aiMove(1)), isTrue);

      final connect6 = ConnectSixGame();
      connect6.apply(9 * 19 + 9);
      expect(connect6.isLegal(connect6.aiMove(1)), isTrue);

      final nine = NineMensMorrisGame();
      expect(nine.isLegal(nine.aiMove(1)), isTrue);

      final amazons = AmazonsGame();
      expect(amazons.isLegal(amazons.aiMove(1)), isTrue);

      final tiger = TigerGame();
      expect(tiger.isLegal(tiger.aiMove(1)), isTrue);

      final chinese = ChineseCheckersGame();
      expect(chinese.isLegal(chinese.aiMove(1)), isTrue);

      final flying = FlyingChessGame();
      expect(flying.isLegal(flying.aiMove(1)), isTrue);

      final backgammon = BackgammonGame();
      expect(backgammon.isLegal(backgammon.aiMove(1)), isTrue);

      final shogi = ShogiGame();
      expect(shogi.isLegal(shogi.aiMove(1)), isTrue);

      final tycoon = TycoonGame();
      expect(tycoon.isLegal(tycoon.aiMove(1)), isTrue);

      final dou = DouDizhuGame();
      expect(dou.isLegal(dou.aiMove(1)), isTrue);

      final mahjong = MahjongGame();
      expect(mahjong.isLegal(mahjong.aiMove(1)), isTrue);
    });
  });

  group('Snakes', () {
    test('ladder climbs', () {
      final game = SnakesGame();
      game.apply(4);
      expect(game.positions[0], 14);
    });

    test('exact 100 wins', () {
      final game = SnakesGame();
      game.positions[0] = 99;
      game.apply(1);
      expect(game.positions[0], 100);
      expect(game.winner, 0);
    });

    test('overshoot stays in place', () {
      final game = SnakesGame();
      game.positions[0] = 98;
      game.apply(4);
      expect(game.positions[0], 98);
    });
  });
}
