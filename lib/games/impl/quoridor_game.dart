import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class QuoridorMove {
  final int to; // pawn destination, or -1 for a wall
  final int wall; // wall cell when to == -1
  const QuoridorMove.move(this.to) : wall = -1;
  const QuoridorMove.wall(this.wall) : to = -1;
  bool get isWall => wall >= 0;
  @override
  String toString() => isWall ? 'Wall($wall)' : 'Move($to)';
}

/// 9x9 Quoridor-inspired maze race using single-cell walls (a simplified
/// wall rule: a wall occupies one cell and can never completely block a path).
class QuoridorGame extends TurnGame {
  static const int size = 9;
  static const int cells = 81;

  final List<bool> walls = List<bool>.filled(cells, false);
  final List<int> pawns = [4 * 9 + 4, 4 * 9 + 4];
  final List<int> wallCount = [10, 10];
  final List<_QuoridorSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  QuoridorGame() {
    _setup();
  }

  void _setup() {
    walls.fillRange(0, cells, false);
    pawns[0] = 4 * 9 + 4; // centre; short race board
    pawns[1] = 4 * 9 + 4;
    // Place the two pawns on opposite edges of the centre row.
    pawns[0] = 4 * 9 + 0;
    pawns[1] = 4 * 9 + 8;
    wallCount[0] = 10;
    wallCount[1] = 10;
    _side = 0;
    _winner = null;
    _last = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.quoridor;

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
  String sideName(int side) => side == 0 ? '红方' : '蓝方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}走子或放墙';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '率先到达对方底线';
  }

  @override
  String scoreText(int side) {
    final goal = side == 0 ? 8 : 0;
    final row = pawns[side] ~/ 9;
    return '距终点 ${(row - goal).abs()} · 墙 ${wallCount[side]}';
  }

  bool _onBoard(int x, int y) => x >= 0 && x < 9 && y >= 0 && y < 9;

  bool _canMoveTo(int side, int to) {
    if (to < 0 || to >= cells || walls[to]) return false;
    if (to == pawns[1 - side]) return false;
    final x = pawns[side] % 9;
    final y = pawns[side] ~/ 9;
    final tx = to % 9;
    final ty = to ~/ 9;
    return (x - tx).abs() + (y - ty).abs() == 1;
  }

  bool _pathExists(int start, int goalRow) {
    final queue = <int>[start];
    final seen = <int>{start};
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur ~/ 9 == goalRow) return true;
      final x = cur % 9;
      final y = cur ~/ 9;
      for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (!_onBoard(nx, ny)) continue;
        final n = ny * 9 + nx;
        if (walls[n] || !seen.add(n)) continue;
        queue.add(n);
      }
    }
    return false;
  }

  int _distanceToGoal(int side, {int? from}) {
    final start = from ?? pawns[side];
    final goal = side == 0 ? 8 : 0;
    final dist = List<int>.filled(cells, 999);
    final queue = <int>[start];
    dist[start] = 0;
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur ~/ 9 == goal) return dist[cur];
      final x = cur % 9;
      final y = cur ~/ 9;
      for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (!_onBoard(nx, ny)) continue;
        final n = ny * 9 + nx;
        if (walls[n] || dist[n] != 999) continue;
        dist[n] = dist[cur] + 1;
        queue.add(n);
      }
    }
    return 999;
  }

  bool _canPlaceWall(int index) {
    if (wallCount[_side] <= 0) return false;
    if (index < 0 || index >= cells || walls[index]) return false;
    if (index == pawns[0] || index == pawns[1]) return false;
    walls[index] = true;
    final ok = _pathExists(pawns[0], 8) && _pathExists(pawns[1], 0);
    walls[index] = false;
    return ok;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! QuoridorMove) return false;
    if (move.isWall) return _canPlaceWall(move.wall);
    return _canMoveTo(_side, move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as QuoridorMove;
    _history.add(_snapshot());
    if (m.isWall) {
      walls[m.wall] = true;
      wallCount[_side]--;
      _last = m.wall;
      _moveCount++;
    } else {
      pawns[_side] = m.to;
      _last = m.to;
      _moveCount++;
      final goal = _side == 0 ? 8 : 0;
      if (m.to ~/ 9 == goal) {
        _winner = _side;
        return;
      }
    }
    _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    walls.setAll(0, s.walls);
    pawns[0] = s.pawn0;
    pawns[1] = s.pawn1;
    wallCount[0] = s.wall0;
    wallCount[1] = s.wall1;
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final random = Random();
    final moves = <QuoridorMove>[];
    for (final target in _adjacentMoves(_side)) {
      moves.add(QuoridorMove.move(target));
    }
    if (wallCount[_side] > 0) {
      final candidates = [
        for (var i = 0; i < cells; i++)
          if (!walls[i] && i != pawns[0] && i != pawns[1]) i,
      ]..shuffle(random);
      for (final index in candidates.take(12)) {
        if (_canPlaceWall(index)) moves.add(QuoridorMove.wall(index));
      }
    }
    if (moves.isEmpty) return null;
    final scored = <(QuoridorMove, int)>[];
    for (final m in moves) {
      var score = 0;
      if (m.isWall) {
        walls[m.wall] = true;
        final mine = _distanceToGoal(_side);
        final theirs = _distanceToGoal(1 - _side);
        walls[m.wall] = false;
        score = (theirs - mine) * 6 + 3;
      } else {
        score = (_distanceToGoal(_side, from: m.to) -
                _distanceToGoal(1 - _side)) *
            -5;
      }
      if (level <= 0) score += random.nextInt(12);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.first.$1;
  }

  List<int> _adjacentMoves(int side) {
    final x = pawns[side] % 9;
    final y = pawns[side] ~/ 9;
    final result = <int>[];
    for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (!_onBoard(nx, ny)) continue;
      final n = ny * 9 + nx;
      if (_canMoveTo(side, n)) result.add(n);
    }
    return result;
  }

  _QuoridorSnapshot _snapshot() => _QuoridorSnapshot(
        List<bool>.of(walls),
        pawns[0],
        pawns[1],
        wallCount[0],
        wallCount[1],
        _side,
        _winner,
        _last,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'walls': walls.map((v) => v ? 1 : 0).toList(),
        'pawns': List<int>.of(pawns),
        'wallCount': List<int>.of(wallCount),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['walls'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      walls[i] = i < raw.length && raw[i].toInt() == 1;
    }
    final p = (json['pawns'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 2; i++) {
      pawns[i] = i < p.length ? p[i].toInt() : (i == 0 ? 36 : 44);
    }
    final wc = (json['wallCount'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 2; i++) {
      wallCount[i] = i < wc.length ? wc[i].toInt() : 10;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => [
        for (final target in _adjacentMoves(_side)) QuoridorMove.move(target),
      ];

  @override
  String get llmState {
    final sb = StringBuffer(
      '墙棋（简化版）9x9。红方从左边第 5 行出发，目标右边；蓝方相反。'
      '每回合可以走到相邻一格，或在空格放一堵单格墙；墙不能完全堵死任一方。'
      '先到对方底线者胜。\n',
    );
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final i = r * 9 + c;
        if (pawns[0] == i) {
          sb.write('R ');
        } else if (pawns[1] == i) {
          sb.write('B ');
        } else {
          sb.write(walls[i] ? '# ' : '. ');
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! QuoridorMove) return '$move';
    if (move.isWall) return '放墙 (${move.wall % 9},${move.wall ~/ 9})';
    return '走到 (${move.to % 9},${move.to ~/ 9})';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '红' : '蓝',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        filled: true,
        size: size,
        fontSize: size * 0.36,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return QuoridorBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _QuoridorSnapshot {
  final List<bool> walls;
  final int pawn0;
  final int pawn1;
  final int wall0;
  final int wall1;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _QuoridorSnapshot(this.walls, this.pawn0, this.pawn1, this.wall0, this.wall1,
      this.side, this.winner, this.last, this.moveCount);
}

class QuoridorBoard extends StatelessWidget {
  final QuoridorGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const QuoridorBoard({
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
        final cell = size / 9;
        final moves = interactive ? game._adjacentMoves(game.side) : const <int>[];
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 8);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 8);
                    final x = flipped ? 8 - vx : vx;
                    final y = flipped ? 8 - vy : vy;
                    final index = y * 9 + x;
                    if (game._canMoveTo(game.side, index)) {
                      onMove(QuoridorMove.move(index));
                    } else if (game._canPlaceWall(index)) {
                      onMove(QuoridorMove.wall(index));
                    }
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _QuoridorPainter(
                      game: game,
                      cell: cell,
                      flipped: flipped,
                      moves: moves,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuoridorPainter extends CustomPainter {
  final QuoridorGame game;
  final double cell;
  final bool flipped;
  final List<int> moves;

  _QuoridorPainter({
    required this.game,
    required this.cell,
    required this.flipped,
    required this.moves,
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
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final i = r * 9 + c;
        final vx = flipped ? 8 - c : c;
        final vy = flipped ? 8 - r : r;
        final rr = Rect.fromLTWH(vx * cell, vy * cell, cell, cell);
        canvas.drawRect(
          rr.deflate(1),
          Paint()
            ..color = (r + c).isEven
                ? const Color(0xFF2F5147)
                : const Color(0xFF29483F),
        );
        if (game.walls[i]) {
          canvas.drawRect(
            rr.deflate(cell * 0.10),
            Paint()..color = const Color(0xFF6A4A2B),
          );
          canvas.drawRect(
            rr.deflate(cell * 0.10),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.4),
          );
        }
        if (moves.contains(i)) {
          canvas.drawCircle(
            rr.center,
            cell * 0.17,
            Paint()..color = const Color(0xFFE7BC6C).withValues(alpha: 0.42),
          );
        }
      }
    }
    for (var side = 0; side < 2; side++) {
      final i = game.pawns[side];
      final r = i ~/ 9;
      final c = i % 9;
      final vx = flipped ? 8 - c : c;
      final vy = flipped ? 8 - r : r;
      final color = side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8);
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.32,
        Paint()..color = color,
      );
      final text = TextPainter(
        text: TextSpan(
          text: side == 0 ? '红' : '蓝',
          style: TextStyle(
            color: Colors.white,
            fontSize: cell * 0.26,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset((vx + 0.5) * cell - text.width / 2,
            (vy + 0.5) * cell - text.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuoridorPainter oldDelegate) => true;
}
