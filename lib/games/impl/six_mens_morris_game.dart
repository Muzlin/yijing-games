import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class SixMove {
  final int from;
  final int to;
  const SixMove(this.from, this.to);
}

class SixMensMorrisGame extends TurnGame {
  static const int points = 16;
  static const List<Offset> coords = [
    Offset(0, 0), Offset(3, 0), Offset(6, 0), Offset(6, 3),
    Offset(6, 6), Offset(3, 6), Offset(0, 6), Offset(0, 3),
    Offset(1, 1), Offset(3, 1), Offset(5, 1), Offset(5, 3),
    Offset(5, 5), Offset(3, 5), Offset(1, 5), Offset(1, 3),
  ];
  static const List<List<int>> mills = [
    [0, 1, 2], [2, 3, 4], [4, 5, 6], [6, 7, 0],
    [8, 9, 10], [10, 11, 12], [12, 13, 14], [14, 15, 8],
  ];
  static const List<List<int>> links = [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 0],
    [8, 9], [9, 10], [10, 11], [11, 12], [12, 13], [13, 14], [14, 15], [15, 8],
    [1, 9], [3, 11], [5, 13], [7, 15],
  ];

  final List<int> board = List<int>.filled(points, 0);
  final List<int> placed = [0, 0];
  final List<_SixSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  bool _pendingRemove = false;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.sixMensMorris;

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

  int countOnBoard(int side) => board.where((v) => v == side + 1).length;

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_pendingRemove) return '${sideName(_side)}取子';
    if (placed[_side] < 6) return '${sideName(_side)}布子 · 还剩 ${6 - placed[_side]} 子';
    return '${sideName(_side)}走子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return countOnBoard(1 - _winner!) < 3 ? '对方少于三子' : '对方无子可动';
  }

  @override
  String scoreText(int side) => '${countOnBoard(side)} 子 · 待布 ${6 - placed[side]}';

  bool _isMillAt(int index, int player) {
    for (final mill in mills) {
      if (mill.contains(index) && mill.every((p) => board[p] == player)) {
        return true;
      }
    }
    return false;
  }

  bool _isInMill(int index) {
    final v = board[index];
    if (v == 0) return false;
    for (final mill in mills) {
      if (mill.contains(index) && mill.every((p) => board[p] == v)) return true;
    }
    return false;
  }

  bool _canRemove(int index) {
    if (board[index] != 2 - _side) return false;
    if (!_isInMill(index)) return true;
    for (var i = 0; i < points; i++) {
      if (board[i] == 2 - _side && !_isInMill(i)) return false;
    }
    return true;
  }

  List<int> _neighbors(int i) => [
        for (final link in links)
          if (link[0] == i) link[1] else if (link[1] == i) link[0],
      ];

  List<SixMove> _movesFor(int side) {
    final result = <SixMove>[];
    if (_pendingRemove) {
      for (var i = 0; i < points; i++) {
        if (_canRemove(i)) result.add(SixMove(-1, i));
      }
      return result;
    }
    if (placed[side] < 6) {
      for (var i = 0; i < points; i++) {
        if (board[i] == 0) result.add(SixMove(-1, i));
      }
      return result;
    }
    for (var i = 0; i < points; i++) {
      if (board[i] != side + 1) continue;
      for (final n in _neighbors(i)) {
        if (board[n] == 0) result.add(SixMove(i, n));
      }
    }
    return result;
  }

  bool _hasMove(int side) {
    if (placed[side] < 6) return true;
    if (countOnBoard(side) < 3) return false;
    for (var i = 0; i < points; i++) {
      if (board[i] != side + 1) continue;
      if (_neighbors(i).any((n) => board[n] == 0)) return true;
    }
    return false;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! SixMove) return false;
    if (move.to < 0 || move.to >= points) return false;
    if (_pendingRemove) return _canRemove(move.to);
    if (board[move.to] != 0) return false;
    if (placed[_side] < 6) return true;
    if (move.from < 0 || board[move.from] != _side + 1) return false;
    return _neighbors(move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as SixMove;
    _history.add(_snapshot());
    if (_pendingRemove) {
      board[m.to] = 0;
      _pendingRemove = false;
      _last = m.to;
      _moveCount++;
      if (placed[1 - _side] >= 6 && countOnBoard(1 - _side) < 3) {
        _winner = _side;
        return;
      }
      _switch();
      return;
    }
    if (placed[_side] < 6) {
      board[m.to] = _side + 1;
      placed[_side]++;
    } else {
      board[m.from] = 0;
      board[m.to] = _side + 1;
    }
    _last = m.to;
    _moveCount++;
    if (_isMillAt(m.to, _side + 1)) {
      _pendingRemove = true;
      return;
    }
    _switch();
  }

  void _switch() {
    _side = 1 - _side;
    if (countOnBoard(_side) < 3 && placed[_side] >= 6) {
      _winner = 1 - _side;
      return;
    }
    if (!_hasMove(_side)) _winner = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    board.setAll(0, s.board);
    placed[0] = s.placed0;
    placed[1] = s.placed1;
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _pendingRemove = s.pending;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _movesFor(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(SixMove, int)>[];
    for (final m in moves) {
      if (_pendingRemove) {
        scored.add((m, _isInMill(m.to) ? 0 : 20));
        continue;
      }
      final old = board[m.to];
      final oldFrom = m.from >= 0 ? board[m.from] : 0;
      if (m.from >= 0) board[m.from] = 0;
      board[m.to] = _side + 1;
      var score = _isMillAt(m.to, _side + 1) ? 800 : 0;
      score += _neighbors(m.to).where((n) => board[n] == _side + 1).length * 6;
      board[m.to] = old;
      if (m.from >= 0) board[m.from] = oldFrom;
      if (level <= 0) score += random.nextInt(40);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _SixSnapshot _snapshot() => _SixSnapshot(
        List<int>.of(board),
        placed[0],
        placed[1],
        _side,
        _winner,
        _last,
        _pendingRemove,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'placed': List<int>.of(placed),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'pending': _pendingRemove,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < points; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    final p = (json['placed'] as List?)?.cast<num>() ?? const [];
    placed[0] = p.isNotEmpty ? p[0].toInt() : 0;
    placed[1] = p.length > 1 ? p[1].toInt() : 0;
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _pendingRemove = json['pending'] == true;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _movesFor(_side);

  @override
  String get llmState {
    final sb = StringBuffer(
      '六子冲（Six Men\'s Morris）7x7 棋盘上的 16 个点，双方各 6 子。'
      '先布子再走子；三子连成一线可吃对方一子；少于 3 子或无法移动者负。\n',
    );
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 7; c++) {
        final i = coords.indexWhere((o) => o.dx == c && o.dy == r);
        sb.write(i < 0 ? '  ' : (board[i] == 0 ? '. ' : (board[i] == 1 ? 'X ' : 'O ')));
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! SixMove) return '$move';
    String p(int i) => '(${coords[i].dx.toInt()},${coords[i].dy.toInt()})';
    return move.from < 0 ? '下${p(move.to)}' : '${p(move.from)}→${p(move.to)}';
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
    return SixMensBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _SixSnapshot {
  final List<int> board;
  final int placed0;
  final int placed1;
  final int side;
  final int? winner;
  final int? last;
  final bool pending;
  final int moveCount;

  _SixSnapshot(this.board, this.placed0, this.placed1, this.side, this.winner,
      this.last, this.pending, this.moveCount);
}

class SixMensBoard extends StatefulWidget {
  final SixMensMorrisGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const SixMensBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<SixMensBoard> createState() => _SixMensBoardState();
}

class _SixMensBoardState extends State<SixMensBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final activeTargets = game._pendingRemove
        ? [for (var i = 0; i < 16; i++) if (game._canRemove(i)) i]
        : game.placed[game.side] < 6
            ? [for (var i = 0; i < 16; i++) if (game.board[i] == 0) i]
            : selected != null
                ? [
                    for (var i = 0; i < 16; i++)
                      if (game.isLegal(SixMove(selected!, i))) i,
                  ]
                : const <int>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 6.8;
        final pad = cell * 0.4;
        final stone = cell * 0.66;
        Offset at(int i) {
          final c = SixMensMorrisGame.coords[i];
          final x = widget.flipped ? 6 - c.dx : c.dx;
          final y = widget.flipped ? 6 - c.dy : c.dy;
          return Offset(pad + x * cell, pad + y * cell);
        }

        final stones = <Widget>[];
        for (var i = 0; i < 16; i++) {
          final v = game.board[i];
          if (v == 0) continue;
          final p = at(i);
          stones.add(Positioned(
            left: p.dx - stone / 2,
            top: p.dy - stone / 2,
            width: stone,
            height: stone,
            child: IgnorePointer(child: GameStone(white: v == 2, size: stone)),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.interactive
                ? (details) {
                    var best = -1;
                    var bestDist = double.infinity;
                    for (var i = 0; i < 16; i++) {
                      final d = (at(i) - details.localPosition).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    if (best < 0 || bestDist > cell * 0.6) return;
                    _tap(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SixPainter(
                      game: game,
                      cell: cell,
                      pad: pad,
                      flipped: widget.flipped,
                      selected: selected,
                      targets: activeTargets,
                      removal: game._pendingRemove,
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

  void _tap(int i) {
    final game = widget.game;
    if (game._pendingRemove) {
      if (game._canRemove(i)) widget.onMove(SixMove(-1, i));
      return;
    }
    if (game.placed[game.side] < 6) {
      if (game.board[i] == 0) widget.onMove(SixMove(-1, i));
      return;
    }
    if (selected != null && targets.contains(i)) {
      widget.onMove(SixMove(selected!, i));
      setState(() {
        selected = null;
        targets = const [];
      });
      return;
    }
    if (game.board[i] == game.side + 1) {
      setState(() {
        selected = i;
        targets = [
          for (var j = 0; j < 16; j++)
            if (game.isLegal(SixMove(i, j))) j,
        ];
      });
    } else {
      setState(() {
        selected = null;
        targets = const [];
      });
    }
  }
}

class _SixPainter extends CustomPainter {
  final SixMensMorrisGame game;
  final double cell;
  final double pad;
  final bool flipped;
  final int? selected;
  final List<int> targets;
  final bool removal;

  _SixPainter({
    required this.game,
    required this.cell,
    required this.pad,
    required this.flipped,
    required this.selected,
    required this.targets,
    required this.removal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7C994), Color(0xFFC89A5E)],
        ).createShader(Offset.zero & size),
    );
    Offset at(int i) {
      final c = SixMensMorrisGame.coords[i];
      final x = flipped ? 6 - c.dx : c.dx;
      final y = flipped ? 6 - c.dy : c.dy;
      return Offset(pad + x * cell, pad + y * cell);
    }

    final line = Paint()
      ..color = const Color(0xFF573B21)
      ..strokeWidth = max(1.4, cell * 0.055)
      ..strokeCap = StrokeCap.round;
    for (final link in SixMensMorrisGame.links) {
      canvas.drawLine(at(link[0]), at(link[1]), line);
    }
    for (final mill in SixMensMorrisGame.mills) {
      final v = game.board[mill[0]];
      if (v == 0 || game.board[mill[1]] != v || game.board[mill[2]] != v) {
        continue;
      }
      canvas.drawLine(
        at(mill[0]),
        at(mill[2]),
        Paint()
          ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.5)
          ..strokeWidth = cell * 0.13
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    final dot = Paint()..color = const Color(0xFF4A301B);
    for (var i = 0; i < 16; i++) {
      canvas.drawCircle(at(i), cell * 0.07, dot);
    }
    for (final i in targets) {
      canvas.drawCircle(
        at(i),
        cell * 0.18,
        Paint()
          ..color = (removal ? const Color(0xFFB53D32) : const Color(0xFF3D6B54))
              .withValues(alpha: 0.5),
      );
    }
    if (selected != null) {
      canvas.drawCircle(
        at(selected!),
        cell * 0.29,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SixPainter oldDelegate) => true;
}
