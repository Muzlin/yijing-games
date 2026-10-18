import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

/// Kalah-style mancala. Side 0 owns pits 0..5 and store 6; side 1 owns
/// pits 7..12 and store 13. Sowing is counter-clockwise.
class MancalaGame extends TurnGame {
  final List<int> pits = List<int>.filled(14, 4);
  final List<_MancalaSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _lastPit;
  int _moveCount = 0;

  MancalaGame() {
    _setup();
  }

  void _setup() {
    for (var i = 0; i < 14; i++) {
      pits[i] = (i == 6 || i == 13) ? 0 : 4;
    }
    _side = 0;
    _winner = null;
    _lastPit = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.mancala;

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
    return '${sideName(_side)}选坑播种';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    if (_winner == 2) return '和棋';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '红 ${pits[6]} · 蓝 ${pits[13]}';
  }

  @override
  String scoreText(int side) => '${pits[side == 0 ? 6 : 13]} 颗';

  bool _ownPit(int side, int index) =>
      side == 0 ? index >= 0 && index <= 5 : index >= 7 && index <= 12;

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! int || move < 0 || move >= 14) return false;
    return _ownPit(_side, move) && pits[move] > 0;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final start = move as int;
    _history.add(_snapshot());
    var seeds = pits[start];
    pits[start] = 0;
    var current = start;
    while (seeds > 0) {
      current = (current + 1) % 14;
      if ((_side == 0 && current == 13) || (_side == 1 && current == 6)) {
        continue;
      }
      pits[current]++;
      seeds--;
    }
    _lastPit = current;
    _moveCount++;
    var extra = current == (_side == 0 ? 6 : 13);
    if (!extra && _ownPit(_side, current) && pits[current] == 1) {
      final opposite = 12 - current;
      if (pits[opposite] > 0) {
        pits[_side == 0 ? 6 : 13] += pits[opposite] + 1;
        pits[opposite] = 0;
        pits[current] = 0;
      }
    }
    if (_sideEmpty(0) || _sideEmpty(1)) {
      _finish();
      return;
    }
    if (!extra) _side = 1 - _side;
  }

  bool _sideEmpty(int side) {
    for (var i = 0; i < 6; i++) {
      if (pits[side == 0 ? i : i + 7] > 0) return false;
    }
    return true;
  }

  void _finish() {
    for (var i = 0; i < 6; i++) {
      pits[6] += pits[i];
      pits[i] = 0;
      pits[13] += pits[i + 7];
      pits[i + 7] = 0;
    }
    _winner = pits[6] == pits[13] ? 2 : (pits[6] > pits[13] ? 0 : 1);
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    pits.setAll(0, s.pits);
    _side = s.side;
    _winner = s.winner;
    _lastPit = s.lastPit;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final moves = [
      for (var i = 0; i < 6; i++)
        if (pits[_side == 0 ? i : i + 7] > 0) (_side == 0 ? i : i + 7),
    ];
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(int, int)>[];
    for (final pit in moves) {
      final storeBefore = pits[_side == 0 ? 6 : 13];
      final saved = List<int>.of(pits);
      // Simulate one sowing without switching sides.
      final side = _side;
      _side = side;
      var seeds = pits[pit];
      pits[pit] = 0;
      var cur = pit;
      while (seeds > 0) {
        cur = (cur + 1) % 14;
        if ((side == 0 && cur == 13) || (side == 1 && cur == 6)) continue;
        pits[cur]++;
        seeds--;
      }
      var score = pits[side == 0 ? 6 : 13] - storeBefore;
      if (cur == (side == 0 ? 6 : 13)) score += 20;
      if (level <= 0) score += random.nextInt(10);
      pits.setAll(0, saved);
      scored.add((pit, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.first.$1;
  }

  _MancalaSnapshot _snapshot() => _MancalaSnapshot(
        List<int>.of(pits),
        _side,
        _winner,
        _lastPit,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'pits': List<int>.of(pits),
        'side': _side,
        'winner': _winner,
        'lastPit': _lastPit,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['pits'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 14; i++) {
      pits[i] = i < raw.length ? raw[i].toInt() : 4;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastPit = (json['lastPit'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => [
        for (var i = 0; i < 6; i++)
          if (pits[_side == 0 ? i : i + 7] > 0) (_side == 0 ? i : i + 7),
      ];

  @override
  String get llmState {
    final sb = StringBuffer(
      '曼卡拉（Kalah）2x6 坑，红方下方 0-5、蓝方上方 7-12；红方先手。'
      '选一个己方有籽的坑，沿逆时针播种；经过己方仓库可放一颗，经过对方仓库跳过。'
      '最后一颗落在己方仓库可再走；落在己方空坑可俘获对面坑的籽。'
      '一方坑空后结束，仓库籽多者胜。\n',
    );
    sb.write('红坑 ${pits.sublist(0, 6)}，红仓 ${pits[6]}；'
        '蓝坑 ${pits.sublist(7, 13)}，蓝仓 ${pits[13]}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    final side = move <= 5 ? 0 : 1;
    final n = side == 0 ? move + 1 : move - 6;
    return '第 $n 坑';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '红' : '蓝',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        filled: true,
        size: size,
        fontSize: size * 0.36,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return MancalaBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _MancalaSnapshot {
  final List<int> pits;
  final int side;
  final int? winner;
  final int? lastPit;
  final int moveCount;

  _MancalaSnapshot(this.pits, this.side, this.winner, this.lastPit, this.moveCount);
}

class MancalaBoard extends StatelessWidget {
  final MancalaGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const MancalaBoard({
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
        final layout = _MancalaLayout(size);
        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    for (var i = 0; i < 14; i++) {
                      final r = layout.pitRect(i);
                      if (r.inflate(4).contains(details.localPosition)) {
                        onMove(i);
                        return;
                      }
                    }
                  }
                : null,
            child: CustomPaint(
              painter: _MancalaPainter(game: game, layout: layout, flipped: flipped),
            ),
          ),
        );
      },
    );
  }
}

class _MancalaLayout {
  final double size;
  final double margin;
  final double storeW;
  final double pitW;
  final double pitH;

  _MancalaLayout(this.size)
      : margin = size * 0.06,
        storeW = size * 0.14,
        pitW = (size * 0.62) / 6,
        pitH = size * 0.20;

  Rect pitRect(int index) {
    if (index == 6) {
      return Rect.fromLTWH(margin, size * 0.28, storeW, size * 0.44);
    }
    if (index == 13) {
      return Rect.fromLTWH(size - margin - storeW, size * 0.28, storeW, size * 0.44);
    }
    final side = index <= 5 ? 0 : 1;
    final n = side == 0 ? index : index - 7;
    final left = margin + storeW + size * 0.03 + n * pitW;
    final top = side == 0 ? size * 0.55 : size * 0.25;
    return Rect.fromLTWH(left, top, pitW * 0.86, pitH);
  }
}

class _MancalaPainter extends CustomPainter {
  final MancalaGame game;
  final _MancalaLayout layout;
  final bool flipped;

  _MancalaPainter({required this.game, required this.layout, required this.flipped});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A3523), Color(0xFF2A1710)],
        ).createShader(rect),
    );
    for (var i = 0; i < 14; i++) {
      final r = layout.pitRect(i);
      final isStore = i == 6 || i == 13;
      final side = i == 6 ? 0 : (i == 13 ? 1 : (i <= 5 ? 0 : 1));
      final color = side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(isStore ? r.width * 0.3 : r.height * 0.5)),
        Paint()..color = color.withValues(alpha: 0.16),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(isStore ? r.width * 0.3 : r.height * 0.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.65),
      );
      final count = game.pits[i];
      final text = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(
            color: const Color(0xFFF6F0E4),
            fontSize: r.height * (isStore ? 0.26 : 0.30),
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, r.center - Offset(text.width / 2, text.height / 2));
      for (var n = 0; n < count && n < 8; n++) {
        final angle = n * 2 * pi / 8;
        final radius = r.width * 0.18;
        canvas.drawCircle(
          r.center + Offset(cos(angle), sin(angle)) * radius,
          r.height * 0.055,
          Paint()..color = const Color(0xFFE7BC6C).withValues(alpha: 0.75),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MancalaPainter oldDelegate) => true;
}
