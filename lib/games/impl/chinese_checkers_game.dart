import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class ChineseMove {
  final int from;
  final int to;
  const ChineseMove(this.from, this.to);
  @override
  String toString() => 'ChineseMove($from,$to)';
}

class ChineseCheckersGame extends TurnGame {
  static const List<int> rowWidths = [
    1, 2, 3, 4, 13, 12, 11, 10, 9, 10, 11, 12, 13, 4, 3, 2, 1,
  ];
  static const int holes = 121;

  final List<int> board = List<int>.filled(holes, 0);
  final List<_ChineseSnapshot> _history = [];
  final List<int> rowStarts = [];
  final List<int> rowOf = [];
  final List<double> xOf = [];
  final List<List<int>> neighborsOf = [];
  final Map<String, int> coordToHole = {};
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  ChineseCheckersGame() {
    var start = 0;
    for (var r = 0; r < rowWidths.length; r++) {
      rowStarts.add(start);
      final width = rowWidths[r];
      for (var c = 0; c < width; c++) {
        final index = start + c;
        rowOf.add(r);
        final x = c - (width - 1) / 2;
        xOf.add(x);
        coordToHole[_key(x, r)] = index;
      }
      start += width;
    }
    for (var i = 0; i < holes; i++) {
      final list = <int>[];
      for (var j = 0; j < holes; j++) {
        if (i == j) continue;
        if (_adjacent(i, j)) list.add(j);
      }
      neighborsOf.add(list);
    }
    _setup();
  }

  String _key(double x, int row) => '${(x * 2).round()}:$row';

  bool _adjacent(int a, int b) {
    final ra = rowOf[a];
    final rb = rowOf[b];
    if ((ra - rb).abs() > 1) return false;
    if (ra == rb) {
      return ((a - b).abs() == 1) &&
          (a - rowStarts[ra]).abs() < rowWidths[ra];
    }
    return ((xOf[a] - xOf[b]).abs() - 0.5).abs() < 0.001;
  }

  void _setup() {
    board.fillRange(0, holes, 0);
    for (var i = 0; i < 10; i++) {
      board[i] = 1;
      board[holes - 1 - i] = 2;
    }
    _side = 0;
    _winner = null;
    _last = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.chineseCheckers;

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

  bool _isHome(int side, int index) {
    if (side == 0) return index >= holes - 10 && index < holes;
    return index >= 0 && index < 10;
  }

  int _homeCount(int side) {
    var count = 0;
    for (var i = 0; i < holes; i++) {
      if (board[i] == side + 1 && _isHome(side, i)) count++;
    }
    return count;
  }

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}移动 · 跳跃可连跳';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '十子全部进入对方营区';
  }

  @override
  String scoreText(int side) => '${_homeCount(side)} / 10 入营';

  List<int> _stepTargets(int from) =>
      [for (final n in neighborsOf[from]) if (board[n] == 0) n];

  List<int> _jumpTargets(int from) {
    final result = <int>[];
    final visited = <int>{from};
    final queue = <int>[from];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final n in neighborsOf[current]) {
        if (board[n] == 0) continue;
        final dx = xOf[n] - xOf[current];
        final dy = (rowOf[n] - rowOf[current]).toDouble();
        final target = coordToHole[_key(xOf[current] + dx * 2, rowOf[current] + (dy * 2).round())];
        if (target == null || board[target] != 0 || !visited.add(target)) continue;
        result.add(target);
        queue.add(target);
      }
    }
    return result;
  }

  List<int> destinations(int from) {
    if (board[from] != _side + 1) return const [];
    return [..._stepTargets(from), ..._jumpTargets(from)];
  }

  List<ChineseMove> _allMoves(int side) {
    final moves = <ChineseMove>[];
    for (var from = 0; from < holes; from++) {
      if (board[from] != side + 1) continue;
      final steps = _stepTargetsFor(side, from);
      final jumps = _jumpTargetsFor(side, from);
      for (final to in [...steps, ...jumps]) {
        moves.add(ChineseMove(from, to));
      }
    }
    return moves;
  }

  List<int> _stepTargetsFor(int side, int from) {
    if (board[from] != side + 1) return const [];
    return [for (final n in neighborsOf[from]) if (board[n] == 0) n];
  }

  List<int> _jumpTargetsFor(int side, int from) {
    if (board[from] != side + 1) return const [];
    final result = <int>[];
    final visited = <int>{from};
    final queue = <int>[from];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final n in neighborsOf[current]) {
        if (board[n] == 0) continue;
        final dx = xOf[n] - xOf[current];
        final dy = (rowOf[n] - rowOf[current]).toDouble();
        final target = coordToHole[_key(xOf[current] + dx * 2, rowOf[current] + (dy * 2).round())];
        if (target == null || board[target] != 0 || !visited.add(target)) continue;
        result.add(target);
        queue.add(target);
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! ChineseMove) return false;
    if (move.from < 0 || move.from >= holes || move.to < 0 || move.to >= holes) {
      return false;
    }
    if (board[move.from] != _side + 1 || board[move.to] != 0) return false;
    return _stepTargets(move.from).contains(move.to) ||
        _jumpTargets(move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as ChineseMove;
    _history.add(_snapshot());
    board[m.from] = 0;
    board[m.to] = _side + 1;
    _last = m.to;
    _moveCount++;
    if (_homeCount(_side) == 10) {
      _winner = _side;
      return;
    }
    _side = 1 - _side;
    if (_allMoves(_side).isEmpty) {
      _winner = 1 - _side;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < holes; i++) {
      board[i] = s.board[i];
    }
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _allMoves(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(ChineseMove, int)>[];
    for (final m in moves) {
      final progress = _side == 0 ? rowOf[m.to] : 16 - rowOf[m.to];
      var score = progress * 12;
      if (_isHome(_side, m.to)) score += 80;
      if (_isHome(_side, m.from) && !_isHome(_side, m.to)) score -= 50;
      if ((m.from - m.to).abs() > 1) score += 15;
      score += _homeCount(_side) * 20;
      if (level <= 0) score += random.nextInt(40);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _ChineseSnapshot _snapshot() => _ChineseSnapshot(
        List<int>.of(board),
        _side,
        _winner,
        _last,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < holes; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _allMoves(_side);

  @override
  String get llmState {
    final sb = StringBuffer(
      '中国跳棋，X=红方，O=蓝方，.=空。红方在顶部营区，蓝方在底部营区，'
      '先手红方。每回合移动一个己方棋子：走一格到相邻空位，或连续跳过相邻棋子落到后面的空位'
      '（可连跳、可转向，不能一次走加跳）。十子全部进入对方营区者胜。\n',
    );
    for (var r = 0; r < rowWidths.length; r++) {
      sb.write('y=$r: ');
      final width = rowWidths[r];
      final start = rowStarts[r];
      for (var c = 0; c < width; c++) {
        final value = board[start + c];
        sb.write(value == 0 ? '.' : (value == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! ChineseMove) return '$move';
    String p(int i) => '(y${rowOf[i]},c${i - rowStarts[rowOf[i]]})';
    return '${p(move.from)}→${p(move.to)}';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: '',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
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
    return ChineseCheckersBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _ChineseSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _ChineseSnapshot(this.board, this.side, this.winner, this.last, this.moveCount);
}

class ChineseCheckersBoard extends StatefulWidget {
  final ChineseCheckersGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const ChineseCheckersBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<ChineseCheckersBoard> createState() => _ChineseCheckersBoardState();
}

class _ChineseCheckersBoardState extends State<ChineseCheckersBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = min(size / 14.5, size / 18);
        final centerX = size / 2;
        final padY = (size - cell * 17) / 2;
        Offset at(int index) {
          final x = widget.flipped ? -game.xOf[index] : game.xOf[index];
          final y = widget.flipped ? 16 - game.rowOf[index] : game.rowOf[index];
          return Offset(centerX + x * cell, padY + (y + 0.5) * cell);
        }

        final pegs = <Widget>[];
        for (var i = 0; i < ChineseCheckersGame.holes; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final p = at(i);
          final disc = cell * 0.78;
          pegs.add(Positioned(
            left: p.dx - disc / 2,
            top: p.dy - disc / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(
              child: GameDisc(
                label: '',
                color: value == 1
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFF6C9BD8),
                background: value == 1
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFF6C9BD8),
                filled: true,
                size: disc,
              ),
            ),
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
                    for (var i = 0; i < ChineseCheckersGame.holes; i++) {
                      final d = (at(i) - details.localPosition).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    if (best < 0 || bestDist > cell * 0.65) return;
                    _tap(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChinesePainter(
                      game: game,
                      cell: cell,
                      centerX: centerX,
                      padY: padY,
                      flipped: widget.flipped,
                      selected: selected,
                      targets: targets,
                    ),
                  ),
                ),
                ...pegs,
              ],
            ),
          ),
        );
      },
    );
  }

  void _tap(int index) {
    final game = widget.game;
    if (selected != null && targets.contains(index)) {
      widget.onMove(ChineseMove(selected!, index));
      setState(() {
        selected = null;
        targets = const [];
      });
      return;
    }
    if (game.board[index] == game.side + 1) {
      setState(() {
        selected = index;
        targets = game.destinations(index);
      });
    } else {
      setState(() {
        selected = null;
        targets = const [];
      });
    }
  }
}

class _ChinesePainter extends CustomPainter {
  final ChineseCheckersGame game;
  final double cell;
  final double centerX;
  final double padY;
  final bool flipped;
  final int? selected;
  final List<int> targets;

  _ChinesePainter({
    required this.game,
    required this.cell,
    required this.centerX,
    required this.padY,
    required this.flipped,
    required this.selected,
    required this.targets,
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
          colors: [Color(0xFF1C3630), Color(0xFF0E201D)],
        ).createShader(rect),
    );
    Offset at(int index) {
      final x = flipped ? -game.xOf[index] : game.xOf[index];
      final y = flipped ? 16 - game.rowOf[index] : game.rowOf[index];
      return Offset(centerX + x * cell, padY + (y + 0.5) * cell);
    }

    final home0 = Paint()..color = const Color(0xFFD95B4E).withValues(alpha: 0.14);
    final home1 = Paint()..color = const Color(0xFF6C9BD8).withValues(alpha: 0.14);
    for (var i = 0; i < ChineseCheckersGame.holes; i++) {
      final p = at(i);
      final home = i < 10
          ? home0
          : (i >= ChineseCheckersGame.holes - 10 ? home1 : null);
      if (home != null) {
        canvas.drawCircle(p, cell * 0.53, home);
      }
      canvas.drawCircle(
        p,
        cell * 0.20,
        Paint()..color = const Color(0xFFB99564).withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        p,
        cell * 0.28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.20),
      );
    }
    void label(String text, Offset p, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color.withValues(alpha: 0.55),
            fontSize: cell * 0.5,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    if (!flipped) {
      label('红营', Offset(centerX, padY + cell * 0.2), const Color(0xFFD95B4E));
      label('蓝营', Offset(centerX, size.height - padY + cell * 0.2),
          const Color(0xFF6C9BD8));
    } else {
      label('蓝营', Offset(centerX, padY + cell * 0.2), const Color(0xFF6C9BD8));
      label('红营', Offset(centerX, size.height - padY + cell * 0.2),
          const Color(0xFFD95B4E));
    }
    for (final index in targets) {
      canvas.drawCircle(
        at(index),
        cell * 0.33,
        Paint()..color = const Color(0xFFE7BC6C).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      canvas.drawCircle(
        at(selected!),
        cell * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFFE7BC6C),
      );
    }
    if (game._last != null) {
      canvas.drawCircle(
        at(game._last!),
        cell * 0.38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB53D32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChinesePainter oldDelegate) => true;
}
