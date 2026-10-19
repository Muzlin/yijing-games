import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class ThreeMove {
  final int from;
  final int to;
  const ThreeMove(this.from, this.to);
}

class ThreeMensMorrisGame extends TurnGame {
  static const List<List<int>> lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  final List<int> board = List<int>.filled(9, 0);
  final List<int> placed = [0, 0];
  final List<_ThreeSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.threeMensMorris;

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
    if (placed[_side] < 3) return '${sideName(_side)}布子';
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
    return board.where((v) => v == 2 - _winner!).length < 3 ? '对方少于三子' : '对方无子可动';
  }

  @override
  String scoreText(int side) =>
      '${board.where((v) => v == side + 1).length} 子 · 待布 ${3 - placed[side]}';

  List<int> _neighbors(int i) {
    final x = i % 3;
    final y = i ~/ 3;
    final r = <int>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (nx >= 0 && nx < 3 && ny >= 0 && ny < 3) r.add(ny * 3 + nx);
      }
    }
    return r;
  }

  List<ThreeMove> _movesFor(int side) {
    final r = <ThreeMove>[];
    if (placed[side] < 3) {
      for (var i = 0; i < 9; i++) {
        if (board[i] == 0) r.add(ThreeMove(-1, i));
      }
      return r;
    }
    for (var i = 0; i < 9; i++) {
      if (board[i] != side + 1) continue;
      for (final n in _neighbors(i)) {
        if (board[n] == 0) r.add(ThreeMove(i, n));
      }
    }
    return r;
  }

  bool _hasMove(int side) => _movesFor(side).isNotEmpty;

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! ThreeMove) return false;
    if (move.to < 0 || move.to >= 9 || board[move.to] != 0) return false;
    if (placed[_side] < 3) return true;
    return move.from >= 0 &&
        board[move.from] == _side + 1 &&
        _neighbors(move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as ThreeMove;
    _history.add(_snapshot());
    if (placed[_side] < 3) {
      board[m.to] = _side + 1;
      placed[_side]++;
    } else {
      board[m.from] = 0;
      board[m.to] = _side + 1;
    }
    _last = m.to;
    _moveCount++;
    final line = _lineAt(m.to);
    if (line != null) {
      _winner = _side;
      return;
    }
    _side = 1 - _side;
    if (placed[_side] >= 3 &&
        board.where((v) => v == _side + 1).length < 3) {
      _winner = 1 - _side;
      return;
    }
    if (!_hasMove(_side)) _winner = 1 - _side;
  }

  List<int>? _lineAt(int index) {
    for (final line in lines) {
      if (!line.contains(index)) continue;
      final v = board[line[0]];
      if (v != 0 && board[line[1]] == v && board[line[2]] == v) return line;
    }
    return null;
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
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _movesFor(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(ThreeMove, int)>[];
    for (final m in moves) {
      final old = board[m.to];
      final from = m.from >= 0 ? board[m.from] : 0;
      if (m.from >= 0) board[m.from] = 0;
      board[m.to] = _side + 1;
      var score = _lineAt(m.to) != null ? 1000 : 0;
      score += _neighbors(m.to).where((n) => board[n] == _side + 1).length * 5;
      board[m.to] = old;
      if (m.from >= 0) board[m.from] = from;
      if (level <= 0) score += random.nextInt(30);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.first.$1;
  }

  _ThreeSnapshot _snapshot() => _ThreeSnapshot(
        List<int>.of(board),
        placed[0],
        placed[1],
        _side,
        _winner,
        _last,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'placed': List<int>.of(placed),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 9; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    final p = (json['placed'] as List?)?.cast<num>() ?? const [];
    placed[0] = p.isNotEmpty ? p[0].toInt() : 0;
    placed[1] = p.length > 1 ? p[1].toInt() : 0;
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _movesFor(_side);

  @override
  String get llmState {
    final sb = StringBuffer('三三棋 3x3，双方各 3 子，先布子后走子；三子成线者胜，不能飞子。\n');
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final v = board[r * 3 + c];
        sb.write(v == 0 ? '.' : (v == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! ThreeMove) return '$move';
    String p(int i) => '(${i % 3},${i ~/ 3})';
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
    return ThreeMensBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _ThreeSnapshot {
  final List<int> board;
  final int placed0;
  final int placed1;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _ThreeSnapshot(this.board, this.placed0, this.placed1, this.side, this.winner,
      this.last, this.moveCount);
}

class ThreeMensBoard extends StatefulWidget {
  final ThreeMensMorrisGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const ThreeMensBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<ThreeMensBoard> createState() => _ThreeMensBoardState();
}

class _ThreeMensBoardState extends State<ThreeMensBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final active = game.placed[game.side] < 3
        ? [for (var i = 0; i < 9; i++) if (game.board[i] == 0) i]
        : selected != null
            ? [
                for (var i = 0; i < 9; i++)
                  if (game.isLegal(ThreeMove(selected!, i))) i,
              ]
            : const <int>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 2.8;
        final pad = (size - cell * 2) / 2;
        final stone = cell * 0.24;
        Offset at(int i) => Offset(
              pad + (i % 3) * cell,
              pad + (i ~/ 3) * cell,
            );
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.interactive
                ? (details) {
                    var best = -1;
                    var bestDist = double.infinity;
                    for (var i = 0; i < 9; i++) {
                      final d = (at(i) - details.localPosition).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    if (best >= 0 && bestDist < cell * 0.38) _tap(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ThreePainter(
                      game: game,
                      cell: cell,
                      pad: pad,
                      selected: selected,
                      targets: active,
                    ),
                  ),
                ),
                for (var i = 0; i < 9; i++)
                  if (game.board[i] != 0)
                    Positioned(
                      left: at(i).dx - stone,
                      top: at(i).dy - stone,
                      width: stone * 2,
                      height: stone * 2,
                      child: IgnorePointer(
                        child: GameStone(white: game.board[i] == 2, size: stone * 2),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _tap(int i) {
    final game = widget.game;
    if (game.placed[game.side] < 3) {
      if (game.board[i] == 0) widget.onMove(ThreeMove(-1, i));
      return;
    }
    if (selected != null && targets.contains(i)) {
      widget.onMove(ThreeMove(selected!, i));
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
          for (var j = 0; j < 9; j++)
            if (game.isLegal(ThreeMove(i, j))) j,
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

class _ThreePainter extends CustomPainter {
  final ThreeMensMorrisGame game;
  final double cell;
  final double pad;
  final int? selected;
  final List<int> targets;

  _ThreePainter({
    required this.game,
    required this.cell,
    required this.pad,
    required this.selected,
    required this.targets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE7C994), Color(0xFFC89A5E)],
        ).createShader(Offset.zero & size),
    );
    Offset at(int i) => Offset(
          pad + (i % 3) * cell,
          pad + (i ~/ 3) * cell,
        );
    final line = Paint()
      ..color = const Color(0xFF573B21)
      ..strokeWidth = 2;
    for (final l in ThreeMensMorrisGame.lines) {
      canvas.drawLine(at(l[0]), at(l[2]), line);
    }
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(at(i), cell * 0.045, Paint()..color = const Color(0xFF4A301B));
    }
    for (final i in targets) {
      canvas.drawCircle(
        at(i),
        cell * 0.08,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.55),
      );
    }
    if (selected != null) {
      canvas.drawCircle(
        at(selected!),
        cell * 0.17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThreePainter oldDelegate) => true;
}
