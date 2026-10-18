import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class TicTacToeGame extends TurnGame {
  static const int size = 3;
  static const int cells = 9;
  static const List<List<int>> lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  final List<int> board = List<int>.filled(cells, 0);
  final List<_TicSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  List<int> _winLine = const [];
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.ticTacToe;

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
  String sideName(int side) => side == 0 ? 'X 方' : 'O 方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
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
    return _winner == 2 ? '九格已满' : '三子成线';
  }

  @override
  String scoreText(int side) => side == 0 ? 'X' : 'O';

  @override
  bool isLegal(Object? move) =>
      !isOver && move is int && move >= 0 && move < cells && board[move] == 0;

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final index = move as int;
    _history.add(_snapshot());
    board[index] = _side + 1;
    _last = index;
    _moveCount++;
    final line = _lineAt(index);
    if (line != null) {
      _winLine = line;
      _winner = _side;
      return;
    }
    if (_moveCount == cells) {
      _winner = 2;
      return;
    }
    _side = 1 - _side;
  }

  List<int>? _lineAt(int index) {
    for (final line in lines) {
      if (!line.contains(index)) continue;
      final value = board[line[0]];
      if (value != 0 && board[line[1]] == value && board[line[2]] == value) {
        return line;
      }
    }
    return null;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < cells; i++) {
      board[i] = s.board[i];
    }
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _winLine = s.winLine;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final empty = [for (var i = 0; i < cells; i++) if (board[i] == 0) i];
    if (empty.isEmpty) return null;
    if (level <= 0) return empty[Random().nextInt(empty.length)];
    // Perfect play for 3x3.
    var bestScore = -100;
    var best = empty.first;
    for (final move in empty) {
      board[move] = _side + 1;
      final score = -_minimax(1 - _side, 1);
      board[move] = 0;
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best;
  }

  int _minimax(int side, int depth) {
    final line = _winnerLine();
    if (line != null) {
      return board[line[0]] == _side + 1 ? 10 - depth : depth - 10;
    }
    if (!board.contains(0)) return 0;
    var best = side == _side ? -100 : 100;
    for (var i = 0; i < cells; i++) {
      if (board[i] != 0) continue;
      board[i] = side + 1;
      final score = _minimax(1 - side, depth + 1);
      board[i] = 0;
      best = side == _side ? max(best, score) : min(best, score);
    }
    return best;
  }

  List<int>? _winnerLine() {
    for (final line in lines) {
      final v = board[line[0]];
      if (v != 0 && board[line[1]] == v && board[line[2]] == v) return line;
    }
    return null;
  }

  _TicSnapshot _snapshot() => _TicSnapshot(
        List<int>.of(board),
        _side,
        _winner,
        _last,
        List<int>.of(_winLine),
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'line': List<int>.of(_winLine),
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
    _last = (json['last'] as num?)?.toInt();
    _winLine = (json['line'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? const [];
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves =>
      [for (var i = 0; i < cells; i++) if (board[i] == 0) i];

  @override
  String get llmState {
    final sb = StringBuffer('3x3 井字棋，X 先手，O 后手；横竖斜三连者胜，九格填满和棋。\n');
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final v = board[r * 3 + c];
        sb.write(v == 0 ? '.' : (v == 1 ? 'X' : 'O'));
        if (c < 2) sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    return '(${move % 3},${move ~/ 3})';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? 'X' : 'O',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        filled: true,
        size: size,
        fontSize: size * 0.45,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return TicTacToeBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _TicSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final List<int> winLine;
  final int moveCount;

  _TicSnapshot(this.board, this.side, this.winner, this.last, this.winLine,
      this.moveCount);
}

class TicTacToeBoard extends StatelessWidget {
  final TicTacToeGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const TicTacToeBoard({
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
        final cell = size / 3;
        final marks = <Widget>[];
        for (var i = 0; i < 9; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final row = i ~/ 3;
          final col = i % 3;
          final vx = flipped ? 2 - col : col;
          final vy = flipped ? 2 - row : row;
          marks.add(Positioned(
            left: vx * cell,
            top: vy * cell,
            width: cell,
            height: cell,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  value == 1 ? 'X' : 'O',
                  style: TextStyle(
                    fontSize: cell * 0.62,
                    fontWeight: FontWeight.w900,
                    color: value == 1
                        ? const Color(0xFFD95B4E)
                        : const Color(0xFF6C9BD8),
                    shadows: [
                      Shadow(
                        color: (value == 1
                                ? const Color(0xFFD95B4E)
                                : const Color(0xFF6C9BD8))
                            .withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 2);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 2);
                    final x = flipped ? 2 - vx : vx;
                    final y = flipped ? 2 - vy : vy;
                    onMove(y * 3 + x);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TicPainter(game: game, cell: cell, flipped: flipped),
                  ),
                ),
                ...marks,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicPainter extends CustomPainter {
  final TicTacToeGame game;
  final double cell;
  final bool flipped;

  _TicPainter({required this.game, required this.cell, required this.flipped});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF203A33), Color(0xFF0E1D19)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final grid = Paint()
      ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.30)
      ..strokeWidth = 2;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
    }
    for (var i = 0; i < 9; i++) {
      if (game.board[i] == 0) continue;
      final row = i ~/ 3;
      final col = i % 3;
      final vx = flipped ? 2 - col : col;
      final vy = flipped ? 2 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.33,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.12),
      );
    }
    if (game._winLine.isNotEmpty) {
      final first = game._winLine.first;
      final last = game._winLine.last;
      final a = Offset((first % 3 + 0.5) * cell, (first ~/ 3 + 0.5) * cell);
      final b = Offset((last % 3 + 0.5) * cell, (last ~/ 3 + 0.5) * cell);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.75)
          ..strokeWidth = cell * 0.07
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicPainter oldDelegate) => true;
}
