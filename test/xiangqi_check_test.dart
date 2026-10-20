import 'package:chess_app/games/impl/xiangqi_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checked side can only resolve check', () {
    final board = List<int>.filled(90, 0);
    board[9 * 9 + 4] = 1; // red king
    board[0 * 9 + 3] = 17; // black king (not same file)
    board[0 * 9 + 4] = 21; // black rook checks red king
    board[6 * 9 + 0] = 7; // red pawn far away
    final game = XiangqiGame();
    game.loadJson({'board': board, 'side': 0, 'noCapture': 0, 'moveCount': 0});
    expect(game.isInCheck(0), isTrue);
    expect(game.legalTargets(6 * 9 + 0), isEmpty);
    expect(game.isLegal((6 * 9 + 0) * 90 + 5 * 9 + 0), isFalse);
  });
}
