import 'package:chess_app/games/impl/draughts_game.dart';
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

  group('Xiangqi', () {
    test('initial horse moves', () {
      final game = XiangqiGame();
      final targets = game.legalTargets(9 * 9 + 1);
      expect(targets, contains(7 * 9 + 0));
      expect(targets, contains(7 * 9 + 2));
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
