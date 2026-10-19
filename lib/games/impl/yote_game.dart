import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class YoteMove {
  final int from;
  final int to;
  const YoteMove(this.from, this.to);
  bool get isPlace => from < 0;
}

/// Yoté on a 5x6 board. Each side has 12 pieces in hand; a turn is either
/// placing a piece or moving one step / jumping an adjacent opponent.
class YoteGame extends TurnGame {
  static const int rows = 5;
  static const int cols = 6;
  static const int cells = 30;

  final List<int> board = List<int>.filled(cells, 0);
  final List<int> hand = [12, 12];
  final List<_YoteSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.yote;

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
    return hand[_side] > 0 ? '${sideName(_side)}布子或走子' : '${sideName(_side)}走子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '对方棋子被吃光或无法移动';
  }

  @override
  String scoreText(int side) =>
      '${board.where((v) => v == side + 1).length + hand[side]} 子 · 手 ${hand[side]}';

  bool _onBoard(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;

  List<int> _targetsFrom(int from) {
    if (board[from] != _side + 1) return const [];
    final x = from % cols;
    final y = from ~/ cols;
    final result = <int>[];
    for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (!_onBoard(nx, ny)) continue;
      final n = ny * cols + nx;
      if (board[n] == 0) result.add(n);
    }
    return result;
  }

  List<int> _jumpsFrom(int from) {
    final x = from % cols;
    final y = from ~/ cols;
    final result = <int>[];
    for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      final mx = x + d[0];
      final my = y + d[1];
      final tx = x + d[0] * 2;
      final ty = y + d[1] * 2;
      if (!_onBoard(mx, my) || !_onBoard(tx, ty)) continue;
      final mid = my * cols + mx;
      final to = ty * cols + tx;
      if (board[mid] == 2 - _side && board[to] == 0) result.add(to);
    }
    return result;
  }

  List<YoteMove> _allMoves() {
    final result = <YoteMove>[];
    if (hand[_side] > 0) {
      for (var i = 0; i < cells; i++) {
        if (board[i] == 0) result.add(YoteMove(-1, i));
      }
    }
    for (var i = 0; i < cells; i++) {
      if (board[i] != _side + 1) continue;
      for (final to in [..._targetsFrom(i), ..._jumpsFrom(i)]) {
        result.add(YoteMove(i, to));
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! YoteMove) return false;
    if (move.to < 0 || move.to >= cells || board[move.to] != 0) return false;
    if (move.isPlace) return hand[_side] > 0;
    if (board[move.from] != _side + 1) return false;
    return _targetsFrom(move.from).contains(move.to) ||
        _jumpsFrom(move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as YoteMove;
    _history.add(_snapshot());
    if (m.isPlace) {
      board[m.to] = _side + 1;
      hand[_side]--;
    } else {
      if (_jumpsFrom(m.from).contains(m.to)) {
        final mx = (m.from % cols + m.to % cols) ~/ 2;
        final my = (m.from ~/ cols + m.to ~/ cols) ~/ 2;
        board[my * cols + mx] = 0;
      }
      board[m.from] = 0;
      board[m.to] = _side + 1;
    }
    _last = m.to;
    _moveCount++;
    final other = 1 - _side;
    if (board.where((v) => v == other + 1).length + hand[other] == 0) {
      _winner = _side;
      return;
    }
    _side = other;
    if (_allMoves().isEmpty) _winner = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    board.setAll(0, s.board);
    hand[0] = s.hand0;
    hand[1] = s.hand1;
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _allMoves();
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(YoteMove, int)>[];
    for (final m in moves) {
      var score = 0;
      if (!m.isPlace && _jumpsFrom(m.from).contains(m.to)) score += 300;
      if (m.isPlace) score += 12;
      final y = m.to ~/ cols;
      score += (2 - (y - 2).abs()) * 3;
      if (level <= 0) score += random.nextInt(25);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _YoteSnapshot _snapshot() => _YoteSnapshot(
        List<int>.of(board),
        hand[0],
        hand[1],
        _side,
        _winner,
        _last,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'hand': List<int>.of(hand),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    final h = (json['hand'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 2; i++) {
      hand[i] = i < h.length ? h[i].toInt() : 12;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _allMoves();

  @override
  String get llmState {
    final sb = StringBuffer(
      '约特棋（Yoté）5x6，双方各 12 子；每回合可在空格布子，或把己方棋子走到相邻空格，'
      '或跳过相邻敌子落到后面空格并吃掉它。吃光对方或堵死对方者胜。\n',
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = board[r * cols + c];
        sb.write(v == 0 ? '.' : (v == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! YoteMove) return '$move';
    String p(int i) => '(${i % cols},${i ~/ cols})';
    return move.isPlace ? '布${p(move.to)}' : '${p(move.from)}→${p(move.to)}';
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
    return YoteBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _YoteSnapshot {
  final List<int> board;
  final int hand0;
  final int hand1;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _YoteSnapshot(this.board, this.hand0, this.hand1, this.side, this.winner,
      this.last, this.moveCount);
}

class YoteBoard extends StatefulWidget {
  final YoteGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const YoteBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<YoteBoard> createState() => _YoteBoardState();
}

class _YoteBoardState extends State<YoteBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = min(size / 6, size / 5.8);
        final boardW = cell * 6;
        final boardH = cell * 5;
        final ox = (size - boardW) / 2;
        final oy = (size - boardH) / 2;
        final disc = cell * 0.66;
        Offset at(int i) => Offset(
              ox + (i % 6) * cell + cell / 2,
              oy + (i ~/ 6) * cell + cell / 2,
            );
        final stones = <Widget>[];
        for (var i = 0; i < 30; i++) {
          final v = game.board[i];
          if (v == 0) continue;
          stones.add(Positioned(
            left: at(i).dx - disc / 2,
            top: at(i).dy - disc / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(child: GameStone(white: v == 2, size: disc)),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.interactive
                ? (details) {
                    final x = ((details.localPosition.dx - ox) / cell).floor().clamp(0, 5);
                    final y = ((details.localPosition.dy - oy) / cell).floor().clamp(0, 4);
                    _tap(y * 6 + x);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _YotePainter(
                      game: game,
                      cell: cell,
                      ox: ox,
                      oy: oy,
                      selected: selected,
                      targets: targets,
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
    if (game.hand[game.side] > 0 && game.board[i] == 0) {
      widget.onMove(YoteMove(-1, i));
      return;
    }
    if (selected != null && targets.contains(i)) {
      widget.onMove(YoteMove(selected!, i));
      setState(() {
        selected = null;
        targets = const [];
      });
      return;
    }
    if (game.board[i] == game.side + 1) {
      setState(() {
        selected = i;
        targets = [...game._targetsFrom(i), ...game._jumpsFrom(i)];
      });
    } else {
      setState(() {
        selected = null;
        targets = const [];
      });
    }
  }
}

class _YotePainter extends CustomPainter {
  final YoteGame game;
  final double cell;
  final double ox;
  final double oy;
  final int? selected;
  final List<int> targets;

  _YotePainter({
    required this.game,
    required this.cell,
    required this.ox,
    required this.oy,
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
          colors: [Color(0xFFE0BE8B), Color(0xFFC79D66)],
        ).createShader(rect),
    );
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 6; c++) {
        final rr = Rect.fromLTWH(ox + c * cell, oy + r * cell, cell, cell);
        canvas.drawRect(
          rr.deflate(1),
          Paint()..color = (r + c).isEven ? const Color(0xFFD2AC77) : const Color(0xFFC99D65),
        );
      }
    }
    for (final i in targets) {
      final c = Offset(ox + (i % 6) * cell + cell / 2, oy + (i ~/ 6) * cell + cell / 2);
      canvas.drawCircle(
        c,
        cell * 0.18,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final c = Offset(ox + (selected! % 6) * cell + cell / 2, oy + (selected! ~/ 6) * cell + cell / 2);
      canvas.drawCircle(
        c,
        cell * 0.31,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _YotePainter oldDelegate) => true;
}
