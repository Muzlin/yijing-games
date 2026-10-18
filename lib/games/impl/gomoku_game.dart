import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class GomokuGame extends TurnGame {
  static const int boardSize = 15;
  static const int cells = boardSize * boardSize;

  final List<int> board = List<int>.filled(cells, 0);
  final List<int> _history = [];
  int _side = 0;
  int? _winner;
  int? _lastMove;
  List<int> _winLine = const [];

  @override
  GameMeta get meta => GameCatalog.gomoku;

  @override
  int get side => _side;

  @override
  bool get isOver => _winner != null;

  @override
  int? get winner => _winner;

  @override
  int get moveCount => _history.length;

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  String sideName(int side) => side == 0 ? '黑方' : '白方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}落子';
  }

  @override
  String get resultTitle {
    if (_winner == 2) return '和棋';
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == 2) return '棋盘已满';
    if (_winner == null) return '';
    return '五子连珠';
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final value in board) {
      if (value == side + 1) count++;
    }
    return '$count 子';
  }

  @override
  bool isLegal(Object? move) {
    if (move is! int || move < 0 || move >= cells) return false;
    return !isOver && board[move] == 0;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final index = move as int;
    final player = _side + 1;
    board[index] = player;
    _history.add(index);
    _lastMove = index;
    final line = _findWin(index, player);
    if (line != null) {
      _winLine = line;
      _winner = _side;
    } else if (_history.length >= cells) {
      _winner = 2;
    } else {
      _side = 1 - _side;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final index = _history.removeLast();
    board[index] = 0;
    _winner = null;
    _winLine = const [];
    _side = _history.length.isEven ? 0 : 1;
    _lastMove = _history.isEmpty ? null : _history.last;
  }

  List<int>? _findWin(int index, int player) {
    final x = index % boardSize;
    final y = index ~/ boardSize;
    const directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];
    for (final direction in directions) {
      final line = <int>[index];
      for (final sign in const [-1, 1]) {
        var nx = x + direction[0] * sign;
        var ny = y + direction[1] * sign;
        while (nx >= 0 &&
            nx < boardSize &&
            ny >= 0 &&
            ny < boardSize &&
            board[ny * boardSize + nx] == player) {
          line.add(ny * boardSize + nx);
          nx += direction[0] * sign;
          ny += direction[1] * sign;
        }
      }
      if (line.length >= 5) {
        line.sort();
        return line;
      }
    }
    return null;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final me = _side + 1;
    final opponent = 2 - me;
    final empty = <int>[];
    var hasStone = false;
    for (var i = 0; i < cells; i++) {
      if (board[i] != 0) {
        hasStone = true;
        continue;
      }
      if (_nearStone(i)) empty.add(i);
    }
    if (empty.isEmpty) {
      return hasStone ? null : 112; // center
    }
    if (!hasStone) return 112;

    final random = Random();
    final scored = <MapEntry<int, int>>[];
    for (final index in empty) {
      board[index] = me;
      var own = _scorePoint(index, me);
      board[index] = opponent;
      final block = _scorePoint(index, opponent);
      board[index] = 0;
      final centerBonus = 12 - (((index % boardSize) - 7).abs() +
          ((index ~/ boardSize) - 7).abs());
      var score = own * 1.12 + block * 1.08 + centerBonus;
      if (level <= 0) {
        score += random.nextInt(2500);
      }
      scored.add(MapEntry(index, score.round()));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    if (scored.first.value >= 100000000) return scored.first.key;

    if (level >= 2 && scored.length > 1) {
      final shortlist = scored.take(level >= 3 ? 10 : 6).toList();
      var best = shortlist.first;
      var bestValue = -1e18;
      for (final candidate in shortlist) {
        board[candidate.key] = me;
        if (_findWin(candidate.key, me) != null) {
          board[candidate.key] = 0;
          return candidate.key;
        }
        int worst = 0;
        for (final reply in _nearbyEmpty()) {
          board[reply] = opponent;
          final value = _scorePoint(reply, opponent);
          board[reply] = 0;
          if (value > worst) worst = value;
        }
        board[candidate.key] = 0;
        final value = candidate.value - worst * 0.92;
        if (value > bestValue) {
          bestValue = value;
          best = candidate;
        }
      }
      return best.key;
    }

    final top = scored.first.value;
    final pool = scored
        .where((entry) => entry.value >= top - (level <= 0 ? 60000 : 0))
        .take(level <= 0 ? 5 : 1)
        .toList();
    return pool[random.nextInt(pool.length)].key;
  }

  bool _nearStone(int index) {
    final x = index % boardSize;
    final y = index ~/ boardSize;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (nx >= 0 &&
            nx < boardSize &&
            ny >= 0 &&
            ny < boardSize &&
            board[ny * boardSize + nx] != 0) {
          return true;
        }
      }
    }
    return false;
  }

  Iterable<int> _nearbyEmpty() sync* {
    for (var i = 0; i < cells; i++) {
      if (board[i] == 0 && _nearStone(i)) yield i;
    }
  }

  int _scorePoint(int index, int player) {
    final x = index % boardSize;
    final y = index ~/ boardSize;
    const directions = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];
    var total = 0;
    for (final direction in directions) {
      var count = 1;
      var open = 0;
      for (final sign in const [-1, 1]) {
        var nx = x + direction[0] * sign;
        var ny = y + direction[1] * sign;
        while (nx >= 0 &&
            nx < boardSize &&
            ny >= 0 &&
            ny < boardSize &&
            board[ny * boardSize + nx] == player) {
          count++;
          nx += direction[0] * sign;
          ny += direction[1] * sign;
        }
        if (nx >= 0 && nx < boardSize && ny >= 0 && ny < boardSize) {
          if (board[ny * boardSize + nx] == 0) open++;
        }
      }
      if (count >= 5) return 100000000;
      if (count == 4) {
        total += open == 2 ? 1200000 : (open == 1 ? 120000 : 0);
      } else if (count == 3) {
        total += open == 2 ? 18000 : (open == 1 ? 1600 : 0);
      } else if (count == 2) {
        total += open == 2 ? 900 : (open == 1 ? 160 : 0);
      } else {
        total += open == 2 ? 40 : 8;
      }

      // Broken patterns: score every 5-cell window containing the center.
      for (var offset = -4; offset <= 0; offset++) {
        var own = 0;
        var blocked = false;
        for (var step = 0; step < 5; step++) {
          final nx = x + direction[0] * (offset + step);
          final ny = y + direction[1] * (offset + step);
          if (nx < 0 || nx >= boardSize || ny < 0 || ny >= boardSize) {
            blocked = true;
            break;
          }
          final value = board[ny * boardSize + nx];
          if (value != 0 && value != player) {
            blocked = true;
            break;
          }
          if (value == player) own++;
        }
        if (!blocked && own > 0) {
          total += const [0, 6, 60, 700, 9000, 100000000][own];
        }
      }
    }
    return total;
  }

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'history': List<int>.of(_history),
        'side': _side,
        'winner': _winner,
        'last': _lastMove,
        'line': List<int>.of(_winLine),
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final rawBoard = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < rawBoard.length ? rawBoard[i].toInt() : 0;
    }
    _history
      ..clear()
      ..addAll((json['history'] as List?)?.cast<num>().map((e) => e.toInt()) ??
          const []);
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastMove = (json['last'] as num?)?.toInt();
    _winLine = (json['line'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ??
        const [];
  }

  @override
  List<Object?> get llmMoves => [
        for (var i = 0; i < cells; i++)
          if (board[i] == 0) i,
      ];

  @override
  String get llmState {
    final sb = StringBuffer(
      '15x15 五子棋，X=黑方，O=白方，.=空。坐标 (x,y)，y=0 是最上面一行。\n',
    );
    for (var y = 0; y < boardSize; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < boardSize; x++) {
        final value = board[y * boardSize + x];
        sb.write(value == 0 ? '.' : (value == 1 ? 'X' : 'O'));
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到 ${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    return '(${move % boardSize},${move ~/ boardSize})';
  }

  @override
  Widget sideBadge(int side, double size) => GameStone(
        white: side == 1,
        size: size,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return GomokuBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      hint: hint is int ? hint : null,
    );
  }
}

class GomokuBoard extends StatelessWidget {
  final GomokuGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final int? hint;

  const GomokuBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / GomokuGame.boardSize;
        final padding = cell * 0.5;
        final stoneSize = cell * 0.86;
        final stones = <Widget>[];
        for (var index = 0; index < GomokuGame.cells; index++) {
          final value = game.board[index];
          if (value == 0) continue;
          final x = index % GomokuGame.boardSize;
          final y = index ~/ GomokuGame.boardSize;
          stones.add(Positioned(
            left: padding + x * cell - stoneSize / 2,
            top: padding + y * cell - stoneSize / 2,
            width: stoneSize,
            height: stoneSize,
            child: IgnorePointer(
              child: GameStone(white: value == 2, size: stoneSize),
            ),
          ));
        }

        return SizedBox.square(
          dimension: size,
          child: BoardTapLayer(
            interactive: interactive,
            onTap: (local, boardSize) {
              final x = ((local.dx - padding) / cell).round();
              final y = ((local.dy - padding) / cell).round();
              if (x < 0 || x >= GomokuGame.boardSize) return;
              if (y < 0 || y >= GomokuGame.boardSize) return;
              final distance = Offset(
                padding + x * cell - local.dx,
                padding + y * cell - local.dy,
              ).distance;
              if (distance > cell * 0.62) return;
              final index = y * GomokuGame.boardSize + x;
              if (game.isLegal(index)) onMove(index);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GomokuPainter(
                      game: game,
                      cell: cell,
                      padding: padding,
                      hint: hint,
                    ),
                  ),
                ),
                ...stones,
                if (hint != null && game.board[hint!] == 0)
                  Positioned(
                    left: padding + (hint! % GomokuGame.boardSize) * cell -
                        stoneSize / 2,
                    top: padding + (hint! ~/ GomokuGame.boardSize) * cell -
                        stoneSize / 2,
                    width: stoneSize,
                    height: stoneSize,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold,
                            width: 2,
                          ),
                          color: AppColors.gold.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GomokuPainter extends CustomPainter {
  final GomokuGame game;
  final double cell;
  final double padding;
  final int? hint;

  _GomokuPainter({
    required this.game,
    required this.cell,
    required this.padding,
    required this.hint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0BE8B), Color(0xFFC79D66)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final grid = Paint()
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.72)
      ..strokeWidth = 1.1;
    for (var i = 0; i < GomokuGame.boardSize; i++) {
      final offset = padding + i * cell;
      canvas.drawLine(
        Offset(padding, offset),
        Offset(size.width - padding, offset),
        grid,
      );
      canvas.drawLine(
        Offset(offset, padding),
        Offset(offset, size.height - padding),
        grid,
      );
    }

    final starPaint = Paint()..color = const Color(0xFF5B3D22);
    const stars = [
      [3, 3],
      [11, 3],
      [7, 7],
      [3, 11],
      [11, 11],
    ];
    for (final star in stars) {
      canvas.drawCircle(
        Offset(padding + star[0] * cell, padding + star[1] * cell),
        cell * 0.10,
        starPaint,
      );
    }

    if (game._lastMove != null) {
      final index = game._lastMove!;
      final center = Offset(
        padding + (index % GomokuGame.boardSize) * cell,
        padding + (index ~/ GomokuGame.boardSize) * cell,
      );
      canvas.drawCircle(
        center,
        cell * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.gold.withValues(alpha: 0.9),
      );
    }

    if (game._winLine.isNotEmpty) {
      final first = game._winLine.first;
      final last = game._winLine.last;
      final start = Offset(
        padding + (first % GomokuGame.boardSize) * cell,
        padding + (first ~/ GomokuGame.boardSize) * cell,
      );
      final end = Offset(
        padding + (last % GomokuGame.boardSize) * cell,
        padding + (last ~/ GomokuGame.boardSize) * cell,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.35)
          ..strokeWidth = cell * 0.34
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = cell * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuPainter oldDelegate) => true;
}
