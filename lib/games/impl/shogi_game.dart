import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class ShogiMove {
  final int from; // -1 for a drop
  final int to;
  final int dropType; // base type 1..7 when from < 0
  const ShogiMove(this.from, this.to, {this.dropType = 0});
  bool get isDrop => from < 0;
  @override
  String toString() => 'ShogiMove($from,$to,$dropType)';
}

/// A playable 9x9 shogi implementation with promotion, drops and check.
/// Values: positive = black (side 0), negative = white (side 1).
/// Types 1..8: pawn, lance, knight, silver, gold, bishop, rook, king.
/// Types 9..14 are promoted pawn/lance/knight/silver/bishop/rook.
class ShogiGame extends TurnGame {
  static const int size = 9;
  static const int cells = 81;
  static const int pawn = 1;
  static const int lance = 2;
  static const int knight = 3;
  static const int silver = 4;
  static const int gold = 5;
  static const int bishop = 6;
  static const int rook = 7;
  static const int king = 8;

  final List<int> board = List<int>.filled(cells, 0);
  final List<List<int>> hand = List.generate(2, (_) => List<int>.filled(8, 0));
  final List<_ShogiSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  ShogiGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    for (final h in hand) {
      h.fillRange(0, 8, 0);
    }
    // White at the top.
    const back = [lance, knight, silver, gold, king, gold, silver, knight, lance];
    for (var c = 0; c < 9; c++) {
      board[0 * 9 + c] = -back[c];
      board[2 * 9 + c] = -pawn;
      board[8 * 9 + c] = back[c];
      board[6 * 9 + c] = pawn;
    }
    board[1 * 9 + 1] = -rook;
    board[1 * 9 + 7] = -bishop;
    board[7 * 9 + 1] = bishop;
    board[7 * 9 + 7] = rook;
    _side = 0;
    _winner = null;
    _last = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.shogi;

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
  bool get inCheck => _inCheck(_side);

  static int ownerOf(int value) => value > 0 ? 0 : 1;
  static int typeOf(int value) => value.abs();
  static bool isPromoted(int value) => value.abs() > 8;
  static int baseType(int value) {
    final t = value.abs();
    return t > 8 ? t - 8 : t;
  }

  static int promoteType(int base) => switch (base) {
        pawn => 9,
        lance => 10,
        knight => 11,
        silver => 12,
        bishop => 13,
        rook => 14,
        _ => base,
      };

  bool _onBoard(int x, int y) => x >= 0 && x < size && y >= 0 && y < size;

  bool _inZone(int side, int row) => side == 0 ? row <= 2 : row >= 6;

  int? _kingIndex(int side) {
    final target = (side == 0 ? 1 : -1) * king;
    for (var i = 0; i < cells; i++) {
      if (board[i] == target) return i;
    }
    return null;
  }

  List<int> _pseudoTargets(int from) {
    final value = board[from];
    if (value == 0) return const [];
    final side = ownerOf(value);
    final type = typeOf(value);
    final base = baseType(value);
    final x = from % size;
    final y = from ~/ size;
    final forward = side == 0 ? -1 : 1;
    final result = <int>[];
    void add(int nx, int ny) {
      if (!_onBoard(nx, ny)) return;
      final target = board[ny * size + nx];
      if (target == 0 || ownerOf(target) != side) {
        result.add(ny * size + nx);
      }
    }

    void ray(int dx, int dy) {
      var nx = x + dx;
      var ny = y + dy;
      while (_onBoard(nx, ny)) {
        final target = board[ny * size + nx];
        if (target == 0) {
          result.add(ny * size + nx);
        } else {
          if (ownerOf(target) != side) result.add(ny * size + nx);
          break;
        }
        nx += dx;
        ny += dy;
      }
    }

    if (type == 9 || type == 10 || type == 11 || type == 12 || base == gold) {
      // Gold movement (promoted minor pieces move as gold).
      add(x, y + forward);
      add(x - 1, y + forward);
      add(x + 1, y + forward);
      add(x - 1, y);
      add(x + 1, y);
      add(x, y - forward);
    } else if (base == pawn) {
      add(x, y + forward);
    } else if (base == lance) {
      ray(0, forward);
    } else if (base == knight) {
      add(x - 1, y + forward * 2);
      add(x + 1, y + forward * 2);
    } else if (base == silver) {
      add(x, y + forward);
      add(x - 1, y + forward);
      add(x + 1, y + forward);
      add(x - 1, y - forward);
      add(x + 1, y - forward);
    } else if (base == king) {
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          if (dx != 0 || dy != 0) add(x + dx, y + dy);
        }
      }
    } else if (base == bishop) {
      ray(-1, -1);
      ray(-1, 1);
      ray(1, -1);
      ray(1, 1);
      if (type == 13) {
        add(x - 1, y);
        add(x + 1, y);
        add(x, y - 1);
        add(x, y + 1);
      }
    } else if (base == rook) {
      ray(-1, 0);
      ray(1, 0);
      ray(0, -1);
      ray(0, 1);
      if (type == 14) {
        add(x - 1, y - 1);
        add(x - 1, y + 1);
        add(x + 1, y - 1);
        add(x + 1, y + 1);
      }
    }
    return result;
  }

  bool _attacked(int index, int bySide) {
    for (var i = 0; i < cells; i++) {
      if (board[i] == 0 || ownerOf(board[i]) != bySide) continue;
      if (_pseudoTargets(i).contains(index)) return true;
    }
    return false;
  }

  bool _inCheck(int side) {
    final kingIndex = _kingIndex(side);
    if (kingIndex == null) return true;
    return _attacked(kingIndex, 1 - side);
  }

  bool _dropAllowed(int side, int type, int to) {
    if (type < pawn || type > rook || hand[side][type] <= 0) return false;
    if (board[to] != 0) return false;
    final row = to ~/ size;
    final col = to % size;
    if (type == pawn || type == lance) {
      if (side == 0 ? row == 0 : row == 8) return false;
    }
    if (type == knight) {
      if (side == 0 ? row <= 1 : row >= 7) return false;
    }
    if (type == pawn) {
      for (var y = 0; y < size; y++) {
        if (board[y * size + col] == (side == 0 ? pawn : -pawn)) return false;
      }
      // A pawn drop that leaves the opponent in checkmate is illegal; this
      // simplified engine only forbids direct checkmate by checking legality.
    }
    return true;
  }

  bool _isLegalRaw(ShogiMove move) {
    if (move.to < 0 || move.to >= cells) return false;
    if (move.isDrop) {
      if (!_dropAllowed(_side, move.dropType, move.to)) return false;
      board[move.to] = _side == 0 ? move.dropType : -move.dropType;
      final safe = !_inCheck(_side);
      board[move.to] = 0;
      return safe;
    }
    if (move.from < 0 || move.from >= cells) return false;
    final value = board[move.from];
    if (value == 0 || ownerOf(value) != _side) return false;
    if (board[move.to] != 0 && ownerOf(board[move.to]) == _side) return false;
    if (!_pseudoTargets(move.from).contains(move.to)) return false;
    final captured = board[move.to];
    board[move.to] = value;
    board[move.from] = 0;
    final safe = !_inCheck(_side);
    board[move.from] = value;
    board[move.to] = captured;
    return safe;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! ShogiMove) return false;
    return _isLegalRaw(move);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as ShogiMove;
    _history.add(_snapshot());
    if (m.isDrop) {
      hand[_side][m.dropType]--;
      board[m.to] = _side == 0 ? m.dropType : -m.dropType;
      _last = m.to;
      _moveCount++;
    } else {
      final value = board[m.from];
      final captured = board[m.to];
      if (captured != 0) {
        final base = baseType(captured);
        if (base != king) hand[_side][base]++;
      }
      board[m.from] = 0;
      var placed = value;
      final base = baseType(value);
      final side = ownerOf(value);
      if (!isPromoted(value) &&
          _inZone(side, m.to ~/ size) &&
          base != gold &&
          base != king) {
        placed = (side == 0 ? 1 : -1) * promoteType(base);
      }
      board[m.to] = placed;
      _last = m.to;
      _moveCount++;
    }
    _side = 1 - _side;
    final opponentKing = _kingIndex(_side);
    if (opponentKing == null) {
      _winner = 1 - _side;
      return;
    }
    final moves = _allLegalMoves(_side);
    if (moves.isEmpty) {
      _winner = 1 - _side;
    }
  }

  List<ShogiMove> _allLegalMoves(int side) {
    final saved = _side;
    _side = side;
    final result = <ShogiMove>[];
    for (var from = 0; from < cells; from++) {
      final value = board[from];
      if (value == 0 || ownerOf(value) != side) continue;
      for (final to in _pseudoTargets(from)) {
        final move = ShogiMove(from, to);
        if (_isLegalRaw(move)) result.add(move);
      }
    }
    for (var type = pawn; type <= rook; type++) {
      if (hand[side][type] <= 0) continue;
      for (var to = 0; to < cells; to++) {
        final move = ShogiMove(-1, to, dropType: type);
        if (_isLegalRaw(move)) result.add(move);
      }
    }
    _side = saved;
    return result;
  }

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_inCheck(_side)) return '王手！${sideName(_side)}应将';
    return '${sideName(_side)}行棋';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '对方王将无合法着法';
  }

  @override
  String scoreText(int side) {
    var value = 0;
    for (final piece in board) {
      if (piece == 0 || ownerOf(piece) != side) continue;
      value += _value(baseType(piece));
    }
    return '战力 $value';
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < cells; i++) {
      board[i] = s.board[i];
    }
    for (var side = 0; side < 2; side++) {
      for (var t = 0; t < 8; t++) {
        hand[side][t] = s.hand[side][t];
      }
    }
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = _allLegalMoves(_side);
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(ShogiMove, int)>[];
    for (final m in moves) {
      final captured = m.isDrop ? 0 : board[m.to];
      var score = captured == 0 ? 0 : _value(baseType(captured)) * 10;
      if (!m.isDrop && _inZone(_side, m.to ~/ size)) score += 12;
      if (m.isDrop) score += 4;
      if (level <= 0) score += random.nextInt(30);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 4 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  int _value(int type) => switch (type) {
        pawn => 1,
        lance => 3,
        knight => 4,
        silver => 6,
        gold => 8,
        bishop => 10,
        rook => 12,
        king => 1000,
        _ => 5,
      };

  _ShogiSnapshot _snapshot() => _ShogiSnapshot(
        List<int>.of(board),
        [List<int>.of(hand[0]), List<int>.of(hand[1])],
        _side,
        _winner,
        _last,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'hand': [List<int>.of(hand[0]), List<int>.of(hand[1])],
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
    final h = (json['hand'] as List?) ?? const [];
    for (var side = 0; side < 2; side++) {
      final list = side < h.length ? (h[side] as List?)?.cast<num>() ?? const [] : const <num>[];
      for (var t = 0; t < 8; t++) {
        hand[side][t] = t < list.length ? list[t].toInt() : 0;
      }
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _allLegalMoves(_side);

  static const List<String> _labels = [
    '', '歩', '香', '桂', '銀', '金', '角', '飛', '玉',
    'と', '杏', '圭', '全', '馬', '龍',
  ];

  @override
  String get llmState {
    final sb = StringBuffer(
      '9x9 将棋，黑方（side 0，大写/正数）在下方先手，白方在上方。'
      '棋子：歩1 香2 桂3 銀4 金5 角6 飛7 玉8；9=と 10=杏 11=圭 12=全 13=馬 14=龍。'
      '进入敌阵可升变；被吃棋子进入持驹，可落子。王被将死或无合法着法者负。\n',
    );
    for (var y = 0; y < size; y++) {
      sb.write('y=$y: ');
      for (var x = 0; x < size; x++) {
        final v = board[y * size + x];
        sb.write(v == 0 ? '.' : _labels[typeOf(v)]);
        sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('轮到${sideName(_side)}。黑持驹 ${_handText(0)}；白持驹 ${_handText(1)}。');
    return sb.toString();
  }

  String _handText(int side) {
    final parts = <String>[];
    for (var t = 1; t <= 7; t++) {
      if (hand[side][t] > 0) parts.add('${_labels[t]}${hand[side][t]}');
    }
    return parts.isEmpty ? '无' : parts.join(' ');
  }

  @override
  String describeMove(Object? move) {
    if (move is! ShogiMove) return '$move';
    String p(int i) => '(${i % size},${i ~/ size})';
    if (move.isDrop) return '落${_labels[move.dropType]}${p(move.to)}';
    return '${p(move.from)}→${p(move.to)}';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: '玉',
        color: side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22),
        background:
            side == 0 ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22),
        filled: true,
        size: size,
        fontSize: size * 0.38,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return ShogiBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _ShogiSnapshot {
  final List<int> board;
  final List<List<int>> hand;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _ShogiSnapshot(this.board, this.hand, this.side, this.winner, this.last,
      this.moveCount);
}

class ShogiBoard extends StatefulWidget {
  final ShogiGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const ShogiBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<ShogiBoard> createState() => _ShogiBoardState();
}

class _ShogiBoardState extends State<ShogiBoard> {
  int? selected;
  int? dropType;
  List<int> targets = const [];

  void _clear() {
    selected = null;
    dropType = null;
    targets = const [];
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = min(constraints.maxHeight, width * 1.10);
        final handH = height * 0.09;
        final boardSize = min(width, height - handH * 2);
        final cell = boardSize / 9;
        final stone = cell * 0.82;

        Widget handRow(int side, bool top) {
          final pieces = <Widget>[];
          for (var t = 1; t <= 7; t++) {
            if (game.hand[side][t] <= 0) continue;
            final isSelected = side == game.side && dropType == t;
            pieces.add(GestureDetector(
              onTap: widget.interactive && side == game.side
                  ? () {
                      setState(() {
                        selected = null;
                        dropType = t;
                        targets = _dropTargets(t);
                      });
                    }
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GameDisc(
                    label: ShogiGame._labels[t],
                    color: side == 0
                        ? const Color(0xFF1B1F22)
                        : const Color(0xFFF6F0E4),
                    background: side == 0
                        ? const Color(0xFFE7C994)
                        : const Color(0xFFE7C994),
                    selected: isSelected,
                    size: cell * 0.72,
                    fontSize: cell * 0.32,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1F22),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${game.hand[side][t]}',
                        style: const TextStyle(
                            color: Color(0xFFE7BC6C),
                            fontSize: 8,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ));
          }
          return SizedBox(
            height: handH,
            child: Row(
              children: [
                Text(
                  side == 0 ? '黑持驹' : '白持驹',
                  style: const TextStyle(fontSize: 9, color: Color(0xFFB9A58A)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final piece in pieces) ...[
                          piece,
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final pieces = <Widget>[];
        for (var i = 0; i < 81; i++) {
          final value = game.board[i];
          if (value == 0) continue;
          final row = i ~/ 9;
          final col = i % 9;
          final vx = widget.flipped ? 8 - col : col;
          final vy = widget.flipped ? 8 - row : row;
          final side = ShogiGame.ownerOf(value);
          pieces.add(Positioned(
            left: vx * cell + (cell - stone) / 2,
            top: vy * cell + (cell - stone) / 2,
            width: stone,
            height: stone,
            child: IgnorePointer(
              child: GameDisc(
                label: ShogiGame._labels[ShogiGame.typeOf(value)],
                color: side == 0
                    ? const Color(0xFF1B1F22)
                    : const Color(0xFF7A2E25),
                background: const Color(0xFFE7C994),
                filled: false,
                size: stone,
                fontSize: stone * 0.43,
                borderColor: side == 0
                    ? const Color(0xFF5B3D22)
                    : const Color(0xFFB53D32),
              ),
            ),
          ));
        }

        return SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              handRow(1, true),
              SizedBox(
                width: boardSize,
                height: boardSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.interactive
                      ? (details) {
                          final vx = (details.localPosition.dx / cell).floor().clamp(0, 8);
                          final vy = (details.localPosition.dy / cell).floor().clamp(0, 8);
                          final x = widget.flipped ? 8 - vx : vx;
                          final y = widget.flipped ? 8 - vy : vy;
                          _tap(y * 9 + x);
                        }
                      : null,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ShogiPainter(
                            game: game,
                            cell: cell,
                            flipped: widget.flipped,
                            selected: selected,
                            targets: targets,
                            inCheck: game._inCheck(game.side),
                          ),
                        ),
                      ),
                      ...pieces,
                    ],
                  ),
                ),
              ),
              handRow(0, false),
            ],
          ),
        );
      },
    );
  }

  List<int> _dropTargets(int type) {
    final result = <int>[];
    for (var i = 0; i < 81; i++) {
      final move = ShogiMove(-1, i, dropType: type);
      if (widget.game.isLegal(move)) result.add(i);
    }
    return result;
  }

  void _tap(int index) {
    final game = widget.game;
    if (dropType != null) {
      if (targets.contains(index)) {
        widget.onMove(ShogiMove(-1, index, dropType: dropType!));
        setState(_clear);
      }
      return;
    }
    if (selected != null && targets.contains(index)) {
      widget.onMove(ShogiMove(selected!, index));
      setState(_clear);
      return;
    }
    final value = game.board[index];
    if (value != 0 && ShogiGame.ownerOf(value) == game.side) {
      setState(() {
        selected = index;
        dropType = null;
        targets = [
          for (final to in game._pseudoTargets(index))
            if (game.isLegal(ShogiMove(index, to))) to,
        ];
      });
    } else {
      setState(_clear);
    }
  }
}

class _ShogiPainter extends CustomPainter {
  final ShogiGame game;
  final double cell;
  final bool flipped;
  final int? selected;
  final List<int> targets;
  final bool inCheck;

  _ShogiPainter({
    required this.game,
    required this.cell,
    required this.flipped,
    required this.selected,
    required this.targets,
    required this.inCheck,
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
          colors: [Color(0xFFE7C994), Color(0xFFC89A5E)],
        ).createShader(rect),
    );
    if (inCheck) {
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFB53D32).withValues(alpha: 0.75),
      );
    }
    final grid = Paint()
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 9; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
    }
    for (final index in targets) {
      final row = index ~/ 9;
      final col = index % 9;
      final vx = flipped ? 8 - col : col;
      final vy = flipped ? 8 - row : row;
      canvas.drawCircle(
        Offset((vx + 0.5) * cell, (vy + 0.5) * cell),
        cell * 0.16,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final row = selected! ~/ 9;
      final col = selected! % 9;
      final vx = flipped ? 8 - col : col;
      final vy = flipped ? 8 - row : row;
      canvas.drawRect(
        Rect.fromLTWH(vx * cell + 1, vy * cell + 1, cell - 2, cell - 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
    if (game._last != null) {
      final row = game._last! ~/ 9;
      final col = game._last! % 9;
      final vx = flipped ? 8 - col : col;
      final vy = flipped ? 8 - row : row;
      canvas.drawRect(
        Rect.fromLTWH(vx * cell + 1, vy * cell + 1, cell - 2, cell - 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFB53D32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShogiPainter oldDelegate) => true;
}
