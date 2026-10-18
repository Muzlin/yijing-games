import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class DotsMove {
  final bool horizontal;
  final int row;
  final int col;
  const DotsMove(this.horizontal, this.row, this.col);
  @override
  String toString() => 'DotsMove($horizontal,$row,$col)';
}

class DotsBoxesGame extends TurnGame {
  static const int dots = 6;
  static const int boxes = 5;
  static const int horizontalCount = dots * (dots - 1);
  static const int verticalCount = (dots - 1) * dots;

  final List<bool> horizontal = List<bool>.filled(horizontalCount, false);
  final List<bool> vertical = List<bool>.filled(verticalCount, false);
  final List<int> owners = List<int>.filled(boxes * boxes, -1);
  final List<_DotsSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int _lastLine = -1;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.dotsBoxes;

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
    return '${sideName(_side)}画线';
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
    return '红 ${_score(0)} 格 · 蓝 ${_score(1)} 格';
  }

  @override
  String scoreText(int side) => '${_score(side)} 格';

  int _score(int side) => owners.where((o) => o == side).length;

  int get _totalLines => horizontalCount + verticalCount;

  int _lineId(DotsMove m) => m.horizontal
      ? m.row * (dots - 1) + m.col
      : horizontalCount + m.row * dots + m.col;


  bool _drawn(DotsMove m) =>
      m.horizontal ? horizontal[_lineId(m)] : vertical[_lineId(m) - horizontalCount];

  bool _boxComplete(int r, int c) {
    final top = horizontal[r * (dots - 1) + c];
    final bottom = horizontal[(r + 1) * (dots - 1) + c];
    final left = vertical[r * dots + c];
    final right = vertical[r * dots + c + 1];
    return top && bottom && left && right;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! DotsMove) return false;
    if (move.row < 0 || move.col < 0) return false;
    if (move.horizontal) {
      if (move.row >= dots || move.col >= dots - 1) return false;
    } else {
      if (move.row >= dots - 1 || move.col >= dots) return false;
    }
    return !_drawn(move);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as DotsMove;
    _history.add(_snapshot());
    final id = _lineId(m);
    if (m.horizontal) {
      horizontal[id] = true;
    } else {
      vertical[id - horizontalCount] = true;
    }
    _lastLine = id;
    _moveCount++;
    var completed = false;
    // Boxes adjacent to this line.
    if (m.horizontal) {
      for (final r in [m.row - 1, m.row]) {
        if (r < 0 || r >= boxes) continue;
        if (_boxComplete(r, m.col) && owners[r * boxes + m.col] < 0) {
          owners[r * boxes + m.col] = _side;
          completed = true;
        }
      }
    } else {
      for (final c in [m.col - 1, m.col]) {
        if (c < 0 || c >= boxes) continue;
        if (_boxComplete(m.row, c) && owners[m.row * boxes + c] < 0) {
          owners[m.row * boxes + c] = _side;
          completed = true;
        }
      }
    }
    if (_moveCount >= _totalLines) {
      final a = _score(0);
      final b = _score(1);
      _winner = a == b ? 2 : (a > b ? 0 : 1);
      return;
    }
    if (!completed) _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    horizontal.setAll(0, s.horizontal);
    vertical.setAll(0, s.vertical);
    owners.setAll(0, s.owners);
    _side = s.side;
    _winner = s.winner;
    _lastLine = s.lastLine;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = <DotsMove>[];
    for (var r = 0; r < dots; r++) {
      for (var c = 0; c < dots - 1; c++) {
        final m = DotsMove(true, r, c);
        if (isLegal(m)) moves.add(m);
      }
    }
    for (var r = 0; r < dots - 1; r++) {
      for (var c = 0; c < dots; c++) {
        final m = DotsMove(false, r, c);
        if (isLegal(m)) moves.add(m);
      }
    }
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(DotsMove, int)>[];
    for (final m in moves) {
      final id = _lineId(m);
      if (m.horizontal) {
        horizontal[id] = true;
      } else {
        vertical[id - horizontalCount] = true;
      }
      var completed = 0;
      var gives = 0;
      for (var r = 0; r < boxes; r++) {
        for (var c = 0; c < boxes; c++) {
          if (owners[r * boxes + c] >= 0) continue;
          final top = horizontal[r * (dots - 1) + c];
          final bottom = horizontal[(r + 1) * (dots - 1) + c];
          final left = vertical[r * dots + c];
          final right = vertical[r * dots + c + 1];
          final sides = [top, bottom, left, right].where((v) => v).length;
          if (sides == 4) completed++;
          if (sides == 3) gives++;
        }
      }
      if (m.horizontal) {
        horizontal[id] = false;
      } else {
        vertical[id - horizontalCount] = false;
      }
      var score = completed * 1000 - gives * 80;
      if (level <= 0) score += random.nextInt(30);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _DotsSnapshot _snapshot() => _DotsSnapshot(
        List<bool>.of(horizontal),
        List<bool>.of(vertical),
        List<int>.of(owners),
        _side,
        _winner,
        _lastLine,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'horizontal': horizontal.map((v) => v ? 1 : 0).toList(),
        'vertical': vertical.map((v) => v ? 1 : 0).toList(),
        'owners': List<int>.of(owners),
        'side': _side,
        'winner': _winner,
        'lastLine': _lastLine,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final h = (json['horizontal'] as List?)?.cast<num>() ?? const [];
    final v = (json['vertical'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < horizontalCount; i++) {
      horizontal[i] = i < h.length && h[i].toInt() == 1;
    }
    for (var i = 0; i < verticalCount; i++) {
      vertical[i] = i < v.length && v[i].toInt() == 1;
    }
    final o = (json['owners'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < owners.length; i++) {
      owners[i] = i < o.length ? o[i].toInt() : -1;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastLine = (json['lastLine'] as num?)?.toInt() ?? -1;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves {
    final moves = <DotsMove>[];
    for (var r = 0; r < dots; r++) {
      for (var c = 0; c < dots - 1; c++) {
        final m = DotsMove(true, r, c);
        if (isLegal(m)) moves.add(m);
      }
    }
    for (var r = 0; r < dots - 1; r++) {
      for (var c = 0; c < dots; c++) {
        final m = DotsMove(false, r, c);
        if (isLegal(m)) moves.add(m);
      }
    }
    return moves;
  }

  @override
  String get llmState {
    final sb = StringBuffer(
      '点格棋（Dots and Boxes）6x6 点、5x5 格。双方轮流画一条未画线段；'
      '完成一个格子的一方得 1 分并继续走；所有格子完成后分数多者胜。\n',
    );
    sb.write('横向线：${horizontal.where((v) => v).length}/$horizontalCount；'
        '纵向线：${vertical.where((v) => v).length}/$verticalCount；'
        '红 ${_score(0)} 格，蓝 ${_score(1)} 格。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! DotsMove) return '$move';
    return '${move.horizontal ? '横' : '竖'} (${move.col},${move.row})';
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
    return DotsBoxesBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
    );
  }
}

class _DotsSnapshot {
  final List<bool> horizontal;
  final List<bool> vertical;
  final List<int> owners;
  final int side;
  final int? winner;
  final int lastLine;
  final int moveCount;

  _DotsSnapshot(this.horizontal, this.vertical, this.owners, this.side,
      this.winner, this.lastLine, this.moveCount);
}

class DotsBoxesBoard extends StatelessWidget {
  final DotsBoxesGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;

  const DotsBoxesBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final margin = size * 0.07;
        final cell = (size - margin * 2) / 6;
        Offset dot(int r, int c) => Offset(margin + c * cell, margin + r * cell);
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    DotsMove? best;
                    var bestDist = double.infinity;
                    for (var r = 0; r < 6; r++) {
                      for (var c = 0; c < 5; c++) {
                        final a = dot(r, c);
                        final b = dot(r, c + 1);
                        final d = _distToSegment(details.localPosition, a, b);
                        if (d < bestDist && !game._drawn(DotsMove(true, r, c))) {
                          bestDist = d;
                          best = DotsMove(true, r, c);
                        }
                      }
                    }
                    for (var r = 0; r < 5; r++) {
                      for (var c = 0; c < 6; c++) {
                        final a = dot(r, c);
                        final b = dot(r + 1, c);
                        final d = _distToSegment(details.localPosition, a, b);
                        if (d < bestDist && !game._drawn(DotsMove(false, r, c))) {
                          bestDist = d;
                          best = DotsMove(false, r, c);
                        }
                      }
                    }
                    if (best != null && bestDist < cell * 0.38) onMove(best);
                  }
                : null,
            child: CustomPaint(
              painter: _DotsPainter(
                game: game,
                margin: margin,
                cell: cell,
              ),
            ),
          ),
        );
      },
    );
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final t = len2 == 0 ? 0.0 : ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0);
    final projection = a + ab * t;
    return (p - projection).distance;
  }
}

class _DotsPainter extends CustomPainter {
  final DotsBoxesGame game;
  final double margin;
  final double cell;

  _DotsPainter({required this.game, required this.margin, required this.cell});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0DFC0), Color(0xFFD8B98D)],
        ).createShader(rect),
    );
    Offset dot(int r, int c) => Offset(margin + c * cell, margin + r * cell);
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        final owner = game.owners[r * 5 + c];
        if (owner < 0) continue;
        final color = owner == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8);
        canvas.drawRect(
          Rect.fromLTWH(margin + c * cell, margin + r * cell, cell, cell).deflate(cell * 0.1),
          Paint()..color = color.withValues(alpha: 0.22),
        );
        final text = TextPainter(
          text: TextSpan(
            text: owner == 0 ? '红' : '蓝',
            style: TextStyle(
              color: color,
              fontSize: cell * 0.22,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(margin + (c + 0.5) * cell - text.width / 2,
              margin + (r + 0.5) * cell - text.height / 2),
        );
      }
    }
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 5; c++) {
        if (!game.horizontal[r * 5 + c]) continue;
        final a = dot(r, c);
        final b = dot(r, c + 1);
        final owner = _lineOwner(r, c, true);
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = owner == 0
                ? const Color(0xFFD95B4E)
                : owner == 1
                    ? const Color(0xFF6C9BD8)
                    : const Color(0xFF5B3D22)
            ..strokeWidth = cell * 0.075
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 6; c++) {
        if (!game.vertical[r * 6 + c]) continue;
        final a = dot(r, c);
        final b = dot(r + 1, c);
        final owner = _lineOwner(r, c, false);
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = owner == 0
                ? const Color(0xFFD95B4E)
                : owner == 1
                    ? const Color(0xFF6C9BD8)
                    : const Color(0xFF5B3D22)
            ..strokeWidth = cell * 0.075
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    final dotPaint = Paint()..color = const Color(0xFF4A301B);
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        canvas.drawCircle(dot(r, c), cell * 0.075, dotPaint);
      }
    }
  }

  int _lineOwner(int r, int c, bool horizontal) {
    // A line belongs to the player who most recently completed an adjacent box;
    // just use the current side for the most recent line as a subtle hint.
    if (horizontal) {
      for (final rr in [r - 1, r]) {
        if (rr >= 0 && rr < 5) {
          final o = game.owners[rr * 5 + c];
          if (o >= 0) return o;
        }
      }
    } else {
      for (final cc in [c - 1, c]) {
        if (cc >= 0 && cc < 5) {
          final o = game.owners[r * 5 + cc];
          if (o >= 0) return o;
        }
      }
    }
    return -1;
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => true;
}
