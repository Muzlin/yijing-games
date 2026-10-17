// ignore_for_file: avoid_print
import 'package:chess_app/core/chess.dart';
import 'package:chess_app/core/chess_ai.dart';

int perft(Position position, int depth) {
  if (depth == 0) return 1;
  final moves = position.legalMoves();
  if (depth == 1) return moves.length;
  var nodes = 0;
  for (final move in moves) {
    position.makeMove(move);
    nodes += perft(position, depth - 1);
    position.unmakeMove();
  }
  return nodes;
}

void check(String label, Object actual, Object expected) {
  if (actual != expected) {
    throw StateError('$label: expected $expected, got $actual');
  }
  print('ok  $label = $actual');
}

void main() {
  final start = Position.initial();
  check('start d1', perft(start, 1), 20);
  check('start d2', perft(start, 2), 400);
  check('start d3', perft(start, 3), 8902);
  check('start d4', perft(start, 4), 197281);

  final kiwi = Position.fromFen(
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
  check('kiwi d1', perft(kiwi, 1), 48);
  check('kiwi d2', perft(kiwi, 2), 2039);
  check('kiwi d3', perft(kiwi, 3), 97862);

  final p3 = Position.fromFen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
  check('p3 d1', perft(p3, 1), 14);
  check('p3 d2', perft(p3, 2), 191);
  check('p3 d3', perft(p3, 3), 2812);
  check('p3 d4', perft(p3, 4), 43238);

  final p4 = Position.fromFen(
      'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
  check('p4 d1', perft(p4, 1), 6);
  check('p4 d2', perft(p4, 2), 264);
  check('p4 d3', perft(p4, 3), 9467);

  final p5 = Position.fromFen(
      'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8');
  check('p5 d1', perft(p5, 1), 44);
  check('p5 d2', perft(p5, 2), 1486);
  check('p5 d3', perft(p5, 3), 62379);

  final p6 = Position.fromFen(
      'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10');
  check('p6 d1', perft(p6, 1), 46);
  check('p6 d2', perft(p6, 2), 2079);
  check('p6 d3', perft(p6, 3), 89890);

  check('fen', start.toFen(), startFen);

  final mate = Position.fromFen(
      'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
  check('checkmate', mate.computeStatus(), GameStatus.checkmate);

  final stale = Position.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
  check('stalemate', stale.computeStatus(), GameStatus.stalemate);

  final rookEnd = Position.fromFen('8/8/8/8/8/8/8/R3K2R w KQ - 0 1');
  final san = rookEnd.legalMoves().firstWhere(
      (m) => moveFrom(m) == 0 && moveTo(m) == 1);
  check('san', rookEnd.sanFor(san), 'Rb1');

  for (final level in [0, 1, 2, 3]) {
    final result = aiCompute({'fen': start.toFen(), 'level': level, 'seed': 7});
    if (result == null) throw StateError('engine returned null');
    final move = result['move'] as int;
    if (!start.legalMoves().contains(move)) {
      throw StateError('illegal engine move ${squareName(moveFrom(move))}'
          '${squareName(moveTo(move))}');
    }
    print('ok  ai level $level -> ${squareName(moveFrom(move))}'
        '${squareName(moveTo(move))} score=${result['score']} '
        'depth=${result['depth']} nodes=${result['nodes']}');
  }

  final mateInOne = aiCompute({
    'fen': '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1',
    'level': 1,
    'seed': 3,
  });
  final best = (mateInOne!['move'] as int);
  check('mate in one', squareName(moveTo(best)), 'e8');

  print('ALL ENGINE CHECKS PASSED');
}
