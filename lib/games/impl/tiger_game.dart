import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

/// A compact 5x5 tiger-and-dogs hunt game.
///
/// The tiger (side 0) wins by eating four dogs; the dogs (side 1) win by
/// leaving the tiger without a legal move. All pieces move one orthogonal
/// step; the tiger may also jump over an adjacent dog into the empty square
/// directly behind it, removing that dog.
class TigerGame extends TurnGame {
  static const int size = 5;
  static const int cells = size * size;
  static const int tiger = 1;
  static const int dog = 2;
  static const int targetCaptures = 4;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_TigerSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _captured = 0;
  int _moveCount = 0;

  TigerGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    board[2] = tiger; // top centre
    for (var x = 0; x < 5; x++) {
      board[4 * 5 + x] = dog;
    }
    board[3 * 5 + 1] = dog;
    board[3 * 5 + 2] = dog;
    board[3 * 5 + 3] = dog;
    _side = 0;
    _winner = null;
    _last = null;
    _captured = 0;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.tiger;

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
  String sideName(int side) => side == 0 ? '虎方' : '犬方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}行动';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return _winner == 0 ? '虎方胜' : '犬方胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return _winner == 0 ? '老虎吃掉 $targetCaptures 只犬' : '老虎被围困';
  }

  @override
  String scoreText(int side) => side == 0
      ? '已吃 $_captured / $targetCaptures'
      : '剩余 ${_dogCount()} 犬';

  int _dogCount() {
    var count = 0;
    for (final value in board) {
      if (value == dog) count++;
    }
    return count;
  }

  bool _onBoard(int x, int y) => x >= 0 && x < size && y >= 0 && y < size;

  List<int> _legalFor(int side) {
    final result = <int>[];
    final piece = side == 0 ? tiger : dog;
    for (var i = 0; i < cells; i++) {
      if (board[i] != piece) continue;
      final x = i % size;
      final y = i ~/ size;
      for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (_onBoard(nx, ny) && board[ny * size + nx] == 0) {
          result.add(ny * size + nx);
        }
        if (side == 0) {
          final jx = x + d[0] * 2;
          final jy = y + d[1] * 2;
          if (_onBoard(jx, jy) &&
              board[ny * size + nx] == dog &&
              board[jy * size + jx] == 0) {
            result.add(jy * size + jx);
          }
        }
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! int || move < 0 || move >= cells) return false;
    return board[move] == 0 && _legalFor(_side).contains(move);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final to = move as int;
    _history.add(_snapshot());
    final piece = _side == 0 ? tiger : dog;
    var from = -1;
    for (var i = 0; i < cells; i++) {
      if (board[i] != piece) continue;
      if (_distanceOne(i, to) || (_side == 0 && _isJump(i, to))) {
        from = i;
        break;
      }
    }
    if (from < 0) return;
    if (_side == 0 && _isJump(from, to)) {
      final mx = (from % size + to % size) ~/ 2;
      final my = (from ~/ size + to ~/ size) ~/ 2;
      board[my * size + mx] = 0;
      _captured++;
    }
    board[from] = 0;
    board[to] = piece;
    _last = to;
    _moveCount++;
    if (_captured >= targetCaptures) {
      _winner = 0;
      return;
    }
    _side = 1 - _side;
    if (_legalFor(_side).isEmpty) {
      _winner = 1 - _side;
    }
  }

  bool _distanceOne(int from, int to) {
    final dx = (from % size - to % size).abs();
    final dy = (from ~/ size - to ~/ size).abs();
    return dx + dy == 1;
  }

  bool _isJump(int from, int to) {
    final dx = (from % size - to % size).abs();
    final dy = (from ~/ size - to ~/ size).abs();
    return dx + dy == 2 && (dx == 0 || dy == 0);
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < cells; i++) {
      board[i] = s.board[i];
    }
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _captured = s.captured;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _legalFor(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(int, int)>[];
    for (final move in moves) {
      final piece = _side == 0 ? tiger : dog;
      var from = -1;
      for (var i = 0; i < cells; i++) {
        if (board[i] == piece &&
            (_distanceOne(i, move) || (_side == 0 && _isJump(i, move)))) {
          from = i;
          break;
        }
      }
      if (from < 0) continue;
      final wasDog = _side == 0 && _isJump(from, move)
          ? board[((from ~/ size + move ~/ size) ~/ 2) * size +
              ((from % size + move % size) ~/ 2)]
          : 0;
      final old = board[move];
      board[from] = 0;
      board[move] = piece;
      if (wasDog != 0) {
        board[((from ~/ size + move ~/ size) ~/ 2) * size +
            ((from % size + move % size) ~/ 2)] = 0;
      }
      final tigerMoves = _legalFor(0).length;
      final dogMoves = _legalFor(1).length;
      var score = _side == 0
          ? (wasDog != 0 ? 1000 : 0) + tigerMoves * 6 - dogMoves
          : -tigerMoves * 8 + dogMoves * 2;
      if (_side == 1 && tigerMoves == 0) score += 100000;
      final cx = move % size;
      final cy = move ~/ size;
      if (_side == 0) score += 4 - ((cx - 2).abs() + (cy - 2).abs());
      board[move] = old;
      board[from] = piece;
      if (wasDog != 0) {
        board[((from ~/ size + move ~/ size) ~/ 2) * size +
            ((from % size + move % size) ~/ 2)] = dog;
      }
      if (level <= 0) score += random.nextInt(30);
      scored.add((move, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 3 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _TigerSnapshot _snapshot() => _TigerSnapshot(
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
  List<Object?> get llmMoves => _legalFor(_side);

  @override
  String get llmState {
    final sb = StringBuffer(
      '5x5 老虎棋，T=老虎（先手），D=犬，.=空。\n'
      '老虎每次走一格，或跳过相邻的一只犬落到后面的空格并吃掉它；犬每次走一格。\n'
      '老虎吃掉 4 只犬获胜；犬把老虎围住（老虎无合法着法）获胜。\n',
    );
    for (var y = 0; y < size; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < size; x++) {
        final value = board[y * size + x];
        sb.write(value == 0 ? '.' : (value == tiger ? 'T' : 'D'));
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}；老虎已吃 $_captured 只犬。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    return '(${move % size},${move ~/ size})';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '虎' : '犬',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFFE0B76A),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFFE0B76A),
        filled: true,
        size: size,
        fontSize: size * 0.42,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return TigerBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _TigerSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int? last;
  final int captured;
  final int moveCount;

  _TigerSnapshot(this.board, this.side, this.winner, this.last, this.captured,
      this.moveCount);
}

class TigerBoard extends StatelessWidget {
  final TigerGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const TigerBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 5;
        final disc = cell * 0.82;
        final pieces = <Widget>[];
        for (var i = 0; i < 25; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final row = i ~/ 5;
          final col = i % 5;
          final vx = flipped ? 4 - col : col;
          final vy = flipped ? 4 - row : row;
          pieces.add(Positioned(
            left: vx * cell + (cell - disc) / 2,
            top: vy * cell + (cell - disc) / 2,
            width: disc,
            height: disc,
            child: IgnorePointer(
              child: GameDisc(
                label: value == TigerGame.tiger ? '虎' : '犬',
                color: value == TigerGame.tiger
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFFE0B76A),
                background: value == TigerGame.tiger
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFFE0B76A),
                filled: true,
                size: disc,
                fontSize: disc * 0.44,
              ),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 4);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 4);
                    final x = flipped ? 4 - vx : vx;
                    final y = flipped ? 4 - vy : vy;
                    final index = y * 5 + x;
                    if (game.isLegal(index)) onMove(index);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TigerPainter(
                      game: game,
                      cell: cell,
                      flipped: flipped,
                      targets: game._legalFor(game.side),
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
}

class _TigerPainter extends CustomPainter {
  final TigerGame game;
  final double cell;
  final bool flipped;
  final List<int> targets;

  _TigerPainter({
    required this.game,
    required this.cell,
    required this.flipped,
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
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.5)
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
        cell * 0.18,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.42),
      );
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF3D6B54).withValues(alpha: 0.65),
      );
    }
    if (game._last != null) {
      final index = game._last!;
      final row = index ~/ 5;
      final col = index % 5;
      final vx = flipped ? 4 - col : col;
      final vy = flipped ? 4 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TigerPainter oldDelegate) => true;
}
