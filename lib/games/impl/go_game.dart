import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class GoGame extends TurnGame {
  final int size;
  late final List<int> board = List<int>.filled(size * size, 0);
  final List<_GoSnapshot> _history = [];
  int _side = 0;
  int _blackCaptures = 0;
  int _whiteCaptures = 0;
  int _passes = 0;
  int? _lastMove;
  int _moveCount = 0;
  List<int>? _koBoard;
  bool _over = false;
  int? _winner;
  double _blackScore = 0;
  double _whiteScore = 0;

  GoGame({this.size = 9});

  @override
  GameMeta get meta => GameCatalog.go;

  @override
  int get side => _side;

  @override
  bool get isOver => _over;

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
    if (_over) return resultTitle;
    if (_lastMove == -1) return '${sideName(1 - _side)}停一手';
    return '${sideName(_side)}落子';
  }

  @override
  String get resultTitle {
    if (!_over) return '';
    if (_winner == 2) return '和棋';
    final diff = (_blackScore - _whiteScore).abs();
    return '${sideName(_winner!)}胜 ${diff.toStringAsFixed(1)} 子';
  }

  @override
  String get resultSubtitle =>
      _over ? '黑 ${_blackScore.toStringAsFixed(1)} · 白 ${_whiteScore.toStringAsFixed(1)}（贴 6.5 子）' : '';

  @override
  String scoreText(int side) =>
      '提 ${side == 0 ? _blackCaptures : _whiteCaptures}';

  @override
  String? get primaryActionLabel => _over ? null : '停一手';

  @override
  IconData get primaryActionIcon => Icons.pan_tool_alt_rounded;

  @override
  bool isLegal(Object? move) {
    if (_over) return false;
    if (move == -1) return true;
    if (move is! int || move < 0 || move >= size * size) return false;
    return _wouldBeLegal(move);
  }

  bool _wouldBeLegal(int index) {
    if (board[index] != 0) return false;
    final simulated = _simulate(board, index, _side + 1);
    if (simulated == null) return false;
    if (_koBoard != null && _listEquals(simulated.board, _koBoard!)) {
      return false;
    }
    return true;
  }

  @override
  void apply(Object? move) {
    if (_over) return;
    if (move == -1) {
      _history.add(_snapshot());
      _passes++;
      _lastMove = -1;
      _moveCount++;
      _koBoard = null;
      if (_passes >= 2) {
        _finishByScore();
      } else {
        _side = 1 - _side;
      }
      return;
    }
    if (move is! int || !isLegal(move)) return;
    final before = List<int>.of(board);
    final simulated = _simulate(board, move, _side + 1);
    if (simulated == null) return;
    _history.add(_snapshot());
    for (var i = 0; i < board.length; i++) {
      board[i] = simulated.board[i];
    }
    if (_side == 0) {
      _blackCaptures += simulated.captures;
    } else {
      _whiteCaptures += simulated.captures;
    }
    _passes = 0;
    _koBoard = before;
    _lastMove = move;
    _moveCount++;
    _side = 1 - _side;
  }

  @override
  void primaryAction() {
    apply(-1);
  }

  void resign(int side) {
    if (_over) return;
    _over = true;
    _winner = 1 - side;
    _blackScore = _countStones(1).toDouble();
    _whiteScore = _countStones(2).toDouble();
    _lastMove = null;
  }

  void _finishByScore() {
    _over = true;
    _lastMove = null;
    final result = _score();
    _blackScore = result.$1;
    _whiteScore = result.$2 + 6.5;
    if ((_blackScore - _whiteScore).abs() < 0.01) {
      _winner = 2;
    } else {
      _winner = _blackScore > _whiteScore ? 0 : 1;
    }
  }

  int _countStones(int player) {
    var count = 0;
    for (final value in board) {
      if (value == player) count++;
    }
    return count;
  }

  (double, double) _score() {
    final visited = List<bool>.filled(board.length, false);
    var black = 0.0;
    var white = 0.0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] == 1) black++;
      if (board[i] == 2) white++;
      if (board[i] != 0 || visited[i]) continue;
      final region = <int>[];
      final queue = <int>[i];
      visited[i] = true;
      var touchesBlack = false;
      var touchesWhite = false;
      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        region.add(index);
        for (final neighbor in _neighbors(index)) {
          final value = board[neighbor];
          if (value == 1) touchesBlack = true;
          if (value == 2) touchesWhite = true;
          if (value == 0 && !visited[neighbor]) {
            visited[neighbor] = true;
            queue.add(neighbor);
          }
        }
      }
      if (touchesBlack && !touchesWhite) {
        black += region.length;
      } else if (touchesWhite && !touchesBlack) {
        white += region.length;
      }
    }
    return (black, white);
  }

  _Simulation? _simulate(List<int> source, int index, int player) {
    if (source[index] != 0) return null;
    final next = List<int>.of(source);
    next[index] = player;
    final opponent = 3 - player;
    var captures = 0;
    for (final neighbor in _neighbors(index)) {
      if (next[neighbor] != opponent) continue;
      final group = _group(next, neighbor);
      if (_liberties(next, group).isEmpty) {
        for (final stone in group) {
          next[stone] = 0;
        }
        captures += group.length;
      }
    }
    final ownGroup = _group(next, index);
    if (_liberties(next, ownGroup).isEmpty) return null;
    return _Simulation(next, captures);
  }

  List<int> _group(List<int> source, int start) {
    final group = <int>[start];
    final seen = <int>{start};
    for (var i = 0; i < group.length; i++) {
      for (final neighbor in _neighbors(group[i])) {
        if (source[neighbor] == source[start] && seen.add(neighbor)) {
          group.add(neighbor);
        }
      }
    }
    return group;
  }

  List<int> _liberties(List<int> source, List<int> group) {
    final liberties = <int>[];
    final seen = <int>{};
    for (final stone in group) {
      for (final neighbor in _neighbors(stone)) {
        if (source[neighbor] == 0 && seen.add(neighbor)) {
          liberties.add(neighbor);
        }
      }
    }
    return liberties;
  }

  List<int> _neighbors(int index) {
    final x = index % size;
    final y = index ~/ size;
    final result = <int>[];
    if (x > 0) result.add(index - 1);
    if (x < size - 1) result.add(index + 1);
    if (y > 0) result.add(index - size);
    if (y < size - 1) result.add(index + size);
    return result;
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  _GoSnapshot _snapshot() => _GoSnapshot(
        List<int>.of(board),
        _side,
        _blackCaptures,
        _whiteCaptures,
        _passes,
        _lastMove,
        _moveCount,
        _koBoard == null ? null : List<int>.of(_koBoard!),
        _over,
        _winner,
        _blackScore,
        _whiteScore,
      );

  void _restore(_GoSnapshot snapshot) {
    for (var i = 0; i < board.length; i++) {
      board[i] = snapshot.board[i];
    }
    _side = snapshot.side;
    _blackCaptures = snapshot.blackCaptures;
    _whiteCaptures = snapshot.whiteCaptures;
    _passes = snapshot.passes;
    _lastMove = snapshot.lastMove;
    _moveCount = snapshot.moveCount;
    _koBoard = snapshot.koBoard == null ? null : List<int>.of(snapshot.koBoard!);
    _over = snapshot.over;
    _winner = snapshot.winner;
    _blackScore = snapshot.blackScore;
    _whiteScore = snapshot.whiteScore;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    _restore(_history.removeLast());
  }

  @override
  Object? aiMove(int level) {
    if (_over) return -1;
    final me = _side + 1;
    final opponent = 3 - me;
    final random = Random();
    final candidates = <MapEntry<int, double>>[];
    final lastX = _lastMove != null && _lastMove! >= 0 ? _lastMove! % size : null;
    final lastY = _lastMove != null && _lastMove! >= 0 ? _lastMove! ~/ size : null;
    var hasLegal = false;
    for (var index = 0; index < board.length; index++) {
      if (board[index] != 0) continue;
      if (_isEye(index, me)) continue;
      final simulated = _simulate(board, index, me);
      if (simulated == null) continue;
      if (_koBoard != null && _listEquals(simulated.board, _koBoard!)) continue;
      hasLegal = true;
      final group = _group(simulated.board, index);
      final liberties = _liberties(simulated.board, group).length;
      var score = simulated.captures * 22.0 + liberties * 2.5;
      final x = index % size;
      final y = index ~/ size;
      final edge = min(min(x, y), min(size - 1 - x, size - 1 - y));
      if (_moveCount < size * 2) {
        score += edge == 0 ? -4 : (edge == 1 ? 1 : 5);
        final center = (size - 1) / 2;
        score += 3 - ((x - center).abs() + (y - center).abs()) * 0.35;
      }
      if (lastX != null && lastY != null) {
        final distance = (x - lastX).abs() + (y - lastY).abs();
        score += distance <= 3 ? 1.8 : 0;
      }
      if (liberties == 1 && simulated.captures == 0) score -= 18;
      if (simulated.captures > 0) score += 6;
      if (level >= 2) {
        // Penalise moves that let the opponent capture a big group next turn.
        var worst = 0.0;
        for (var reply = 0; reply < board.length; reply += 1) {
          if (simulated.board[reply] != 0) continue;
          final response = _simulate(simulated.board, reply, opponent);
          if (response == null) continue;
          if (response.captures > worst) worst = response.captures.toDouble();
        }
        score -= worst * 14;
      }
      score += random.nextDouble() * (level <= 0 ? 20 : 1.2);
      candidates.add(MapEntry(index, score));
    }
    if (!hasLegal) return -1;
    candidates.sort((a, b) => b.value.compareTo(a.value));
    if (level <= 0) {
      final pool = candidates.take(max(1, min(8, candidates.length))).toList();
      return pool[random.nextInt(pool.length)].key;
    }
    final best = candidates.first;
    // In the endgame, pass instead of filling our own only remaining area.
    final empty = board.where((value) => value == 0).length;
    if (empty < size * size * 0.16 &&
        best.value < 8 &&
        level >= 2) {
      return -1;
    }
    return best.key;
  }

  bool _isEye(int index, int player) {
    final x = index % size;
    final y = index ~/ size;
    if (x > 0 && board[index - 1] != player) return false;
    if (x < size - 1 && board[index + 1] != player) return false;
    if (y > 0 && board[index - size] != player) return false;
    if (y < size - 1 && board[index + size] != player) return false;
    var diagonals = 0;
    for (final d in const [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (nx < 0 || nx >= size || ny < 0 || ny >= size) {
        diagonals++;
      } else if (board[ny * size + nx] == player) {
        diagonals++;
      }
    }
    return diagonals >= 3;
  }

  @override
  Map<String, Object?> toJson() => {
        'size': size,
        'board': List<int>.of(board),
        'side': _side,
        'blackCaptures': _blackCaptures,
        'whiteCaptures': _whiteCaptures,
        'passes': _passes,
        'last': _lastMove,
        'moveCount': _moveCount,
        'ko': _koBoard == null ? null : List<int>.of(_koBoard!),
        'over': _over,
        'winner': _winner,
        'blackScore': _blackScore,
        'whiteScore': _whiteScore,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final rawBoard = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < board.length; i++) {
      board[i] = i < rawBoard.length ? rawBoard[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _blackCaptures = (json['blackCaptures'] as num?)?.toInt() ?? 0;
    _whiteCaptures = (json['whiteCaptures'] as num?)?.toInt() ?? 0;
    _passes = (json['passes'] as num?)?.toInt() ?? 0;
    _lastMove = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    final ko = (json['ko'] as List?)?.cast<num>();
    _koBoard = ko?.map((e) => e.toInt()).toList();
    _over = json['over'] == true;
    _winner = (json['winner'] as num?)?.toInt();
    _blackScore = (json['blackScore'] as num?)?.toDouble() ?? 0;
    _whiteScore = (json['whiteScore'] as num?)?.toDouble() ?? 0;
    _history.clear();
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
    return GoBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      hint: hint is int ? hint : null,
    );
  }
}

class _Simulation {
  final List<int> board;
  final int captures;

  _Simulation(this.board, this.captures);
}

class _GoSnapshot {
  final List<int> board;
  final int side;
  final int blackCaptures;
  final int whiteCaptures;
  final int passes;
  final int? lastMove;
  final int moveCount;
  final List<int>? koBoard;
  final bool over;
  final int? winner;
  final double blackScore;
  final double whiteScore;

  _GoSnapshot(
    this.board,
    this.side,
    this.blackCaptures,
    this.whiteCaptures,
    this.passes,
    this.lastMove,
    this.moveCount,
    this.koBoard,
    this.over,
    this.winner,
    this.blackScore,
    this.whiteScore,
  );
}

class GoBoard extends StatelessWidget {
  final GoGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final int? hint;

  const GoBoard({
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
        final n = game.size;
        final padding = size / (n + 1) * 0.72;
        final cell = (size - padding * 2) / (n - 1);
        final stone = cell * 0.9;
        final stones = <Widget>[];
        for (var i = 0; i < game.board.length; i++) {
          if (game.board[i] == 0) continue;
          final x = i % n;
          final y = i ~/ n;
          stones.add(Positioned(
            left: padding + x * cell - stone / 2,
            top: padding + y * cell - stone / 2,
            width: stone,
            height: stone,
            child: IgnorePointer(
              child: GameStone(white: game.board[i] == 2, size: stone),
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
              if (x < 0 || x >= n || y < 0 || y >= n) return;
              final index = y * n + x;
              if (game.isLegal(index)) onMove(index);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GoPainter(
                      size: n,
                      cell: cell,
                      padding: padding,
                      lastMove: game._lastMove,
                      hint: hint,
                    ),
                  ),
                ),
                ...stones,
                if (hint != null && game.board[hint!] == 0)
                  Positioned(
                    left: padding + (hint! % n) * cell - stone / 2,
                    top: padding + (hint! ~/ n) * cell - stone / 2,
                    width: stone,
                    height: stone,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold,
                            width: 2,
                          ),
                          color: AppColors.gold.withValues(alpha: 0.16),
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

class _GoPainter extends CustomPainter {
  final int size;
  final double cell;
  final double padding;
  final int? lastMove;
  final int? hint;

  _GoPainter({
    required this.size,
    required this.cell,
    required this.padding,
    required this.lastMove,
    required this.hint,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final rect = Offset.zero & canvasSize;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE2C08A), Color(0xFFC99E62)],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = const Color(0xFF5B3F24).withValues(alpha: 0.8)
      ..strokeWidth = 1.1;
    for (var i = 0; i < size; i++) {
      final offset = padding + i * cell;
      canvas.drawLine(
        Offset(padding, offset),
        Offset(canvasSize.width - padding, offset),
        grid,
      );
      canvas.drawLine(
        Offset(offset, padding),
        Offset(offset, canvasSize.height - padding),
        grid,
      );
    }
    final stars = size == 9
        ? const [
            [2, 2],
            [6, 2],
            [4, 4],
            [2, 6],
            [6, 6],
          ]
        : const [
            [3, 3],
            [9, 3],
            [6, 6],
            [3, 9],
            [9, 9],
          ];
    final starPaint = Paint()..color = const Color(0xFF51381F);
    for (final star in stars) {
      canvas.drawCircle(
        Offset(padding + star[0] * cell, padding + star[1] * cell),
        cell * 0.11,
        starPaint,
      );
    }
    if (lastMove != null && lastMove! >= 0) {
      final index = lastMove!;
      final center = Offset(
        padding + (index % size) * cell,
        padding + (index ~/ size) * cell,
      );
      canvas.drawCircle(
        center,
        cell * 0.28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.gold.withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoPainter oldDelegate) => true;
}
