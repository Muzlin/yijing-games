import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class DraughtsGame extends TurnGame {
  static const int boardSize = 8;
  final List<int> board = List<int>.filled(64, 0);
  int _side = 0;
  int _quiet = 0;
  int _moveCount = 0;
  int? _winner;
  List<int> _lastPath = const [];
  final List<_DraughtsSnapshot> _history = [];

  DraughtsGame() {
    _resetBoard();
  }

  void _resetBoard() {
    board.fillRange(0, 64, 0);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isOdd) board[row * 8 + col] = 2; // black man
      }
    }
    for (var row = 5; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isOdd) board[row * 8 + col] = 1; // white man
      }
    }
    _side = 0;
    _quiet = 0;
    _moveCount = 0;
    _winner = null;
    _lastPath = const [];
  }

  @override
  GameMeta get meta => GameCatalog.draughts;

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
  String sideName(int side) => side == 0 ? '白方' : '黑方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    final captures = _captureMovesFor(_side);
    return captures.isNotEmpty
        ? '${sideName(_side)} · 必须连吃'
        : '${sideName(_side)}落子';
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
    return '对方无子可动';
  }

  @override
  String scoreText(int side) {
    var men = 0;
    var kings = 0;
    for (final piece in board) {
      if (piece == 0) continue;
      if (_colorOf(piece) != side) continue;
      if (_isKing(piece)) {
        kings++;
      } else {
        men++;
      }
    }
    return kings > 0 ? '$men+$kings王' : '$men 子';
  }

  int _colorOf(int piece) => piece == 0 ? -1 : (piece == 1 || piece == 3 ? 0 : 1);
  bool _isKing(int piece) => piece == 3 || piece == 4;
  int _king(int color) => color == 0 ? 3 : 4;

  @override
  bool isLegal(Object? move) {
    if (move is! List) return false;
    final path = move.cast<num>().map((e) => e.toInt()).toList();
    if (path.length < 2) return false;
    final all = _allLegalMoves(_side);
    for (final candidate in all) {
      if (_samePath(candidate, path)) return true;
    }
    return false;
  }

  bool _samePath(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void apply(Object? move) {
    if (isOver || move is! List) return;
    final path = move.cast<num>().map((e) => e.toInt()).toList();
    if (!isLegal(path)) return;
    _history.add(_snapshot());
    final color = _side;
    final piece = board[path.first];
    final king = _isKing(piece);
    var captured = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      final fromRow = from ~/ 8;
      final fromCol = from % 8;
      final toRow = to ~/ 8;
      final toCol = to % 8;
      if ((toRow - fromRow).abs() == 2 && (toCol - fromCol).abs() == 2) {
        final middle = ((fromRow + toRow) ~/ 2) * 8 + (fromCol + toCol) ~/ 2;
        if (board[middle] != 0) {
          board[middle] = 0;
          captured++;
        }
      }
    }
    board[path.first] = 0;
    var finalPiece = piece;
    final landingRow = path.last ~/ 8;
    if (!king && ((color == 0 && landingRow == 0) || (color == 1 && landingRow == 7))) {
      finalPiece = _king(color);
    }
    board[path.last] = finalPiece;
    _lastPath = path;
    _moveCount++;
    if (captured > 0) {
      _quiet = 0;
    } else {
      _quiet++;
    }
    _side = 1 - _side;
    _checkGameOver();
  }

  void _checkGameOver() {
    final moves = _allLegalMoves(_side);
    if (moves.isEmpty) {
      _winner = 1 - _side;
      return;
    }
    if (_quiet >= 80) {
      _winner = 2;
    }
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    for (var i = 0; i < 64; i++) {
      board[i] = snapshot.board[i];
    }
    _side = snapshot.side;
    _quiet = snapshot.quiet;
    _moveCount = snapshot.moveCount;
    _winner = snapshot.winner;
    _lastPath = snapshot.lastPath;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final simulation = _DraughtsPosition(List<int>.of(board), _side, _quiet, _moveCount);
    final depth = switch (level) {
      0 => 1,
      1 => 3,
      2 => 4,
      _ => 5,
    };
    final best = _search(simulation, depth, -1000000, 1000000, level == 0);
    return best.$2;
  }

  (int, List<int>?) _search(
    _DraughtsPosition position,
    int depth,
    int alpha,
    int beta,
    bool randomise,
  ) {
    final moves = _allLegalMovesFor(position);
    if (moves.isEmpty) {
      return (-900000 + (10 - depth) * 100, null);
    }
    if (depth <= 0) {
      return (_evaluate(position), null);
    }
    final scored = <(List<int>, int)>[];
    for (final move in moves) {
      final next = position.apply(move);
      final result = _search(next, depth - 1, -beta, -alpha, false);
      final score = -result.$1;
      scored.add((move, score));
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    if (randomise) {
      final top = scored.first.$2;
      final pool = scored.where((entry) => entry.$2 >= top - 20).toList();
      return (pool[Random().nextInt(pool.length)].$2, pool[Random().nextInt(pool.length)].$1);
    }
    return (scored.first.$2, scored.first.$1);
  }

  int _evaluate(_DraughtsPosition position) {
    var score = 0;
    for (var i = 0; i < 64; i++) {
      final piece = position.board[i];
      if (piece == 0) continue;
      final color = _colorOf(piece);
      final king = _isKing(piece);
      final row = i ~/ 8;
      final col = i % 8;
      var value = king ? 175 : 100;
      if (!king) {
        final advancement = color == 0 ? 7 - row : row;
        value += advancement * 4;
      }
      final center = 3.5;
      value += ((3.5 - (col - center).abs()) * 1.5).round();
      if (!king && ((color == 0 && row == 7) || (color == 1 && row == 0))) {
        value -= 8;
      }
      score += color == 0 ? value : -value;
    }
    return position.side == 0 ? score : -score;
  }

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'side': _side,
        'quiet': _quiet,
        'moveCount': _moveCount,
        'winner': _winner,
        'last': List<int>.of(_lastPath),
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 64; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _quiet = (json['quiet'] as num?)?.toInt() ?? 0;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastPath = (json['last'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ??
        const [];
    _history.clear();
  }

  @override
  List<Object?> get llmMoves =>
      _allLegalMoves(_side).map<Object?>((move) => move).toList();

  @override
  String get llmState {
    final sb = StringBuffer(
      '8x8 国际跳棋，w=白兵，W=白王，b=黑兵，B=黑王，.=空。'
      '坐标 a1..h8，a1 在左下角；y=0 是最上面一行。\n',
    );
    for (var y = 0; y < 8; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < 8; x++) {
        final piece = board[y * 8 + x];
        sb.write(piece == 0
            ? '.'
            : piece == 1
                ? 'w'
                : piece == 2
                    ? 'b'
                    : piece == 3
                        ? 'W'
                        : 'B');
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}；必须连吃：');
    sb.write(_captureMovesFor(_side).isNotEmpty ? '是' : '否');
    sb.write('。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! List) return '$move';
    final path = move.cast<num>().map((e) => e.toInt()).toList();
    return path.map(_squareName).join('->');
  }

  String _squareName(int index) =>
      '${String.fromCharCode(97 + index % 8)}${8 - index ~/ 8}';

  @override
  Widget sideBadge(int side, double size) => _CheckersBadge(side: side, size: size);

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return DraughtsBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      hint: hint,
      flipped: flipped,
    );
  }

  List<List<int>> _allLegalMoves(int side) {
    return _allLegalMovesFor(
      _DraughtsPosition(List<int>.of(board), side, _quiet, _moveCount),
    );
  }
  List<List<int>> _captureMovesFor(int side) {
    final moves = _allLegalMoves(side);
    return moves.where((move) => move.length > 2).toList();
  }

  List<List<int>> _allLegalMovesFor(_DraughtsPosition position) {
    final captures = <List<int>>[];
    for (var i = 0; i < 64; i++) {
      final piece = position.board[i];
      if (piece == 0 || _colorOf(piece) != position.side) continue;
      _findCaptures(position.board, i, piece, <int>[i], <int>{}, captures);
    }
    if (captures.isNotEmpty) return captures;
    final moves = <List<int>>[];
    for (var i = 0; i < 64; i++) {
      final piece = position.board[i];
      if (piece == 0 || _colorOf(piece) != position.side) continue;
      final king = _isKing(piece);
      final directions = king
          ? const [[-1, -1], [-1, 1], [1, -1], [1, 1]]
          : (position.side == 0
              ? const [[-1, -1], [-1, 1]]
              : const [[1, -1], [1, 1]]);
      final x = i % 8;
      final y = i ~/ 8;
      for (final d in directions) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (nx < 0 || nx > 7 || ny < 0 || ny > 7) continue;
        final to = ny * 8 + nx;
        if (position.board[to] == 0) moves.add([i, to]);
      }
    }
    return moves;
  }

  void _findCaptures(
    List<int> source,
    int index,
    int piece,
    List<int> path,
    Set<int> captured,
    List<List<int>> result,
  ) {
    final color = _colorOf(piece);
    final x = index % 8;
    final y = index ~/ 8;
    var foundCapture = false;
    for (final d in const [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
      final mx = x + d[0];
      final my = y + d[1];
      final lx = x + d[0] * 2;
      final ly = y + d[1] * 2;
      if (lx < 0 || lx > 7 || ly < 0 || ly > 7) continue;
      final middle = my * 8 + mx;
      final landing = ly * 8 + lx;
      final target = source[middle];
      if (target == 0 || _colorOf(target) == color) continue;
      if (source[landing] != 0) continue;
      if (captured.contains(middle)) continue;
      foundCapture = true;
      final promoted = !_isKing(piece) &&
          ((color == 0 && ly == 0) || (color == 1 && ly == 7));
      final nextPath = List<int>.of(path)..add(landing);
      final nextCaptured = Set<int>.of(captured)..add(middle);
      if (promoted) {
        // Promotion ends the turn; the path without this capture is not legal
        // because a capture is still available.
        result.add(nextPath);
      } else {
        final simulated = List<int>.of(source);
        simulated[index] = 0;
        simulated[middle] = 0;
        simulated[landing] = piece;
        _findCaptures(simulated, landing, piece, nextPath, nextCaptured, result);
      }
    }
    // Only stop here if there was genuinely no further capture from this
    // square. Previously a promoting capture left the shorter path legal.
    if (!foundCapture && path.length > 1) {
      result.add(path);
    }
  }

  _DraughtsSnapshot _snapshot() => _DraughtsSnapshot(
        List<int>.of(board),
        _side,
        _quiet,
        _moveCount,
        _winner,
        List<int>.of(_lastPath),
      );
}

class _DraughtsSnapshot {
  final List<int> board;
  final int side;
  final int quiet;
  final int moveCount;
  final int? winner;
  final List<int> lastPath;

  _DraughtsSnapshot(this.board, this.side, this.quiet, this.moveCount, this.winner, this.lastPath);
}

class _DraughtsPosition {
  final List<int> board;
  final int side;
  final int quiet;
  final int moveCount;

  _DraughtsPosition(this.board, this.side, this.quiet, this.moveCount);

  _DraughtsPosition apply(List<int> path) {
    final next = List<int>.of(board);
    final piece = next[path.first];
    int colorOf(int p) => p == 0 ? -1 : (p == 1 || p == 3 ? 0 : 1);
    bool isKing(int p) => p == 3 || p == 4;
    final color = colorOf(piece);
    var captured = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      final fromRow = from ~/ 8;
      final fromCol = from % 8;
      final toRow = to ~/ 8;
      final toCol = to % 8;
      if ((toRow - fromRow).abs() == 2 && (toCol - fromCol).abs() == 2) {
        final mid = ((fromRow + toRow) ~/ 2) * 8 + (fromCol + toCol) ~/ 2;
        if (next[mid] != 0) {
          next[mid] = 0;
          captured++;
        }
      }
    }
    next[path.first] = 0;
    var resultPiece = piece;
    final row = path.last ~/ 8;
    if (!isKing(piece) && ((color == 0 && row == 0) || (color == 1 && row == 7))) {
      resultPiece = color == 0 ? 3 : 4;
    }
    next[path.last] = resultPiece;
    return _DraughtsPosition(next, 1 - side, captured > 0 ? 0 : quiet + 1, moveCount + 1);
  }
}

class _CheckersBadge extends StatelessWidget {
  final int side;
  final double size;

  const _CheckersBadge({required this.side, required this.size});

  @override
  Widget build(BuildContext context) {
    return GameDisc(
      label: '',
      color: side == 0 ? const Color(0xFFF4EEE2) : const Color(0xFF2A3136),
      background: side == 0 ? const Color(0xFFF4EEE2) : const Color(0xFF2A3136),
      filled: true,
      size: size,
    );
  }
}

class DraughtsBoard extends StatefulWidget {
  final DraughtsGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final Object? hint;
  final bool flipped;

  const DraughtsBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.hint,
    this.flipped = false,
  });

  @override
  State<DraughtsBoard> createState() => _DraughtsBoardState();
}

class _DraughtsBoardState extends State<DraughtsBoard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 8;
        final pieceSize = cell * 0.78;
        final allMoves = game._allLegalMoves(game.side);
        final moves = _selected == null
            ? <List<int>>[]
            : allMoves.where((move) => move.first == _selected).toList();
        final targets = <int>{};
        for (final move in moves) {
          targets.add(move.last);
        }

        Offset centerOf(int index) {
          final row = index ~/ 8;
          final col = index % 8;
          final x = widget.flipped ? 7 - col : col;
          final y = widget.flipped ? 7 - row : row;
          return Offset((x + 0.5) * cell, (y + 0.5) * cell);
        }

        final pieces = <Widget>[];
        for (var i = 0; i < 64; i++) {
          final piece = game.board[i];
          if (piece == 0) continue;
          final center = centerOf(i);
          final color = game._colorOf(piece);
          final king = game._isKing(piece);
          pieces.add(Positioned(
            left: center.dx - pieceSize / 2,
            top: center.dy - pieceSize / 2,
            width: pieceSize,
            height: pieceSize,
            child: IgnorePointer(
              child: GameDisc(
                label: king ? '王' : '',
                color: color == 0 ? const Color(0xFFF4EEE2) : const Color(0xFF20262A),
                background: color == 0 ? const Color(0xFFF4EEE2) : const Color(0xFF20262A),
                filled: true,
                selected: _selected == i,
                size: pieceSize,
                fontSize: pieceSize * 0.5,
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
                    final x = (details.localPosition.dx / cell).floor().clamp(0, 7);
                    final y = (details.localPosition.dy / cell).floor().clamp(0, 7);
                    final col = widget.flipped ? 7 - x : x;
                    final row = widget.flipped ? 7 - y : y;
                    final index = row * 8 + col;
                    if (_selected != null && targets.contains(index)) {
                      final candidates = moves.where((m) => m.last == index).toList();
                      candidates.sort((a, b) => b.length.compareTo(a.length));
                      final move = candidates.first;
                      setState(() => _selected = null);
                      widget.onMove(move);
                      return;
                    }
                    final piece = game.board[index];
                    if (piece != 0 && game._colorOf(piece) == game.side) {
                      final pieceMoves =
                          allMoves.where((m) => m.first == index).toList();
                      setState(() {
                        _selected = pieceMoves.isEmpty ? null : index;
                      });
                    } else {
                      setState(() => _selected = null);
                    }
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DraughtsPainter(
                      game: game,
                      cell: cell,
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
        );
      },
    );
  }
}

class _DraughtsPainter extends CustomPainter {
  final DraughtsGame game;
  final double cell;
  final bool flipped;
  final Set<int> targets;
  final int? selected;

  _DraughtsPainter({
    required this.game,
    required this.cell,
    required this.flipped,
    required this.targets,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFEDE3CF);
    final dark = Paint()..color = const Color(0xFF7F9B83);
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final vx = flipped ? 7 - col : col;
        final vy = flipped ? 7 - row : row;
        canvas.drawRect(
          Rect.fromLTWH(vx * cell, vy * cell, cell, cell),
          (row + col).isOdd ? dark : light,
        );
      }
    }
    if (game._lastPath.isNotEmpty) {
      for (final index in [game._lastPath.first, game._lastPath.last]) {
        final row = index ~/ 8;
        final col = index % 8;
        final vx = flipped ? 7 - col : col;
        final vy = flipped ? 7 - row : row;
        canvas.drawRect(
          Rect.fromLTWH(vx * cell, vy * cell, cell, cell),
          Paint()..color = AppColors.gold.withValues(alpha: 0.28),
        );
      }
    }
    for (final index in targets) {
      final row = index ~/ 8;
      final col = index % 8;
      final vx = flipped ? 7 - col : col;
      final vy = flipped ? 7 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.15,
        Paint()..color = const Color(0xFF1A241E).withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DraughtsPainter oldDelegate) => true;
}
