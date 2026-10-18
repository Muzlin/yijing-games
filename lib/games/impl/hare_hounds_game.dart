import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class HareMove {
  final int from;
  final int to;
  const HareMove(this.from, this.to);
  @override
  String toString() => 'HareMove($from,$to)';
}

/// Three hounds (side 1) try to trap the hare (side 0) on a 7x7 board.
/// The hare moves one square in any direction; hounds move one square down
/// or diagonally down. The hare wins by reaching the top row.
class HareHoundsGame extends TurnGame {
  static const int size = 7;
  static const int cells = 49;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_HareSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  HareHoundsGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    board[0 * 7 + 2] = 2;
    board[0 * 7 + 3] = 2;
    board[0 * 7 + 4] = 2;
    board[6 * 7 + 3] = 1;
    _side = 0;
    _winner = null;
    _last = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.hareHounds;

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
  String sideName(int side) => side == 0 ? '野兔' : '猎犬';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}行动';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return _winner == 0 ? '野兔胜' : '猎犬胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return _winner == 0 ? '野兔到达顶部' : '野兔被围困';
  }

  @override
  String scoreText(int side) => side == 0 ? '第 ${6 - _lastRow(1)} 行' : '三犬';

  int _lastRow(int side) {
    for (var i = cells - 1; i >= 0; i--) {
      if (board[i] == side + 1) return i ~/ 7;
    }
    return 0;
  }

  bool _onBoard(int x, int y) => x >= 0 && x < 7 && y >= 0 && y < 7;

  List<int> _targetsFrom(int from) {
    final side = board[from] == 1 ? 0 : 1;
    if (board[from] != side + 1) return const [];
    final x = from % 7;
    final y = from ~/ 7;
    final result = <int>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        if (side == 1 && dy < 0) continue; // hounds never move up
        final nx = x + dx;
        final ny = y + dy;
        if (_onBoard(nx, ny) && board[ny * 7 + nx] == 0) {
          result.add(ny * 7 + nx);
        }
      }
    }
    return result;
  }

  List<HareMove> _allMoves() {
    final result = <HareMove>[];
    for (var from = 0; from < cells; from++) {
      if (board[from] != _side + 1) continue;
      for (final to in _targetsFrom(from)) {
        result.add(HareMove(from, to));
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! HareMove) return false;
    if (move.from < 0 || move.from >= cells || move.to < 0 || move.to >= cells) {
      return false;
    }
    return board[move.from] == _side + 1 &&
        board[move.to] == 0 &&
        _targetsFrom(move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as HareMove;
    _history.add(_snapshot());
    board[m.from] = 0;
    board[m.to] = _side + 1;
    _last = m.to;
    _moveCount++;
    if (_side == 0 && m.to ~/ 7 == 0) {
      _winner = 0;
      return;
    }
    _side = 1 - _side;
    if (_allMoves().isEmpty) {
      _winner = 1 - _side;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    board.setAll(0, s.board);
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
    final scored = <(HareMove, int)>[];
    for (final m in moves) {
      var score = 0;
      if (_side == 0) {
        score += (6 - m.to ~/ 7) * 20;
        score += (m.to % 7 - 3).abs() * -2;
      } else {
        // Hounds prefer central positions that reduce the hare's exits.
        score += 30 - (m.to ~/ 7);
        score += (3 - (m.to % 7 - 3).abs()) * 4;
      }
      if (level <= 0) score += random.nextInt(20);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 3 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _HareSnapshot _snapshot() => _HareSnapshot(
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
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
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
      '7x7 野兔与猎犬。H=野兔（先在底部），D=三只猎犬（顶部）。'
      '野兔每次向任意方向走一格；猎犬只能向下或斜下走一格。'
      '野兔到达顶部获胜；猎犬把野兔围住（野兔无合法着法）获胜。\n',
    );
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 7; c++) {
        final v = board[r * 7 + c];
        sb.write(v == 0 ? '.' : (v == 1 ? 'H' : 'D'));
        sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! HareMove) return '$move';
    String p(int i) => '(${i % 7},${i ~/ 7})';
    return '${p(move.from)}→${p(move.to)}';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '兔' : '犬',
        color: side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFFB78A54),
        background:
            side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFFB78A54),
        filled: true,
        size: size,
        fontSize: size * 0.38,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return HareHoundsBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _HareSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _HareSnapshot(this.board, this.side, this.winner, this.last, this.moveCount);
}

class HareHoundsBoard extends StatefulWidget {
  final HareHoundsGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const HareHoundsBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<HareHoundsBoard> createState() => _HareHoundsBoardState();
}

class _HareHoundsBoardState extends State<HareHoundsBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 7;
        final disc = cell * 0.68;
        final pieces = <Widget>[];
        for (var i = 0; i < 49; i++) {
          final v = game.board[i];
          if (v == 0) continue;
          final row = i ~/ 7;
          final col = i % 7;
          final vx = widget.flipped ? 6 - col : col;
          final vy = widget.flipped ? 6 - row : row;
          pieces.add(Positioned(
            left: vx * cell + (cell - disc) / 2,
            top: vy * cell + (cell - disc) / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(
              child: GameDisc(
                label: v == 1 ? '兔' : '犬',
                color: v == 1 ? const Color(0xFFF6F0E4) : const Color(0xFFB78A54),
                background:
                    v == 1 ? const Color(0xFFF6F0E4) : const Color(0xFFB78A54),
                filled: true,
                size: disc,
                fontSize: disc * 0.38,
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
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 6);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 6);
                    final x = widget.flipped ? 6 - vx : vx;
                    final y = widget.flipped ? 6 - vy : vy;
                    _tap(y * 7 + x);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HarePainter(
                      game: game,
                      cell: cell,
                      flipped: widget.flipped,
                      selected: selected,
                      targets: targets,
                    ),
                  ),
                ),
                ...pieces,
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
      widget.onMove(HareMove(selected!, index));
      setState(() {
        selected = null;
        targets = const [];
      });
      return;
    }
    if (game.board[index] == game.side + 1) {
      setState(() {
        selected = index;
        targets = game._targetsFrom(index);
      });
    } else {
      setState(() {
        selected = null;
        targets = const [];
      });
    }
  }
}

class _HarePainter extends CustomPainter {
  final HareHoundsGame game;
  final double cell;
  final bool flipped;
  final int? selected;
  final List<int> targets;

  _HarePainter({
    required this.game,
    required this.cell,
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
          colors: [Color(0xFFD9C09A), Color(0xFFB78C5E)],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = const Color(0xFF5B3D22).withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var i = 1; i < 7; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    for (final index in targets) {
      final row = index ~/ 7;
      final col = index % 7;
      final vx = flipped ? 6 - col : col;
      final vy = flipped ? 6 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.16,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final row = selected! ~/ 7;
      final col = selected! % 7;
      final vx = flipped ? 6 - col : col;
      final vy = flipped ? 6 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HarePainter oldDelegate) => true;
}
