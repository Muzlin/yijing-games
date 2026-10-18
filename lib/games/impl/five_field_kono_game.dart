import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class KonoMove {
  final int from;
  final int to;
  const KonoMove(this.from, this.to);
  @override
  String toString() => 'KonoMove($from,$to)';
}

class FiveFieldKonoGame extends TurnGame {
  static const int size = 5;
  static const int cells = 25;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_KonoSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  FiveFieldKonoGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    for (var c = 0; c < 5; c++) {
      board[0 * 5 + c] = 2;
      board[4 * 5 + c] = 1;
    }
    _side = 0;
    _winner = null;
    _last = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.fiveFieldKono;

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
    return '${sideName(_side)}移动';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '五子全部到达对方底线';
  }

  @override
  String scoreText(int side) => '${_homeCount(side)} / 5 到达';

  int _homeCount(int side) {
    final row = side == 0 ? 0 : 4;
    var count = 0;
    for (var c = 0; c < 5; c++) {
      if (board[row * 5 + c] == side + 1) count++;
    }
    return count;
  }

  bool _onBoard(int x, int y) => x >= 0 && x < 5 && y >= 0 && y < 5;

  List<int> _targetsFrom(int from) {
    if (board[from] != _side + 1) return const [];
    final x = from % 5;
    final y = from ~/ 5;
    final result = <int>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (_onBoard(nx, ny) && board[ny * 5 + nx] == 0) {
          result.add(ny * 5 + nx);
        }
      }
    }
    return result;
  }

  List<KonoMove> _allMoves() {
    final result = <KonoMove>[];
    for (var from = 0; from < cells; from++) {
      if (board[from] != _side + 1) continue;
      for (final to in _targetsFrom(from)) {
        result.add(KonoMove(from, to));
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! KonoMove) return false;
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
    final m = move as KonoMove;
    _history.add(_snapshot());
    board[m.from] = 0;
    board[m.to] = _side + 1;
    _last = m.to;
    _moveCount++;
    if (_homeCount(_side) == 5) {
      _winner = _side;
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
    final scored = <(KonoMove, int)>[];
    for (final m in moves) {
      final targetRow = _side == 0 ? 0 : 4;
      final progress = 4 - (m.to ~/ 5 - targetRow).abs();
      final before = 4 - (m.from ~/ 5 - targetRow).abs();
      var score = (progress - before) * 30;
      if (m.to ~/ 5 == targetRow) score += 50;
      if (level <= 0) score += random.nextInt(20);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _KonoSnapshot _snapshot() => _KonoSnapshot(
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
      '五子飞（Five Field Kono）5x5。红方（X）从底部出发，蓝方（O）从顶部出发；'
      '每回合把一个己方棋子走到相邻空格（横竖斜均可），不能吃子；'
      '五子全部到达对方底线者胜。\n',
    );
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        final v = board[r * 5 + c];
        sb.write(v == 0 ? '.' : (v == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! KonoMove) return '$move';
    String p(int i) => '(${i % 5},${i ~/ 5})';
    return '${p(move.from)}→${p(move.to)}';
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
    return FiveFieldKonoBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _KonoSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _KonoSnapshot(this.board, this.side, this.winner, this.last, this.moveCount);
}

class FiveFieldKonoBoard extends StatefulWidget {
  final FiveFieldKonoGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const FiveFieldKonoBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<FiveFieldKonoBoard> createState() => _FiveFieldKonoBoardState();
}

class _FiveFieldKonoBoardState extends State<FiveFieldKonoBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 5;
        final disc = cell * 0.72;
        final pieces = <Widget>[];
        for (var i = 0; i < 25; i++) {
          final v = game.board[i];
          if (v == 0) continue;
          final row = i ~/ 5;
          final col = i % 5;
          final vx = widget.flipped ? 4 - col : col;
          final vy = widget.flipped ? 4 - row : row;
          pieces.add(Positioned(
            left: vx * cell + (cell - disc) / 2,
            top: vy * cell + (cell - disc) / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(
              child: GameStone(white: v == 2, size: disc),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.interactive
                ? (details) {
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 4);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 4);
                    final x = widget.flipped ? 4 - vx : vx;
                    final y = widget.flipped ? 4 - vy : vy;
                    _tap(y * 5 + x);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _KonoPainter(
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
      widget.onMove(KonoMove(selected!, index));
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

class _KonoPainter extends CustomPainter {
  final FiveFieldKonoGame game;
  final double cell;
  final bool flipped;
  final int? selected;
  final List<int> targets;

  _KonoPainter({
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
          colors: [Color(0xFFE0BE8B), Color(0xFFC79D66)],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    for (final index in targets) {
      final row = index ~/ 5;
      final col = index % 5;
      final vx = flipped ? 4 - col : col;
      final vy = flipped ? 4 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.20,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final row = selected! ~/ 5;
      final col = selected! % 5;
      final vx = flipped ? 4 - col : col;
      final vy = flipped ? 4 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.31,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KonoPainter oldDelegate) => true;
}
