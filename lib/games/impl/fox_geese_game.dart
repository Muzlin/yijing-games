import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class FoxMove {
  final int from;
  final int to;
  const FoxMove(this.from, this.to);
  @override
  String toString() => 'FoxMove($from,$to)';
}

/// Fox and Geese on a 33-point cross board. The fox (side 0) tries to eat
/// five geese; the geese (side 1) try to trap the fox.
class FoxGeeseGame extends TurnGame {
  static const int size = 7;
  static const int cells = 49;
  static const List<List<int>> _validList = [
    [2, 3, 4],
    [9, 10, 11],
    [14, 15, 16, 17, 18, 19, 20],
    [21, 22, 23, 24, 25, 26, 27],
    [28, 29, 30, 31, 32, 33, 34],
    [37, 38, 39],
    [44, 45, 46],
  ];
  static final Set<int> valid = {
    for (final row in _validList) ...row,
  };

  final List<int> board = List<int>.filled(cells, 0);
  final List<_FoxSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _captured = 0;
  int _moveCount = 0;

  FoxGeeseGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    board[3 * 7 + 3] = 1;
    for (final i in [..._validList[0], ..._validList[1], ..._validList[2]]) {
      board[i] = 2;
    }
    _side = 0;
    _winner = null;
    _last = null;
    _captured = 0;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.foxGeese;

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
  String sideName(int side) => side == 0 ? '狐狸' : '鹅群';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}行动';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return _winner == 0 ? '狐狸胜' : '鹅群胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return _winner == 0 ? '狐狸吃掉五只鹅' : '狐狸被围困';
  }

  @override
  String scoreText(int side) =>
      side == 0 ? '已吃 $_captured / 5' : '剩余 ${_geeseCount()} 鹅';

  int _geeseCount() => board.where((v) => v == 2).length;

  bool _onBoard(int x, int y) =>
      x >= 0 && x < 7 && y >= 0 && y < 7 && valid.contains(y * 7 + x);

  List<int> _targetsFor(int side, int from) {
    if (board[from] != side + 1) return const [];
    final x = from % 7;
    final y = from ~/ 7;
    final result = <int>[];
    for (final d in const [[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (side == 1 && ny < y) continue; // geese never move up
      if (!_onBoard(nx, ny)) continue;
      if (board[ny * 7 + nx] == 0) result.add(ny * 7 + nx);
      if (side == 0) {
        final jx = x + d[0] * 2;
        final jy = y + d[1] * 2;
        if (_onBoard(jx, jy) &&
            board[ny * 7 + nx] == 2 &&
            board[jy * 7 + jx] == 0) {
          result.add(jy * 7 + jx);
        }
      }
    }
    return result;
  }

  List<FoxMove> _allMoves() {
    final result = <FoxMove>[];
    for (var i = 0; i < cells; i++) {
      if (board[i] != _side + 1) continue;
      for (final to in _targetsFor(_side, i)) {
        result.add(FoxMove(i, to));
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! FoxMove) return false;
    if (move.from < 0 || move.from >= cells || move.to < 0 || move.to >= cells) {
      return false;
    }
    return board[move.from] == _side + 1 &&
        board[move.to] == 0 &&
        _targetsFor(_side, move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as FoxMove;
    _history.add(_snapshot());
    final fromX = m.from % 7;
    final fromY = m.from ~/ 7;
    final toX = m.to % 7;
    final toY = m.to ~/ 7;
    if (_side == 0 &&
        (toX - fromX).abs() == 2 &&
        (toY - fromY).abs() <= 2) {
      final mx = (fromX + toX) ~/ 2;
      final my = (fromY + toY) ~/ 2;
      board[my * 7 + mx] = 0;
      _captured++;
    }
    board[m.from] = 0;
    board[m.to] = _side + 1;
    _last = m.to;
    _moveCount++;
    if (_captured >= 5) {
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
    _captured = s.captured;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _allMoves();
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(FoxMove, int)>[];
    for (final m in moves) {
      var score = 0;
      final jump = (m.to % 7 - m.from % 7).abs() == 2 ||
          (m.to ~/ 7 - m.from ~/ 7).abs() == 2;
      if (_side == 0 && jump) score += 500;
      if (_side == 1) {
        score += (m.to ~/ 7) * 8;
        score += 4 - (m.to % 7 - 3).abs();
      } else {
        score += (m.to ~/ 7) * 4;
      }
      if (level <= 0) score += random.nextInt(25);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 3 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _FoxSnapshot _snapshot() => _FoxSnapshot(
        List<int>.of(board),
        _side,
        _winner,
        _last,
        _captured,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'captured': _captured,
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
    _captured = (json['captured'] as num?)?.toInt() ?? 0;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _allMoves();

  @override
  String get llmState {
    final sb = StringBuffer(
      '7x7 十字形狐狸与鹅（33 个点）。F=狐狸（先手），G=鹅。狐狸每次走一格，'
      '或跳过相邻的一只鹅落到后面的空格并吃掉它；鹅只能向下或横走一格。'
      '狐狸吃 5 只鹅获胜；鹅把狐狸围住（狐狸无合法着法）获胜。\n',
    );
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 7; c++) {
        final i = r * 7 + c;
        if (!valid.contains(i)) {
          sb.write('  ');
          continue;
        }
        final v = board[i];
        sb.write(v == 0 ? '.' : (v == 1 ? 'F' : 'G'));
        sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! FoxMove) return '$move';
    String p(int i) => '(${i % 7},${i ~/ 7})';
    return '${p(move.from)}→${p(move.to)}';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '狐' : '鹅',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFFF6F0E4),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFFF6F0E4),
        filled: true,
        size: size,
        fontSize: size * 0.34,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return FoxGeeseBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _FoxSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final int captured;
  final int moveCount;

  _FoxSnapshot(this.board, this.side, this.winner, this.last, this.captured,
      this.moveCount);
}

class FoxGeeseBoard extends StatefulWidget {
  final FoxGeeseGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const FoxGeeseBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<FoxGeeseBoard> createState() => _FoxGeeseBoardState();
}

class _FoxGeeseBoardState extends State<FoxGeeseBoard> {
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 7;
        final disc = cell * 0.66;
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
                label: v == 1 ? '狐' : '鹅',
                color: v == 1 ? const Color(0xFFD95B4E) : const Color(0xFFF6F0E4),
                background:
                    v == 1 ? const Color(0xFFD95B4E) : const Color(0xFFF6F0E4),
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
                    painter: _FoxPainter(
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
    if (!FoxGeeseGame.valid.contains(index)) return;
    if (selected != null && targets.contains(index)) {
      widget.onMove(FoxMove(selected!, index));
      setState(() {
        selected = null;
        targets = const [];
      });
      return;
    }
    if (game.board[index] == game.side + 1) {
      setState(() {
        selected = index;
        targets = game._targetsFor(game.side, index);
      });
    } else {
      setState(() {
        selected = null;
        targets = const [];
      });
    }
  }
}

class _FoxPainter extends CustomPainter {
  final FoxGeeseGame game;
  final double cell;
  final bool flipped;
  final int? selected;
  final List<int> targets;

  _FoxPainter({
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
    final fill = Paint()..color = const Color(0xFFD2AC77);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.45);
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 7; c++) {
        final i = r * 7 + c;
        if (!FoxGeeseGame.valid.contains(i)) continue;
        final vx = flipped ? 6 - c : c;
        final vy = flipped ? 6 - r : r;
        final rr = Rect.fromLTWH(vx * cell + 1, vy * cell + 1, cell - 2, cell - 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rr, Radius.circular(cell * 0.12)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rr, Radius.circular(cell * 0.12)),
          border,
        );
      }
    }
    for (final index in targets) {
      final r = index ~/ 7;
      final c = index % 7;
      final vx = flipped ? 6 - c : c;
      final vy = flipped ? 6 - r : r;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.15,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final r = selected! ~/ 7;
      final c = selected! % 7;
      final vx = flipped ? 6 - c : c;
      final vy = flipped ? 6 - r : r;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.29,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FoxPainter oldDelegate) => true;
}
