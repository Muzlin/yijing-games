import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class NineMove {
  final int from;
  final int to;
  const NineMove(this.from, this.to);
  @override
  String toString() => 'NineMove($from,$to)';
}

class NineMensMorrisGame extends TurnGame {
  static const int points = 24;
  static const List<Offset> coordinates = [
    Offset(0, 0), Offset(3, 0), Offset(6, 0), Offset(6, 3),
    Offset(6, 6), Offset(3, 6), Offset(0, 6), Offset(0, 3),
    Offset(1, 1), Offset(3, 1), Offset(5, 1), Offset(5, 3),
    Offset(5, 5), Offset(3, 5), Offset(1, 5), Offset(1, 3),
    Offset(2, 2), Offset(3, 2), Offset(4, 2), Offset(4, 3),
    Offset(4, 4), Offset(3, 4), Offset(2, 4), Offset(2, 3),
  ];
  static const List<List<int>> mills = [
    [0, 1, 2], [2, 3, 4], [4, 5, 6], [6, 7, 0],
    [8, 9, 10], [10, 11, 12], [12, 13, 14], [14, 15, 8],
    [16, 17, 18], [18, 19, 20], [20, 21, 22], [22, 23, 16],
    [1, 9, 17], [3, 11, 19], [5, 13, 21], [7, 15, 23],
  ];
  static const List<List<int>> links = [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 0],
    [8, 9], [9, 10], [10, 11], [11, 12], [12, 13], [13, 14],
    [14, 15], [15, 8],
    [16, 17], [17, 18], [18, 19], [19, 20], [20, 21], [21, 22],
    [22, 23], [23, 16],
    [1, 9], [9, 17], [3, 11], [11, 19], [5, 13], [13, 21],
    [7, 15], [15, 23],
  ];

  final List<int> board = List<int>.filled(points, 0);
  final List<int> placed = [0, 0];
  final List<_NineSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  bool _pendingRemove = false;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.nineMensMorris;

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

  int countOnBoard(int side) {
    var count = 0;
    for (final value in board) {
      if (value == side + 1) count++;
    }
    return count;
  }

  bool get _flying => placed[0] >= 9 && placed[1] >= 9 && countOnBoard(_side) == 3;

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_pendingRemove) return '${sideName(_side)}取子';
    if (placed[_side] < 9) {
      return '${sideName(_side)}布子 · 还剩 ${9 - placed[_side]} 子';
    }
    return _flying ? '${sideName(_side)}飞子' : '${sideName(_side)}走子';
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
  String scoreText(int side) =>
      '${countOnBoard(side)} 子 · 待布 ${9 - placed[side]}';

  bool _isMillAt(int index, int player) {
    for (final mill in mills) {
      if (mill.contains(index) && mill.every((p) => board[p] == player)) {
        return true;
      }
    }
    return false;
  }

  bool _isInMill(int index) {
    final player = board[index];
    if (player == 0) return false;
    for (final mill in mills) {
      if (mill.contains(index) && mill.every((p) => board[p] == player)) {
        return true;
      }
    }
    return false;
  }

  bool _canRemove(int index) {
    if (board[index] != 2 - _side) return false;
    if (!_isInMill(index)) return true;
    var allInMills = true;
    for (var i = 0; i < points; i++) {
      if (board[i] == 2 - _side && !_isInMill(i)) {
        allInMills = false;
        break;
      }
    }
    return allInMills;
  }

  List<int> _neighbors(int index) => [
        for (final link in links)
          if (link[0] == index) link[1] else if (link[1] == index) link[0],
      ];

  bool _hasMove(int side) {
    if (placed[side] < 9) return true;
    final own = countOnBoard(side);
    if (own < 3) return false;
    final flying = own == 3;
    for (var i = 0; i < points; i++) {
      if (board[i] != side + 1) continue;
      if (flying) {
        if (board.contains(0)) return true;
      } else {
        for (final n in _neighbors(i)) {
          if (board[n] == 0) return true;
        }
      }
    }
    return false;
  }

  List<Object?> _movesFor(int side) {
    final list = <Object?>[];
    if (_pendingRemove) {
      for (var i = 0; i < points; i++) {
        if (_canRemove(i)) list.add(NineMove(-1, i));
      }
      return list;
    }
    if (placed[side] < 9) {
      for (var i = 0; i < points; i++) {
        if (board[i] == 0) list.add(NineMove(-1, i));
      }
      return list;
    }
    final flying = countOnBoard(side) == 3;
    for (var i = 0; i < points; i++) {
      if (board[i] != side + 1) continue;
      if (flying) {
        for (var j = 0; j < points; j++) {
          if (board[j] == 0) list.add(NineMove(i, j));
        }
      } else {
        for (final n in _neighbors(i)) {
          if (board[n] == 0) list.add(NineMove(i, n));
        }
      }
    }
    return list;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! NineMove) return false;
    if (_pendingRemove) return move.to >= 0 && move.to < points && _canRemove(move.to);
    if (move.to < 0 || move.to >= points || board[move.to] != 0) return false;
    if (placed[_side] < 9) return true;
    if (move.from < 0 || move.from >= points || board[move.from] != _side + 1) {
      return false;
    }
    if (countOnBoard(_side) == 3) return true;
    return _neighbors(move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as NineMove;
    _history.add(_snapshot());
    if (_pendingRemove) {
      board[m.to] = 0;
      _pendingRemove = false;
      _last = m.to;
      _moveCount++;
      if (placed[1 - _side] >= 9 && countOnBoard(1 - _side) < 3) {
        _winner = _side;
        return;
      }
      _switchSide();
      return;
    }
    if (placed[_side] < 9) {
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
    _switchSide();
  }

  void _switchSide() {
    _side = 1 - _side;
    if (countOnBoard(_side) < 3 && placed[_side] >= 9) {
      _winner = 1 - _side;
      return;
    }
    if (!_hasMove(_side)) {
      _winner = 1 - _side;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < points; i++) {
      board[i] = s.board[i];
    }
    placed[0] = s.placed0;
    placed[1] = s.placed1;
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _pendingRemove = s.pendingRemove;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _movesFor(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    if (_pendingRemove) {
      final scored = <(NineMove, int)>[];
      for (final m in moves.cast<NineMove>()) {
        var score = _isInMill(m.to) ? 0 : 30;
        score += 10 - _neighbors(m.to).where((n) => board[n] == 2 - _side).length;
        scored.add((m, score));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final pool = scored.take(level <= 0 ? 3 : 1).toList();
      return pool[random.nextInt(pool.length)].$1;
    }
    final scored = <(NineMove, int)>[];
    for (final m in moves.cast<NineMove>()) {
      final from = m.from;
      final to = m.to;
      final old = board[to];
      final oldFrom = from >= 0 ? board[from] : 0;
      if (from >= 0) board[from] = 0;
      board[to] = _side + 1;
      var score = 0;
      if (_isMillAt(to, _side + 1)) score += 900;
      score += _neighbors(to).where((n) => board[n] == _side + 1).length * 8;
      score += 20 - (coordinates[to].dx + coordinates[to].dy).abs().round();
      if (from >= 0) {
        score += 3;
      }
      board[to] = old;
      if (from >= 0) board[from] = oldFrom;
      if (level <= 0) score += random.nextInt(80);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 5 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _NineSnapshot _snapshot() => _NineSnapshot(
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
        'pendingRemove': _pendingRemove,
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
    _pendingRemove = json['pendingRemove'] == true;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _movesFor(_side);

  @override
  String get llmState {
    final sb = StringBuffer(
      '九子棋（Nine Men\'s Morris）7x7 棋盘上的 24 个点。X=黑方，O=白方。\n'
      '黑方先布子，双方各 9 子；布完后走子。三子连成一线（横或竖）可吃掉对方一子，'
      '不能吃已成三连的棋子，除非对方所有棋子都在三连中。\n'
      '棋子少于 3 或无法移动者负；只剩 3 子时可以飞到任意空点。\n',
    );
    for (var y = 0; y < 7; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < 7; x++) {
        final index = coordinates.indexWhere((c) => c.dx == x && c.dy == y);
        if (index < 0) {
          sb.write('  ');
        } else {
          final value = board[index];
          sb.write(value == 0 ? '.' : (value == 1 ? 'X' : 'O'));
          sb.write(' ');
        }
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}；盘面 ${countOnBoard(_side)} 子，'
        '待布 ${9 - placed[_side]} 子。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! NineMove) return '$move';
    final to = coordinates[move.to];
    if (move.from < 0) {
      return _pendingRemove ? '取 (${to.dx.toInt()},${to.dy.toInt()})' : '下 (${to.dx.toInt()},${to.dy.toInt()})';
    }
    final from = coordinates[move.from];
    return '(${from.dx.toInt()},${from.dy.toInt()})→(${to.dx.toInt()},${to.dy.toInt()})';
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
    return NineMensMorrisBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _NineSnapshot {
  final List<int> board;
  final int placed0;
  final int placed1;
  final int side;
  final int? winner;
  final int? last;
  final bool pendingRemove;
  final int moveCount;

  _NineSnapshot(this.board, this.placed0, this.placed1, this.side, this.winner,
      this.last, this.pendingRemove, this.moveCount);
}

class NineMensMorrisBoard extends StatefulWidget {
  final NineMensMorrisGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const NineMensMorrisBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<NineMensMorrisBoard> createState() => _NineMensMorrisBoardState();
}

class _NineMensMorrisBoardState extends State<NineMensMorrisBoard> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 6.8;
        final pad = cell * 0.4;
        final stone = cell * 0.68;
        Offset at(int index) {
          final c = NineMensMorrisGame.coordinates[index];
          final x = widget.flipped ? 6 - c.dx : c.dx;
          final y = widget.flipped ? 6 - c.dy : c.dy;
          return Offset(pad + x * cell, pad + y * cell);
        }

        final stones = <Widget>[];
        for (var i = 0; i < 24; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final p = at(i);
          stones.add(Positioned(
            left: p.dx - stone / 2,
            top: p.dy - stone / 2,
            width: stone,
            height: stone,
            child: IgnorePointer(
              child: GameStone(white: value == 2, size: stone),
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
                    for (var i = 0; i < 24; i++) {
                      final d = (at(i) - details.localPosition).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    if (best < 0 || bestDist > cell * 0.62) return;
                    _tap(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NinePainter(
                      cell: cell,
                      pad: pad,
                      flipped: widget.flipped,
                      last: game._last,
                      selected: selected,
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

  void _tap(int index) {
    final game = widget.game;
    if (game._pendingRemove) {
      if (game._canRemove(index)) widget.onMove(NineMove(-1, index));
      return;
    }
    if (game.placed[game.side] < 9) {
      if (game.board[index] == 0) widget.onMove(NineMove(-1, index));
      return;
    }
    if (selected != null) {
      final move = NineMove(selected!, index);
      if (game.isLegal(move)) {
        widget.onMove(move);
        setState(() => selected = null);
        return;
      }
    }
    if (game.board[index] == game.side + 1) {
      setState(() => selected = index);
    } else {
      setState(() => selected = null);
    }
  }
}

class _NinePainter extends CustomPainter {
  final double cell;
  final double pad;
  final bool flipped;
  final int? last;
  final int? selected;

  _NinePainter({
    required this.cell,
    required this.pad,
    required this.flipped,
    required this.last,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE7C994), Color(0xFFC89A5E)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    Offset at(int index) {
      final c = NineMensMorrisGame.coordinates[index];
      final x = flipped ? 6 - c.dx : c.dx;
      final y = flipped ? 6 - c.dy : c.dy;
      return Offset(pad + x * cell, pad + y * cell);
    }

    final line = Paint()
      ..color = const Color(0xFF573B21)
      ..strokeWidth = max(1.4, cell * 0.055)
      ..strokeCap = StrokeCap.round;
    for (final link in NineMensMorrisGame.links) {
      canvas.drawLine(at(link[0]), at(link[1]), line);
    }
    final pointPaint = Paint()..color = const Color(0xFF4A301B);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(at(i), cell * 0.075, pointPaint);
    }
    if (selected != null) {
      canvas.drawCircle(
        at(selected!),
        cell * 0.30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFE7BC6C),
      );
    }
    if (last != null) {
      canvas.drawCircle(
        at(last!),
        cell * 0.29,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB53D32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NinePainter oldDelegate) => true;
}
