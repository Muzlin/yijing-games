import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class AmazonMove {
  final int from;
  final int to;
  final int arrow;
  const AmazonMove(this.from, this.to, this.arrow);
  @override
  String toString() => 'AmazonMove($from,$to,$arrow)';
}

class AmazonsGame extends TurnGame {
  static const int size = 10;
  static const int cells = size * size;
  static const int arrowMark = 3;
  static const List<int> initialBlack = [3, 30, 60, 93];
  static const List<int> initialWhite = [6, 39, 69, 96];

  final List<int> board = List<int>.filled(cells, 0);
  final List<_AmazonSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int _last = -1;
  int _moveCount = 0;

  AmazonsGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    for (final p in initialBlack) {
      board[p] = 1;
    }
    for (final p in initialWhite) {
      board[p] = 2;
    }
    _side = 0;
    _winner = null;
    _last = -1;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.amazons;

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
  String sideName(int side) => side == 0 ? '黑方' : '白方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}行棋 · 移动皇后并射箭';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '对方皇后无路可走';
  }

  @override
  String scoreText(int side) {
    var count = 0;
    for (final value in board) {
      if (value == side + 1) count++;
    }
    return '$count 后';
  }

  static bool onBoard(int x, int y) => x >= 0 && x < size && y >= 0 && y < size;

  static List<int> queenTargets(List<int> source, int from) {
    final result = <int>[];
    final x = from % size;
    final y = from ~/ size;
    for (final d in const [
      [-1, -1], [-1, 0], [-1, 1], [0, -1],
      [0, 1], [1, -1], [1, 0], [1, 1],
    ]) {
      var nx = x + d[0];
      var ny = y + d[1];
      while (onBoard(nx, ny) && source[ny * size + nx] == 0) {
        result.add(ny * size + nx);
        nx += d[0];
        ny += d[1];
      }
    }
    return result;
  }

  List<int> _movesForSide(int side) {
    final result = <int>[];
    for (var i = 0; i < cells; i++) {
      if (board[i] == side + 1) result.addAll(queenTargets(board, i));
    }
    return result;
  }

  List<AmazonMove> _allMoves(int side) {
    final result = <AmazonMove>[];
    for (var from = 0; from < cells; from++) {
      if (board[from] != side + 1) continue;
      final destinations = queenTargets(board, from);
      for (final to in destinations) {
        board[from] = 0;
        board[to] = side + 1;
        final arrows = queenTargets(board, to);
        for (final arrow in arrows) {
          result.add(AmazonMove(from, to, arrow));
        }
        board[to] = 0;
        board[from] = side + 1;
      }
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! AmazonMove) return false;
    if (move.from < 0 || move.from >= cells || board[move.from] != _side + 1) {
      return false;
    }
    if (move.to < 0 || move.to >= cells || board[move.to] != 0) return false;
    if (!queenTargets(board, move.from).contains(move.to)) return false;
    board[move.from] = 0;
    board[move.to] = _side + 1;
    final arrowOk = move.arrow >= 0 &&
        move.arrow < cells &&
        board[move.arrow] == 0 &&
        queenTargets(board, move.to).contains(move.arrow);
    board[move.to] = 0;
    board[move.from] = _side + 1;
    return arrowOk;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as AmazonMove;
    _history.add(_snapshot());
    board[m.from] = 0;
    board[m.to] = _side + 1;
    board[m.arrow] = arrowMark;
    _last = m.arrow;
    _moveCount++;
    final other = 1 - _side;
    if (_movesForSide(other).isEmpty) {
      _winner = _side;
      return;
    }
    _side = other;
    if (_movesForSide(_side).isEmpty) {
      _winner = 1 - _side;
    }
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
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _allMoves(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(AmazonMove, int)>[];
    final sample = moves.length > 650 ? (moves..shuffle(random)).take(650).toList() : moves;
    for (final m in sample) {
      board[m.from] = 0;
      board[m.to] = _side + 1;
      board[m.arrow] = arrowMark;
      final otherMoves = _movesForSide(1 - _side).length;
      final ownMoves = _movesForSide(_side).length;
      var score = ownMoves - otherMoves * 2;
      if (otherMoves == 0) score += 1000000;
      final ax = m.arrow % size;
      final ay = m.arrow ~/ size;
      score += 12 - ((ax - 4).abs() + (ay - 4).abs());
      board[m.arrow] = 0;
      board[m.to] = 0;
      board[m.from] = _side + 1;
      if (level <= 0) score += random.nextInt(80);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _AmazonSnapshot _snapshot() => _AmazonSnapshot(
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
    _last = (json['last'] as num?)?.toInt() ?? -1;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _allMoves(_side);

  @override
  String get llmState {
    final sb = StringBuffer(
      '10x10 亚马逊棋，X=黑方皇后，O=白方皇后，*=箭，.=空。\n'
      '每回合必须移动一个己方皇后（横竖斜任意距离），然后从新位置向任意方向射出一箭；'
      '皇后和箭都不能越过棋子。皇后无路可走者负。\n',
    );
    for (var y = 0; y < size; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < size; x++) {
        final value = board[y * size + x];
        sb.write(value == 0 ? '.' : (value == 1 ? 'X' : (value == 2 ? 'O' : '*')));
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! AmazonMove) return '$move';
    String p(int i) => '(${i % size},${i ~/ size})';
    return '${p(move.from)}→${p(move.to)}，射${p(move.arrow)}';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: '♛',
        color: side == 0 ? const Color(0xFF1B1F22) : const Color(0xFFF6F0E4),
        background:
            side == 0 ? const Color(0xFF1B1F22) : const Color(0xFFF6F0E4),
        filled: true,
        size: size,
        fontSize: size * 0.55,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return AmazonsBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _AmazonSnapshot {
  final List<int> board;
  final int side;
  final int? winner;
  final int last;
  final int moveCount;

  _AmazonSnapshot(this.board, this.side, this.winner, this.last, this.moveCount);
}

class AmazonsBoard extends StatefulWidget {
  final AmazonsGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const AmazonsBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<AmazonsBoard> createState() => _AmazonsBoardState();
}

class _AmazonsBoardState extends State<AmazonsBoard> {
  int? from;
  int? to;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 10;
        final disc = cell * 0.78;
        final widgets = <Widget>[];
        for (var i = 0; i < AmazonsGame.cells; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final row = i ~/ 10;
          final col = i % 10;
          final vx = widget.flipped ? 9 - col : col;
          final vy = widget.flipped ? 9 - row : row;
          if (value == AmazonsGame.arrowMark) {
            widgets.add(Positioned(
              left: vx * cell + cell * 0.18,
              top: vy * cell + cell * 0.18,
              width: cell * 0.64,
              height: cell * 0.64,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: pi / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2E1F),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: const Color(0xFFE7BC6C), width: 1),
                    ),
                  ),
                ),
              ),
            ));
          } else {
            widgets.add(Positioned(
              left: vx * cell + (cell - disc) / 2,
              top: vy * cell + (cell - disc) / 2,
              width: disc,
              height: disc,
              child: IgnorePointer(
                child: GameDisc(
                  label: '♛',
                  color: value == 1
                      ? const Color(0xFF1B1F22)
                      : const Color(0xFFF6F0E4),
                  background: value == 1
                      ? const Color(0xFF1B1F22)
                      : const Color(0xFFF6F0E4),
                  filled: true,
                  size: disc,
                  fontSize: disc * 0.58,
                ),
              ),
            ));
          }
        }
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.interactive
                ? (details) {
                    final vx = (details.localPosition.dx / cell).floor().clamp(0, 9);
                    final vy = (details.localPosition.dy / cell).floor().clamp(0, 9);
                    final x = widget.flipped ? 9 - vx : vx;
                    final y = widget.flipped ? 9 - vy : vy;
                    _tap(y * 10 + x);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AmazonPainter(
                      game: game,
                      cell: cell,
                      flipped: widget.flipped,
                      selected: from,
                      target: to,
                      targets: targets,
                    ),
                  ),
                ),
                ...widgets,
              ],
            ),
          ),
        );
      },
    );
  }

  void _tap(int index) {
    final game = widget.game;
    if (from == null) {
      if (game.board[index] == game.side + 1) {
        setState(() {
          from = index;
          to = null;
          targets = AmazonsGame.queenTargets(game.board, index);
        });
      }
      return;
    }
    if (to == null) {
      if (targets.contains(index)) {
        setState(() {
          to = index;
          final b = List<int>.of(game.board);
          b[from!] = 0;
          b[to!] = game.side + 1;
          targets = AmazonsGame.queenTargets(b, to!);
        });
      } else {
        setState(() {
          from = null;
          to = null;
          targets = const [];
        });
      }
      return;
    }
    if (targets.contains(index)) {
      widget.onMove(AmazonMove(from!, to!, index));
      setState(() {
        from = null;
        to = null;
        targets = const [];
      });
    } else {
      setState(() {
        from = null;
        to = null;
        targets = const [];
      });
    }
  }
}

class _AmazonPainter extends CustomPainter {
  final AmazonsGame game;
  final double cell;
  final bool flipped;
  final int? selected;
  final int? target;
  final List<int> targets;

  _AmazonPainter({
    required this.game,
    required this.cell,
    required this.flipped,
    required this.selected,
    required this.target,
    required this.targets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < 10; row++) {
      for (var col = 0; col < 10; col++) {
        final vx = flipped ? 9 - col : col;
        final vy = flipped ? 9 - row : row;
        canvas.drawRect(
          Rect.fromLTWH(vx * cell, vy * cell, cell, cell),
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFFD9B77F)
                : const Color(0xFFC89D62),
        );
      }
    }
    for (final index in targets) {
      final row = index ~/ 10;
      final col = index % 10;
      final vx = flipped ? 9 - col : col;
      final vy = flipped ? 9 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.12,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.55),
      );
    }
    if (selected != null) {
      _ring(canvas, selected!, const Color(0xFFE7BC6C));
    }
    if (target != null) {
      _ring(canvas, target!, const Color(0xFFB53D32));
    }
    if (game._last >= 0) {
      _ring(canvas, game._last, const Color(0xFFB53D32));
    }
  }

  void _ring(Canvas canvas, int index, Color color) {
    final row = index ~/ 10;
    final col = index % 10;
    final vx = flipped ? 9 - col : col;
    final vy = flipped ? 9 - row : row;
    canvas.drawCircle(
      Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
      cell * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AmazonPainter oldDelegate) => true;
}
