import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class ReversiGame extends TurnGame {
  static const int size = 8;
  static const int cells = size * size;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_ReversiSnapshot> _history = [];
  int _side = 0; // 0 black, 1 white
  int? _winner;
  int _lastMove = -1;
  int _moveCount = 0;

  ReversiGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    board[3 * size + 3] = 1;
    board[4 * size + 4] = 1;
    board[3 * size + 4] = 2;
    board[4 * size + 3] = 2;
    _side = 0;
    _winner = null;
    _lastMove = -1;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.reversi;

  @override
  int get side => _side;

  @override
  bool get isOver => _winner != null;

  @override
  int? get winner => _winner;

  @override
  int get moveCount => _moveCount;

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  String sideName(int side) => side == 0 ? '黑方' : '白方';

  int _discCount(int side) {
    var count = 0;
    for (final value in board) {
      if (value == side + 1) count++;
    }
    return count;
  }

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    final moves = _legalMovesOn(board, _side);
    if (moves.isEmpty) return '${sideName(_side)}无子可下';
    return '${sideName(_side)}落子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    if (_winner == 2) return '和棋';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '黑 ${_discCount(0)} · 白 ${_discCount(1)}';
  }

  @override
  String scoreText(int side) => '${_discCount(side)} 子';

  List<int> _flipsOn(List<int> source, int index, int side) {
    if (index < 0 || index >= cells || source[index] != 0) return const [];
    final player = side + 1;
    final opponent = 3 - player;
    final flips = <int>[];
    final x = index % size;
    final y = index ~/ size;
    for (final d in const [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1], [0, 1],
      [1, -1], [1, 0], [1, 1],
    ]) {
      final line = <int>[];
      var nx = x + d[0];
      var ny = y + d[1];
      while (nx >= 0 && nx < size && ny >= 0 && ny < size) {
        final at = ny * size + nx;
        final value = source[at];
        if (value == opponent) {
          line.add(at);
        } else if (value == player) {
          if (line.isNotEmpty) flips.addAll(line);
          break;
        } else {
          break;
        }
        nx += d[0];
        ny += d[1];
      }
    }
    return flips;
  }

  List<int> _legalMovesOn(List<int> source, int side) {
    final moves = <int>[];
    for (var i = 0; i < cells; i++) {
      if (source[i] == 0 && _flipsOn(source, i, side).isNotEmpty) {
        moves.add(i);
      }
    }
    return moves;
  }

  List<int> _applyOn(List<int> source, int index, int side) {
    final next = List<int>.of(source);
    final flips = _flipsOn(source, index, side);
    next[index] = side + 1;
    for (final flip in flips) {
      next[flip] = side + 1;
    }
    return next;
  }

  @override
  bool isLegal(Object? move) {
    if (move is! int || move < 0 || move >= cells || isOver) return false;
    return _flipsOn(board, move, _side).isNotEmpty;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    _history.add(_snapshot());
    final index = move as int;
    final flips = _flipsOn(board, index, _side);
    board[index] = _side + 1;
    for (final flip in flips) {
      board[flip] = _side + 1;
    }
    _lastMove = index;
    _moveCount++;
    _side = 1 - _side;

    final nextMoves = _legalMovesOn(board, _side);
    if (nextMoves.isEmpty) {
      final previousMoves = _legalMovesOn(board, 1 - _side);
      if (previousMoves.isNotEmpty) {
        // The next side cannot move, so it passes back to the previous side.
        _side = 1 - _side;
        return;
      }
      _finish();
    }
  }

  void _finish() {
    final black = _discCount(0);
    final white = _discCount(1);
    if (black == white) {
      _winner = 2;
    } else {
      _winner = black > white ? 0 : 1;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    for (var i = 0; i < cells; i++) {
      board[i] = snapshot.board[i];
    }
    _side = snapshot.side;
    _winner = snapshot.winner;
    _lastMove = snapshot.lastMove;
    _moveCount = snapshot.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _legalMovesOn(board, _side);
    if (moves.isEmpty) return null;
    final depth = switch (level) {
      0 => 1,
      1 => 2,
      2 => 3,
      _ => 4,
    };
    final random = Random();
    var bestMove = moves.first;
    var bestScore = -1 << 30;
    final scored = <(int, int)>[];
    for (final move in moves) {
      final next = _applyOn(board, move, _side);
      final score = -_search(next, 1 - _side, depth - 1, -(1 << 30), 1 << 30);
      scored.add((move, score));
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    if (level == 0) {
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final pool = scored.take(min(4, scored.length)).toList();
      return pool[random.nextInt(pool.length)].$1;
    }
    return bestMove;
  }

  int _search(List<int> source, int side, int depth, int alpha, int beta) {
    final moves = _legalMovesOn(source, side);
    if (moves.isEmpty) {
      final otherMoves = _legalMovesOn(source, 1 - side);
      if (otherMoves.isEmpty) return _evaluate(source, side);
      return -_search(source, 1 - side, max(0, depth - 1), -beta, -alpha);
    }
    if (depth <= 0) return _evaluate(source, side);
    for (final move in moves) {
      final next = _applyOn(source, move, side);
      final score = -_search(next, 1 - side, depth - 1, -beta, -alpha);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int _evaluate(List<int> source, int side) {
    const weights = [
      120, -20, 20, 5, 5, 20, -20, 120,
      -20, -40, -5, -5, -5, -5, -40, -20,
      20, -5, 15, 3, 3, 15, -5, 20,
      5, -5, 3, 3, 3, 3, -5, 5,
      5, -5, 3, 3, 3, 3, -5, 5,
      20, -5, 15, 3, 3, 15, -5, 20,
      -20, -40, -5, -5, -5, -5, -40, -20,
      120, -20, 20, 5, 5, 20, -20, 120,
    ];
    var score = 0;
    for (var i = 0; i < cells; i++) {
      final value = source[i];
      if (value == 0) continue;
      final sign = value == side + 1 ? 1 : -1;
      score += sign * weights[i];
    }
    final myMoves = _legalMovesOn(source, side).length;
    final otherMoves = _legalMovesOn(source, 1 - side).length;
    score += (myMoves - otherMoves) * 8;
    return score;
  }

  _ReversiSnapshot _snapshot() => _ReversiSnapshot(
        List<int>.of(board),
        _side,
        _winner,
        _lastMove,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'winner': _winner,
        'last': _lastMove,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastMove = (json['last'] as num?)?.toInt() ?? -1;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves =>
      _legalMovesOn(board, _side).map<Object?>((move) => move).toList();

  @override
  String get llmState {
    final sb = StringBuffer(
      '8x8 黑白棋（奥赛罗），X=黑方，O=白方，.=空。'
      '坐标 (x,y)，x=0 最左列，y=0 最上面一行。\\n',
    );
    for (var y = 0; y < size; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < size; x++) {
        final value = board[y * size + x];
        sb.write(value == 0 ? '.' : (value == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}；黑 ${_discCount(0)} 子，白 ${_discCount(1)} 子。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    return '(${move % size},${move ~/ size})';
  }

  @override
  Widget sideBadge(int side, double size) =>
      GameStone(white: side == 1, size: size);

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return ReversiBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _ReversiSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int lastMove;
  final int moveCount;

  _ReversiSnapshot(this.board, this.side, this.winner, this.lastMove, this.moveCount);
}

class ReversiBoard extends StatelessWidget {
  final ReversiGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const ReversiBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 8;
        final disc = cell * 0.8;
        final legal = game._legalMovesOn(game.board, game.side);
        final pieces = <Widget>[];
        for (var i = 0; i < 64; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final row = i ~/ 8;
          final col = i % 8;
          final vx = flipped ? 7 - col : col;
          final vy = flipped ? 7 - row : row;
          pieces.add(Positioned(
            left: vx * cell + (cell - disc) / 2,
            top: vy * cell + (cell - disc) / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(
              child: GameStone(white: value == 2, size: disc),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 7);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 7);
                    final col = flipped ? 7 - vx : vx;
                    final row = flipped ? 7 - vy : vy;
                    final index = row * 8 + col;
                    if (legal.contains(index)) onMove(index);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ReversiPainter(
                      game: game,
                      cell: cell,
                      flipped: flipped,
                      legal: interactive ? legal : const [],
                    ),
                  ),
                ),
                ...pieces,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReversiPainter extends CustomPainter {
  final ReversiGame game;
  final double cell;
  final bool flipped;
  final List<int> legal;

  _ReversiPainter({
    required this.game,
    required this.cell,
    required this.flipped,
    required this.legal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final vx = flipped ? 7 - col : col;
        final vy = flipped ? 7 - row : row;
        final rect = Rect.fromLTWH(vx * cell, vy * cell, cell, cell);
        canvas.drawRect(
          rect,
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFF5E8F72)
                : const Color(0xFF3D6B54),
        );
      }
    }
    for (final index in legal) {
      final row = index ~/ 8;
      final col = index % 8;
      final vx = flipped ? 7 - col : col;
      final vy = flipped ? 7 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.12,
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
    }
    if (game._lastMove >= 0) {
      final row = game._lastMove ~/ 8;
      final col = game._lastMove % 8;
      final vx = flipped ? 7 - col : col;
      final vy = flipped ? 7 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.44,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReversiPainter oldDelegate) => true;
}
