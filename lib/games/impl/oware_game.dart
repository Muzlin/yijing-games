import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

/// Oware / Awari: twelve pits, four seeds each. Sowing is counter-clockwise.
class OwareGame extends TurnGame {
  final List<int> pits = List<int>.filled(12, 4);
  final List<int> captured = [0, 0];
  final List<_OwareSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _lastPit;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.oware;

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
    return '${sideName(_side)}播种';
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
    return '红 ${_total(0)} · 蓝 ${_total(1)}';
  }

  @override
  String scoreText(int side) => '${captured[side]} 俘';

  int _total(int side) {
    var total = captured[side];
    for (var i = 0; i < 6; i++) {
      if (side == 0) total += pits[i];
      if (side == 1) total += pits[i + 6];
    }
    return total;
  }

  bool _ownPit(int side, int index) =>
      side == 0 ? index >= 0 && index < 6 : index >= 6 && index < 12;

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! int || move < 0 || move >= 12) return false;
    return _ownPit(_side, move) && pits[move] > 0;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    _history.add(_snapshot());
    final start = move as int;
    var seeds = pits[start];
    pits[start] = 0;
    var current = start;
    while (seeds > 0) {
      current = (current + 1) % 12;
      pits[current]++;
      seeds--;
    }
    _lastPit = current;
    _moveCount++;
    if (!_ownPit(_side, current)) {
      var c = current;
      while (_ownPit(1 - _side, c) && (pits[c] == 2 || pits[c] == 3)) {
        captured[_side] += pits[c];
        pits[c] = 0;
        c = (c - 1 + 12) % 12;
      }
    }
    if (_sideEmpty(0) || _sideEmpty(1) || captured[_side] >= 25) {
      _finish();
      return;
    }
    _side = 1 - _side;
    if (!_hasMoves(_side)) {
      _finish();
    }
  }

  bool _sideEmpty(int side) {
    for (var i = 0; i < 6; i++) {
      if (pits[side == 0 ? i : i + 6] > 0) return false;
    }
    return true;
  }

  bool _hasMoves(int side) {
    for (var i = 0; i < 6; i++) {
      if (pits[side == 0 ? i : i + 6] > 0) return true;
    }
    return false;
  }

  void _finish() {
    final a = _total(0);
    final b = _total(1);
    _winner = a == b ? 2 : (a > b ? 0 : 1);
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    pits.setAll(0, s.pits);
    captured[0] = s.captured0;
    captured[1] = s.captured1;
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
        if (pits[_side == 0 ? i : i + 6] > 0) (_side == 0 ? i : i + 6),
    ];
    if (moves.isEmpty) return null;
    final random = Random();
    final scored = <(int, int)>[];
    for (final pit in moves) {
      final saved = List<int>.of(pits);
      final capBefore = captured[_side];
      // Simulate sowing and capture.
      var seeds = pits[pit];
      pits[pit] = 0;
      var cur = pit;
      while (seeds > 0) {
        cur = (cur + 1) % 12;
        pits[cur]++;
        seeds--;
      }
      if (!_ownPit(_side, cur)) {
        var c = cur;
        while (_ownPit(1 - _side, c) && (pits[c] == 2 || pits[c] == 3)) {
          captured[_side] += pits[c];
          pits[c] = 0;
          c = (c - 1 + 12) % 12;
        }
      }
      var score = (captured[_side] - capBefore) * 20;
      if (level <= 0) score += random.nextInt(10);
      captured[_side] = capBefore;
      pits.setAll(0, saved);
      scored.add((pit, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.first.$1;
  }

  _OwareSnapshot _snapshot() => _OwareSnapshot(
        List<int>.of(pits),
        captured[0],
        captured[1],
        _side,
        _winner,
        _lastPit,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'pits': List<int>.of(pits),
        'captured': List<int>.of(captured),
        'side': _side,
        'winner': _winner,
        'lastPit': _lastPit,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['pits'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 12; i++) {
      pits[i] = i < raw.length ? raw[i].toInt() : 4;
    }
    final c = (json['captured'] as List?)?.cast<num>() ?? const [];
    captured[0] = c.isNotEmpty ? c[0].toInt() : 0;
    captured[1] = c.length > 1 ? c[1].toInt() : 0;
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastPit = (json['lastPit'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => [
        for (var i = 0; i < 6; i++)
          if (pits[_side == 0 ? i : i + 6] > 0) (_side == 0 ? i : i + 6),
      ];

  @override
  String get llmState {
    final sb = StringBuffer(
      '播棋（Oware）2x6 坑，红方下方 0-5、蓝方上方 6-11，每坑 4 籽，红方先手。'
      '选己方有籽的坑逆时针播种；最后一颗落在对方坑且该坑有 2 或 3 籽时可俘获，'
      '并继续向前俘获连续的 2/3 籽坑。俘获 25 籽或对方无子可动者胜。\n',
    );
    sb.write('红坑 ${pits.sublist(0, 6)}，蓝坑 ${pits.sublist(6, 12)}；'
        '红俘 ${captured[0]}，蓝俘 ${captured[1]}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    final side = move < 6 ? 0 : 1;
    final n = side == 0 ? move + 1 : move - 5;
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
    return OwareBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _OwareSnapshot {
  final List<int> pits;
  final int captured0;
  final int captured1;
  final int side;
  final int? winner;
  final int? lastPit;
  final int moveCount;

  _OwareSnapshot(this.pits, this.captured0, this.captured1, this.side, this.winner,
      this.lastPit, this.moveCount);
}

class OwareBoard extends StatelessWidget {
  final OwareGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const OwareBoard({
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
        final margin = size * 0.06;
        final pitW = (size - margin * 2) / 6;
        final pitH = size * 0.26;
        Offset center(int index) {
          final side = index < 6 ? 0 : 1;
          final n = index % 6;
          final vx = flipped ? 5 - n : n;
          final x = margin + (vx + 0.5) * pitW;
          final y = side == 0 ? size * 0.68 : size * 0.32;
          return Offset(x, y);
        }

        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    for (var i = 0; i < 12; i++) {
                      if ((center(i) - details.localPosition).distance < pitW * 0.42) {
                        onMove(i);
                        return;
                      }
                    }
                  }
                : null,
            child: CustomPaint(
              painter: _OwarePainter(
                game: game,
                margin: margin,
                pitW: pitW,
                pitH: pitH,
                center: center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OwarePainter extends CustomPainter {
  final OwareGame game;
  final double margin;
  final double pitW;
  final double pitH;
  final Offset Function(int) center;

  _OwarePainter({
    required this.game,
    required this.margin,
    required this.pitW,
    required this.pitH,
    required this.center,
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
          colors: [Color(0xFF5A3523), Color(0xFF2A1710)],
        ).createShader(rect),
    );
    for (var i = 0; i < 12; i++) {
      final c = center(i);
      final r = Rect.fromCenter(center: c, width: pitW * 0.82, height: pitH);
      final side = i < 6 ? 0 : 1;
      final color = side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(pitH * 0.5)),
        Paint()..color = color.withValues(alpha: 0.14),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(pitH * 0.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = color.withValues(alpha: 0.6),
      );
      final count = game.pits[i];
      final text = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(
            color: const Color(0xFFF6F0E4),
            fontSize: pitH * 0.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
      for (var n = 0; n < count && n < 8; n++) {
        final angle = n * 2 * pi / 8;
        canvas.drawCircle(
          c + Offset(cos(angle), sin(angle)) * pitW * 0.14,
          pitH * 0.06,
          Paint()..color = const Color(0xFFE7BC6C).withValues(alpha: 0.75),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OwarePainter oldDelegate) => true;
}
