import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class TycoonTurn {
  const TycoonTurn();
}

class TycoonSpace {
  final String name;
  final int type; // 0 go, 1 property, 2 chance, 3 jail, 4 free, 5 tax, 6 go-to-jail
  final int price;
  final int rent;
  const TycoonSpace(this.name, this.type, {this.price = 0, this.rent = 0});
}

/// A compact two-player property-trading board game inspired by classic
/// roll-and-move games, using original names and artwork.
class TycoonGame extends TurnGame {
  static const int boardSpaces = 24;
  static const List<TycoonSpace> spaces = [
    TycoonSpace('起点', 0),
    TycoonSpace('松林街', 1, price: 60, rent: 10),
    TycoonSpace('河畔巷', 1, price: 80, rent: 14),
    TycoonSpace('机会', 2),
    TycoonSpace('老车站', 1, price: 140, rent: 20),
    TycoonSpace('旧城墙', 1, price: 100, rent: 16),
    TycoonSpace('监狱', 3),
    TycoonSpace('银杏路', 1, price: 120, rent: 18),
    TycoonSpace('电力站', 1, price: 150, rent: 24),
    TycoonSpace('桂花坊', 1, price: 140, rent: 20),
    TycoonSpace('湖畔街', 1, price: 180, rent: 26),
    TycoonSpace('机会', 2),
    TycoonSpace('免费停车', 4),
    TycoonSpace('钟楼', 1, price: 200, rent: 30),
    TycoonSpace('山前街', 1, price: 220, rent: 34),
    TycoonSpace('港口', 1, price: 240, rent: 38),
    TycoonSpace('税务局', 5, price: 100),
    TycoonSpace('云顶大道', 1, price: 260, rent: 42),
    TycoonSpace('入狱', 6),
    TycoonSpace('金融街', 1, price: 300, rent: 50),
    TycoonSpace('皇宫', 1, price: 350, rent: 60),
    TycoonSpace('机会', 2),
    TycoonSpace('花园', 1, price: 280, rent: 45),
    TycoonSpace('老街', 1, price: 160, rent: 22),
  ];

  final List<int> positions = [0, 0];
  final List<int> cash = [1500, 1500];
  final List<int> owners = List<int>.filled(boardSpaces, -1);
  final List<int> jail = [0, 0];
  final List<_TycoonSnapshot> _history = [];
  final Random _random = Random();
  int _side = 0;
  int? _winner;
  int _lastDice = 0;
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.tycoon;

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
    if (jail[_side] > 0) return '${sideName(_side)}监禁中 · 暂停一回合';
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
    return '对手资金耗尽';
  }

  @override
  String scoreText(int side) {
    var owned = 0;
    for (final owner in owners) {
      if (owner == side) owned++;
    }
    return '¥${cash[side]} · $owned 处';
  }

  @override
  String? get primaryActionLabel => '掷骰子';
  @override
  IconData get primaryActionIcon => Icons.casino_rounded;

  @override
  void primaryAction() {
    if (isOver) return;
    _takeTurn();
  }

  void _takeTurn() {
    _history.add(_snapshot());
    if (jail[_side] > 0) {
      jail[_side]--;
      _moveCount++;
      _side = 1 - _side;
      return;
    }
    final d1 = _random.nextInt(6) + 1;
    final d2 = _random.nextInt(6) + 1;
    _lastDice = d1 + d2;
    final old = positions[_side];
    var next = old + d1 + d2;
    if (next >= boardSpaces) {
      next %= boardSpaces;
      cash[_side] += 200;
    }
    positions[_side] = next;
    final space = spaces[next];
    switch (space.type) {
      case 1:
        final owner = owners[next];
        if (owner < 0) {
          if (cash[_side] >= space.price) {
            cash[_side] -= space.price;
            owners[next] = _side;
          }
        } else if (owner != _side) {
          cash[_side] -= space.rent;
          if (cash[_side] < 0) {
            _winner = 1 - _side;
          }
        }
        break;
      case 2:
        _chance();
        break;
      case 5:
        cash[_side] -= space.price;
        if (cash[_side] < 0) _winner = 1 - _side;
        break;
      case 6:
        positions[_side] = 6;
        jail[_side] = 1;
        break;
    }
    _moveCount++;
    if (_winner != null) return;
    if (d1 != d2) _side = 1 - _side;
  }

  void _chance() {
    final card = _random.nextInt(4);
    switch (card) {
      case 0:
        cash[_side] += 100;
        break;
      case 1:
        cash[_side] -= 50;
        break;
      case 2:
        positions[_side] = 0;
        cash[_side] += 200;
        break;
      case 3:
        positions[_side] = 6;
        jail[_side] = 1;
        break;
    }
    if (cash[_side] < 0) _winner = 1 - _side;
  }

  @override
  bool isLegal(Object? move) => move is TycoonTurn && !isOver;

  @override
  void apply(Object? move) {
    // The whole turn (roll, move, resolve) is performed by primaryAction or
    // aiMove; this keeps the generic screen's action model simple.
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    _takeTurn();
    return const TycoonTurn();
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    positions[0] = s.positions[0];
    positions[1] = s.positions[1];
    cash[0] = s.cash[0];
    cash[1] = s.cash[1];
    owners.setAll(0, s.owners);
    jail[0] = s.jail[0];
    jail[1] = s.jail[1];
    _side = s.side;
    _winner = s.winner;
    _lastDice = s.lastDice;
    _moveCount = s.moveCount;
  }

  _TycoonSnapshot _snapshot() => _TycoonSnapshot(
        List<int>.of(positions),
        List<int>.of(cash),
        List<int>.of(owners),
        List<int>.of(jail),
        _side,
        _winner,
        _lastDice,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'positions': List<int>.of(positions),
        'cash': List<int>.of(cash),
        'owners': List<int>.of(owners),
        'jail': List<int>.of(jail),
        'side': _side,
        'winner': _winner,
        'lastDice': _lastDice,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final p = (json['positions'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 2; i++) {
      positions[i] = i < p.length ? p[i].toInt() : 0;
    }
    final c = (json['cash'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 2; i++) {
      cash[i] = i < c.length ? c[i].toInt() : 1500;
    }
    final o = (json['owners'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < boardSpaces; i++) {
      owners[i] = i < o.length ? o[i].toInt() : -1;
    }
    final j = (json['jail'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 2; i++) {
      jail[i] = i < j.length ? j[i].toInt() : 0;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastDice = (json['lastDice'] as num?)?.toInt() ?? 0;
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => const [];

  @override
  String get llmState {
    final sb = StringBuffer(
      '地产大亨（2 人掷骰子棋盘游戏）：红蓝双方初始 1500 元，绕 24 格棋盘行进。'
      '经过起点得 200 元；空地可购买；停在对手地产付租；机会卡、税务局、入狱。'
      '资金耗尽者负。\n',
    );
    for (var i = 0; i < boardSpaces; i++) {
      final owner = owners[i] < 0 ? '空' : '${owners[i] == 0 ? '红' : '蓝'}有';
      sb.write('$i ${spaces[i].name}：$owner\n');
    }
    sb.write('红 ¥${cash[0]} 位置 ${positions[0]}；蓝 ¥${cash[1]} 位置 ${positions[1]}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) => '掷骰子';

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
    return TycoonBoard(game: this);
  }
}

class _TycoonSnapshot {
  final List<int> positions;
  final List<int> cash;
  final List<int> owners;
  final List<int> jail;
  final int side;
  final int? winner;
  final int lastDice;
  final int moveCount;

  _TycoonSnapshot(this.positions, this.cash, this.owners, this.jail, this.side,
      this.winner, this.lastDice, this.moveCount);
}

class TycoonBoard extends StatelessWidget {
  final TycoonGame game;

  const TycoonBoard({super.key, required this.game});

  static const List<Offset> cells = [
    Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0), Offset(4, 0),
    Offset(5, 0), Offset(6, 0), Offset(6, 1), Offset(6, 2), Offset(6, 3),
    Offset(6, 4), Offset(6, 5), Offset(6, 6), Offset(5, 6), Offset(4, 6),
    Offset(3, 6), Offset(2, 6), Offset(1, 6), Offset(0, 6), Offset(0, 5),
    Offset(0, 4), Offset(0, 3), Offset(0, 2), Offset(0, 1),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 7;
        final tokens = <Widget>[];
        for (var side = 0; side < 2; side++) {
          final p = cells[game.positions[side]];
          final token = cell * 0.26;
          tokens.add(Positioned(
            left: p.dx * cell + cell * 0.20 + side * cell * 0.24,
            top: p.dy * cell + cell * 0.62,
            width: token,
            height: token,
            child: IgnorePointer(
              child: GameDisc(
                label: side == 0 ? '红' : '蓝',
                color: side == 0
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFF6C9BD8),
                background: side == 0
                    ? const Color(0xFFD95B4E)
                    : const Color(0xFF6C9BD8),
                filled: true,
                size: token,
                fontSize: token * 0.45,
              ),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TycoonPainter(game: game, cell: cell),
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

class _TycoonPainter extends CustomPainter {
  final TycoonGame game;
  final double cell;

  _TycoonPainter({required this.game, required this.cell});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C3D35), Color(0xFF0B1C18)],
        ).createShader(rect),
    );
    final board = Paint()..color = const Color(0xFFE8D3A9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), board);
    for (var i = 0; i < 24; i++) {
      final p = TycoonBoard.cells[i];
      final r = Rect.fromLTWH(p.dx * cell, p.dy * cell, cell, cell);
      final space = TycoonGame.spaces[i];
      final owner = game.owners[i];
      final color = owner == 0
          ? const Color(0xFFD95B4E)
          : owner == 1
              ? const Color(0xFF6C9BD8)
              : const Color(0xFFCDBB98);
      canvas.drawRect(
        r.deflate(1),
        Paint()..color = color.withValues(alpha: owner < 0 ? 0.45 : 0.26),
      );
      canvas.drawRect(
        r.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF5B3D22).withValues(alpha: 0.55),
      );
      final label = TextPainter(
        text: TextSpan(
          text: space.name,
          style: TextStyle(
            color: const Color(0xFF3A2416),
            fontSize: cell * 0.145,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cell * 0.9);
      label.paint(
        canvas,
        Offset(r.center.dx - label.width / 2, r.top + cell * 0.08),
      );
      if (owner >= 0) {
        final mark = TextPainter(
          text: TextSpan(
            text: owner == 0 ? '红' : '蓝',
            style: TextStyle(
              color: owner == 0
                  ? const Color(0xFFB53D32)
                  : const Color(0xFF315B8A),
              fontSize: cell * 0.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        mark.paint(canvas, Offset(r.right - mark.width - 3, r.top + 2));
      }
      if (space.type == 1) {
        final price = TextPainter(
          text: TextSpan(
            text: '¥${space.price}',
            style: TextStyle(
              color: const Color(0xFF6A4A2B),
              fontSize: cell * 0.12,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        price.paint(
          canvas,
          Offset(r.center.dx - price.width / 2, r.bottom - cell * 0.23),
        );
      }
    }
    final inner = Rect.fromLTWH(cell * 1.15, cell * 1.15, cell * 4.7, cell * 4.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.3)),
      Paint()..color = const Color(0xFF162A25),
    );
    final title = TextPainter(
      text: const TextSpan(
        text: '地产大亨',
        style: TextStyle(
          color: Color(0xFFE7BC6C),
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(
      canvas,
      Offset(inner.center.dx - title.width / 2, inner.top + cell * 0.55),
    );
    final info = TextPainter(
      text: TextSpan(
        text: '红 ¥${game.cash[0]}\n蓝 ¥${game.cash[1]}\n\n${game.sideName(game.side)}回合 · 骰子 ${game._lastDice == 0 ? '—' : game._lastDice}',
        style: TextStyle(
          color: const Color(0xFFE8D3A9),
          fontSize: cell * 0.19,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    info.paint(
      canvas,
      Offset(inner.center.dx - info.width / 2, inner.top + cell * 1.45),
    );
  }

  @override
  bool shouldRepaint(covariant _TycoonPainter oldDelegate) => true;
}
