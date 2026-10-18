import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

/// A compact, open-information 军棋 variant: 5x10, 15 pieces per side,
/// one-step movement, camps and flags. Hidden-piece Luzhanqi is not modelled.
class JunqiGame extends TurnGame {
  static const int cols = 5;
  static const int rows = 10;
  static const int cells = cols * rows;

  static const int flag = 1;
  static const int mine = 2;
  static const int bomb = 3;
  static const int engineer = 4;
  static const int platoon = 5;
  static const int company = 6;
  static const int battalion = 7;
  static const int regiment = 8;
  static const int brigade = 9;
  static const int division = 10;
  static const int army = 11;
  static const int commander = 12;

  static const List<String> _names = [
    '',
    '军旗',
    '地雷',
    '炸弹',
    '工兵',
    '排长',
    '连长',
    '营长',
    '团长',
    '旅长',
    '师长',
    '军长',
    '司令',
  ];

  static const List<List<int>> _camps = [
    [3, 1],
    [3, 3],
    [6, 1],
    [6, 3],
  ];

  final List<int> board = List<int>.filled(cells, 0);
  final List<_JunqiSnapshot> _history = [];
  int _side = 0; // 0 red (bottom), 1 blue (top)
  int _moveCount = 0;
  int _noCapture = 0;
  int? _winner;
  List<int> _lastMove = const [];

  JunqiGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    void put(int color, int row, int col, int code) {
      board[row * cols + col] = color * 16 + code;
    }

    // Red (bottom)
    const redBack = [mine, flag, commander, mine, bomb];
    const redMid = [engineer, division, army, brigade, engineer];
    const redFront = [company, platoon, regiment, battalion, company];
    for (var col = 0; col < 5; col++) {
      put(0, 9, col, redBack[col]);
      put(0, 8, col, redMid[col]);
      put(0, 7, col, redFront[col]);
    }
    // Blue (top), mirrored
    const blueBack = [bomb, mine, commander, flag, mine];
    const blueMid = [engineer, brigade, army, division, engineer];
    const blueFront = [company, battalion, regiment, platoon, company];
    for (var col = 0; col < 5; col++) {
      put(1, 0, col, blueBack[col]);
      put(1, 1, col, blueMid[col]);
      put(1, 2, col, blueFront[col]);
    }
    _side = 0;
    _moveCount = 0;
    _noCapture = 0;
    _winner = null;
    _lastMove = const [];
    _history.clear();
  }

  int _colorOf(int piece) => piece == 0 ? -1 : piece ~/ 16;
  int _codeOf(int piece) => piece == 0 ? 0 : piece % 16;
  bool _isCamp(int row, int col) =>
      _camps.any((cell) => cell[0] == row && cell[1] == col);

  @override
  GameMeta get meta => GameCatalog.junqi;

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
    return '夺得军旗';
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final piece in board) {
      if (piece != 0 && _colorOf(piece) == side) count++;
    }
    return '$count 子';
  }

  bool _isMovable(int piece) {
    final code = _codeOf(piece);
    return code != flag && code != mine;
  }

  bool _canCapture(int attacker, int defender, int toRow, int toCol) {
    if (_isCamp(toRow, toCol)) return false;
    final a = _codeOf(attacker);
    final d = _codeOf(defender);
    if (d == flag) return true;
    if (a == bomb || d == bomb) return true;
    if (d == mine) return a == engineer;
    return a >= d;
  }

  bool _isLegalMove(int from, int to) {
    if (isOver) return false;
    if (from < 0 || from >= cells || to < 0 || to >= cells) return false;
    final piece = board[from];
    if (piece == 0 || _colorOf(piece) != _side || !_isMovable(piece)) {
      return false;
    }
    final fromRow = from ~/ cols;
    final fromCol = from % cols;
    final toRow = to ~/ cols;
    final toCol = to % cols;
    if ((fromRow - toRow).abs() + (fromCol - toCol).abs() != 1) return false;
    final target = board[to];
    if (target != 0 && _colorOf(target) == _side) return false;
    if (target != 0 && !_canCapture(piece, target, toRow, toCol)) return false;
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
    if (!isLegal(move)) return;
    final from = ((move as List)[0] as num).toInt();
    final to = (move[1] as num).toInt();
    _history.add(_snapshot());
    final piece = board[from];
    final target = board[to];
    final mover = _side;
    final code = _codeOf(piece);
    var captured = false;
    if (target != 0) {
      captured = true;
      final targetCode = _codeOf(target);
      if (targetCode == flag) {
        _winner = mover;
        board[to] = piece;
        board[from] = 0;
        _lastMove = [from, to];
        _moveCount++;
        return;
      }
      if (code == bomb || targetCode == bomb) {
        board[to] = 0;
      } else {
        board[to] = piece;
      }
    } else {
      board[to] = piece;
    }
    board[from] = 0;
    _lastMove = [from, to];
    _moveCount++;
    _noCapture = captured ? 0 : _noCapture + 1;
    _side = 1 - _side;
    if (!_hasMove(_side)) {
      _winner = mover;
      return;
    }
    if (_noCapture >= 100) _winner = 2;
  }

  bool _hasMove(int color) {
    final saved = _side;
    _side = color;
    var has = false;
    for (var from = 0; from < cells && !has; from++) {
      final piece = board[from];
      if (piece == 0 || _colorOf(piece) != color || !_isMovable(piece)) continue;
      final row = from ~/ cols;
      final col = from % cols;
      for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final r = row + d[0];
        final c = col + d[1];
        if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
        if (_isLegalMove(from, r * cols + c)) {
          has = true;
          break;
        }
      }
    }
    _side = saved;
    return has;
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

  List<int> legalTargets(int from) {
    final result = <int>[];
    if (from < 0 || from >= cells) return result;
    if (board[from] == 0 || _colorOf(board[from]) != _side) return result;
    final row = from ~/ cols;
    final col = from % cols;
    for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final r = row + d[0];
      final c = col + d[1];
      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      final to = r * cols + c;
      if (_isLegalMove(from, to)) result.add(to);
    }
    return result;
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
    final position = _JunqiPosition(List<int>.of(board), _side, _noCapture, _moveCount);
    final result = _search(position, depth, -1000000, 1000000, level == 0);
    return result.$2;
  }

  (int, List<int>?) _search(
    _JunqiPosition position,
    int depth,
    int alpha,
    int beta,
    bool randomise,
  ) {
    if (depth <= 0) return (_quiesce(position, alpha, beta, 0), null);
    final moves = _movesFor(position);
    if (moves.isEmpty) return (-900000 + (6 - depth) * 100, null);
    final scored = <(List<int>, int)>[];
    for (final move in moves) {
      final applied = _applyPosition(position, move);
      if (applied.$2 != null) {
        scored.add((move, 900000 - depth));
        continue;
      }
      final score = -_search(applied.$1, depth - 1, -beta, -alpha, false).$1;
      scored.add((move, score));
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    if (randomise) {
      final pool = scored.where((e) => e.$2 >= scored.first.$2 - 30).toList();
      final chosen = pool[Random().nextInt(pool.length)];
      return (chosen.$2, chosen.$1);
    }
    return (scored.first.$2, scored.first.$1);
  }

  int _quiesce(_JunqiPosition position, int alpha, int beta, int qdepth) {
    final stand = _evaluate(position);
    if (stand >= beta) return beta;
    if (stand > alpha) alpha = stand;
    if (qdepth >= 3) return alpha;
    final moves = _movesFor(position)
        .where((move) => position.board[move[1]] != 0)
        .toList();
    if (moves.isEmpty) return alpha;
    moves.sort((a, b) {
      final av = _codeOf(position.board[a[1]]);
      final bv = _codeOf(position.board[b[1]]);
      return bv.compareTo(av);
    });
    for (final move in moves) {
      final applied = _applyPosition(position, move);
      if (applied.$2 != null) return 900000 - qdepth;
      final score = -_quiesce(applied.$1, -beta, -alpha, qdepth + 1);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  List<List<int>> _movesFor(_JunqiPosition position) {
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
      if (piece == 0 || _colorOf(piece) != position.side || !_isMovable(piece)) {
        continue;
      }
      final row = from ~/ cols;
      final col = from % cols;
      for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final r = row + d[0];
        final c = col + d[1];
        if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
        final to = r * cols + c;
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

  (_JunqiPosition, int?) _applyPosition(_JunqiPosition position, List<int> move) {
    final next = List<int>.of(position.board);
    final from = move[0];
    final to = move[1];
    final piece = next[from];
    final target = next[to];
    final color = _colorOf(piece);
    if (target != 0) {
      if (_codeOf(target) == flag) {
        return (_JunqiPosition(next, 1 - color, 0, position.moveCount + 1), color);
      }
      if (_codeOf(piece) == bomb || _codeOf(target) == bomb) {
        next[to] = 0;
      } else {
        next[to] = piece;
      }
    } else {
      next[to] = piece;
    }
    next[from] = 0;
    final opponentHasMove = _positionHasMove(next, 1 - color);
    final positionNext = _JunqiPosition(
      next,
      1 - color,
      target == 0 ? position.noCapture + 1 : 0,
      position.moveCount + 1,
    );
    if (!opponentHasMove) return (positionNext, color);
    return (positionNext, null);
  }

  bool _positionHasMove(List<int> source, int color) {
    for (var from = 0; from < cells; from++) {
      final piece = source[from];
      if (piece == 0 || _colorOf(piece) != color || !_isMovable(piece)) continue;
      final row = from ~/ cols;
      final col = from % cols;
      for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final r = row + d[0];
        final c = col + d[1];
        if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
        final to = r * cols + c;
        final target = source[to];
        if (target != 0 && _colorOf(target) == color) continue;
        if (target != 0 && !_canCaptureForBoard(source, piece, target, r, c)) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  bool _canCaptureForBoard(List<int> source, int attacker, int defender, int row, int col) {
    if (_isCamp(row, col)) return false;
    final a = _codeOf(attacker);
    final d = _codeOf(defender);
    if (d == flag) return true;
    if (a == bomb || d == bomb) return true;
    if (d == mine) return a == engineer;
    return a >= d;
  }

  int _evaluate(_JunqiPosition position) {
    var score = 0;
    for (var i = 0; i < cells; i++) {
      final piece = position.board[i];
      if (piece == 0) continue;
      final color = _colorOf(piece);
      final code = _codeOf(piece);
      var value = const [0, 5000, 140, 220, 100, 120, 180, 250, 350, 450, 550, 700, 900][code];
      final row = i ~/ cols;
      final col = i % cols;
      if (code != flag && code != mine) {
        final enemyBack = color == 0 ? 0 : 9;
        value += (9 - (row - enemyBack).abs()) * 3;
      }
      if (_isCamp(row, col)) value += 12;
      score += color == 0 ? value : -value;
    }
    return position.side == 0 ? score : -score;
  }

  _JunqiSnapshot _snapshot() => _JunqiSnapshot(
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
  List<Object?> get llmMoves {
    final moves = <Object?>[];
    for (var from = 0; from < cells; from++) {
      final piece = board[from];
      if (piece == 0 || _colorOf(piece) != _side) continue;
      for (final to in legalTargets(from)) {
        moves.add(<int>[from, to]);
      }
    }
    return moves;
  }

  @override
  String get llmState {
    final sb = StringBuffer(
      '5x10 军棋（明棋），r=红方，b=蓝方，后面是棋子名；.=空。'
      '坐标 (x,y)，x=0 最左列，y=0 最上面一行。\n',
    );
    for (var y = 0; y < rows; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < cols; x++) {
        final piece = board[y * cols + x];
        sb.write(piece == 0
            ? '.'
            : '${_colorOf(piece) == 0 ? 'r' : 'b'}${_names[_codeOf(piece)]}');
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! List || move.length != 2) return '$move';
    final from = (move[0] as num).toInt();
    final to = (move[1] as num).toInt();
    final piece = board[from];
    final name = piece == 0
        ? '?'
        : '${_colorOf(piece) == 0 ? '红' : '蓝'}${_names[_codeOf(piece)]}';
    return '$name(${from % cols},${from ~/ cols})->'
        '(${to % cols},${to ~/ cols})';
  }

  @override
  Widget sideBadge(int side, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: side == 0 ? const Color(0xFFC94F43) : const Color(0xFF4E86C7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          side == 0 ? '军' : '军',
          style: TextStyle(
            fontSize: size * 0.4,
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
    return JunqiBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _JunqiSnapshot {
  final List<int> board;
  final int side;
  final int moveCount;
  final int noCapture;
  final int? winner;
  final List<int> lastMove;

  _JunqiSnapshot(this.board, this.side, this.moveCount, this.noCapture, this.winner, this.lastMove);
}

class _JunqiPosition {
  final List<int> board;
  final int side;
  final int noCapture;
  final int moveCount;

  _JunqiPosition(this.board, this.side, this.noCapture, this.moveCount);
}

class JunqiBoard extends StatefulWidget {
  final JunqiGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const JunqiBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<JunqiBoard> createState() => _JunqiBoardState();
}

class _JunqiBoardState extends State<JunqiBoard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, constraints.maxHeight * 0.5);
        final height = width * 2;
        final cellW = width / 5;
        final cellH = height / 10;
        final targets = _selected == null ? <int>[] : game.legalTargets(_selected!);
        final pieces = <Widget>[];
        for (var i = 0; i < JunqiGame.cells; i++) {
          final piece = game.board[i];
          if (piece == 0) continue;
          final row = i ~/ 5;
          final col = i % 5;
          final vx = widget.flipped ? 4 - col : col;
          final vy = widget.flipped ? 9 - row : row;
          final size = min(cellW, cellH) * 0.78;
          pieces.add(Positioned(
            left: (vx + 0.5) * cellW - size / 2,
            top: (vy + 0.5) * cellH - size / 2,
            width: size,
            height: size,
            child: IgnorePointer(
              child: GameDisc(
                label: JunqiGame._names[game._codeOf(piece)],
                color: game._colorOf(piece) == 0
                    ? const Color(0xFFC94F43)
                    : const Color(0xFF4E86C7),
                size: size,
                selected: _selected == i,
                fontSize: size * 0.27,
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
                      final vx = (details.localPosition.dx / cellW).floor().clamp(0, 4);
                      final vy = (details.localPosition.dy / cellH).floor().clamp(0, 9);
                      final col = widget.flipped ? 4 - vx : vx;
                      final row = widget.flipped ? 9 - vy : vy;
                      final index = row * 5 + col;
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
                      painter: _JunqiPainter(
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

class _JunqiPainter extends CustomPainter {
  final JunqiGame game;
  final double cellW;
  final double cellH;
  final bool flipped;
  final List<int> targets;
  final int? selected;

  _JunqiPainter({
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
          colors: [Color(0xFF3E584A), Color(0xFF21352B)],
        ).createShader(rect),
    );
    for (var row = 0; row < 10; row++) {
      for (var col = 0; col < 5; col++) {
        final vx = flipped ? 4 - col : col;
        final vy = flipped ? 9 - row : row;
        final r = Rect.fromLTWH(vx * cellW, vy * cellH, cellW, cellH);
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFFD8C79F).withValues(alpha: 0.24),
        );
        if (JunqiGame._camps.any((c) => c[0] == row && c[1] == col)) {
          canvas.drawRect(
            r.deflate(3),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.8),
          );
          _text(canvas, '营', r.center, cellH * 0.22, const Color(0xFFE7BC6C));
        }
      }
    }
    if (game._lastMove.length == 2) {
      for (final index in game._lastMove) {
        final row = index ~/ 5;
        final col = index % 5;
        final vx = flipped ? 4 - col : col;
        final vy = flipped ? 9 - row : row;
        canvas.drawRect(
          Rect.fromLTWH(vx * cellW, vy * cellH, cellW, cellH),
          Paint()..color = AppColors.gold.withValues(alpha: 0.2),
        );
      }
    }
    for (final index in targets) {
      final row = index ~/ 5;
      final col = index % 5;
      final vx = flipped ? 4 - col : col;
      final vy = flipped ? 9 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cellW, (vy + 0.5) * cellH),
        min(cellW, cellH) * 0.12,
        Paint()..color = const Color(0xFF0E1A14).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final row = selected! ~/ 5;
      final col = selected! % 5;
      final vx = flipped ? 4 - col : col;
      final vy = flipped ? 9 - row : row;
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
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _JunqiPainter oldDelegate) => true;
}
