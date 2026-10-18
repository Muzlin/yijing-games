import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class BackgammonMove {
  final int from; // -1 = bar
  final int to; // -1 = off (side 0), 24 = off (side 1)
  final int die;
  const BackgammonMove(this.from, this.to, this.die);
  bool get isPass => from == -9;
  @override
  String toString() => 'BackgammonMove($from,$to,$die)';
}

class BackgammonGame extends TurnGame {
  final List<int> board = List<int>.filled(24, 0);
  final List<int> bar = [0, 0];
  final List<int> off = [0, 0];
  final List<_BackgammonSnapshot> _history = [];
  final Random _random = Random();
  int _side = 0;
  int? _winner;
  List<int> _dice = [];
  bool _awaiting = false;
  int _moveCount = 0;

  BackgammonGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, 24, 0);
    bar[0] = bar[1] = 0;
    off[0] = off[1] = 0;
    // White (side 0) moves 24 -> 1; black (side 1) moves 1 -> 24.
    board[23] = 2;
    board[12] = 5;
    board[7] = 3;
    board[5] = 5;
    board[0] = -2;
    board[11] = -5;
    board[16] = -3;
    board[18] = -5;
    _side = 0;
    _winner = null;
    _dice = [];
    _awaiting = false;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.backgammon;

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
  bool get llmSupported => false;

  @override
  String sideName(int side) => side == 0 ? '白方' : '黑方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_dice.isNotEmpty) return '${sideName(_side)}行棋 · 剩余点数 ${_dice.join(' / ')}';
    return '${sideName(_side)}掷骰子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '十五枚棋子全部离盘';
  }

  @override
  String scoreText(int side) => '离盘 ${off[side]} · 棋盘 ${_count(side)}';

  int _count(int side) {
    var count = bar[side];
    for (final value in board) {
      if (side == 0 && value > 0) count += value;
      if (side == 1 && value < 0) count += -value;
    }
    return count;
  }

  List<int> get dice => List<int>.unmodifiable(_dice);

  @override
  String? get primaryActionLabel => _dice.isEmpty ? '掷骰子' : null;
  @override
  IconData get primaryActionIcon => Icons.casino_rounded;

  @override
  void primaryAction() {
    if (isOver || _dice.isNotEmpty) return;
    _dice = [for (var i = 0; i < 2; i++) _random.nextInt(6) + 1];
    if (_dice[0] == _dice[1]) {
      _dice = [_dice[0], _dice[0], _dice[0], _dice[0]];
    }
    _awaiting = _legalMoves(_side).isNotEmpty;
    if (!_awaiting) {
      _dice = [];
      _side = 1 - _side;
    }
  }

  bool _inHome(int side, int index) =>
      side == 0 ? index >= 0 && index <= 5 : index >= 18 && index <= 23;

  bool _allHome(int side) {
    if (bar[side] != 0) return false;
    for (var i = 0; i < 24; i++) {
      final v = board[i];
      if (side == 0 && v > 0 && !_inHome(0, i)) return false;
      if (side == 1 && v < 0 && !_inHome(1, i)) return false;
    }
    return true;
  }

  bool _canLand(int side, int index) {
    if (index < 0 || index >= 24) return false;
    final v = board[index];
    return side == 0 ? v >= -1 : v <= 1;
  }

  bool _canBearOff(int side, int from, int die) {
    if (!_allHome(side)) return false;
    if (side == 0) {
      final target = from - die;
      if (target >= 0) return false;
      if (from + 1 == die) return true;
      for (var i = from + 1; i <= 5; i++) {
        if (board[i] > 0) return false;
      }
      return true;
    } else {
      final target = from + die;
      if (target <= 23) return false;
      if (24 - from == die) return true;
      for (var i = 18; i < from; i++) {
        if (board[i] < 0) return false;
      }
      return true;
    }
  }

  List<BackgammonMove> legalMoves() => _legalMoves(_side);

  List<BackgammonMove> _legalMoves(int side) {
    final result = <BackgammonMove>[];
    final seen = <String>{};
    final dice = _dice.toSet();
    void add(int from, int to, int die) {
      final key = '$from:$to:$die';
      if (seen.add(key)) result.add(BackgammonMove(from, to, die));
    }

    if (bar[side] > 0) {
      for (final die in dice) {
        final to = side == 0 ? 24 - die : die - 1;
        if (_canLand(side, to)) add(-1, to, die);
      }
      return result;
    }
    for (var from = 0; from < 24; from++) {
      final v = board[from];
      if (side == 0 && v <= 0) continue;
      if (side == 1 && v >= 0) continue;
      for (final die in dice) {
        final to = from + (side == 0 ? -die : die);
        if (to < 0 || to >= 24) {
          if (_canBearOff(side, from, die)) add(from, side == 0 ? -1 : 24, die);
        } else if (_canLand(side, to)) {
          add(from, to, die);
        }
      }
    }
    return result;
  }

  /// Targets available from [from] for the currently selected checker.
  List<int> targetsFor(int from) {
    final result = <int>{};
    for (final m in _legalMoves(_side)) {
      if (m.from == from) result.add(m.to);
    }
    return result.toList();
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! BackgammonMove) return false;
    if (move.isPass) return _legalMoves(_side).isEmpty;
    if (move.die < 1 || move.die > 6 || !_dice.contains(move.die)) return false;
    return _legalMoves(_side)
        .any((m) => m.from == move.from && m.to == move.to && m.die == move.die);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as BackgammonMove;
    _history.add(_snapshot());
    if (m.isPass) {
      _dice = [];
      _awaiting = false;
      _side = 1 - _side;
      return;
    }
    final side = _side;
    _dice.remove(m.die);
    _moveCount++;
    if (m.from < 0) {
      bar[side]--;
    } else {
      board[m.from] -= side == 0 ? 1 : -1;
    }
    if (m.to < 0 || m.to >= 24) {
      off[side]++;
    } else {
      final target = board[m.to];
      if (side == 0 && target == -1) {
        board[m.to] = 0;
        bar[1]++;
      } else if (side == 1 && target == 1) {
        board[m.to] = 0;
        bar[0]++;
      }
      board[m.to] += side == 0 ? 1 : -1;
    }
    if (off[side] >= 15) {
      _winner = side;
      return;
    }
    _awaiting = _legalMoves(side).isNotEmpty;
    if (!_awaiting) {
      _dice = [];
      _side = 1 - _side;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < 24; i++) {
      board[i] = s.board[i];
    }
    bar[0] = s.bar0;
    bar[1] = s.bar1;
    off[0] = s.off0;
    off[1] = s.off1;
    _side = s.side;
    _winner = s.winner;
    _dice = List<int>.of(s.dice);
    _awaiting = s.awaiting;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    if (_dice.isEmpty) {
      _dice = [for (var i = 0; i < 2; i++) _random.nextInt(6) + 1];
      if (_dice[0] == _dice[1]) {
        _dice = [_dice[0], _dice[0], _dice[0], _dice[0]];
      }
    }
    final moves = _legalMoves(_side);
    if (moves.isEmpty) return const BackgammonMove(-9, -9, 0);
    final scored = <(BackgammonMove, int)>[];
    for (final m in moves) {
      var score = 0;
      if (m.to < 0 || m.to >= 24) score += 900;
      if (m.from < 0) score += 120;
      if (m.to >= 0 && m.to < 24) {
        final target = board[m.to];
        if (_side == 0 && target == -1) score += 500;
        if (_side == 1 && target == 1) score += 500;
        score += _side == 0 ? (23 - m.to) : m.to;
      }
      if (level <= 0) score += _random.nextInt(30);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 3 : 1).toList();
    return pool[_random.nextInt(pool.length)].$1;
  }

  _BackgammonSnapshot _snapshot() => _BackgammonSnapshot(
        List<int>.of(board),
        bar[0],
        bar[1],
        off[0],
        off[1],
        _side,
        _winner,
        List<int>.of(_dice),
        _awaiting,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'bar': List<int>.of(bar),
        'off': List<int>.of(off),
        'side': _side,
        'winner': _winner,
        'dice': List<int>.of(_dice),
        'awaiting': _awaiting,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 24; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    final b = (json['bar'] as List?)?.cast<num>() ?? const [];
    bar[0] = b.isNotEmpty ? b[0].toInt() : 0;
    bar[1] = b.length > 1 ? b[1].toInt() : 0;
    final o = (json['off'] as List?)?.cast<num>() ?? const [];
    off[0] = o.isNotEmpty ? o[0].toInt() : 0;
    off[1] = o.length > 1 ? o[1].toInt() : 0;
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    final d = (json['dice'] as List?)?.cast<num>() ?? const [];
    _dice = d.map((e) => e.toInt()).toList();
    _awaiting = json['awaiting'] == true;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => const [];

  @override
  String get llmState {
    final sb = StringBuffer(
      '双陆棋（Backgammon）：白方从 24 点向 1 点移动，黑方从 1 点向 24 点移动，'
      '双方各 15 子。掷两枚骰子，可分别移动；掷出对子时可走四次。'
      '不能落在对方两子以上的点；落在单子上把对方打回中线，必须先重新入场。'
      '十五子全部离盘者胜。\n',
    );
    for (var i = 23; i >= 0; i--) {
      final v = board[i];
      sb.write('point ${i + 1}: ${v == 0 ? '.' : (v > 0 ? 'W$v' : 'B${-v}')}\n');
    }
    sb.write('bar W${bar[0]} B${bar[1]}；off W${off[0]} B${off[1]}；'
        '轮到${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! BackgammonMove) return '$move';
    if (move.isPass) return '无子可动';
    String p(int i) => i < 0 ? (i == -9 ? '无' : '中线') : (i >= 24 ? '离盘' : '${i + 1}点');
    return '${p(move.from)}→${p(move.to)}（${move.die}）';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: '',
        color: side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22),
        background:
            side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22),
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
    return BackgammonBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _BackgammonSnapshot {
  final List<int> board;
  final int bar0;
  final int bar1;
  final int off0;
  final int off1;
  final int side;
  final int? winner;
  final List<int> dice;
  final bool awaiting;
  final int moveCount;

  _BackgammonSnapshot(this.board, this.bar0, this.bar1, this.off0, this.off1,
      this.side, this.winner, this.dice, this.awaiting, this.moveCount);
}

class BackgammonBoard extends StatefulWidget {
  final BackgammonGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const BackgammonBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<BackgammonBoard> createState() => _BackgammonBoardState();
}

class _BackgammonBoardState extends State<BackgammonBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = min(constraints.maxHeight, width * 0.78);
        final pointW = width / 12.7;
        final barW = width * 0.055;
        final left = barW * 0.15;
        final topH = height * 0.44;
        final bottomY = height * 0.56;
        final checker = min(pointW, height * 0.075) * 0.82;

        Offset pointTop(int index) {
          final side = index < 12 ? 0 : 1;
          final local = index % 12;
          final vx = widget.flipped ? 11 - local : local;
          final x = left + vx * pointW + pointW / 2 + (side == 1 ? barW : 0);
          final y = side == 0 ? height * 0.44 : height * 0.56;
          return Offset(x, y);
        }

        final widgets = <Widget>[];
        for (var i = 0; i < 24; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final side = value > 0 ? 0 : 1;
          final count = value.abs();
          final base = pointTop(i);
          final upward = i < 12;
          for (var n = 0; n < count && n < 5; n++) {
            final y = base.dy + (upward ? 1 : -1) * (checker * 0.7 * n);
            widgets.add(Positioned(
              left: base.dx - checker / 2,
              top: y - checker / 2,
              width: checker,
              height: checker,
              child: IgnorePointer(
                child: GameStone(white: side == 0, size: checker),
              ),
            ));
          }
          if (count > 5) {
            widgets.add(Positioned(
              left: base.dx + checker * 0.5,
              top: base.dy + (upward ? checker * 3.2 : -checker * 3.2),
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
            ));
          }
        }

        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.interactive
                ? (details) {
                    final p = details.localPosition;
                    // Bar
                    if (p.dx < left + barW * 1.2) {
                      _tapBar();
                      return;
                    }
                    // Off tray on the right.
                    if (p.dx > width - barW * 1.4) {
                      _tapOff();
                      return;
                    }
                    var best = -1;
                    var bestDist = double.infinity;
                    for (var i = 0; i < 24; i++) {
                      final d = (pointTop(i) - p).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    if (best >= 0 && bestDist < pointW * 0.75) _tapPoint(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BackgammonPainter(
                      game: game,
                      width: width,
                      height: height,
                      pointW: pointW,
                      barW: barW,
                      left: left,
                      topH: topH,
                      bottomY: bottomY,
                      flipped: widget.flipped,
                      selected: selected,
                      targets: targets,
                    ),
                  ),
                ),
                ...widgets,
              ],
            ),
          ),
        );
      },
    );
  }

  void _tapBar() {
    final game = widget.game;
    if (game.bar[game.side] == 0) return;
    setState(() {
      selected = -1;
      targets = game.targetsFor(-1);
    });
  }

  void _tapOff() {
    if (selected == null) return;
    final game = widget.game;
    final offTarget = game.side == 0 ? -1 : 24;
    if (!targets.contains(offTarget)) return;
    _commit(offTarget);
  }

  void _tapPoint(int index) {
    final game = widget.game;
    if (selected == null) {
      final own = game.side == 0 ? game.board[index] > 0 : game.board[index] < 0;
      if (own) {
        setState(() {
          selected = index;
          targets = game.targetsFor(index);
        });
      }
      return;
    }
    if (targets.contains(index)) {
      _commit(index);
    } else {
      final own = game.side == 0 ? game.board[index] > 0 : game.board[index] < 0;
      setState(() {
        selected = own ? index : null;
        targets = own ? game.targetsFor(index) : const [];
      });
    }
  }

  void _commit(int to) {
    final game = widget.game;
    for (final m in game.legalMoves()) {
      if (m.from == selected && m.to == to) {
        widget.onMove(m);
        setState(() {
          selected = null;
          targets = const [];
        });
        return;
      }
    }
  }
}

class _BackgammonPainter extends CustomPainter {
  final BackgammonGame game;
  final double width;
  final double height;
  final double pointW;
  final double barW;
  final double left;
  final double topH;
  final double bottomY;
  final bool flipped;
  final int? selected;
  final List<int> targets;

  _BackgammonPainter({
    required this.game,
    required this.width,
    required this.height,
    required this.pointW,
    required this.barW,
    required this.left,
    required this.topH,
    required this.bottomY,
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
          colors: [Color(0xFF5A3523), Color(0xFF2A1710)],
        ).createShader(rect),
    );
    final dark = Paint()..color = const Color(0xFF24140E);
    final light = Paint()..color = const Color(0xFFE3C08A);
    final middle = Paint()..color = const Color(0xFF3D2318);

    Offset center(int index) {
      final side = index < 12 ? 0 : 1;
      final local = index % 12;
      final vx = flipped ? 11 - local : local;
      final x = left + vx * pointW + pointW / 2 + (side == 1 ? barW : 0);
      final y = side == 0 ? topH : bottomY;
      return Offset(x, y);
    }

    for (var i = 0; i < 24; i++) {
      final c = center(i);
      final upward = i < 12;
      final tipY = upward ? topH - pointW * 1.05 : bottomY + pointW * 1.05;
      final baseY = upward ? topH : bottomY;
      final path = Path()
        ..moveTo(c.dx - pointW * 0.42, baseY)
        ..lineTo(c.dx + pointW * 0.42, baseY)
        ..lineTo(c.dx, tipY)
        ..close();
      canvas.drawPath(path, i.isEven ? light : dark);
    }
    canvas.drawRect(
      Rect.fromLTWH(left, topH - pointW * 0.1, width - left * 2, pointW * 0.2),
      middle,
    );
    canvas.drawRect(
      Rect.fromLTWH(left + barW * 0.8, 0, barW * 0.9, height),
      Paint()..color = const Color(0xFF1A0E09),
    );
    // Bar checkers.
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < game.bar[side] && i < 5; i++) {
        final x = left + barW * 1.0;
        final y = side == 0 ? height * 0.40 - i * pointW * 0.38 : height * 0.60 + i * pointW * 0.38;
        canvas.drawCircle(
          Offset(x, y),
          pointW * 0.25,
          Paint()..color = side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22),
        );
      }
    }
    // Off trays.
    final tray = Rect.fromLTWH(width - barW * 1.2, 0, barW * 0.9, height);
    canvas.drawRect(tray, Paint()..color = const Color(0xFF1A0E09));
    for (var side = 0; side < 2; side++) {
      final text = TextPainter(
        text: TextSpan(
          text: '${side == 0 ? '白' : '黑'}\n${game.off[side]}',
          style: TextStyle(
            color: side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFFB9A58A),
            fontSize: pointW * 0.28,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(tray.center.dx - text.width / 2,
            side == 0 ? height * 0.25 : height * 0.70),
      );
    }
    for (final index in targets) {
      final c = index < 0 ? Offset(left + barW * 1.0, height * 0.5) : center(index);
      canvas.drawCircle(
        c,
        pointW * 0.28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
    if (selected != null) {
      final c = selected! < 0
          ? Offset(left + barW * 1.0, height * 0.5)
          : center(selected!);
      canvas.drawCircle(
        c,
        pointW * 0.31,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgammonPainter oldDelegate) => true;
}
