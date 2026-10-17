import 'package:chess_app/core/chess.dart';
import 'package:chess_app/core/chess_ai.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('Perft', () {
    test('start position', () {
      final position = Position.initial();
      expect(perft(position, 1), 20);
      expect(perft(position, 2), 400);
      expect(perft(position, 3), 8902);
      expect(perft(position, 4), 197281);
    });

    test('kiwipete', () {
      final position = Position.fromFen(
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
      expect(perft(position, 1), 48);
      expect(perft(position, 2), 2039);
      expect(perft(position, 3), 97862);
    });

    test('endgame position', () {
      final position =
          Position.fromFen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
      expect(perft(position, 1), 14);
      expect(perft(position, 2), 191);
      expect(perft(position, 3), 2812);
      expect(perft(position, 4), 43238);
    });

    test('promotion / castling position', () {
      final position = Position.fromFen(
          'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
      expect(perft(position, 1), 6);
      expect(perft(position, 2), 264);
      expect(perft(position, 3), 9467);
    });

    test('position five', () {
      final position = Position.fromFen(
          'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8');
      expect(perft(position, 1), 44);
      expect(perft(position, 2), 1486);
      expect(perft(position, 3), 62379);
    });

    test('position six', () {
      final position = Position.fromFen(
          'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10');
      expect(perft(position, 1), 46);
      expect(perft(position, 2), 2079);
      expect(perft(position, 3), 89890);
    });
  });

  group('Rules', () {
    test('FEN round trip', () {
      final position = Position.initial();
      expect(position.toFen(), startFen);
    });

    test('detects checkmate', () {
      final position =
          Position.fromFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
      expect(position.computeStatus(), GameStatus.checkmate);
      expect(position.isInCheck(), isTrue);
    });

    test('detects stalemate', () {
      final position =
          Position.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(position.computeStatus(), GameStatus.stalemate);
    });

    test('detects insufficient material', () {
      final position = Position.fromFen('8/8/4k3/8/8/2K1B3/8/8 w - - 0 1');
      expect(position.isInsufficientMaterial, isTrue);
    });

    test('en passant is generated and applied', () {
      final position =
          Position.fromFen('rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3');
      final moves = position.legalMoves();
      final epMove = moves.firstWhere((m) => moveIsEnPassant(m));
      expect(squareName(moveFrom(epMove)), 'e5');
      expect(squareName(moveTo(epMove)), 'd6');
      position.makeMove(epMove);
      expect(position.pieceAt(parseSquare('d5')!), 0);
      expect(position.pieceAt(parseSquare('d6')!),
          makePiece(white, pawn));
    });

    test('castling moves the rook', () {
      final position =
          Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final castle = position.legalMoves().firstWhere(
          (m) => moveIsCastle(m) && moveTo(m) == 6);
      position.makeMove(castle);
      expect(position.pieceAt(parseSquare('g1')!), makePiece(white, king));
      expect(position.pieceAt(parseSquare('f1')!), makePiece(white, rook));
      expect(position.pieceAt(parseSquare('h1')!), 0);
      position.unmakeMove();
      expect(position.pieceAt(parseSquare('e1')!), makePiece(white, king));
      expect(position.pieceAt(parseSquare('h1')!), makePiece(white, rook));
    });

    test('promotion', () {
      final position =
          Position.fromFen('8/P6k/8/8/8/8/7K/8 w - - 0 1');
      final promo = position.legalMoves().firstWhere(
          (m) => movePromotion(m) == queen && moveTo(m) == 56);
      position.makeMove(promo);
      expect(position.pieceAt(56), makePiece(white, queen));
      expect(position.toFen().split(' ').first,
          'Q7/7k/8/8/8/8/7K/8');
    });

    test('SAN disambiguation', () {
      final position =
          Position.fromFen('8/8/8/8/8/5N2/8/1N2K3 w - - 0 1');
      final move = position.legalMoves().firstWhere(
          (m) => moveFrom(m) == 1 && moveTo(m) == 11);
      expect(position.sanFor(move), 'Nbd2');
    });
  });

  group('Engine', () {
    test('returns a legal move', () {
      final position = Position.initial();
      final result = aiCompute({
        'fen': position.toFen(),
        'level': 0,
        'seed': 7,
      });
      expect(result, isNotNull);
      final move = result!['move'] as int;
      expect(position.legalMoves(), contains(move));
    });

    test('finds mate in one', () {
      final result = aiCompute({
        'fen': '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1',
        'level': 1,
        'seed': 3,
      });
      expect(result, isNotNull);
      final move = result!['move'] as int;
      expect(moveTo(move), 60); // Re8 mate
    });
  });
}
