import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

/// 11x11 Hex. Black (side 0) connects top to bottom; white (side 1)
/// connects left to right. Stones never move.
class HexGame extends TurnGame {
  static const int size = 11;
  static const int cells = 121;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_HexSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  List<int> _winPath = const [];
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.hex;

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
    return _winner == 2 ? '棋盘已满' : (_winner == 0 ? '上下连通' : '左右连通');
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final v in board) {
      if (v == side + 1) count++;
    }
    return '$count 子';
  }

  static int indexOf(int row, int col) => row * size + col;

  static List<int> neighborsOf(int index) {
    final r = index ~/ size;
    final c = index % size;
    const dirs = [[0, -1], [0, 1], [-1, 0], [1, 0], [-1, 1], [1, -1]];
    return [
      for (final d in dirs)
        if (r + d[0] >= 0 && r + d[0] < size && c + d[1] >= 0 && c + d[1] < size)
          (r + d[0]) * size + c + d[1],
    ];
  }

  List<int>? _pathFor(int player) {
    final queue = <int>[];
    final parent = <int, int>{};
    final seen = <int>{};
    for (var i = 0; i < size; i++) {
      final index = player == 1 ? indexOf(0, i) : indexOf(i, 0);
      if (board[index] == player && seen.add(index)) {
        queue.add(index);
      }
    }
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final r = current ~/ size;
      final c = current % size;
      final reached = player == 1 ? r == size - 1 : c == size - 1;
      if (reached && board[current] == player) {
        final path = <int>[current];
        var node = current;
        while (parent.containsKey(node)) {
          node = parent[node]!;
          path.add(node);
        }
        return path.reversed.toList();
      }
      for (final n in neighborsOf(current)) {
        if (board[n] == player && seen.add(n)) {
          parent[n] = current;
          queue.add(n);
        }
      }
    }
    return null;
  }

  int _distance(int player) {
    final dist = List<int>.filled(cells, 999);
    final queue = <int>[];
    for (var i = 0; i < size; i++) {
      final index = player == 1 ? indexOf(0, i) : indexOf(i, 0);
      if (board[index] != (2 - player)) {
        dist[index] = 0;
        queue.add(index);
      }
    }
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final r = cur ~/ size;
      final c = cur % size;
      final done = player == 1 ? r == size - 1 : c == size - 1;
      if (done) return dist[cur];
      for (final n in neighborsOf(cur)) {
        if (board[n] == (2 - player)) continue;
        if (dist[n] > dist[cur] + 1) {
          dist[n] = dist[cur] + 1;
          queue.add(n);
        }
      }
    }
    return 999;
  }

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
    final path = _pathFor(_side + 1);
    if (path != null) {
      _winPath = path;
      _winner = _side;
      return;
    }
    if (_moveCount == cells) {
      _winner = 2;
      return;
    }
    _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    board.setAll(0, s.board);
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _winPath = s.winPath;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final empty = [for (var i = 0; i < cells; i++) if (board[i] == 0) i];
    if (empty.isEmpty) return null;
    final random = Random();
    final scored = <(int, int)>[];
    for (final move in empty) {
      board[move] = _side + 1;
      final win = _pathFor(_side + 1) != null;
      final mine = _distance(_side + 1);
      final theirs = _distance(2 - _side);
      board[move] = 0;
      var score = (theirs - mine) * 10;
      if (win) score += 100000;
      if (level <= 0) score += random.nextInt(20);
      scored.add((move, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _HexSnapshot _snapshot() => _HexSnapshot(
        List<int>.of(board),
        _side,
        _winner,
        _last,
        List<int>.of(_winPath),
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'winPath': List<int>.of(_winPath),
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
    _winPath = (json['winPath'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? const [];
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves =>
      [for (var i = 0; i < cells; i++) if (board[i] == 0) i];

  @override
  String get llmState {
    final sb = StringBuffer(
      '11x11 六角棋（Hex），X=黑方上下连通，O=白方左右连通，黑方先手。'
      '每回合在空格落子，棋子不移动；先把己方两条边连成通路者胜。\n',
    );
    for (var r = 0; r < size; r++) {
      sb.write(List.filled(r, ' ').join());
      for (var c = 0; c < size; c++) {
        final v = board[r * size + c];
        sb.write(v == 0 ? '.' : (v == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
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
    return HexBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _HexSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final List<int> winPath;
  final int moveCount;

  _HexSnapshot(this.board, this.side, this.winner, this.last, this.winPath,
      this.moveCount);
}

class HexBoard extends StatelessWidget {
  final HexGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const HexBoard({
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
        final radius = min(
          size / (15 * sqrt(3)),
          size / 17,
        ) * 0.94;
        final boardW = sqrt(3) * radius * (11 + 5);
        final boardH = radius * 17;
        final dx = (size - boardW) / 2;
        final dy = (size - boardH) / 2;
        Offset center(int index) {
          final rawR = index ~/ 11;
          final rawC = index % 11;
          final r = flipped ? 10 - rawR : rawR;
          final c = flipped ? 10 - rawC : rawC;
          final x = radius * sqrt(3) * (c + r / 2) + dx + radius * sqrt(3) / 2;
          final y = radius * 1.5 * r + dy + radius;
          return Offset(x, y);
        }

        final stones = <Widget>[];
        for (var i = 0; i < 121; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final c = center(i);
          stones.add(Positioned(
            left: c.dx - radius * 0.62,
            top: c.dy - radius * 0.62,
            width: radius * 1.24,
            height: radius * 1.24,
            child: IgnorePointer(
              child: GameStone(white: value == 2, size: radius * 1.24),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    var best = -1;
                    var bestDist = double.infinity;
                    for (var i = 0; i < 121; i++) {
                      final d = (center(i) - details.localPosition).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    if (best >= 0 && bestDist <= radius * 0.9) onMove(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HexPainter(
                      game: game,
                      radius: radius,
                      center: center,
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

class _HexPainter extends CustomPainter {
  final HexGame game;
  final double radius;
  final Offset Function(int) center;
  final bool flipped;

  _HexPainter({
    required this.game,
    required this.radius,
    required this.center,
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
          colors: [Color(0xFF203A33), Color(0xFF0E1D19)],
        ).createShader(rect),
    );
    for (var i = 0; i < 121; i++) {
      final c = center(i);
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final angle = -pi / 2 + k * pi / 3;
        final p = c + Offset(cos(angle), sin(angle)) * radius;
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      final winning = game._winPath.contains(i);
      canvas.drawPath(
        path,
        Paint()
          ..color = winning
              ? const Color(0xFFE7BC6C).withValues(alpha: 0.22)
              : const Color(0xFF3F6E5E).withValues(alpha: 0.20),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFE7BC6C).withValues(alpha: winning ? 0.65 : 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) => true;
}
