import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class FlyingTurn {
  final int dice;
  final int plane;
  const FlyingTurn(this.dice, this.plane);
  @override
  String toString() => 'FlyingTurn($dice,$plane)';
}

/// Two-player 飞行棋 / Ludo on a 48-cell ring.
///
/// Each side has four planes. A six launches a plane from the hangar and
/// grants another roll. A plane must reach the finish exactly; landing on an
/// opponent on the track sends that opponent back to its hangar.
class FlyingChessGame extends TurnGame {
  static const int trackLength = 48;
  static const int finish = 52;
  static const int planesPerSide = 4;

  final List<int> planes = List<int>.filled(8, -1); // -1 hangar, 0..52
  final List<_FlyingSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int _dice = 0;
  bool _awaiting = false;
  int _moveCount = 0;
  final Random _random = Random();

  @override
  GameMeta get meta => GameCatalog.flyingChess;

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
  bool get llmSupported => false;

  @override
  String sideName(int side) => side == 0 ? '红方' : '蓝方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_awaiting) return '${sideName(_side)}选择飞机 · 点数 $_dice';
    return '${sideName(_side)}掷骰子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '四架飞机全部到达终点';
  }

  @override
  String scoreText(int side) {
    var finished = 0;
    var flying = 0;
    for (var i = 0; i < planesPerSide; i++) {
      final p = planes[side * planesPerSide + i];
      if (p == finish) {
        finished++;
      } else if (p >= 0) {
        flying++;
      }
    }
    return '$finished 到达 · $flying 飞行';
  }

  int startOffset(int side) => side == 0 ? 0 : trackLength ~/ 2;

  int trackIndex(int side, int progress) =>
      (startOffset(side) + progress) % trackLength;

  List<int> legalPlanesFor(int dice) {
    final result = <int>[];
    for (var i = 0; i < planesPerSide; i++) {
      final index = _side * planesPerSide + i;
      final p = planes[index];
      if (p == finish) continue;
      if (p < 0) {
        if (dice == 6) result.add(i);
      } else if (p + dice <= finish) {
        result.add(i);
      }
    }
    return result;
  }

  List<int> get selectablePlanes =>
      _awaiting ? legalPlanesFor(_dice) : const [];

  @override
  String? get primaryActionLabel => _awaiting ? null : '掷骰子';
  @override
  IconData get primaryActionIcon => Icons.casino_rounded;

  @override
  void primaryAction() {
    if (isOver || _awaiting) return;
    _history.add(_snapshot());
    _dice = _random.nextInt(6) + 1;
    if (legalPlanesFor(_dice).isEmpty) {
      _awaiting = false;
      _moveCount++;
      _switchSide();
    } else {
      _awaiting = true;
    }
  }

  @override
  bool isLegal(Object? move) {
    if (isOver) return false;
    if (move is FlyingTurn) {
      if (move.dice < 1 || move.dice > 6) return false;
      if (move.plane < 0) return legalPlanesFor(move.dice).isEmpty;
      return legalPlanesFor(move.dice).contains(move.plane);
    }
    if (move is int) {
      return _awaiting && selectablePlanes.contains(move);
    }
    return false;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    if (move is! FlyingTurn && !_awaiting) return;
    if (move is FlyingTurn) {
      _dice = move.dice;
    }
    final plane = move is FlyingTurn ? move.plane : move as int;
    if (_history.isEmpty || !_awaiting) {
      _history.add(_snapshot());
    }
    _awaiting = false;
    if (plane < 0) {
      _moveCount++;
      _switchSide();
      return;
    }
    final index = _side * planesPerSide + plane;
    final old = planes[index];
    if (old < 0) {
      planes[index] = 0;
    } else {
      planes[index] = old + _dice;
    }
    if (old >= 0 && planes[index] < finish) {
      final absolute = trackIndex(_side, planes[index]);
      for (var i = 0; i < planesPerSide; i++) {
        final oi = (1 - _side) * planesPerSide + i;
        final op = planes[oi];
        if (op >= 0 && op < trackLength && trackIndex(1 - _side, op) == absolute) {
          planes[oi] = -1;
        }
      }
    }
    _moveCount++;
    if (_allFinished(_side)) {
      _winner = _side;
      return;
    }
    if (_dice == 6) return;
    _switchSide();
  }

  bool _allFinished(int side) {
    for (var i = 0; i < planesPerSide; i++) {
      if (planes[side * planesPerSide + i] != finish) return false;
    }
    return true;
  }

  void _switchSide() {
    _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    for (var i = 0; i < planes.length; i++) {
      planes[i] = s.planes[i];
    }
    _side = s.side;
    _winner = s.winner;
    _dice = s.dice;
    _awaiting = s.awaiting;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver || _awaiting) return null;
    final dice = _random.nextInt(6) + 1;
    final legal = legalPlanesFor(dice);
    if (legal.isEmpty) return FlyingTurn(dice, -1);
    var best = legal.first;
    var bestScore = -1 << 30;
    for (final plane in legal) {
      final index = _side * planesPerSide + plane;
      final p = planes[index];
      var score = p < 0 ? 30 : p;
      if (p >= 0 && p + dice == finish) score += 500;
      if (p < 0 && dice == 6) score += 60;
      if (p >= 0 && p + dice < trackLength) {
        final absolute = trackIndex(_side, p + dice);
        for (var i = 0; i < planesPerSide; i++) {
          final op = planes[(1 - _side) * planesPerSide + i];
          if (op >= 0 && op < trackLength && trackIndex(1 - _side, op) == absolute) {
            score += 300;
          }
        }
      }
      score += _random.nextInt(level <= 0 ? 30 : 3);
      if (score > bestScore) {
        bestScore = score;
        best = plane;
      }
    }
    return FlyingTurn(dice, best);
  }

  _FlyingSnapshot _snapshot() => _FlyingSnapshot(
        List<int>.of(planes),
        _side,
        _winner,
        _dice,
        _awaiting,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'planes': List<int>.of(planes),
        'side': _side,
        'winner': _winner,
        'dice': _dice,
        'awaiting': _awaiting,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['planes'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < planes.length; i++) {
      planes[i] = i < raw.length ? raw[i].toInt() : -1;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _dice = (json['dice'] as num?)?.toInt() ?? 0;
    _awaiting = json['awaiting'] == true;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => const [];

  @override
  String get llmState =>
      '飞行棋（掷骰子游戏），红蓝各四架飞机；当前${sideName(_side)}，'
      '点数 $_dice。';

  @override
  String describeMove(Object? move) {
    if (move is FlyingTurn) return '掷 $_dice 点，飞机 ${move.plane + 1}';
    if (move is int) return '飞机 ${move + 1}';
    return '$move';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '红' : '蓝',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
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
    return FlyingChessBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _FlyingSnapshot {
  final List<int> planes;
  final int side;
  final int? winner;
  final int dice;
  final bool awaiting;
  final int moveCount;

  _FlyingSnapshot(this.planes, this.side, this.winner, this.dice, this.awaiting,
      this.moveCount);
}

class FlyingChessBoard extends StatelessWidget {
  final FlyingChessGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const FlyingChessBoard({
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
        final cell = size / 13;
        final center = Offset(size / 2, size / 2);
        final radius = size * 0.36;
        Offset track(int i) {
          final idx = flipped ? (i + 24) % 48 : i;
          final angle = -pi / 2 + idx * 2 * pi / 48;
          return center + Offset(cos(angle), sin(angle)) * radius;
        }

        Offset planePosition(int side, int plane, int progress) {
          if (progress < 0) {
            final base = side == 0 ? const Offset(0.13, 0.82) : const Offset(0.87, 0.18);
            final p = flipped ? Offset(1 - base.dx, 1 - base.dy) : base;
            final col = plane % 2;
            final row = plane ~/ 2;
            return Offset(
              p.dx * size + (col - 0.5) * cell * 0.9,
              p.dy * size + (row - 0.5) * cell * 0.9,
            );
          }
          if (progress >= 48) {
            final p = progress - 48;
            final base = side == 0 ? const Offset(0.50, 0.70) : const Offset(0.50, 0.30);
            final b = flipped ? Offset(base.dx, 1 - base.dy) : base;
            return Offset(b.dx * size + (p - 1.5) * cell * 0.55, b.dy * size);
          }
          return track(game.trackIndex(side, progress));
        }

        final widgets = <Widget>[];
        for (var side = 0; side < 2; side++) {
          for (var i = 0; i < 4; i++) {
            final progress = game.planes[side * 4 + i];
            final pos = planePosition(side, i, progress);
            final canSelect = interactive &&
                game._awaiting &&
                side == game.side &&
                game.selectablePlanes.contains(i);
            final disc = cell * 0.62;
            widgets.add(Positioned(
              left: pos.dx - disc / 2,
              top: pos.dy - disc / 2,
              width: disc,
              height: disc,
              child: IgnorePointer(
                child: GameDisc(
                  label: '${i + 1}',
                  color: side == 0
                      ? const Color(0xFFD95B4E)
                      : const Color(0xFF6C9BD8),
                  background: side == 0
                      ? const Color(0xFFD95B4E)
                      : const Color(0xFF6C9BD8),
                  filled: true,
                  size: disc,
                  selected: canSelect,
                  dimmed: progress == -1,
                  fontSize: disc * 0.42,
                ),
              ),
            ));
          }
        }

        return SizedBox.square(
          dimension: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: interactive
                ? (details) {
                    var best = -1;
                    var bestDist = double.infinity;
                    for (final plane in game.selectablePlanes) {
                      final pos = planePosition(game.side, plane,
                          game.planes[game.side * 4 + plane]);
                      final d = (pos - details.localPosition).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        best = plane;
                      }
                    }
                    if (best >= 0 && bestDist < cell * 0.9) onMove(best);
                  }
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FlyingPainter(
                      game: game,
                      cell: cell,
                      center: center,
                      radius: radius,
                      flipped: flipped,
                      track: track,
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
}

class _FlyingPainter extends CustomPainter {
  final FlyingChessGame game;
  final double cell;
  final Offset center;
  final double radius;
  final bool flipped;
  final Offset Function(int) track;

  _FlyingPainter({
    required this.game,
    required this.cell,
    required this.center,
    required this.radius,
    required this.flipped,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1A3C35), Color(0xFF0A1714)],
        ).createShader(rect),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 1.25
      ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.22);
    canvas.drawCircle(center, radius, ring);

    for (var i = 0; i < 48; i++) {
      final p = track(i);
      final isStart = i == 0 || i == 24;
      canvas.drawCircle(
        p,
        cell * 0.38,
        Paint()
          ..color = i == 0
              ? const Color(0xFFD95B4E).withValues(alpha: 0.35)
              : i == 24
                  ? const Color(0xFF6C9BD8).withValues(alpha: 0.35)
                  : const Color(0xFF24443C),
      );
      canvas.drawCircle(
        p,
        cell * 0.38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isStart ? 1.8 : 0.7
          ..color = isStart
              ? const Color(0xFFE7BC6C)
              : const Color(0xFF7FA998).withValues(alpha: 0.35),
      );
    }

    for (var side = 0; side < 2; side++) {
      final base = side == 0 ? const Offset(0.13, 0.82) : const Offset(0.87, 0.18);
      final p = flipped ? Offset(1 - base.dx, 1 - base.dy) : base;
      final color = side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8);
      final box = Rect.fromCenter(
        center: Offset(p.dx * size.width, p.dy * size.height),
        width: cell * 2.2,
        height: cell * 2.2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(cell * 0.4)),
        Paint()..color = color.withValues(alpha: 0.15),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(cell * 0.4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.55),
      );
    }

    final home = Rect.fromCenter(
      center: center,
      width: cell * 3.2,
      height: cell * 3.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(home, Radius.circular(cell * 0.5)),
      Paint()..color = const Color(0xFFE7BC6C).withValues(alpha: 0.10),
    );
    final text = TextPainter(
      text: TextSpan(
        text: '终点',
        style: TextStyle(
          color: const Color(0xFFE7BC6C).withValues(alpha: 0.72),
          fontSize: cell * 0.7,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    if (game._dice > 0) {
      final dice = TextPainter(
        text: TextSpan(
          text: '🎲 ${game._dice}',
          style: TextStyle(
            color: const Color(0xFFE7BC6C),
            fontSize: cell * 0.85,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dice.paint(
        canvas,
        center + Offset(-dice.width / 2, cell * 0.95),
      );
      final hint = TextPainter(
        text: TextSpan(
          text: game._awaiting ? '选择飞机' : '继续掷骰',
          style: TextStyle(
            color: const Color(0xFFB9A58A),
            fontSize: cell * 0.32,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hint.paint(
        canvas,
        center + Offset(-hint.width / 2, cell * 1.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingPainter oldDelegate) => true;
}
