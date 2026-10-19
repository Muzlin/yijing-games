import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class OnitamaMove {
  final int card;
  final int from;
  final int to;
  const OnitamaMove(this.card, this.from, this.to);
}

class OnitamaGame extends TurnGame {
  static const int size = 5;
  static const int cells = 25;
  static const int master = 8;
  static const List<List<List<int>>> cards = [
    [[0, -2], [0, 1]], // Tiger
    [[-2, 0], [2, 0], [-1, -1], [1, 1], [-1, 1], [1, -1]], // Dragon
    [[-1, -1], [1, -1], [-1, 1], [1, 1]], // Monkey
    [[0, -1], [-1, -1], [1, -1]], // Crane
    [[-1, 0], [1, 0], [-1, -1], [1, -1]], // Elephant
  ];
  static const List<String> cardNames = ['虎', '龙', '猿', '鹤', '象'];

  final List<int> board = List<int>.filled(cells, 0);
  final List<List<int>> sideCards = [
    [0, 1],
    [2, 3],
  ];
  int extraCard = 4;
  final List<_OniSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  int _moveCount = 0;

  OnitamaGame() {
    _setup();
  }

  void _setup() {
    board.fillRange(0, cells, 0);
    board[2 * 5 + 2] = master; // red master
    board[0 * 5 + 2] = -master; // blue master
    for (final p in const [1, 3, 6, 8]) {
      board[0 * 5 + p] = -1;
    }
    for (final p in const [21, 23, 16, 18]) {
      board[p] = 1;
    }
    _side = 0;
    _winner = null;
    _last = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.onitama;

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
    return '${sideName(_side)}选卡走子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '主将被吃或进入对方王座';
  }

  @override
  String scoreText(int side) =>
      '${board.where((v) => v != 0 && (v > 0) == (side == 0)).length} 子';

  bool _own(int side, int v) => side == 0 ? v > 0 : v < 0;

  List<int> _targets(int side, int card, int from) {
    final v = board[from];
    if (v == 0 || !_own(side, v)) return const [];
    final x = from % 5;
    final y = from ~/ 5;
    final result = <int>[];
    for (final d in cards[card]) {
      final dy = side == 0 ? d[1] : -d[1];
      final nx = x + d[0];
      final ny = y + dy;
      if (nx < 0 || nx >= 5 || ny < 0 || ny >= 5) continue;
      final n = ny * 5 + nx;
      if (!_own(side, board[n])) result.add(n);
    }
    return result;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! OnitamaMove) return false;
    if (move.card < 0 || move.card >= 5) return false;
    if (!sideCards[_side].contains(move.card)) return false;
    if (move.from < 0 || move.from >= cells || move.to < 0 || move.to >= cells) return false;
    if (!_own(_side, board[move.from]) || _own(_side, board[move.to])) return false;
    return _targets(_side, move.card, move.from).contains(move.to);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as OnitamaMove;
    _history.add(_snapshot());
    final captured = board[m.to];
    board[m.to] = board[m.from];
    board[m.from] = 0;
    _last = m.to;
    _moveCount++;
    board[m.to] = _side == 0 ? board[m.to].abs() : -board[m.to].abs();
    if (captured.abs() == master) {
      _winner = _side;
      return;
    }
    // Master reaching the opponent throne.
    if (board[m.to].abs() == master) {
      if (_side == 0 && m.to ~/ 5 == 0) {
        _winner = 0;
        return;
      }
      if (_side == 1 && m.to ~/ 5 == 4) {
        _winner = 1;
        return;
      }
    }
    final chosen = m.card;
    sideCards[_side].remove(chosen);
    sideCards[_side].add(extraCard);
    extraCard = chosen;
    _side = 1 - _side;
    if (_allMoves(_side).isEmpty) _winner = 1 - _side;
  }

  List<OnitamaMove> _allMoves(int side) {
    final saved = _side;
    _side = side;
    final result = <OnitamaMove>[];
    for (final card in sideCards[side]) {
      for (var from = 0; from < cells; from++) {
        if (board[from] == 0 || !_own(side, board[from])) continue;
        for (final to in _targets(side, card, from)) {
          result.add(OnitamaMove(card, from, to));
        }
      }
    }
    _side = saved;
    return result;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    board.setAll(0, s.board);
    sideCards[0] = List<int>.of(s.cards0);
    sideCards[1] = List<int>.of(s.cards1);
    extraCard = s.extra;
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
    final scored = <(OnitamaMove, int)>[];
    for (final m in moves) {
      var score = 0;
      final cap = board[m.to].abs();
      if (cap == master) score += 100000;
      if (cap > 0) score += 100;
      if (board[m.from].abs() == master) score += 20;
      if (level <= 0) score += random.nextInt(25);
      scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final pool = scored.take(level <= 0 ? 3 : 1).toList();
    return pool[random.nextInt(pool.length)].$1;
  }

  _OniSnapshot _snapshot() => _OniSnapshot(
        List<int>.of(board),
        List<int>.of(sideCards[0]),
        List<int>.of(sideCards[1]),
        extraCard,
        _side,
        _winner,
        _last,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'cards0': List<int>.of(sideCards[0]),
        'cards1': List<int>.of(sideCards[1]),
        'extra': extraCard,
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
    final c0 = (json['cards0'] as List?)?.cast<num>() ?? const [];
    final c1 = (json['cards1'] as List?)?.cast<num>() ?? const [];
    sideCards[0] = c0.map((e) => e.toInt()).toList();
    sideCards[1] = c1.map((e) => e.toInt()).toList();
    extraCard = (json['extra'] as num?)?.toInt() ?? 4;
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => _allMoves(_side);

  @override
  String get llmState {
    final sb = StringBuffer(
      '鬼将棋（Onitama）5x5，红方下方、蓝方上方。每方 1 主将 + 4 弟子，'
      '每方有两张移动卡，另有一张公共卡。每回合用一张己方卡移动一个棋子，'
      '然后把该卡与公共卡交换。吃掉对方主将或主将进入对方王座者胜。\n',
    );
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        final v = board[r * 5 + c];
        sb.write(v == 0 ? '.' : (v > 0 ? (v == master ? 'M' : 'X') : (v == -master ? 'm' : 'o')));
        sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! OnitamaMove) return '$move';
    String p(int i) => '(${i % 5},${i ~/ 5})';
    return '${cardNames[move.card]} ${p(move.from)}→${p(move.to)}';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: 'M',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        filled: true,
        size: size,
        fontSize: size * 0.4,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return OnitamaBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _OniSnapshot {
  final List<int> board;
  final List<int> cards0;
  final List<int> cards1;
  final int extra;
  final int side;
  final int? winner;
  final int? last;
  final int moveCount;

  _OniSnapshot(this.board, this.cards0, this.cards1, this.extra, this.side,
      this.winner, this.last, this.moveCount);
}

class OnitamaBoard extends StatefulWidget {
  final OnitamaGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const OnitamaBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<OnitamaBoard> createState() => _OnitamaBoardState();
}

class _OnitamaBoardState extends State<OnitamaBoard> {
  int? card;
  int? selected;
  List<int> targets = const [];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final boardSize = size * 0.74;
        final cell = boardSize / 5;
        final cardH = size * 0.18;
        final cardY = size - cardH;
        Offset at(int i) => Offset(
              (i % 5) * cell + cell / 2,
              (i ~/ 5) * cell + cell / 2,
            );
        final pieces = <Widget>[];
        for (var i = 0; i < 25; i++) {
          final v = game.board[i];
          if (v == 0) continue;
          final p = at(i);
          final red = v > 0;
          pieces.add(Positioned(
            left: p.dx - cell * 0.36,
            top: p.dy - cell * 0.36,
            width: cell * 0.72,
            height: cell * 0.72,
            child: IgnorePointer(
              child: GameDisc(
                label: v.abs() == OnitamaGame.master ? 'M' : '·',
                color: red ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
                background: red ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
                filled: true,
                size: cell * 0.72,
                fontSize: cell * 0.32,
              ),
            ),
          ));
        }
        final cards = game.sideCards[game.side];
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: boardSize,
                height: boardSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.interactive
                      ? (details) {
                          final x = (details.localPosition.dx / cell).floor().clamp(0, 4);
                          final y = (details.localPosition.dy / cell).floor().clamp(0, 4);
                          _tap(y * 5 + x);
                        }
                      : null,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OniPainter(
                            game: game,
                            cell: cell,
                            selected: selected,
                            targets: targets,
                          ),
                        ),
                      ),
                      ...pieces,
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < cards.length; i++)
                Positioned(
                  left: i * (size * 0.34) + size * 0.05,
                  top: cardY,
                  width: size * 0.28,
                  height: cardH,
                  child: GestureDetector(
                    onTap: widget.interactive
                        ? () => setState(() {
                              card = cards[i];
                              selected = null;
                              targets = const [];
                            })
                        : null,
                    child: _OniCard(
                      name: OnitamaGame.cardNames[cards[i]],
                      pattern: OnitamaGame.cards[cards[i]],
                      selected: card == cards[i],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _tap(int i) {
    final game = widget.game;
    if (card == null) return;
    if (selected != null && targets.contains(i)) {
      widget.onMove(OnitamaMove(card!, selected!, i));
      setState(() {
        selected = null;
        targets = const [];
        card = null;
      });
      return;
    }
    if (game.board[i] != 0 && (game.board[i] > 0) == (game.side == 0)) {
      setState(() {
        selected = i;
        targets = game._targets(game.side, card!, i);
      });
    }
  }
}

class _OniCard extends StatelessWidget {
  final String name;
  final List<List<int>> pattern;
  final bool selected;

  const _OniCard({required this.name, required this.pattern, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF0C8) : const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFFE7BC6C) : const Color(0xFFC9BFAE),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1F22))),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pattern.length && i < 3; i++)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.all(1),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB53D32),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OniPainter extends CustomPainter {
  final OnitamaGame game;
  final double cell;
  final int? selected;
  final List<int> targets;

  _OniPainter({
    required this.game,
    required this.cell,
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
          colors: [Color(0xFFE0BE8B), Color(0xFFC79D66)],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = const Color(0xFF6A4A2B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    for (final i in targets) {
      final c = Offset((i % 5 + 0.5) * cell, (i ~/ 5 + 0.5) * cell);
      canvas.drawCircle(
        c,
        cell * 0.16,
        Paint()..color = const Color(0xFF3D6B54).withValues(alpha: 0.45),
      );
    }
    if (selected != null) {
      final c = Offset((selected! % 5 + 0.5) * cell, (selected! ~/ 5 + 0.5) * cell);
      canvas.drawCircle(
        c,
        cell * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE7BC6C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OniPainter oldDelegate) => true;
}
