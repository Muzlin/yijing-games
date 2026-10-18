import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class ConnectSixGame extends TurnGame {
  static const int size = 19;
  static const int cells = size * size;
  static const int winLength = 6;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_SixSnapshot> _history = [];
  int _side = 0; // 0 black, 1 white
  int _stonesLeft = 1; // black opens with one stone, then two per turn
  int? _winner;
  int? _lastMove;
  List<int> _winLine = const [];

  @override
  GameMeta get meta => GameCatalog.connect6;

  @override
  int get side => _side;

  @override
  bool get isOver => _winner != null;

  @override
  int? get winner => _winner;

  @override
  int get moveCount {
    var count = 0;
    for (final value in board) {
      if (value != 0) count++;
    }
    return count;
  }

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  String sideName(int side) => side == 0 ? '黑方' : '白方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_stonesLeft <= 1) return '${sideName(_side)}落子 · 本回合最后一手';
    return '${sideName(_side)}落子 · 可下 2 手';
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
    return '六子连珠';
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final value in board) {
      if (value == side + 1) count++;
    }
    return '$count 子';
  }

  @override
  bool isLegal(Object? move) {
    if (move is! int || move < 0 || move >= cells || isOver) return false;
    return board[move] == 0;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final index = move as int;
    _history.add(_snapshot());
    board[index] = _side + 1;
    _lastMove = index;
    final line = _findWin(index, _side + 1);
    if (line != null) {
      _winLine = line;
      _winner = _side;
      return;
    }
    if (moveCount >= cells) {
      _winner = 2;
      return;
    }
    _stonesLeft--;
    if (_stonesLeft <= 0) {
      _side = 1 - _side;
      _stonesLeft = 2;
    }
  }

  List<int>? _findWin(int index, int player) {
    final x = index % size;
    final y = index ~/ size;
    for (final d in const [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      final line = <int>[index];
      for (final sign in const [-1, 1]) {
        var nx = x + d[0] * sign;
        var ny = y + d[1] * sign;
        while (nx >= 0 && nx < size && ny >= 0 && ny < size &&
            board[ny * size + nx] == player) {
          line.add(ny * size + nx);
          nx += d[0] * sign;
          ny += d[1] * sign;
        }
      }
      if (line.length >= winLength) {
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
    _stonesLeft = snapshot.stonesLeft;
    _winner = snapshot.winner;
    _lastMove = snapshot.lastMove;
    _winLine = snapshot.winLine;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final me = _side + 1;
    final opponent = 2 - me;
    final candidates = <int>[];
    var hasStone = false;
    for (var i = 0; i < cells; i++) {
      if (board[i] != 0) {
        hasStone = true;
      }
    }
    if (!hasStone) return 9 * size + 9; // center
    for (var i = 0; i < cells; i++) {
      if (board[i] != 0) continue;
      if (_nearStone(i)) candidates.add(i);
    }
    if (candidates.isEmpty) return null;
    final random = Random();
    final scored = <(int, int)>[];
    for (final index in candidates) {
      board[index] = me;
      final own = _scorePoint(index, me);
      board[index] = opponent;
      final block = _scorePoint(index, opponent);
      board[index] = 0;
      final center = 18 - (((index % size) - 9).abs() + ((index ~/ size) - 9).abs());
      var score = own * 1.15 + block * 1.08 + center;
      if (level <= 0) score += random.nextInt(3000);
      scored.add((index, score.round()));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    if (scored.first.$2 >= 100000000) return scored.first.$1;
    if (level >= 2 && scored.length > 1) {
      final shortlist = scored.take(8).toList();
      var best = shortlist.first;
      var bestValue = -1e18;
      for (final candidate in shortlist) {
        board[candidate.$1] = me;
        var worst = 0;
        for (final reply in _nearbyEmpty()) {
          board[reply] = opponent;
          final value = _scorePoint(reply, opponent);
          board[reply] = 0;
          if (value > worst) worst = value;
        }
        board[candidate.$1] = 0;
        final value = candidate.$2 - worst * 0.9;
        if (value > bestValue) {
          bestValue = value;
          best = candidate;
        }
      }
      return best.$1;
    }
    final pool = scored
        .take(level <= 0 ? 4 : 1)
        .toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  bool _nearStone(int index) {
    final x = index % size;
    final y = index ~/ size;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (nx >= 0 && nx < size && ny >= 0 && ny < size &&
            board[ny * size + nx] != 0) {
          return true;
        }
      }
    }
    return false;
  }

  Iterable<int> _nearbyEmpty() sync* {
    for (var i = 0; i < cells; i++) {
      if (board[i] == 0 && _nearStone(i)) yield i;
    }
  }

  int _scorePoint(int index, int player) {
    final x = index % size;
    final y = index ~/ size;
    var total = 0;
    for (final dir in const [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      var count = 1;
      var open = 0;
      for (final sign in const [-1, 1]) {
        var nx = x + dir[0] * sign;
        var ny = y + dir[1] * sign;
        while (nx >= 0 && nx < size && ny >= 0 && ny < size &&
            board[ny * size + nx] == player) {
          count++;
          nx += dir[0] * sign;
          ny += dir[1] * sign;
        }
        if (nx >= 0 && nx < size && ny >= 0 && ny < size &&
            board[ny * size + nx] == 0) {
          open++;
        }
      }
      if (count >= 6) return 100000000;
      if (count == 5) total += open == 2 ? 1200000 : (open == 1 ? 200000 : 0);
      if (count == 4) total += open == 2 ? 30000 : (open == 1 ? 3000 : 0);
      if (count == 3) total += open == 2 ? 1200 : (open == 1 ? 150 : 0);
      if (count == 2) total += open == 2 ? 100 : (open == 1 ? 20 : 0);
      if (count == 1) total += open == 2 ? 8 : 2;

      for (var offset = -5; offset <= 0; offset++) {
        var own = 0;
        var blocked = false;
        for (var step = 0; step < 6; step++) {
          final nx = x + dir[0] * (offset + step);
          final ny = y + dir[1] * (offset + step);
          if (nx < 0 || nx >= size || ny < 0 || ny >= size) {
            blocked = true;
            break;
          }
          final value = board[ny * size + nx];
          if (value != 0 && value != player) {
            blocked = true;
            break;
          }
          if (value == player) own++;
        }
        if (!blocked && own > 0) {
          total += const [0, 5, 40, 400, 4000, 50000, 100000000][own];
        }
      }
    }
    return total;
  }

  _SixSnapshot _snapshot() => _SixSnapshot(
        List<int>.of(board),
        _side,
        _stonesLeft,
        _winner,
        _lastMove,
        List<int>.of(_winLine),
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'stonesLeft': _stonesLeft,
        'winner': _winner,
        'last': _lastMove,
        'line': List<int>.of(_winLine),
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _stonesLeft = (json['stonesLeft'] as num?)?.toInt() ?? 2;
    _winner = (json['winner'] as num?)?.toInt();
    _lastMove = (json['last'] as num?)?.toInt();
    _winLine = (json['line'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? const [];
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => [
        for (var i = 0; i < cells; i++)
          if (board[i] == 0) i,
      ];

  @override
  String get llmState {
    final sb = StringBuffer(
      '19x19 六子棋，X=黑方，O=白方，.=空。黑方第一手只下一子，'
      '之后每方每回合下两子；横竖斜先连成 6 子者胜。'
      '坐标 (x,y)，y=0 是最上面一行。\\n',
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
    sb.write('轮到${sideName(_side)}；本回合还可下 $_stonesLeft 子。');
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
    return ConnectSixBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _SixSnapshot {
  final List<int> board;
  final int side;
  final int stonesLeft;
  final int? winner;
  final int? lastMove;
  final List<int> winLine;

  _SixSnapshot(this.board, this.side, this.stonesLeft, this.winner, this.lastMove, this.winLine);
}

class ConnectSixBoard extends StatelessWidget {
  final ConnectSixGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const ConnectSixBoard({
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
        final cell = size / ConnectSixGame.size;
        final padding = cell * 0.5;
        final stoneSize = cell * 0.86;
        final stones = <Widget>[];
        for (var i = 0; i < ConnectSixGame.cells; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final x = i % ConnectSixGame.size;
          final y = i ~/ ConnectSixGame.size;
          final vx = flipped ? 18 - x : x;
          final vy = flipped ? 18 - y : y;
          stones.add(Positioned(
            left: padding + vx * cell - stoneSize / 2,
            top: padding + vy * cell - stoneSize / 2,
            width: stoneSize,
            height: stoneSize,
            child: IgnorePointer(
              child: GameStone(white: value == 2, size: stoneSize),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    final vx = ((details.localPosition.dx - padding) / cell)
                        .round()
                        .clamp(0, 18);
                    final vy = ((details.localPosition.dy - padding) / cell)
                        .round()
                        .clamp(0, 18);
                    final x = flipped ? 18 - vx : vx;
                    final y = flipped ? 18 - vy : vy;
                    final index = y * 19 + x;
                    if (game.isLegal(index)) onMove(index);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SixPainter(
                      game: game,
                      cell: cell,
                      padding: padding,
                      flipped: flipped,
                    ),
                  ),
                ),
                ...stones,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SixPainter extends CustomPainter {
  final ConnectSixGame game;
  final double cell;
  final double padding;
  final bool flipped;

  _SixPainter({
    required this.game,
    required this.cell,
    required this.padding,
    required this.flipped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0BE8B), Color(0xFFC79D66)],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var i = 0; i < 19; i++) {
      final offset = padding + i * cell;
      canvas.drawLine(Offset(padding, offset),
          Offset(size.width - padding, offset), grid);
      canvas.drawLine(Offset(offset, padding),
          Offset(offset, size.height - padding), grid);
    }
    final star = Paint()..color = const Color(0xFF5B3D22);
    for (final p in const [[3, 3], [9, 3], [15, 3], [3, 9], [9, 9], [15, 9], [3, 15], [9, 15], [15, 15]]) {
      canvas.drawCircle(
        Offset(padding + p[0] * cell, padding + p[1] * cell),
        cell * 0.10,
        star,
      );
    }
    if (game._lastMove != null) {
      final index = game._lastMove!;
      final x = index % 19;
      final y = index ~/ 19;
      final vx = flipped ? 18 - x : x;
      final vy = flipped ? 18 - y : y;
      canvas.drawCircle(
        Offset(padding + vx * cell, padding + vy * cell),
        cell * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
    if (game._winLine.isNotEmpty) {
      final first = game._winLine.first;
      final last = game._winLine.last;
      Offset center(int index) {
        final x = index % 19;
        final y = index ~/ 19;
        final vx = flipped ? 18 - x : x;
        final vy = flipped ? 18 - y : y;
        return Offset(padding + vx * cell, padding + vy * cell);
      }
      canvas.drawLine(
        center(first),
        center(last),
        Paint()
          ..color = const Color(0xFFE7BC6C)
          ..strokeWidth = cell * 0.08
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SixPainter oldDelegate) => true;
}
