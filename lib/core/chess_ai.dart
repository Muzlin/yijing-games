// Alpha-beta chess engine with quiescence search, transposition table and
// piece-square evaluation. Runs in a background isolate via [aiCompute].
import 'dart:math';
import 'dart:typed_data';

import 'chess.dart';

const int _infinity = 1 << 20;
const int _mateScore = 30000;
const int _mateThreshold = 28000;

const List<int> _pieceValue = [0, 100, 320, 330, 500, 900, 20000];

// Piece-square tables written from White's point of view, rank 8 first.
const List<int> _pawnPst = [
  0, 0, 0, 0, 0, 0, 0, 0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];

const List<int> _knightPst = [
  -50, -40, -30, -30, -30, -30, -40, -50,
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];

const List<int> _bishopPst = [
  -20, -10, -10, -10, -10, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];

const List<int> _rookPst = [
  0, 0, 0, 0, 0, 0, 0, 0,
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];

const List<int> _queenPst = [
  -20, -10, -10, -5, -5, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];

const List<int> _kingPst = [
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];

const List<int> _kingEndPst = [
  -50, -40, -30, -20, -20, -30, -40, -50,
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];

const List<int> _passedPawnBonus = [0, 5, 10, 20, 35, 60, 100, 0];

class AiConfig {
  final int maxDepth;
  final int timeMs;
  final int marginCp;
  final bool exactRoot;

  const AiConfig({
    required this.maxDepth,
    required this.timeMs,
    this.marginCp = 0,
    this.exactRoot = false,
  });
}

const List<AiConfig> aiLevels = [
  AiConfig(maxDepth: 2, timeMs: 400, marginCp: 110, exactRoot: true),
  AiConfig(maxDepth: 4, timeMs: 900, marginCp: 40),
  AiConfig(maxDepth: 6, timeMs: 1800, marginCp: 10),
  AiConfig(maxDepth: 8, timeMs: 3200, marginCp: 0),
];

class AiResult {
  final int move;
  final int score;
  final int depth;
  final int nodes;

  const AiResult(this.move, this.score, this.depth, this.nodes);
}

/// Entry point used with Flutter's `compute`.
///
/// Request keys: `fen`, `level`, `seed`. Result keys: `move`, `score`,
/// `depth`, `nodes`.
Map<String, Object?>? aiCompute(Map<String, Object?> request) {
  final fen = request['fen'] as String?;
  if (fen == null) return null;
  final level = (request['level'] as int?) ?? 1;
  final seed = (request['seed'] as int?) ?? 1;
  final levelIndex = level < 0
      ? 0
      : (level >= aiLevels.length ? aiLevels.length - 1 : level);
  final config = aiLevels[levelIndex];
  final position = Position.fromFen(fen);
  final engine = _Engine(position, config, seed);
  final result = engine.search();
  if (result == null) return null;
  return {
    'move': result.move,
    'score': result.score,
    'depth': result.depth,
    'nodes': result.nodes,
  };
}

class _RootMove {
  final int move;
  final int score;

  const _RootMove(this.move, this.score);
}

class _Engine {
  final Position position;
  final AiConfig config;
  final Random random;
  final Stopwatch watch = Stopwatch()..start();
  final List<int> _pathHashes = [];
  final List<List<int>> _killers = List.generate(128, (_) => [0, 0]);
  final List<List<int>> _history = List.generate(2, (_) => List.filled(64, 0));

  final int _ttSize = 1 << 18;
  late final Int32List _ttKeys = Int32List(_ttSize);
  late final Int32List _ttMoves = Int32List(_ttSize);
  late final Int16List _ttScores = Int16List(_ttSize);
  late final Int8List _ttDepths = Int8List(_ttSize)..fillRange(0, _ttSize, -1);
  late final Int8List _ttFlags = Int8List(_ttSize);

  int nodes = 0;
  bool stopped = false;
  int depthReached = 0;

  _Engine(this.position, this.config, int seed) : random = Random(seed);

  bool get _timeUp =>
      watch.elapsedMilliseconds >= config.timeMs;

  AiResult? search() {
    _pathHashes.add(position.hash);
    final moves = position.legalMoves();
    if (moves.isEmpty) return null;

    if (config.exactRoot) {
      final scored = _searchRootExact(moves);
      if (scored.isEmpty) return null;
      return _pickResult(scored);
    }

    var best = <_RootMove>[];
    for (var depth = 1; depth <= config.maxDepth; depth++) {
      final iteration = <_RootMove>[];
      final ordered = best.isEmpty
          ? moves
          : best.map((r) => r.move).toList(growable: true);

      var alpha = -_infinity;
      const beta = _infinity;
      for (final move in ordered) {
        position.makeMove(move);
        _pathHashes.add(position.hash);
        final score = -_negamax(depth - 1, -beta, -alpha, 1);
        position.unmakeMove();
        _pathHashes.removeLast();
        if (stopped) break;
        iteration.add(_RootMove(move, score));
        if (score > alpha) alpha = score;
      }

      if (stopped) break;
      // A completed iteration gives trustworthy ordering.
      iteration.sort((a, b) => b.score.compareTo(a.score));
      best = iteration;
      depthReached = depth;
      if (best.first.score.abs() > _mateThreshold) break;
      if (_timeUp) break;
    }

    if (best.isEmpty) {
      // Extremely short time limit: fall back to the first legal move.
      return AiResult(moves.first, 0, 1, nodes);
    }
    return _pickResult(best);
  }

  AiResult _pickResult(List<_RootMove> scored) {
    final sorted = List<_RootMove>.of(scored)
      ..sort((a, b) => b.score.compareTo(a.score));
    var chosen = sorted.first;
    if (config.marginCp > 0 && sorted.first.score.abs() < _mateThreshold) {
      final floor = sorted.first.score - config.marginCp;
      final candidates =
          sorted.where((r) => r.score >= floor).toList(growable: false);
      if (candidates.length > 1) {
        // Bias towards stronger moves while keeping a little unpredictability.
        final index = random.nextInt(candidates.length);
        chosen = candidates[index];
      }
    }
    return AiResult(chosen.move, chosen.score, depthReached, nodes);
  }

  List<_RootMove> _searchRootExact(List<int> moves) {
    final result = <_RootMove>[];
    for (final move in moves) {
      if (_timeUp && result.isNotEmpty) break;
      position.makeMove(move);
      _pathHashes.add(position.hash);
      final score = -_negamax(config.maxDepth - 1, -_infinity, _infinity, 1);
      position.unmakeMove();
      _pathHashes.removeLast();
      result.add(_RootMove(move, score));
    }
    depthReached = config.maxDepth;
    return result;
  }

  int _negamax(int depth, int alpha, int beta, int ply) {
    nodes++;
    if ((nodes & 1023) == 0 && _timeUp) {
      stopped = true;
      return 0;
    }
    if (position.halfmoveClock >= 100) return 0;
    if (_isRepetition()) return 0;

    if (ply > 0 && depth <= 0) {
      return _quiescence(alpha, beta, ply);
    }

    final inCheck = position.isInCheck();
    if (inCheck && ply < 40) depth++;

    final key = position.hash;
    final ttIndex = key & (_ttSize - 1);
    var ttMove = 0;
    if (_ttKeys[ttIndex] == key && _ttDepths[ttIndex] >= depth) {
      final entryScore = _fromTTScore(_ttScores[ttIndex], ply);
      final flag = _ttFlags[ttIndex];
      ttMove = _ttMoves[ttIndex];
      if (flag == 1) return entryScore;
      if (flag == 2 && entryScore >= beta) return beta;
      if (flag == 3 && entryScore <= alpha) return alpha;
    } else if (_ttKeys[ttIndex] == key) {
      ttMove = _ttMoves[ttIndex];
    }

    final moves = position.legalMoves();
    if (moves.isEmpty) {
      return inCheck ? -_mateScore + ply : 0;
    }

    final scores = _scoreMoves(moves, ttMove, ply);
    _sortMoves(moves, scores);

    final originalAlpha = alpha;
    var bestMove = moves.first;

    for (var i = 0; i < moves.length; i++) {
      final move = moves[i];
      position.makeMove(move);
      _pathHashes.add(position.hash);

      int score;
      if (i == 0) {
        score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      } else {
        // Principal variation search with a tiny full-window fallback.
        score = -_negamax(depth - 1, -alpha - 1, -alpha, ply + 1);
        if (score > alpha && score < beta) {
          score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
        }
      }

      position.unmakeMove();
      _pathHashes.removeLast();

      if (stopped) return 0;

      if (score > alpha) {
        alpha = score;
        bestMove = move;
        if (score >= beta) {
          if (!moveIsCapture(move)) {
            final k = ply.clamp(0, 127);
            _killers[k][1] = _killers[k][0];
            _killers[k][0] = move;
            _history[position.side][moveFrom(move)] += depth * depth;
          }
          _storeTT(ttIndex, key, depth, score, 2, move, ply);
          return beta;
        }
      }
    }

    _storeTT(
      ttIndex,
      key,
      depth,
      alpha,
      alpha > originalAlpha ? 1 : 3,
      bestMove,
      ply,
    );
    return alpha;
  }

  int _quiescence(int alpha, int beta, int ply, [int qdepth = 0]) {
    nodes++;
    if ((nodes & 1023) == 0 && _timeUp) {
      stopped = true;
      return 0;
    }

    if (qdepth > 10) return evaluate(position);
    final inCheck = position.isInCheck();
    var best = -_infinity;
    if (!inCheck) {
      best = evaluate(position);
      if (best >= beta) return beta;
      if (best > alpha) alpha = best;
    }

    final moves = position.legalMoves();
    if (moves.isEmpty) {
      return inCheck ? -_mateScore + ply : 0;
    }
    if (inCheck && ply < 40) {
      // Full evasion search when in check.
    }

    final tactical = moves
        .where((m) => inCheck || moveIsCapture(m) || movePromotion(m) != 0)
        .toList(growable: false);
    if (tactical.isEmpty) return best == -_infinity ? alpha : best;

    final scores = _scoreMoves(tactical, 0, ply);
    _sortMoves(tactical, scores);

    var raised = false;
    for (final move in tactical) {
      position.makeMove(move);
      final score = -_quiescence(-beta, -alpha, ply + 1, qdepth + 1);
      position.unmakeMove();
      if (stopped) return 0;
      if (score > best) best = score;
      if (score > alpha) {
        alpha = score;
        raised = true;
      }
      if (alpha >= beta) break;
    }
    if (best == -_infinity) return raised ? alpha : 0;
    return best;
  }

  bool _isRepetition() {
    final hash = position.hash;
    final start = max(0, _pathHashes.length - 16);
    for (var i = _pathHashes.length - 2; i >= start; i -= 2) {
      if (_pathHashes[i] == hash) return true;
    }
    return false;
  }

  List<int> _scoreMoves(List<int> moves, int ttMove, int ply) {
    final scores = List<int>.filled(moves.length, 0);
    for (var i = 0; i < moves.length; i++) {
      final move = moves[i];
      if (move == ttMove) {
        scores[i] = 1000000;
        continue;
      }
      final promo = movePromotion(move);
      if (moveIsCapture(move)) {
        final from = moveFrom(move);
        final to = moveTo(move);
        final attacker = position.board[from];
        final victim = moveIsEnPassant(move)
            ? makePiece(1 - colorOf(attacker), pawn)
            : position.board[to];
        scores[i] = 100000 +
            _pieceValue[typeOf(victim)] * 10 -
            _pieceValue[typeOf(attacker)] +
            (promo != 0 ? _pieceValue[promo] : 0);
      } else if (promo != 0) {
        scores[i] = 90000 + _pieceValue[promo];
      } else if (move == _killers[ply.clamp(0, 127)][0]) {
        scores[i] = 80000;
      } else if (move == _killers[ply.clamp(0, 127)][1]) {
        scores[i] = 79000;
      } else {
        scores[i] = _history[position.side][moveFrom(move)];
      }
    }
    return scores;
  }

  void _sortMoves(List<int> moves, List<int> scores) {
    // Insertion sort: move lists are small and almost sorted after the first
    // few iterations.
    for (var i = 1; i < moves.length; i++) {
      final move = moves[i];
      final score = scores[i];
      var j = i - 1;
      while (j >= 0 && scores[j] < score) {
        moves[j + 1] = moves[j];
        scores[j + 1] = scores[j];
        j--;
      }
      moves[j + 1] = move;
      scores[j + 1] = score;
    }
  }

  int _toTTScore(int score, int ply) {
    if (score > _mateThreshold) return score + ply;
    if (score < -_mateThreshold) return score - ply;
    return score;
  }

  int _fromTTScore(int score, int ply) {
    if (score > _mateThreshold) return score - ply;
    if (score < -_mateThreshold) return score + ply;
    return score;
  }

  void _storeTT(int index, int key, int depth, int score, int flag, int move,
      int ply) {
    if (_ttDepths[index] > depth) return;
    _ttKeys[index] = key;
    _ttDepths[index] = depth;
    _ttScores[index] = _toTTScore(score, ply);
    _ttFlags[index] = flag;
    _ttMoves[index] = move;
  }
}

int evaluate(Position position) {
  var score = 0;
  var phase = 0;

  final pawnFiles = [
    List<int>.filled(8, 0),
    List<int>.filled(8, 0),
  ];
  final pawnSquares = [<int>[], <int>[]];
  final bishopCount = [0, 0];
  final kingSq = [position.kingSquare[0], position.kingSquare[1]];

  for (var sq = 0; sq < 64; sq++) {
    final piece = position.board[sq];
    if (piece == 0) continue;
    final color = colorOf(piece);
    final type = typeOf(piece);
    final pstIndex = color == white ? sq ^ 56 : sq;
    final sign = color == white ? 1 : -1;
    final file = sq & 7;

    score += sign * _pieceValue[type];

    switch (type) {
      case pawn:
        score += sign * _pawnPst[pstIndex];
        pawnFiles[color][file]++;
        pawnSquares[color].add(sq);
        break;
      case knight:
        score += sign * _knightPst[pstIndex];
        phase += 1;
        break;
      case bishop:
        score += sign * _bishopPst[pstIndex];
        bishopCount[color]++;
        phase += 1;
        break;
      case rook:
        score += sign * _rookPst[pstIndex];
        phase += 2;
        // Rooks like open files.
        final ownPawns = pawnFiles[color][file];
        final enemyPawns = pawnFiles[1 - color][file];
        if (ownPawns == 0) score += sign * (enemyPawns == 0 ? 18 : 9);
        break;
      case queen:
        score += sign * _queenPst[pstIndex];
        phase += 4;
        break;
      case king:
        score += sign * _kingPst[pstIndex];
        break;
    }
  }

  if (bishopCount[0] >= 2) score += 35;
  if (bishopCount[1] >= 2) score -= 35;

  // Pawn structure
  for (var color = 0; color < 2; color++) {
    final sign = color == white ? 1 : -1;
    final files = pawnFiles[color];

    for (var file = 0; file < 8; file++) {
      final count = files[file];
      if (count > 1) score -= sign * 12 * (count - 1);
      if (count > 0) {
        final left = file > 0 ? files[file - 1] : 0;
        final right = file < 7 ? files[file + 1] : 0;
        if (left == 0 && right == 0) score -= sign * 14;
      }
    }

    for (final sq in pawnSquares[color]) {
      final file = sq & 7;
      final rank = sq >> 3;
      final relativeRank = color == white ? rank : 7 - rank;
      var passed = true;
      for (var df = -1; df <= 1; df++) {
        final f = file + df;
        if (f < 0 || f > 7) continue;
        final enemyList = pawnSquares[1 - color];
        for (final enemy in enemyList) {
          if ((enemy & 7) != f) continue;
          final enemyRank = enemy >> 3;
          if (color == white
              ? enemyRank > rank
              : enemyRank < rank) {
            passed = false;
            break;
          }
        }
        if (!passed) break;
      }
      if (passed && relativeRank < 7) {
        score += sign * _passedPawnBonus[relativeRank];
      }
    }
  }

  // King safety: blend in centralisation during the endgame.
  final endgameWeight = (24 - phase).clamp(0, 24) / 24.0;
  if (endgameWeight > 0) {
    for (var color = 0; color < 2; color++) {
      final sq = kingSq[color];
      final pstIndex = color == white ? sq ^ 56 : sq;
      final delta = (_kingEndPst[pstIndex] - _kingPst[pstIndex]) *
          endgameWeight *
          (color == white ? 1 : -1);
      score += delta.round();
    }
  }

  return position.side == white ? score : -score;
}
