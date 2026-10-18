import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class ConnectFourGame extends TurnGame {
  static const int cols = 7;
  static const int rows = 6;
  static const int cells = cols * rows;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_ConnectSnapshot> _history = [];
  int _side = 0; // 0 red, 1 yellow
  int? _winner;
  int? _lastColumn;
  int _lastMove = -1;
  int _moveCount = 0;
  List<int> _winLine = const [];

  @override
  GameMeta get meta => GameCatalog.connect4;

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
  String sideName(int side) => side == 0 ? '红方' : '黄方';

  int _count(int side) {
    var count = 0;
    for (final value in board) {
      if (value == side + 1) count++;
    }
    return count;
  }

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
    if (_winner == 2) return '棋盘已满';
    return '四子连线';
  }

  @override
  String scoreText(int side) => '${_count(side)} 子';

  @override
  bool isLegal(Object? move) {
    if (move is! int || move < 0 || move >= cols || isOver) return false;
    return board[move] == 0;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final column = move as int;
    _history.add(_snapshot());
    final row = _dropRow(board, column);
    board[row * cols + column] = _side + 1;
    _lastColumn = column;
    _lastMove = row * cols + column;
    _moveCount++;
    final line = _findLine(row * cols + column, _side + 1);
    if (line != null) {
      _winLine = line;
      _winner = _side;
      return;
    }
    if (_moveCount >= cells) {
      _winner = 2;
      return;
    }
    _side = 1 - _side;
  }

  int _dropRow(List<int> source, int column) {
    for (var row = rows - 1; row >= 0; row--) {
      if (source[row * cols + column] == 0) return row;
    }
    return -1;
  }

  List<int>? _findLine(int index, int player) {
    final x = index % cols;
    final y = index ~/ cols;
    for (final d in const [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      final line = <int>[index];
      for (final sign in const [-1, 1]) {
        var nx = x + d[0] * sign;
        var ny = y + d[1] * sign;
        while (nx >= 0 && nx < cols && ny >= 0 && ny < rows &&
            board[ny * cols + nx] == player) {
          line.add(ny * cols + nx);
          nx += d[0] * sign;
          ny += d[1] * sign;
        }
      }
      if (line.length >= 4) {
        line.sort();
        return line;
      }
    }
    return null;
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
    _lastColumn = snapshot.lastColumn;
    _lastMove = snapshot.lastMove;
    _moveCount = snapshot.moveCount;
    _winLine = snapshot.winLine;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final depth = switch (level) {
      0 => 2,
      1 => 4,
      2 => 6,
      _ => 7,
    };
    final moves = _legalColumns(board);
    if (moves.isEmpty) return null;
    final random = Random();
    var bestColumn = moves.first;
    var bestScore = -1 << 30;
    final scored = <(int, int)>[];
    for (final column in moves) {
      final next = List<int>.of(board);
      final row = _dropRow(next, column);
      next[row * cols + column] = _side + 1;
      final score = -_search(next, 1 - _side, depth - 1, -(1 << 30), 1 << 30);
      scored.add((column, score));
      if (score > bestScore) {
        bestScore = score;
        bestColumn = column;
      }
    }
    if (level == 0) {
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final pool = scored.take(min(3, scored.length)).toList();
      return pool[random.nextInt(pool.length)].$1;
    }
    return bestColumn;
  }

  int _search(List<int> source, int side, int depth, int alpha, int beta) {
    if (depth <= 0) return _evaluate(source, side);
    final moves = _legalColumns(source);
    if (moves.isEmpty) return 0;
    for (final column in moves) {
      final next = List<int>.of(source);
      final row = _dropRow(next, column);
      next[row * cols + column] = side + 1;
      final line = _lineOn(next, row * cols + column, side + 1);
      if (line != null) return 100000 - (7 - depth);
      final score = -_search(next, 1 - side, depth - 1, -beta, -alpha);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  List<int>? _lineOn(List<int> source, int index, int player) {
    final x = index % cols;
    final y = index ~/ cols;
    for (final d in const [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      var count = 1;
      for (final sign in const [-1, 1]) {
        var nx = x + d[0] * sign;
        var ny = y + d[1] * sign;
        while (nx >= 0 && nx < cols && ny >= 0 && ny < rows &&
            source[ny * cols + nx] == player) {
          count++;
          nx += d[0] * sign;
          ny += d[1] * sign;
        }
      }
      if (count >= 4) return const [0];
    }
    return null;
  }

  List<int> _legalColumns(List<int> source) => [
        for (var column = 0; column < cols; column++)
          if (source[column] == 0) column,
      ];

  int _evaluate(List<int> source, int side) {
    var score = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if (col + 3 < cols) {
          score += _windowScore(source, row, col, 1, 0, side);
        }
        if (row + 3 < rows) {
          score += _windowScore(source, row, col, 0, 1, side);
        }
        if (row + 3 < rows && col + 3 < cols) {
          score += _windowScore(source, row, col, 1, 1, side);
        }
        if (row - 3 >= 0 && col + 3 < cols) {
          score += _windowScore(source, row, col, 1, -1, side);
        }
      }
    }
    for (var row = 0; row < rows; row++) {
      if (source[row * cols + 3] == side + 1) score += 6;
    }
    return score;
  }

  int _windowScore(List<int> source, int row, int col, int dx, int dy, int side) {
    var mine = 0;
    var theirs = 0;
    for (var i = 0; i < 4; i++) {
      final value = source[(row + dy * i) * cols + col + dx * i];
      if (value == side + 1) mine++;
      if (value == 2 - side) theirs++;
    }
    if (mine > 0 && theirs > 0) return 0;
    if (mine == 4) return 100000;
    if (mine == 3) return 100;
    if (mine == 2) return 10;
    if (mine == 1) return 1;
    if (theirs == 4) return -100000;
    if (theirs == 3) return -100;
    if (theirs == 2) return -10;
    if (theirs == 1) return -1;
    return 0;
  }

  _ConnectSnapshot _snapshot() => _ConnectSnapshot(
        List<int>.of(board),
        _side,
        _winner,
        _lastColumn,
        _lastMove,
        _moveCount,
        List<int>.of(_winLine),
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'winner': _winner,
        'lastColumn': _lastColumn,
        'last': _lastMove,
        'moveCount': _moveCount,
        'line': List<int>.of(_winLine),
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastColumn = (json['lastColumn'] as num?)?.toInt();
    _lastMove = (json['last'] as num?)?.toInt() ?? -1;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _winLine = (json['line'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? const [];
    _history.clear();
  }

  @override
  List<Object?> get llmMoves =>
      _legalColumns(board).map<Object?>((move) => move).toList();

  @override
  String get llmState {
    final sb = StringBuffer(
      '7x6 四子棋，R=红方，Y=黄方，.=空，红方先手；棋子会落到该列最下面的空位。'
      '坐标 x=0 最左列，y=0 最上面一行。\\n',
    );
    for (var y = 0; y < rows; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < cols; x++) {
        final value = board[y * cols + x];
        sb.write(value == 0 ? '.' : (value == 1 ? 'R' : 'Y'));
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    return '第 ${move + 1} 列';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: '',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFFE9C45C),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFFE9C45C),
        filled: true,
        size: size,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return ConnectFourBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
    );
  }
}

class _ConnectSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? lastColumn;
  final int lastMove;
  final int moveCount;
  final List<int> winLine;

  _ConnectSnapshot(this.board, this.side, this.winner, this.lastColumn,
      this.lastMove, this.moveCount, this.winLine);
}

class ConnectFourBoard extends StatelessWidget {
  final ConnectFourGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;

  const ConnectFourBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * 6 / 7;
        final cellW = width / 7;
        final cellH = height / 6;
        final disc = min(cellW, cellH) * 0.78;
        final pieces = <Widget>[];
        for (var i = 0; i < 42; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final row = i ~/ 7;
          final col = i % 7;
          pieces.add(Positioned(
            left: col * cellW + (cellW - disc) / 2,
            top: row * cellH + (cellH - disc) / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(
              child: GameDisc(
                label: '',
                color: value == 1
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFFE9C45C),
                background: value == 1
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFFE9C45C),
                filled: true,
                size: disc,
              ),
            ),
          ));
        }
        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    final col = (details.localPosition.dx / cellW)
                        .floor()
                        .clamp(0, 6);
                    if (game.isLegal(col)) onMove(col);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConnectPainter(
                      game: game,
                      cellW: cellW,
                      cellH: cellH,
                      discFraction: disc / min(cellW, cellH),
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

class _ConnectPainter extends CustomPainter {
  final ConnectFourGame game;
  final double cellW;
  final double cellH;
  final double discFraction;

  _ConnectPainter({
    required this.game,
    required this.cellW,
    required this.cellH,
    required this.discFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF203A5B),
    );
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 7; col++) {
        final center = Offset((col + 0.5) * cellW, (row + 0.5) * cellH);
        canvas.drawCircle(
          center,
          min(cellW, cellH) * discFraction * 0.52,
          Paint()..color = const Color(0xFF142A44),
        );
      }
    }
    if (game._lastMove >= 0) {
      final row = game._lastMove ~/ 7;
      final col = game._lastMove % 7;
      canvas.drawCircle(
        Offset((col + 0.5) * cellW, (row + 0.5) * cellH),
        min(cellW, cellH) * discFraction * 0.55,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
    if (game._winLine.isNotEmpty) {
      final first = game._winLine.first;
      final last = game._winLine.last;
      final start = Offset(
        (first % 7 + 0.5) * cellW,
        (first ~/ 7 + 0.5) * cellH,
      );
      final end = Offset(
        (last % 7 + 0.5) * cellW,
        (last ~/ 7 + 0.5) * cellH,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.6)
          ..strokeWidth = min(cellW, cellH) * 0.16
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectPainter oldDelegate) => true;
}
