// A self-contained chess rules engine: board representation, legal move
// generation, FEN/SAN support, and position hashing.
import 'dart:math';

const int white = 0;
const int black = 1;

const int pawn = 1;
const int knight = 2;
const int bishop = 3;
const int rook = 4;
const int queen = 5;
const int king = 6;

const int wKingside = 1;
const int wQueenside = 2;
const int bKingside = 4;
const int bQueenside = 8;

int colorOf(int piece) => piece >> 3;
int typeOf(int piece) => piece & 7;
int makePiece(int color, int type) => (color << 3) | type;

bool isWhitePiece(int piece) => piece != 0 && (piece >> 3) == white;
bool isBlackPiece(int piece) => piece != 0 && (piece >> 3) == black;

/// Flip a square vertically (mirror for black's point of view).
int flipSquare(int sq) => sq ^ 56;

String squareName(int sq) {
  if (sq < 0 || sq > 63) return '-';
  return '${String.fromCharCode(97 + (sq & 7))}${(sq >> 3) + 1}';
}

int? parseSquare(String name) {
  if (name.length != 2) return null;
  final file = name.codeUnitAt(0) - 97;
  final rank = name.codeUnitAt(1) - 49;
  if (file < 0 || file > 7 || rank < 0 || rank > 7) return null;
  return rank * 8 + file;
}

String pieceLetter(int type) {
  const letters = ['', 'P', 'N', 'B', 'R', 'Q', 'K'];
  return letters[type];
}

String pieceNameZh(int type) {
  const names = ['', '兵', '马', '象', '车', '后', '王'];
  return names[type];
}

/// Encoded move: from[0..5] to[6..11] promotion[12..14] flags[15..18].
const int _captureFlag = 1 << 15;
const int _epFlag = 1 << 16;
const int _castleFlag = 1 << 17;
const int _doubleFlag = 1 << 18;

int encodeMove(
  int from,
  int to, {
  int promotion = 0,
  bool capture = false,
  bool enPassant = false,
  bool castle = false,
  bool doublePush = false,
}) {
  return from |
      (to << 6) |
      (promotion << 12) |
      (capture ? _captureFlag : 0) |
      (enPassant ? _epFlag : 0) |
      (castle ? _castleFlag : 0) |
      (doublePush ? _doubleFlag : 0);
}

int moveFrom(int move) => move & 63;
int moveTo(int move) => (move >> 6) & 63;
int movePromotion(int move) => (move >> 12) & 7;
bool moveIsCapture(int move) => (move & _captureFlag) != 0;
bool moveIsEnPassant(int move) => (move & _epFlag) != 0;
bool moveIsCastle(int move) => (move & _castleFlag) != 0;
bool moveIsDoublePush(int move) => (move & _doubleFlag) != 0;

/// UCI coordinate notation, e.g. e2e4 or e7e8q.
String uciForMove(int move) {
  final from = squareName(moveFrom(move));
  final to = squareName(moveTo(move));
  final promotion = movePromotion(move);
  const promotionLetters = ['', '', 'n', 'b', 'r', 'q', 'k'];
  return '$from$to${promotion != 0 ? promotionLetters[promotion] : ''}';
}

class Undo {
  final int move;
  int captured;
  int capturedSquare;
  final int castling;
  final int epSquare;
  final int halfmoveClock;
  final int fullmoveNumber;
  final int hash;
  final int whiteKing;
  final int blackKing;

  Undo(
    this.move,
    this.captured,
    this.capturedSquare,
    this.castling,
    this.epSquare,
    this.halfmoveClock,
    this.fullmoveNumber,
    this.hash,
    this.whiteKing,
    this.blackKing,
  );
}

// ---------------------------------------------------------------------------
// Pre-computed geometry
// ---------------------------------------------------------------------------

List<int> _targets(int sq, List<List<int>> deltas) {
  final file = sq & 7, rank = sq >> 3;
  final out = <int>[];
  for (final d in deltas) {
    final f = file + d[0], r = rank + d[1];
    if (f >= 0 && f < 8 && r >= 0 && r < 8) out.add(r * 8 + f);
  }
  return out;
}

final List<List<int>> knightTargets = List.generate(
  64,
  (sq) => _targets(sq, const [
    [1, 2], [2, 1], [2, -1], [1, -2],
    [-1, -2], [-2, -1], [-2, 1], [-1, 2],
  ]),
  growable: false,
);

final List<List<int>> kingTargets = List.generate(
  64,
  (sq) => _targets(sq, const [
    [0, 1], [1, 1], [1, 0], [1, -1],
    [0, -1], [-1, -1], [-1, 0], [-1, 1],
  ]),
  growable: false,
);

List<List<int>> _raysFor(int sq, List<List<int>> dirs) {
  final file = sq & 7, rank = sq >> 3;
  final rays = <List<int>>[];
  for (final d in dirs) {
    final ray = <int>[];
    var f = file + d[0], r = rank + d[1];
    while (f >= 0 && f < 8 && r >= 0 && r < 8) {
      ray.add(r * 8 + f);
      f += d[0];
      r += d[1];
    }
    rays.add(ray);
  }
  return rays;
}

const List<List<int>> _diagDirections = [
  [1, 1], [1, -1], [-1, 1], [-1, -1],
];
const List<List<int>> _straightDirections = [
  [0, 1], [0, -1], [1, 0], [-1, 0],
];

final List<List<List<int>>> bishopRays =
    List.generate(64, (sq) => _raysFor(sq, _diagDirections), growable: false);
final List<List<List<int>>> rookRays =
    List.generate(64, (sq) => _raysFor(sq, _straightDirections), growable: false);

// ---------------------------------------------------------------------------
// Zobrist hashing (31 bit keys keep web integers small)
// ---------------------------------------------------------------------------

final Random _zRandom = Random(0x51EED);
final List<List<int>> _zPiece = List.generate(
  64,
  (_) => List.generate(16, (_) => _zRandom.nextInt(0x7FFFFFFF)),
  growable: false,
);
final int _zSide = _zRandom.nextInt(0x7FFFFFFF);
final List<int> _zCastling =
    List.generate(16, (_) => _zRandom.nextInt(0x7FFFFFFF), growable: false);
final List<int> _zEp =
    List.generate(8, (_) => _zRandom.nextInt(0x7FFFFFFF), growable: false);

// ---------------------------------------------------------------------------

const String startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const List<int> _clearCastlingOnSquare = [
  wQueenside, 0, 0, 0, wKingside | wQueenside, 0, 0, wKingside,
  0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,
  bQueenside, 0, 0, 0, bKingside | bQueenside, 0, 0, bKingside,
];

enum GameStatus {
  playing,
  checkmate,
  stalemate,
  insufficientMaterial,
  fiftyMove,
  threefold,
  forfeit,
}

extension GameStatusX on GameStatus {
  bool get isOver => this != GameStatus.playing;
  bool get isDraw =>
      this == GameStatus.stalemate ||
      this == GameStatus.insufficientMaterial ||
      this == GameStatus.fiftyMove ||
      this == GameStatus.threefold;
}

class Position {
  final List<int> board;
  int side;
  int castling;
  int epSquare;
  int halfmoveClock;
  int fullmoveNumber;
  int hash;
  final List<int> kingSquare;
  final List<Undo> _undo = [];

  Position._(
    this.board,
    this.side,
    this.castling,
    this.epSquare,
    this.halfmoveClock,
    this.fullmoveNumber,
    this.hash,
    this.kingSquare,
  );

  factory Position.initial() => Position.fromFen(startFen);

  factory Position.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) {
      throw const FormatException('Invalid FEN');
    }
    final board = List<int>.filled(64, 0);
    final rows = parts[0].split('/');
    if (rows.length != 8) throw const FormatException('Invalid FEN board');
    for (var r = 0; r < 8; r++) {
      var file = 0;
      for (final ch in rows[r].split('')) {
        if (ch.codeUnitAt(0) >= 49 && ch.codeUnitAt(0) <= 56) {
          file += int.parse(ch);
        } else {
          const pieces = {
            'p': pawn, 'n': knight, 'b': bishop,
            'r': rook, 'q': queen, 'k': king,
          };
          final type = pieces[ch.toLowerCase()];
          if (type == null || file > 7) {
            throw const FormatException('Invalid FEN piece');
          }
          board[(7 - r) * 8 + file] =
              makePiece(ch == ch.toUpperCase() ? white : black, type);
          file++;
        }
      }
    }

    final side = parts[1] == 'b' ? black : white;
    var castling = 0;
    if (parts[2].contains('K')) castling |= wKingside;
    if (parts[2].contains('Q')) castling |= wQueenside;
    if (parts[2].contains('k')) castling |= bKingside;
    if (parts[2].contains('q')) castling |= bQueenside;

    var ep = -1;
    if (parts[3] != '-') {
      ep = parseSquare(parts[3]) ?? -1;
    }
    final halfmove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    final fullmove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;

    final kings = [4, 60];
    for (var sq = 0; sq < 64; sq++) {
      if (typeOf(board[sq]) == king && board[sq] != 0) {
        kings[colorOf(board[sq])] = sq;
      }
    }

    final pos = Position._(
      board,
      side,
      castling,
      ep,
      halfmove,
      fullmove,
      0,
      kings,
    );
    pos.hash = pos._computeHash();
    return pos;
  }

  Position copy() {
    final p = Position._(
      List<int>.of(board),
      side,
      castling,
      epSquare,
      halfmoveClock,
      fullmoveNumber,
      hash,
      List<int>.of(kingSquare),
    );
    return p;
  }

  int pieceAt(int sq) => board[sq];
  bool get isWhiteToMove => side == white;
  int get opponent => 1 - side;

  bool isInCheck([int? forSide]) {
    final s = forSide ?? side;
    return isAttacked(kingSquare[s], 1 - s);
  }

  bool isAttacked(int sq, int byColor) {
    final file = sq & 7;
    // Pawns
    if (byColor == white) {
      if (file > 0) {
        final s = sq - 9;
        if (s >= 0 && board[s] == makePiece(white, pawn)) return true;
      }
      if (file < 7) {
        final s = sq - 7;
        if (s >= 0 && board[s] == makePiece(white, pawn)) return true;
      }
    } else {
      if (file > 0) {
        final s = sq + 7;
        if (s < 64 && board[s] == makePiece(black, pawn)) return true;
      }
      if (file < 7) {
        final s = sq + 9;
        if (s < 64 && board[s] == makePiece(black, pawn)) return true;
      }
    }
    // Knights
    final knightPiece = makePiece(byColor, knight);
    for (final s in knightTargets[sq]) {
      if (board[s] == knightPiece) return true;
    }
    // King
    final kingPiece = makePiece(byColor, king);
    for (final s in kingTargets[sq]) {
      if (board[s] == kingPiece) return true;
    }
    // Diagonals (bishop / queen)
    final bishopPiece = makePiece(byColor, bishop);
    final queenPiece = makePiece(byColor, queen);
    for (final ray in bishopRays[sq]) {
      for (final s in ray) {
        final p = board[s];
        if (p == 0) continue;
        if (p == bishopPiece || p == queenPiece) return true;
        break;
      }
    }
    // Files and ranks (rook / queen)
    final rookPiece = makePiece(byColor, rook);
    for (final ray in rookRays[sq]) {
      for (final s in ray) {
        final p = board[s];
        if (p == 0) continue;
        if (p == rookPiece || p == queenPiece) return true;
        break;
      }
    }
    return false;
  }

  List<int> legalMoves() {
    final result = <int>[];
    for (final move in _pseudoMoves()) {
      final mover = side;
      makeMove(move);
      if (!isAttacked(kingSquare[mover], side)) result.add(move);
      unmakeMove();
    }
    return result;
  }

  List<int> legalMovesFrom(int sq) {
    if (sq < 0 || sq > 63) return const [];
    final piece = board[sq];
    if (piece == 0 || colorOf(piece) != side) return const [];
    return legalMoves().where((m) => moveFrom(m) == sq).toList(growable: false);
  }

  List<int> capturesFrom(int sq) {
    return legalMovesFrom(sq).where(moveIsCapture).toList(growable: false);
  }

  List<int> _pseudoMoves() {
    final moves = <int>[];
    final us = side;
    final them = 1 - side;
    final forward = us == white ? 8 : -8;
    final startRank = us == white ? 1 : 6;
    final promotionRank = us == white ? 7 : 0;

    for (var sq = 0; sq < 64; sq++) {
      final piece = board[sq];
      if (piece == 0 || colorOf(piece) != us) continue;

      switch (typeOf(piece)) {
        case pawn:
          final oneStep = sq + forward;
          if (oneStep >= 0 && oneStep < 64 && board[oneStep] == 0) {
            if ((oneStep >> 3) == promotionRank) {
              for (var promo = knight; promo <= queen; promo++) {
                moves.add(encodeMove(sq, oneStep, promotion: promo));
              }
            } else {
              moves.add(encodeMove(sq, oneStep));
              if ((sq >> 3) == startRank) {
                final twoStep = sq + forward * 2;
                if (board[twoStep] == 0) {
                  moves.add(encodeMove(sq, twoStep, doublePush: true));
                }
              }
            }
          }
          for (final df in const [-1, 1]) {
            final f = (sq & 7) + df;
            if (f < 0 || f > 7) continue;
            final to = sq + forward + df;
            if (to < 0 || to > 63) continue;
            if (to == epSquare) {
              final capturedSq = to + (us == white ? -8 : 8);
              if (board[capturedSq] == makePiece(them, pawn)) {
                moves.add(encodeMove(sq, to,
                    capture: true, enPassant: true));
              }
            } else {
              final target = board[to];
              if (target != 0 && colorOf(target) == them) {
                if ((to >> 3) == promotionRank) {
                  for (var promo = knight; promo <= queen; promo++) {
                    moves.add(encodeMove(sq, to,
                        promotion: promo, capture: true));
                  }
                } else {
                  moves.add(encodeMove(sq, to, capture: true));
                }
              }
            }
          }
          break;

        case knight:
          for (final to in knightTargets[sq]) {
            final target = board[to];
            if (target == 0) {
              moves.add(encodeMove(sq, to));
            } else if (colorOf(target) == them) {
              moves.add(encodeMove(sq, to, capture: true));
            }
          }
          break;

        case bishop:
          for (final ray in bishopRays[sq]) {
            for (final to in ray) {
              final target = board[to];
              if (target == 0) {
                moves.add(encodeMove(sq, to));
              } else {
                if (colorOf(target) == them) {
                  moves.add(encodeMove(sq, to, capture: true));
                }
                break;
              }
            }
          }
          break;

        case rook:
          for (final ray in rookRays[sq]) {
            for (final to in ray) {
              final target = board[to];
              if (target == 0) {
                moves.add(encodeMove(sq, to));
              } else {
                if (colorOf(target) == them) {
                  moves.add(encodeMove(sq, to, capture: true));
                }
                break;
              }
            }
          }
          break;

        case queen:
          for (final ray in [
            ...bishopRays[sq],
            ...rookRays[sq],
          ]) {
            for (final to in ray) {
              final target = board[to];
              if (target == 0) {
                moves.add(encodeMove(sq, to));
              } else {
                if (colorOf(target) == them) {
                  moves.add(encodeMove(sq, to, capture: true));
                }
                break;
              }
            }
          }
          break;

        case king:
          for (final to in kingTargets[sq]) {
            final target = board[to];
            if (target == 0) {
              moves.add(encodeMove(sq, to));
            } else if (colorOf(target) == them) {
              moves.add(encodeMove(sq, to, capture: true));
            }
          }
          _addCastlingMoves(moves, us);
          break;
      }
    }
    return moves;
  }

  void _addCastlingMoves(List<int> moves, int us) {
    final home = kingSquare[us];
    if (isAttacked(home, 1 - us)) return;
    final kingPiece = makePiece(us, king);
    final rookPiece = makePiece(us, rook);
    if (board[home] != kingPiece) return;

    if (us == white && home == 4) {
      if ((castling & wKingside) != 0 &&
          board[5] == 0 &&
          board[6] == 0 &&
          board[7] == rookPiece &&
          !isAttacked(5, black) &&
          !isAttacked(6, black)) {
        moves.add(encodeMove(4, 6, castle: true));
      }
      if ((castling & wQueenside) != 0 &&
          board[3] == 0 &&
          board[2] == 0 &&
          board[1] == 0 &&
          board[0] == rookPiece &&
          !isAttacked(3, black) &&
          !isAttacked(2, black)) {
        moves.add(encodeMove(4, 2, castle: true));
      }
    } else if (us == black && home == 60) {
      if ((castling & bKingside) != 0 &&
          board[61] == 0 &&
          board[62] == 0 &&
          board[63] == rookPiece &&
          !isAttacked(61, white) &&
          !isAttacked(62, white)) {
        moves.add(encodeMove(60, 62, castle: true));
      }
      if ((castling & bQueenside) != 0 &&
          board[59] == 0 &&
          board[58] == 0 &&
          board[57] == 0 &&
          board[56] == rookPiece &&
          !isAttacked(59, white) &&
          !isAttacked(58, white)) {
        moves.add(encodeMove(60, 58, castle: true));
      }
    }
  }

  Undo makeMove(int move) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final promotion = movePromotion(move);
    final moving = board[from];
    final mover = colorOf(moving);
    final undo = Undo(
      move,
      board[to],
      to,
      castling,
      epSquare,
      halfmoveClock,
      fullmoveNumber,
      hash,
      kingSquare[0],
      kingSquare[1],
    );
    _undo.add(undo);

    if (moveIsEnPassant(move)) {
      final capturedSq = to + (mover == white ? -8 : 8);
      undo.captured = board[capturedSq];
      undo.capturedSquare = capturedSq;
      board[capturedSq] = 0;
    }

    board[to] = promotion != 0 ? makePiece(mover, promotion) : moving;
    board[from] = 0;

    if (typeOf(moving) == king) {
      kingSquare[mover] = to;
      if (moveIsCastle(move)) {
        if (to > from) {
          board[from + 1] = board[from + 3];
          board[from + 3] = 0;
        } else {
          board[from - 1] = board[from - 4];
          board[from - 4] = 0;
        }
      }
    }

    castling &= ~(_clearCastlingOnSquare[from] | _clearCastlingOnSquare[to]);

    if (typeOf(moving) == pawn) {
      halfmoveClock = 0;
      epSquare = moveIsDoublePush(move) ? (from + to) >> 1 : -1;
    } else {
      halfmoveClock++;
      epSquare = -1;
    }
    if (moveIsCapture(move)) halfmoveClock = 0;
    if (mover == black) fullmoveNumber++;
    side = 1 - side;
    hash = _computeHash();
    return undo;
  }

  void unmakeMove() {
    final undo = _undo.removeLast();
    final move = undo.move;
    final from = moveFrom(move);
    final to = moveTo(move);
    final promotion = movePromotion(move);
    final moved = board[to];
    final mover = colorOf(moved);

    board[from] = promotion != 0 ? makePiece(mover, pawn) : moved;
    board[to] = 0;

    if (moveIsEnPassant(move)) {
      board[undo.capturedSquare] = undo.captured;
    } else if (undo.captured != 0) {
      board[to] = undo.captured;
    }

    if (moveIsCastle(move)) {
      if (to > from) {
        board[from + 3] = board[from + 1];
        board[from + 1] = 0;
      } else {
        board[from - 4] = board[from - 1];
        board[from - 1] = 0;
      }
    }

    castling = undo.castling;
    epSquare = undo.epSquare;
    halfmoveClock = undo.halfmoveClock;
    fullmoveNumber = undo.fullmoveNumber;
    hash = undo.hash;
    kingSquare[0] = undo.whiteKing;
    kingSquare[1] = undo.blackKing;
    side = 1 - side;
  }

  int _computeHash() {
    var h = 0;
    for (var sq = 0; sq < 64; sq++) {
      final piece = board[sq];
      if (piece != 0) h ^= _zPiece[sq][piece];
    }
    if (side == black) h ^= _zSide;
    h ^= _zCastling[castling];
    if (epSquare >= 0) h ^= _zEp[epSquare & 7];
    return h & 0x7FFFFFFF;
  }

  // -------------------------------------------------------------------------
  // Status
  // -------------------------------------------------------------------------

  bool get isCheckmate => isInCheck() && legalMoves().isEmpty;
  bool get isStalemate => !isInCheck() && legalMoves().isEmpty;

  bool get isInsufficientMaterial {
    var knights = 0;
    final bishopSquares = <int>[];
    for (var sq = 0; sq < 64; sq++) {
      final piece = board[sq];
      if (piece == 0) continue;
      switch (typeOf(piece)) {
        case pawn:
        case rook:
        case queen:
          return false;
        case knight:
          knights++;
          break;
        case bishop:
          bishopSquares.add(sq);
          break;
      }
    }
    if (knights == 0) {
      if (bishopSquares.isEmpty) return true;
      final color = (bishopSquares.first & 7) + (bishopSquares.first >> 3);
      final allSame = bishopSquares.every(
          (s) => ((s & 7) + (s >> 3)) % 2 == color % 2);
      return allSame;
    }
    // King + knight vs king is a draw by insufficient material.
    return knights == 1 && bishopSquares.isEmpty;
  }

  GameStatus computeStatus({int repetitions = 1}) {
    final moves = legalMoves();
    if (moves.isEmpty) {
      return isInCheck() ? GameStatus.checkmate : GameStatus.stalemate;
    }
    if (halfmoveClock >= 100) return GameStatus.fiftyMove;
    if (isInsufficientMaterial) return GameStatus.insufficientMaterial;
    if (repetitions >= 3) return GameStatus.threefold;
    return GameStatus.playing;
  }

  // -------------------------------------------------------------------------
  // FEN
  // -------------------------------------------------------------------------

  String toFen() {
    final buffer = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      var empty = 0;
      for (var file = 0; file < 8; file++) {
        final piece = board[rank * 8 + file];
        if (piece == 0) {
          empty++;
        } else {
          if (empty > 0) {
            buffer.write(empty);
            empty = 0;
          }
          const letters = ['', 'p', 'n', 'b', 'r', 'q', 'k'];
          final letter = letters[typeOf(piece)];
          buffer.write(colorOf(piece) == white ? letter.toUpperCase() : letter);
        }
      }
      if (empty > 0) buffer.write(empty);
      if (rank > 0) buffer.write('/');
    }
    buffer.write(side == white ? ' w ' : ' b ');
    final rights = StringBuffer();
    if ((castling & wKingside) != 0) rights.write('K');
    if ((castling & wQueenside) != 0) rights.write('Q');
    if ((castling & bKingside) != 0) rights.write('k');
    if ((castling & bQueenside) != 0) rights.write('q');
    buffer.write(rights.isEmpty ? '-' : rights.toString());
    buffer.write(' ');
    buffer.write(epSquare >= 0 ? squareName(epSquare) : '-');
    buffer.write(' ');
    buffer.write(halfmoveClock);
    buffer.write(' ');
    buffer.write(fullmoveNumber);
    return buffer.toString();
  }

  // -------------------------------------------------------------------------
  // SAN
  // -------------------------------------------------------------------------

  String sanFor(int move) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final piece = board[from];
    final type = typeOf(piece);
    final isCapture = moveIsCapture(move) || moveIsEnPassant(move);
    final promotion = movePromotion(move);

    String base;
    if (moveIsCastle(move)) {
      base = to > from ? 'O-O' : 'O-O-O';
    } else if (type == pawn) {
      if (isCapture) {
        base = '${String.fromCharCode(97 + (from & 7))}x${squareName(to)}';
      } else {
        base = squareName(to);
      }
      if (promotion != 0) base += '=${pieceLetter(promotion)}';
    } else {
      final letter = pieceLetter(type);
      // Disambiguation: which other identical pieces can reach `to`?
      final others = <int>[];
      for (final other in legalMoves()) {
        if (other == move) continue;
        if (moveTo(other) != to) continue;
        final otherPiece = board[moveFrom(other)];
        if (typeOf(otherPiece) != type || colorOf(otherPiece) != colorOf(piece)) {
          continue;
        }
        others.add(moveFrom(other));
      }
      var disambiguation = '';
      if (others.isNotEmpty) {
        final sameFile = others.any((s) => (s & 7) == (from & 7));
        final sameRank = others.any((s) => (s >> 3) == (from >> 3));
        if (!sameFile) {
          disambiguation = String.fromCharCode(97 + (from & 7));
        } else if (!sameRank) {
          disambiguation = '${(from >> 3) + 1}';
        } else {
          disambiguation = squareName(from);
        }
      }
      base = '$letter$disambiguation${isCapture ? 'x' : ''}${squareName(to)}';
    }

    // Check / mate suffix.
    final probe = copy();
    probe.makeMove(move);
    if (probe.isInCheck()) {
      base += probe.legalMoves().isEmpty ? '#' : '+';
    }
    return base;
  }

  int materialFor(int color) {
    var total = 0;
    for (var sq = 0; sq < 64; sq++) {
      final piece = board[sq];
      if (piece == 0 || colorOf(piece) != color) continue;
      switch (typeOf(piece)) {
        case pawn:
          total += 1;
          break;
        case knight:
        case bishop:
          total += 3;
          break;
        case rook:
          total += 5;
          break;
        case queen:
          total += 9;
          break;
      }
    }
    return total;
  }
}
