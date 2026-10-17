import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class JungleGame extends TurnGame {
  static const int cols = 7;
  static const int rows = 9;
  static const int cells = cols * rows;

  final List<int> board = List<int>.filled(cells, 0);
  final List<_JungleSnapshot> _history = [];
  int _side = 0; // 0 red (bottom), 1 blue (top)
  int _moveCount = 0;
  int _noCapture = 0;
  int? _winner;
  List<int> _lastMove = const [];

  static const List<int> _redDen = [8, 3];
  static const List<int> _blueDen = [0, 3];
  static const List<List<int>> _redTraps = [
    [8, 2],
    [8, 4],
    [7, 3],
  ];
  static const List<List<int>> _blueTraps = [
    [0, 2],
    [0, 4],
    [1, 3],
  ];
  static const List<List<int>> _river = [
    [3, 1], [3, 2], [4, 1], [4, 2], [5, 1], [5, 2],
    [3, 4], [3, 5], [4, 4], [4, 5], [5, 4], [5, 5],
  ];
  static const List<String> _names = ['', '鼠', '猫', '狗', '狼', '豹', '虎', '狮', '象'];

  JungleGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    void put(int color, int row, int col, int rank) {
      board[row * cols + col] = color * 16 + rank;
    }

    // Blue (top)
    put(1, 0, 0, 7);
    put(1, 0, 6, 6);
    put(1, 1, 1, 3);
    put(1, 1, 5, 2);
    put(1, 2, 0, 1);
    put(1, 2, 2, 5);
    put(1, 2, 4, 4);
    put(1, 2, 6, 8);
    // Red (bottom), 180° rotation
    put(0, 6, 0, 8);
    put(0, 6, 2, 4);
    put(0, 6, 4, 5);
    put(0, 6, 6, 1);
    put(0, 7, 1, 2);
    put(0, 7, 5, 3);
    put(0, 8, 0, 6);
    put(0, 8, 6, 7);
    _side = 0;
    _moveCount = 0;
    _noCapture = 0;
    _winner = null;
    _lastMove = const [];
    _history.clear();
  }

  int _colorOf(int piece) => piece == 0 ? -1 : piece ~/ 16;
  int _rankOf(int piece) => piece == 0 ? 0 : piece % 16;
  bool _isRiver(int row, int col) =>
      _river.any((cell) => cell[0] == row && cell[1] == col);
  bool _isTrap(int row, int col, int color) {
    final traps = color == 0 ? _redTraps : _blueTraps;
    return traps.any((cell) => cell[0] == row && cell[1] == col);
  }
  bool _isDen(int row, int col, int color) {
    final den = color == 0 ? _redDen : _blueDen;
    return den[0] == row && den[1] == col;
  }

  @override
  GameMeta get meta => GameCatalog.jungle;

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
    return '攻入兽穴';
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final piece in board) {
      if (piece != 0 && _colorOf(piece) == side) count++;
    }
    return '$count 子';
  }

  bool _canCapture(int attacker, int defender, int toRow, int toCol) {
    if (defender == 0) return true;
    final attackerColor = _colorOf(attacker);
    final defenderColor = _colorOf(defender);
    if (attackerColor == defenderColor) return false;
    // A defender standing in its own trap is defenceless.
    if (_isTrap(toRow, toCol, defenderColor)) return true;
    final a = _rankOf(attacker);
    final d = _rankOf(defender);
    if (a == 1 && d == 8) return true;
    if (a == 8 && d == 1) return false;
    return a >= d;
  }

  bool _canEnterRiver(int piece, int row, int col) {
    if (!_isRiver(row, col)) return true;
    return _rankOf(piece) == 1;
  }

  bool _isJump(int piece, int fromRow, int fromCol, int toRow, int toCol) {
    final rank = _rankOf(piece);
    if (rank != 6 && rank != 7) return false;
    if (fromRow != toRow && fromCol != toCol) return false;
    if ((fromRow - toRow).abs() + (fromCol - toCol).abs() <= 1) return false;
    if (fromRow == toRow) {
      final step = toCol > fromCol ? 1 : -1;
      var crossed = false;
      for (var col = fromCol + step; col != toCol; col += step) {
        if (!_isRiver(fromRow, col)) return false;
        crossed = true;
        final blocker = board[fromRow * cols + col];
        if (blocker != 0 && _rankOf(blocker) == 1) return false;
      }
      return crossed;
    }
    final step = toRow > fromRow ? 1 : -1;
    var crossed = false;
    for (var row = fromRow + step; row != toRow; row += step) {
      if (!_isRiver(row, fromCol)) return false;
      crossed = true;
      final blocker = board[row * cols + fromCol];
      if (blocker != 0 && _rankOf(blocker) == 1) return false;
    }
    return crossed;
  }

  bool _isLegalMove(int from, int to) {
    if (isOver) return false;
    if (from < 0 || from >= cells || to < 0 || to >= cells) return false;
    final piece = board[from];
    if (piece == 0 || _colorOf(piece) != _side) return false;
    final fromRow = from ~/ cols;
    final fromCol = from % cols;
    final toRow = to ~/ cols;
    final toCol = to % cols;
    if (from == to) return false;
    if (_isDen(toRow, toCol, _colorOf(piece))) return false;
    final jump = _isJump(piece, fromRow, fromCol, toRow, toCol);
    if (!jump &&
        ((fromRow - toRow).abs() + (fromCol - toCol).abs() != 1)) {
      return false;
    }
    if (!_canEnterRiver(piece, toRow, toCol)) return false;
    final target = board[to];
    if (target != 0 && !_canCapture(piece, target, toRow, toCol)) {
      return false;
    }
    return true;
  }

  @override
  bool isLegal(Object? move) {
    if (move is! List || move.length != 2) return false;
    return _isLegalMove(
      (move[0] as num).toInt(),
      (move[1] as num).toInt(),
    );
  }

  @override
  void apply(Object? move) {
    if (isLegal(move)) {
      final from = ((move as List)[0] as num).toInt();
      final to = (move[1] as num).toInt();
      _history.add(_snapshot());
      final piece = board[from];
      final captured = board[to];
      board[to] = piece;
      board[from] = 0;
      _lastMove = [from, to];
      _moveCount++;
      _noCapture = captured == 0 ? _noCapture + 1 : 0;
      final toRow = to ~/ cols;
      final toCol = to % cols;
      if (_isDen(toRow, toCol, 1 - _side)) {
        _winner = _side;
        return;
      }
      final opponent = 1 - _side;
      if (!_hasPieces(opponent)) {
        _winner = _side;
        return;
      }
      _side = opponent;
      if (!_hasAnyMove(opponent)) {
        _winner = 1 - opponent;
        return;
      }
      if (_noCapture >= 100) {
        _winner = 2;
      }
    }
  }

  bool _hasPieces(int color) {
    for (final piece in board) {
      if (piece != 0 && _colorOf(piece) == color) return true;
    }
    return false;
  }

  bool _hasAnyMove(int color) {
    final savedSide = _side;
    _side = color;
    for (var i = 0; i < cells; i++) {
      final piece = board[i];
      if (piece == 0 || _colorOf(piece) != color) continue;
      for (final j in _candidateTargets(i)) {
        if (_isLegalMove(i, j)) {
          _side = savedSide;
          return true;
        }
      }
    }
    _side = savedSide;
    return false;
  }

  List<int> _candidateTargets(int from) {
    final piece = board[from];
    if (piece == 0) return const [];
    final row = from ~/ cols;
    final col = from % cols;
    final targets = <int>[];
    for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final nr = row + d[0];
      final nc = col + d[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        targets.add(nr * cols + nc);
      }
    }
    final rank = _rankOf(piece);
    if (rank == 6 || rank == 7) {
      for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        var nr = row + d[0];
        var nc = col + d[1];
        var crossed = false;
        while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          if (!_isRiver(nr, nc)) break;
          crossed = true;
          final blocker = board[nr * cols + nc];
          if (blocker != 0 && _rankOf(blocker) == 1) {
            crossed = false;
            break;
          }
          nr += d[0];
          nc += d[1];
        }
        if (crossed && nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          targets.add(nr * cols + nc);
        }
      }
    }
    return targets;
  }

  Set<int> legalTargets(int from) {
    final result = <int>{};
    if (from < 0 || from >= cells) return result;
    if (board[from] == 0 || _colorOf(board[from]) != _side) return result;
    for (final to in _candidateTargets(from)) {
      if (_isLegalMove(from, to)) result.add(to);
    }
    return result;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    for (var i = 0; i < cells; i++) {
      board[i] = snapshot.board[i];
    }
    _side = snapshot.side;
    _moveCount = snapshot.moveCount;
    _noCapture = snapshot.noCapture;
    _winner = snapshot.winner;
    _lastMove = snapshot.lastMove;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final depth = switch (level) {
      0 => 1,
      1 => 2,
      2 => 3,
      _ => 4,
    };
    final position = _JunglePosition(List<int>.of(board), _side, _noCapture, _moveCount);
    final result = _search(position, depth, -1000000, 1000000, level == 0);
    return result.$2;
  }

  (int, List<int>?) _search(
    _JunglePosition position,
    int depth,
    int alpha,
    int beta,
    bool randomise,
  ) {
    final moves = _movesFor(position);
    if (moves.isEmpty) return (-900000 + (8 - depth) * 100, null);
    if (depth <= 0) return (_evaluate(position), null);
    final scored = <(List<int>, int)>[];
    for (final move in moves) {
      final next = _applyPosition(position, move);
      if (next.$2 != null) {
        scored.add((move, 900000 - depth));
        continue;
      }
      final child = _search(next.$1, depth - 1, -beta, -alpha, false);
      scored.add((move, -child.$1));
      if (-child.$1 > alpha) alpha = -child.$1;
      if (alpha >= beta) break;
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    if (randomise) {
      final pool = scored.where((entry) => entry.$2 >= scored.first.$2 - 30).toList();
      final chosen = pool[Random().nextInt(pool.length)];
      return (chosen.$2, chosen.$1);
    }
    return (scored.first.$2, scored.first.$1);
  }

  List<List<int>> _movesFor(_JunglePosition position) {
    final savedBoard = List<int>.of(board);
    final savedSide = _side;
    final savedWinner = _winner;
    for (var i = 0; i < cells; i++) {
      board[i] = position.board[i];
    }
    _side = position.side;
    _winner = null;
    final moves = <List<int>>[];
    for (var from = 0; from < cells; from++) {
      final piece = board[from];
      if (piece == 0 || _colorOf(piece) != position.side) continue;
      for (final to in _candidateTargets(from)) {
        if (_isLegalMove(from, to)) moves.add([from, to]);
      }
    }
    for (var i = 0; i < cells; i++) {
      board[i] = savedBoard[i];
    }
    _side = savedSide;
    _winner = savedWinner;
    return moves;
  }

  (_JunglePosition, int?) _applyPosition(_JunglePosition position, List<int> move) {
    final next = List<int>.of(position.board);
    final from = move[0];
    final to = move[1];
    final piece = next[from];
    next[to] = piece;
    next[from] = 0;
    final toRow = to ~/ cols;
    final toCol = to % cols;
    final color = _colorOf(piece);
    if (_isDen(toRow, toCol, 1 - color)) {
      return (_JunglePosition(next, 1 - color, position.noCapture + 1, position.moveCount + 1), color);
    }
    var opponentPieces = 0;
    for (final p in next) {
      if (p != 0 && _colorOf(p) == 1 - color) opponentPieces++;
    }
    if (opponentPieces == 0) {
      return (_JunglePosition(next, 1 - color, position.noCapture, position.moveCount + 1), color);
    }
    return (
      _JunglePosition(
        next,
        1 - color,
        position.board[to] == 0 ? position.noCapture + 1 : 0,
        position.moveCount + 1,
      ),
      null,
    );
  }

  int _evaluate(_JunglePosition position) {
    var score = 0;
    for (var i = 0; i < cells; i++) {
      final piece = position.board[i];
      if (piece == 0) continue;
      final color = _colorOf(piece);
      final rank = _rankOf(piece);
      var value = const [0, 12, 18, 24, 32, 42, 58, 78, 100][rank];
      final row = i ~/ cols;
      final col = i % cols;
      final enemyDen = color == 0 ? _blueDen : _redDen;
      final distance = (row - enemyDen[0]).abs() + (col - enemyDen[1]).abs();
      value += max(0, 9 - distance) * 2;
      if (_isTrap(row, col, color)) value -= 20;
      score += color == 0 ? value : -value;
    }
    return position.side == 0 ? score : -score;
  }

  _JungleSnapshot _snapshot() => _JungleSnapshot(
        List<int>.of(board),
        _side,
        _moveCount,
        _noCapture,
        _winner,
        List<int>.of(_lastMove),
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'moveCount': _moveCount,
        'noCapture': _noCapture,
        'winner': _winner,
        'last': List<int>.of(_lastMove),
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < cells; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _noCapture = (json['noCapture'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastMove = (json['last'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? const [];
    _history.clear();
  }

  @override
  Widget sideBadge(int side, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: side == 0 ? const Color(0xFFD05A4E) : const Color(0xFF4E86C7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          side == 0 ? '兽' : '兽',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return JungleBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      hint: hint,
      flipped: flipped,
    );
  }
}

class _JungleSnapshot {
  final List<int> board;
  final int side;
  final int moveCount;
  final int noCapture;
  final int? winner;
  final List<int> lastMove;

  _JungleSnapshot(this.board, this.side, this.moveCount, this.noCapture, this.winner, this.lastMove);
}

class _JunglePosition {
  final List<int> board;
  final int side;
  final int noCapture;
  final int moveCount;

  _JunglePosition(this.board, this.side, this.noCapture, this.moveCount);
}

class JungleBoard extends StatefulWidget {
  final JungleGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final Object? hint;
  final bool flipped;

  const JungleBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.hint,
    this.flipped = false,
  });

  @override
  State<JungleBoard> createState() => _JungleBoardState();
}

class _JungleBoardState extends State<JungleBoard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, constraints.maxHeight * 7 / 9);
        final height = width * 9 / 7;
        final cellW = width / 7;
        final cellH = height / 9;
        final targets = _selected == null ? <int>{} : game.legalTargets(_selected!);
        final pieces = <Widget>[];
        Offset centerOf(int index) {
          final row = index ~/ 7;
          final col = index % 7;
          final vx = widget.flipped ? 6 - col : col;
          final vy = widget.flipped ? 8 - row : row;
          return Offset((vx + 0.5) * cellW, (vy + 0.5) * cellH);
        }

        for (var i = 0; i < JungleGame.cells; i++) {
          final piece = game.board[i];
          if (piece == 0) continue;
          final center = centerOf(i);
          final size = min(cellW, cellH) * 0.78;
          pieces.add(Positioned(
            left: center.dx - size / 2,
            top: center.dy - size / 2,
            width: size,
            height: size,
            child: IgnorePointer(
              child: GameDisc(
                label: JungleGame._names[game._rankOf(piece)],
                color: game._colorOf(piece) == 0
                    ? const Color(0xFFC94F43)
                    : const Color(0xFF4E86C7),
                size: size,
                selected: _selected == i,
                fontSize: size * 0.4,
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
                      final vx = (details.localPosition.dx / cellW).floor().clamp(0, 6);
                      final vy = (details.localPosition.dy / cellH).floor().clamp(0, 8);
                      final col = widget.flipped ? 6 - vx : vx;
                      final row = widget.flipped ? 8 - vy : vy;
                      final index = row * 7 + col;
                      if (_selected != null && targets.contains(index)) {
                        final from = _selected!;
                        setState(() => _selected = null);
                        widget.onMove([from, index]);
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
                      painter: _JunglePainter(
                        game: game,
                        cellW: cellW,
                        cellH: cellH,
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


class _JunglePainter extends CustomPainter {
  final JungleGame game;
  final double cellW;
  final double cellH;
  final bool flipped;
  final Set<int> targets;
  final int? selected;

  _JunglePainter({
    required this.game,
    required this.cellW,
    required this.cellH,
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
          colors: [Color(0xFF3D6B45), Color(0xFF244B32)],
        ).createShader(rect),
    );

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 7; col++) {
        final vx = flipped ? 6 - col : col;
        final vy = flipped ? 8 - row : row;
        final r = Rect.fromLTWH(vx * cellW, vy * cellH, cellW, cellH);
        if (JungleGame._river.any((cell) => cell[0] == row && cell[1] == col)) {
          canvas.drawRect(
            r,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3F7FA8), Color(0xFF24546F)],
              ).createShader(r),
          );
          final wave = Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
          for (var i = 1; i <= 2; i++) {
            final y = r.top + r.height * i / 3;
            canvas.drawLine(
              Offset(r.left + cellW * 0.12, y),
              Offset(r.right - cellW * 0.12, y),
              wave,
            );
          }
        } else {
          canvas.drawRect(
            r,
            Paint()..color = (row + col).isEven
                ? const Color(0xFF4A7C52).withValues(alpha: 0.35)
                : const Color(0xFF2E5C3A).withValues(alpha: 0.35),
          );
        }
        if (JungleGame._redTraps.any((c) => c[0] == row && c[1] == col) ||
            JungleGame._blueTraps.any((c) => c[0] == row && c[1] == col)) {
          canvas.drawRect(
            r.deflate(2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = const Color(0xFFD8A35B).withValues(alpha: 0.85),
          );
          _text(canvas, '陷', r.center, 9, const Color(0xFFE8C68A));
        }
        if ((JungleGame._redDen[0] == row && JungleGame._redDen[1] == col) ||
            (JungleGame._blueDen[0] == row && JungleGame._blueDen[1] == col)) {
          canvas.drawRect(
            r.deflate(2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFE7BC6C),
          );
          _text(canvas, '穴', r.center, 14, const Color(0xFFE7BC6C));
        }
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6
            ..color = const Color(0xFFD7C79F).withValues(alpha: 0.24),
        );
      }
    }

    if (game._lastMove.length == 2) {
      for (final index in game._lastMove) {
        final row = index ~/ 7;
        final col = index % 7;
        final vx = flipped ? 6 - col : col;
        final vy = flipped ? 8 - row : row;
        canvas.drawRect(
          Rect.fromLTWH(vx * cellW, vy * cellH, cellW, cellH),
          Paint()..color = AppColors.gold.withValues(alpha: 0.22),
        );
      }
    }
    for (final index in targets) {
      final row = index ~/ 7;
      final col = index % 7;
      final vx = flipped ? 6 - col : col;
      final vy = flipped ? 8 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cellW, (vy + 0.5) * cellH),
        min(cellW, cellH) * 0.12,
        Paint()..color = const Color(0xFF102016).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final row = selected! ~/ 7;
      final col = selected! % 7;
      final vx = flipped ? 6 - col : col;
      final vy = flipped ? 8 - row : row;
      canvas.drawRect(
        Rect.fromLTWH(vx * cellW + 2, vy * cellH + 2, cellW - 4, cellH - 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
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
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _JunglePainter oldDelegate) => true;
}
