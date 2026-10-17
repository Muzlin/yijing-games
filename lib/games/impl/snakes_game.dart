import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';

class SnakesGame extends TurnGame {
  static const int size = 10;
  static const int cells = size * size;

  static const Map<int, int> ladders = {
    4: 14,
    9: 31,
    20: 38,
    28: 84,
    40: 59,
    51: 67,
    63: 81,
    71: 91,
  };
  static const Map<int, int> snakes = {
    17: 7,
    54: 34,
    62: 19,
    64: 60,
    87: 24,
    93: 73,
    95: 75,
    99: 78,
  };

  final List<int> positions = [0, 0];
  final List<_SnakeSnapshot> _history = [];
  int _side = 0;
  int _winner = -1;
  int _moveCount = 0;
  int _lastRoll = 0;
  int _lastFrom = 0;
  int _lastTo = 0;

  @override
  GameMeta get meta => GameCatalog.snakes;

  @override
  int get side => _side;

  @override
  bool get isOver => _winner >= 0;

  @override
  int? get winner => isOver ? _winner : null;

  @override
  int get moveCount => _moveCount;

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  String sideName(int side) => side == 0 ? '红方' : '蓝方';

  @override
  String get statusText {
    if (isOver) return resultTitle;
    if (_lastRoll > 0) {
      return '${sideName(1 - _side)}掷出 $_lastRoll 点';
    }
    return '${sideName(_side)}掷骰子';
  }

  @override
  String get resultTitle {
    if (!isOver) return '';
    return '${sideName(_winner)}胜';
  }

  @override
  String get resultSubtitle => isOver ? '率先到达 100 格' : '';

  @override
  String scoreText(int side) => '第 ${positions[side]} 格';

  @override
  String? get primaryActionLabel => isOver ? null : '掷骰子';

  @override
  IconData get primaryActionIcon => Icons.casino_rounded;

  @override
  void primaryAction() {
    if (isOver) return;
    apply(1 + Random().nextInt(6));
  }

  @override
  bool isLegal(Object? move) => !isOver && move is int && move >= 1 && move <= 6;

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final roll = move as int;
    _history.add(_snapshot());
    _lastRoll = roll;
    _lastFrom = positions[_side];
    var next = positions[_side] + roll;
    if (next > 100) next = positions[_side];
    if (ladders.containsKey(next)) next = ladders[next]!;
    if (snakes.containsKey(next)) next = snakes[next]!;
    positions[_side] = next;
    _lastTo = next;
    _moveCount++;
    if (next == 100) {
      _winner = _side;
      return;
    }
    _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    positions[0] = snapshot.positions[0];
    positions[1] = snapshot.positions[1];
    _side = snapshot.side;
    _winner = snapshot.winner;
    _moveCount = snapshot.moveCount;
    _lastRoll = snapshot.lastRoll;
    _lastFrom = snapshot.lastFrom;
    _lastTo = snapshot.lastTo;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    return 1 + Random().nextInt(6);
  }

  _SnakeSnapshot _snapshot() => _SnakeSnapshot(
        List<int>.of(positions),
        _side,
        _winner,
        _moveCount,
        _lastRoll,
        _lastFrom,
        _lastTo,
      );

  @override
  Map<String, Object?> toJson() => {
        'positions': List<int>.of(positions),
        'side': _side,
        'winner': _winner,
        'moveCount': _moveCount,
        'lastRoll': _lastRoll,
        'lastFrom': _lastFrom,
        'lastTo': _lastTo,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['positions'] as List?)?.cast<num>() ?? const [];
    positions[0] = raw.isNotEmpty ? raw[0].toInt() : 0;
    positions[1] = raw.length > 1 ? raw[1].toInt() : 0;
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt() ?? -1;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _lastRoll = (json['lastRoll'] as num?)?.toInt() ?? 0;
    _lastFrom = (json['lastFrom'] as num?)?.toInt() ?? 0;
    _lastTo = (json['lastTo'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  Widget sideBadge(int side, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: side == 0
                ? const [Color(0xFFFF8A7C), Color(0xFFC94F43)]
                : const [Color(0xFF8EC2FF), Color(0xFF4E86C7)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded,
            size: size * 0.5, color: Colors.white),
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return SnakesBoard(game: this, flipped: flipped);
  }
}

class _SnakeSnapshot {
  final List<int> positions;
  final int side;
  final int winner;
  final int moveCount;
  final int lastRoll;
  final int lastFrom;
  final int lastTo;

  _SnakeSnapshot(this.positions, this.side, this.winner, this.moveCount, this.lastRoll, this.lastFrom, this.lastTo);
}

class SnakesBoard extends StatelessWidget {
  final SnakesGame game;
  final bool flipped;

  const SnakesBoard({super.key, required this.game, this.flipped = false});

  Offset _cellCenter(int number, double cell, double padding) {
    if (number <= 0) {
      return Offset(padding + cell * 0.5, padding + cell * 9.5);
    }
    final index = number - 1;
    final rowFromBottom = index ~/ 10;
    final col = rowFromBottom.isEven ? index % 10 : 9 - index % 10;
    final row = 9 - rowFromBottom;
    final vx = flipped ? 9 - col : col;
    final vy = flipped ? 9 - row : row;
    return Offset(padding + (vx + 0.5) * cell, padding + (vy + 0.5) * cell);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final cell = side / 10;
        final padding = 0.0;
        final tokens = <Widget>[];
        for (var player = 0; player < 2; player++) {
          final number = game.positions[player];
          final center = _cellCenter(number, cell, padding);
          final offset = player == 0 ? -cell * 0.14 : cell * 0.14;
          tokens.add(Positioned(
            left: center.dx - cell * 0.22 + offset,
            top: center.dy - cell * 0.22 + (number == 0 ? player * cell * 0.1 : 0),
            width: cell * 0.44,
            height: cell * 0.44,
            child: IgnorePointer(
              child: game.sideBadge(player, cell * 0.44),
            ),
          ));
        }
        return SizedBox.square(
          dimension: side,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SnakesPainter(
                    game: game,
                    cell: cell,
                    flipped: flipped,
                  ),
                ),
              ),
              ...tokens,
            ],
          ),
        );
      },
    );
  }
}

class _SnakesPainter extends CustomPainter {
  final SnakesGame game;
  final double cell;
  final bool flipped;

  _SnakesPainter({required this.game, required this.cell, required this.flipped});

  Offset _center(int number) {
    if (number <= 0) return Offset(cell * 0.5, cell * 9.5);
    final index = number - 1;
    final rowFromBottom = index ~/ 10;
    final col = rowFromBottom.isEven ? index % 10 : 9 - index % 10;
    final row = 9 - rowFromBottom;
    final vx = flipped ? 9 - col : col;
    final vy = flipped ? 9 - row : row;
    return Offset((vx + 0.5) * cell, (vy + 0.5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F4B55), Color(0xFF182B32)],
        ).createShader(rect),
    );
    for (var number = 1; number <= 100; number++) {
      final center = _center(number);
      final r = Rect.fromCenter(
        center: center,
        width: cell - 1,
        height: cell - 1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.12)),
        Paint()
          ..color = number % 2 == 0
              ? const Color(0xFF203A44)
              : const Color(0xFF244650),
      );
      final text = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            fontSize: cell * 0.2,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        center - Offset(text.width / 2, text.height / 2),
      );
    }

    // Ladders
    for (final entry in SnakesGame.ladders.entries) {
      final start = _center(entry.key);
      final end = _center(entry.value);
      final delta = end - start;
      final length = delta.distance;
      if (length < 1) continue;
      final dir = delta / length;
      final normal = Offset(-dir.dy, dir.dx) * (cell * 0.2);
      final paint = Paint()
        ..color = const Color(0xFFD8B87A)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start + normal, end + normal, paint);
      canvas.drawLine(start - normal, end - normal, paint);
      final steps = (length / (cell * 0.34)).floor();
      for (var i = 1; i < steps; i++) {
        final p = start + delta * (i / steps);
        canvas.drawLine(
          p + normal,
          p - normal,
          Paint()
            ..color = const Color(0xFFD8B87A).withValues(alpha: 0.7)
            ..strokeWidth = 1.2,
        );
      }
    }

    // Snakes
    for (final entry in SnakesGame.snakes.entries) {
      final start = _center(entry.key);
      final end = _center(entry.value);
      final control = (start + end) / 2 +
          Offset((end.dx - start.dx) * 0.35, (end.dy - start.dy) * 0.35);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.16
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF88B36B).withValues(alpha: 0.85),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFC5E3A8).withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        start,
        cell * 0.16,
        Paint()..color = const Color(0xFF9AC679),
      );
    }

    if (game._lastRoll > 0 && !game.isOver) {
      final center = Offset(size.width - cell * 0.6, cell * 0.55);
      final r = Rect.fromCenter(center: center, width: cell * 0.72, height: cell * 0.72);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.16)),
        Paint()..color = const Color(0xFFE7BC6C),
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${game._lastRoll}',
          style: TextStyle(
            fontSize: cell * 0.4,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF231A08),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SnakesPainter oldDelegate) => true;
}
