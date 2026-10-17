import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class XiangqiGame extends TurnGame {
  static const int cols = 9;
  static const int rows = 10;
  static const int cells = cols * rows;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_XiangqiSnapshot> _history = [];
  int _side = 0; // 0 red, 1 black
  int _noCapture = 0;
  int _moveCount = 0;
  int? _winner;
  int _lastMove = -1;

  static const List<String> _redNames = ['', '帅', '仕', '相', '马', '车', '炮', '兵'];
  static const List<String> _blackNames = ['', '将', '士', '象', '马', '车', '炮', '卒'];

  XiangqiGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    void put(int color, int row, int col, int type) {
      board[row * cols + col] = color * 16 + type;
    }

    const back = [5, 4, 3, 2, 1, 2, 3, 4, 5];
    for (var col = 0; col < 9; col++) {
      put(1, 0, col, back[col]);
      put(0, 9, col, back[col]);
    }
    put(1, 2, 1, 6);
    put(1, 2, 7, 6);
    put(0, 7, 1, 6);
    put(0, 7, 7, 6);
    for (final col in const [0, 2, 4, 6, 8]) {
      put(1, 3, col, 7);
      put(0, 6, col, 7);
    }
    _side = 0;
    _noCapture = 0;
    _moveCount = 0;
    _winner = null;
    _lastMove = -1;
    _history.clear();
  }

  int _colorOf(int piece) => piece == 0 ? -1 : piece ~/ 16;
  int _typeOf(int piece) => piece == 0 ? 0 : piece % 16;
  int _palaceMinRow(int color) => color == 0 ? 7 : 0;
  int _palaceMaxRow(int color) => color == 0 ? 9 : 2;
  bool _inPalace(int row, int col, int color) =>
      col >= 3 && col <= 5 && row >= _palaceMinRow(color) && row <= _palaceMaxRow(color);
  int _kingSquare(int color) {
    for (var i = 0; i < cells; i++) {
      final piece = board[i];
      if (piece != 0 && _colorOf(piece) == color && _typeOf(piece) == 1) {
        return i;
      }
    }
    return -1;
  }

  @override
  GameMeta get meta => GameCatalog.xiangqi;

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
  String sideName(int side) => side == 0 ? '红方' : '黑方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (isInCheck(_side)) return '${sideName(_side)}被将军';
    return '${sideName(_side)}走棋';
  }

  @override
  String get resultTitle {
    if (_winner == 2) return '和棋';
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == 2) return '长时间无吃子';
    if (_winner == null) return '';
    return '将死 / 无子可动';
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final piece in board) {
      if (piece != 0 && _colorOf(piece) == side) count++;
    }
    return '$count 子';
  }

  @override
  bool isLegal(Object? move) {
    if (move is! int) return false;
    final from = move ~/ cells;
    final to = move % cells;
    if (from < 0 || from >= cells || to < 0 || to >= cells) return false;
    final piece = board[from];
    if (piece == 0 || _colorOf(piece) != _side) return false;
    if (!_pseudoMovesFor(from, _side).contains(to)) return false;
    final undo = _make(from, to);
    final legal = !isInCheck(_side);
    _unmake(undo);
    return legal;
  }

  @override
  void apply(Object? move) {
    if (isOver || move is! int || !isLegal(move)) return;
    final from = move ~/ cells;
    final to = move % cells;
    _history.add(_snapshot());
    final captured = board[to];
    final mover = _side;
    _make(from, to);
    _noCapture = captured == 0 ? _noCapture + 1 : 0;
    _moveCount++;
    _lastMove = move;
    _side = 1 - _side;
    final moves = _allLegalMoves(_side);
    if (moves.isEmpty) {
      _winner = mover;
      return;
    }
    if (_noCapture >= 120) {
      _winner = 2;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    for (var i = 0; i < cells; i++) {
      board[i] = snapshot.board[i];
    }
    _side = snapshot.side;
    _noCapture = snapshot.noCapture;
    _moveCount = snapshot.moveCount;
    _winner = snapshot.winner;
    _lastMove = snapshot.lastMove;
  }

  _XiangqiUndo _make(int from, int to) {
    final captured = board[to];
    final undo = _XiangqiUndo(
      from,
      to,
      captured,
      _noCapture,
    );
    board[to] = board[from];
    board[from] = 0;
    return undo;
  }

  void _unmake(_XiangqiUndo undo) {
    board[undo.from] = board[undo.to];
    board[undo.to] = undo.captured;
  }

  bool isInCheck(int color) {
    final king = _kingSquare(color);
    if (king < 0) return true;
    return _isAttacked(king ~/ cols, king % cols, 1 - color);
  }

  bool _isAttacked(int row, int col, int by) {
    // King (adjacent orthogonal) and flying general.
    for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final r = row + d[0];
      final c = col + d[1];
      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      final piece = board[r * cols + c];
      if (piece != 0 && _colorOf(piece) == by && _typeOf(piece) == 1) {
        return true;
      }
    }

    // Pawn.
    if (by == 0) {
      if (row + 1 < rows) {
        final piece = board[(row + 1) * cols + col];
        if (piece != 0 && _colorOf(piece) == by && _typeOf(piece) == 7) {
          return true;
        }
      }
      for (final dc in const [-1, 1]) {
        final c = col + dc;
        if (c < 0 || c >= cols) continue;
        final piece = board[row * cols + c];
        if (piece != 0 &&
            _colorOf(piece) == by &&
            _typeOf(piece) == 7 &&
            (row >= 5 || (row * cols + c) ~/ cols <= 4)) {
          // A red pawn that has crossed the river can attack sideways.
          if (row <= 4) return true;
        }
      }
    } else {
      if (row - 1 >= 0) {
        final piece = board[(row - 1) * cols + col];
        if (piece != 0 && _colorOf(piece) == by && _typeOf(piece) == 7) {
          return true;
        }
      }
      for (final dc in const [-1, 1]) {
        final c = col + dc;
        if (c < 0 || c >= cols) continue;
        final piece = board[row * cols + c];
        if (piece != 0 &&
            _colorOf(piece) == by &&
            _typeOf(piece) == 7 &&
            row >= 5) {
          return true;
        }
      }
    }

    // Horse.
    const horseMoves = [
      [-2, -1], [-2, 1], [2, -1], [2, 1],
      [-1, -2], [1, -2], [-1, 2], [1, 2],
    ];
    for (final move in horseMoves) {
      final r = row + move[0];
      final c = col + move[1];
      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      final piece = board[r * cols + c];
      if (piece == 0 || _colorOf(piece) != by || _typeOf(piece) != 4) continue;
      final legRow = r + (move[0].abs() == 2 ? move[0] ~/ 2 : 0);
      final legCol = c + (move[1].abs() == 2 ? move[1] ~/ 2 : 0);
      if (board[legRow * cols + legCol] == 0) return true;
    }

    // Advisor.
    for (final d in const [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
      final r = row + d[0];
      final c = col + d[1];
      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      final piece = board[r * cols + c];
      if (piece != 0 && _colorOf(piece) == by && _typeOf(piece) == 2) {
        return true;
      }
    }

    // Elephant.
    for (final d in const [[-2, -2], [-2, 2], [2, -2], [2, 2]]) {
      final r = row + d[0];
      final c = col + d[1];
      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      final piece = board[r * cols + c];
      if (piece == 0 || _colorOf(piece) != by || _typeOf(piece) != 3) continue;
      final midRow = row + d[0] ~/ 2;
      final midCol = col + d[1] ~/ 2;
      if (board[midRow * cols + midCol] == 0) return true;
    }

    // Rook / cannon / flying general along files and ranks.
    for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      var r = row + d[0];
      var c = col + d[1];
      var screens = 0;
      while (r >= 0 && r < rows && c >= 0 && c < cols) {
        final piece = board[r * cols + c];
        if (piece != 0) {
          if (screens == 0) {
            if (_colorOf(piece) == by) {
              final type = _typeOf(piece);
              if (type == 5) return true; // rook
              if (type == 1 && (r - row).abs() + (c - col).abs() == 1) {
                return true;
              }
            }
            screens = 1;
          } else {
            if (_colorOf(piece) == by && _typeOf(piece) == 6) return true;
            break;
          }
        }
        r += d[0];
        c += d[1];
      }
    }

    // Flying general: the two kings facing on the same file.
    if (by != _colorOf(board[row * cols + col])) {
      // Only relevant when the target is a king; the caller passes a king sq.
    }
    final targetPiece = board[row * cols + col];
    if (targetPiece != 0 && _typeOf(targetPiece) == 1 && _colorOf(targetPiece) != by) {
      final enemyKing = _kingSquare(by);
      if (enemyKing >= 0 && enemyKing % cols == col) {
        final minRow = min(row, enemyKing ~/ cols) + 1;
        final maxRow = max(row, enemyKing ~/ cols);
        var blocked = false;
        for (var r = minRow; r < maxRow; r++) {
          if (board[r * cols + col] != 0) {
            blocked = true;
            break;
          }
        }
        if (!blocked) return true;
      }
    }

    return false;
  }

  List<int> _pseudoMovesFor(int from, int color) {
    final piece = board[from];
    if (piece == 0 || _colorOf(piece) != color) return const [];
    final type = _typeOf(piece);
    final row = from ~/ cols;
    final col = from % cols;
    final moves = <int>[];
    void add(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return;
      final target = board[r * cols + c];
      if (target != 0 && _colorOf(target) == color) return;
      moves.add(r * cols + c);
    }

    switch (type) {
      case 1: // king
        for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final r = row + d[0];
          final c = col + d[1];
          if (_inPalace(r, c, color)) add(r, c);
        }
        break;
      case 2: // advisor
        for (final d in const [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
          final r = row + d[0];
          final c = col + d[1];
          if (_inPalace(r, c, color)) add(r, c);
        }
        break;
      case 3: // elephant
        for (final d in const [[-2, -2], [-2, 2], [2, -2], [2, 2]]) {
          final r = row + d[0];
          final c = col + d[1];
          if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
          final ownHalf = color == 0 ? r >= 5 : r <= 4;
          if (!ownHalf) continue;
          if (board[(row + d[0] ~/ 2) * cols + (col + d[1] ~/ 2)] != 0) continue;
          add(r, c);
        }
        break;
      case 4: // horse
        const movesH = [
          [-2, -1], [-2, 1], [2, -1], [2, 1],
          [-1, -2], [1, -2], [-1, 2], [1, 2],
        ];
        for (final m in movesH) {
          final r = row + m[0];
          final c = col + m[1];
          if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
          final legRow = row + (m[0].abs() == 2 ? m[0] ~/ 2 : 0);
          final legCol = col + (m[1].abs() == 2 ? m[1] ~/ 2 : 0);
          if (board[legRow * cols + legCol] != 0) continue;
          add(r, c);
        }
        break;
      case 5: // rook
        for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          var r = row + d[0];
          var c = col + d[1];
          while (r >= 0 && r < rows && c >= 0 && c < cols) {
            final target = board[r * cols + c];
            if (target == 0) {
              moves.add(r * cols + c);
            } else {
              if (_colorOf(target) != color) moves.add(r * cols + c);
              break;
            }
            r += d[0];
            c += d[1];
          }
        }
        break;
      case 6: // cannon
        for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          var r = row + d[0];
          var c = col + d[1];
          var screen = false;
          while (r >= 0 && r < rows && c >= 0 && c < cols) {
            final target = board[r * cols + c];
            if (!screen) {
              if (target == 0) {
                moves.add(r * cols + c);
              } else {
                screen = true;
              }
            } else if (target != 0) {
              if (_colorOf(target) != color) moves.add(r * cols + c);
              break;
            }
            r += d[0];
            c += d[1];
          }
        }
        break;
      case 7: // pawn
        final forward = color == 0 ? row - 1 : row + 1;
        if (forward >= 0 && forward < rows) add(forward, col);
        final crossed = color == 0 ? row <= 4 : row >= 5;
        if (crossed) {
          add(row, col - 1);
          add(row, col + 1);
        }
        break;
    }
    return moves;
  }

  List<int> _allLegalMoves(int color) {
    final moves = <int>[];
    for (var i = 0; i < cells; i++) {
      final piece = board[i];
      if (piece == 0 || _colorOf(piece) != color) continue;
      for (final to in _pseudoMovesFor(i, color)) {
        final undo = _make(i, to);
        if (!isInCheck(color)) moves.add(i * cells + to);
        _unmake(undo);
      }
    }
    return moves;
  }

  List<int> legalTargets(int from) {
    final piece = board[from];
    if (piece == 0 || _colorOf(piece) != _side) return const [];
    final result = <int>[];
    for (final to in _pseudoMovesFor(from, _side)) {
      final undo = _make(from, to);
      if (!isInCheck(_side)) result.add(to);
      _unmake(undo);
    }
    return result;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    // Depth 3 keeps the master level responsive on mobile while still
    // searching captures and king safety several plies ahead.
    final depth = switch (level) {
      0 => 1,
      1 => 2,
      _ => 3,
    };
    final moves = _allLegalMoves(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    var bestMove = moves.first;
    var bestScore = -1000000;
    final scored = <(int, int)>[];
    for (final move in moves) {
      final from = move ~/ cells;
      final to = move % cells;
      final undo = _make(from, to);
      _side = 1 - _side;
      final score = -_search(depth - 1, -1000000, 1000000, 1);
      _side = 1 - _side;
      _unmake(undo);
      scored.add((move, score));
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    if (level == 0) {
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final pool = scored.take(max(1, min(4, scored.length))).toList();
      return pool[random.nextInt(pool.length)].$1;
    }
    return bestMove;
  }

  int _search(int depth, int alpha, int beta, int ply) {
    final moves = _allLegalMoves(_side);
    if (moves.isEmpty) return -100000 + ply;
    if (depth <= 0) return _evaluate();
    moves.sort((a, b) {
      final av = board[a % cells] == 0 ? 0 : _typeOf(board[a % cells]);
      final bv = board[b % cells] == 0 ? 0 : _typeOf(board[b % cells]);
      return bv.compareTo(av);
    });
    for (final move in moves) {
      final undo = _make(move ~/ cells, move % cells);
      _side = 1 - _side;
      final score = -_search(depth - 1, -beta, -alpha, ply + 1);
      _side = 1 - _side;
      _unmake(undo);
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return alpha;
  }

  int _evaluate() {
    var score = 0;
    for (var i = 0; i < cells; i++) {
      final piece = board[i];
      if (piece == 0) continue;
      final color = _colorOf(piece);
      final type = _typeOf(piece);
      var value = const [0, 10000, 200, 200, 400, 900, 450, 100][type];
      final row = i ~/ cols;
      final col = i % cols;
      if (type == 7) {
        final crossed = color == 0 ? row <= 4 : row >= 5;
        value += crossed ? 30 : 0;
        value += color == 0 ? (6 - row) * 8 : (row - 3) * 8;
      }
      if (type == 4 || type == 6) {
        value += (4 - (col - 4).abs()) * 3;
      }
      score += color == 0 ? value : -value;
    }
    return _side == 0 ? score : -score;
  }

  _XiangqiSnapshot _snapshot() => _XiangqiSnapshot(
        List<int>.of(board),
        _side,
        _noCapture,
        _moveCount,
        _winner,
        _lastMove,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'noCapture': _noCapture,
        'moveCount': _moveCount,
        'winner': _winner,
        'last': _lastMove,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _noCapture = (json['noCapture'] as num?)?.toInt() ?? 0;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastMove = (json['last'] as num?)?.toInt() ?? -1;
    _history.clear();
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '帅' : '将',
        color: side == 0 ? const Color(0xFFC94F43) : const Color(0xFF2B3138),
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
    return XiangqiBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _XiangqiUndo {
  final int from;
  final int to;
  final int captured;
  final int noCapture;

  _XiangqiUndo(this.from, this.to, this.captured, this.noCapture);
}

class _XiangqiSnapshot {
  final List<int> board;
  final int side;
  final int noCapture;
  final int moveCount;
  final int? winner;
  final int lastMove;

  _XiangqiSnapshot(this.board, this.side, this.noCapture, this.moveCount, this.winner, this.lastMove);
}

class XiangqiBoard extends StatefulWidget {
  final XiangqiGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const XiangqiBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<XiangqiBoard> createState() => _XiangqiBoardState();
}

class _XiangqiBoardState extends State<XiangqiBoard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = min(constraints.maxWidth / 9, constraints.maxHeight / 10);
        final width = cell * 9;
        final height = cell * 10;
        final padding = cell * 0.5;
        final pieceSize = cell * 0.86;
        final targets = _selected == null ? <int>[] : game.legalTargets(_selected!);
        final pieces = <Widget>[];

        Offset centerOf(int index) {
          final row = index ~/ 9;
          final col = index % 9;
          final vx = widget.flipped ? 8 - col : col;
          final vy = widget.flipped ? 9 - row : row;
          return Offset(padding + vx * cell, padding + vy * cell);
        }

        for (var i = 0; i < XiangqiGame.cells; i++) {
          final piece = game.board[i];
          if (piece == 0) continue;
          final center = centerOf(i);
          final color = game._colorOf(piece);
          final type = game._typeOf(piece);
          pieces.add(Positioned(
            left: center.dx - pieceSize / 2,
            top: center.dy - pieceSize / 2,
            width: pieceSize,
            height: pieceSize,
            child: IgnorePointer(
              child: GameDisc(
                label: color == 0
                    ? XiangqiGame._redNames[type]
                    : XiangqiGame._blackNames[type],
                color: color == 0
                    ? const Color(0xFFC94F43)
                    : const Color(0xFF2B3138),
                size: pieceSize,
                selected: _selected == i,
                fontSize: pieceSize * 0.42,
              ),
            ),
          ));
        }

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.interactive
                  ? (details) {
                      final vx = ((details.localPosition.dx - padding) / cell).round();
                      final vy = ((details.localPosition.dy - padding) / cell).round();
                      if (vx < 0 || vx > 8 || vy < 0 || vy > 9) return;
                      final col = widget.flipped ? 8 - vx : vx;
                      final row = widget.flipped ? 9 - vy : vy;
                      final index = row * 9 + col;
                      if (_selected != null && targets.contains(index)) {
                        final from = _selected!;
                        setState(() => _selected = null);
                        widget.onMove(from * 90 + index);
                        return;
                      }
                      final piece = game.board[index];
                      if (piece != 0 && game._colorOf(piece) == game.side) {
                        setState(() => _selected = index);
                      } else {
                        setState(() => _selected = null);
                      }
                    }
                  : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _XiangqiPainter(
                        game: game,
                        cell: cell,
                        padding: padding,
                        flipped: widget.flipped,
                        targets: targets,
                        selected: _selected,
                      ),
                    ),
                  ),
                  ...pieces,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _XiangqiPainter extends CustomPainter {
  final XiangqiGame game;
  final double cell;
  final double padding;
  final bool flipped;
  final List<int> targets;
  final int? selected;

  _XiangqiPainter({
    required this.game,
    required this.cell,
    required this.padding,
    required this.flipped,
    required this.targets,
    required this.selected,
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
          colors: [Color(0xFFE4C28D), Color(0xFFCB9F63)],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = const Color(0xFF5B3F24).withValues(alpha: 0.82)
      ..strokeWidth = 1.1;
    for (var col = 0; col < 9; col++) {
      final x = padding + col * cell;
      if (col == 0 || col == 8) {
        canvas.drawLine(Offset(x, padding), Offset(x, size.height - padding), grid);
      } else {
        canvas.drawLine(Offset(x, padding), Offset(x, padding + 4 * cell), grid);
        canvas.drawLine(Offset(x, padding + 5 * cell), Offset(x, size.height - padding), grid);
      }
    }
    for (var row = 0; row < 10; row++) {
      final y = padding + row * cell;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), grid);
    }
    final palace = Paint()
      ..color = const Color(0xFF5B3F24).withValues(alpha: 0.82)
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(padding + 3 * cell, padding),
      Offset(padding + 5 * cell, padding + 2 * cell),
      palace,
    );
    canvas.drawLine(
      Offset(padding + 5 * cell, padding),
      Offset(padding + 3 * cell, padding + 2 * cell),
      palace,
    );
    canvas.drawLine(
      Offset(padding + 3 * cell, padding + 7 * cell),
      Offset(padding + 5 * cell, padding + 9 * cell),
      palace,
    );
    canvas.drawLine(
      Offset(padding + 5 * cell, padding + 7 * cell),
      Offset(padding + 3 * cell, padding + 9 * cell),
      palace,
    );
    _text(
      canvas,
      '楚 河',
      Offset(padding + cell * 2.2, padding + 4.5 * cell),
      cell * 0.34,
      const Color(0xFF684728).withValues(alpha: 0.8),
    );
    _text(
      canvas,
      '汉 界',
      Offset(padding + cell * 5.7, padding + 4.5 * cell),
      cell * 0.34,
      const Color(0xFF684728).withValues(alpha: 0.8),
    );

    if (game._lastMove >= 0) {
      for (final index in [game._lastMove ~/ 90, game._lastMove % 90]) {
        final row = index ~/ 9;
        final col = index % 9;
        final vx = flipped ? 8 - col : col;
        final vy = flipped ? 9 - row : row;
        canvas.drawCircle(
          Offset(padding + vx * cell, padding + vy * cell),
          cell * 0.48,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.gold.withValues(alpha: 0.85),
        );
      }
    }
    for (final index in targets) {
      final row = index ~/ 9;
      final col = index % 9;
      final vx = flipped ? 8 - col : col;
      final vy = flipped ? 9 - row : row;
      final center = Offset(padding + vx * cell, padding + vy * cell);
      final occupied = game.board[index] != 0;
      if (occupied) {
        canvas.drawCircle(
          center,
          cell * 0.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.gold.withValues(alpha: 0.75),
        );
      } else {
        canvas.drawCircle(
          center,
          cell * 0.13,
          Paint()..color = const Color(0xFF4A2E16).withValues(alpha: 0.45),
        );
      }
    }
    if (selected != null) {
      final row = selected! ~/ 9;
      final col = selected! % 9;
      final vx = flipped ? 8 - col : col;
      final vy = flipped ? 9 - row : row;
      canvas.drawCircle(
        Offset(padding + vx * cell, padding + vy * cell),
        cell * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = AppColors.gold,
      );
    }
  }

  void _text(Canvas canvas, String value, Offset center, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _XiangqiPainter oldDelegate) => true;
}
