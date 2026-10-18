import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

/// A compact two-player mahjong variant using 108 tiles (three suits, no
/// honours) and a draw-and-discard turn. There are no calls (chi/pong/kong);
/// a player wins by completing four melds and a pair, or seven pairs.
class MahjongGame extends TurnGame {
  static const int tileTypes = 27;
  static const int copies = 4;
  static const int deckSize = tileTypes * copies;

  final List<List<int>> hands = [[], []];
  final List<_MahjongSnapshot> _history = [];
  final Random _random = Random();
  List<int> _wall = [];
  int _side = 0;
  int? _winner;
  int? _lastDiscard;
  int _moveCount = 0;
  int _viewerSide = 0;

  MahjongGame() {
    _deal();
  }

  void _deal() {
    final deck = <int>[];
    for (var t = 0; t < tileTypes; t++) {
      for (var i = 0; i < copies; i++) {
        deck.add(t);
      }
    }
    deck.shuffle(_random);
    hands[0] = deck.sublist(0, 13)..sort();
    hands[1] = deck.sublist(13, 26)..sort();
    _wall = deck.sublist(26);
    _side = 0;
    _winner = null;
    _lastDiscard = null;
    _moveCount = 0;
    _history.clear();
    _drawFor(0);
  }

  @override
  GameMeta get meta => GameCatalog.mahjong;

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
  void setViewerSide(int side) => _viewerSide = side;

  @override
  String sideName(int side) => side == 0 ? '红方' : '蓝方';

  static const List<String> _numbers = [
    '一', '二', '三', '四', '五', '六', '七', '八', '九',
  ];
  static const List<String> _suits = ['万', '条', '筒'];

  static String labelOf(int tile) {
    final suit = tile ~/ 9;
    final number = tile % 9;
    return '${_numbers[number]}${_suits[suit]}';
  }

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}出牌 · 牌墙 ${_wall.length}';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    if (_winner == 2) return '流局';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return _winner == 2 ? '牌墙已摸完' : '四组面子 + 一对将';
  }

  @override
  String scoreText(int side) => '${hands[side].length} 张 · 牌墙 ${_wall.length}';

  void _drawFor(int side) {
    if (_wall.isEmpty) {
      _winner = 2;
      return;
    }
    final tile = _wall.removeLast();
    hands[side].add(tile);
    hands[side].sort();
    if (_canWin(hands[side])) {
      _winner = side;
    }
  }

  bool _canWin(List<int> tiles) {
    if (tiles.length != 14) return false;
    final counts = List<int>.filled(tileTypes, 0);
    for (final t in tiles) {
      counts[t]++;
    }
    // Seven pairs.
    if (counts.every((c) => c == 0 || c == 2) &&
        counts.where((c) => c == 2).length == 7) {
      return true;
    }
    for (var i = 0; i < tileTypes; i++) {
      if (counts[i] < 2) continue;
      counts[i] -= 2;
      final ok = _canFormMelds(counts);
      counts[i] += 2;
      if (ok) return true;
    }
    return false;
  }

  bool _canFormMelds(List<int> counts) {
    var first = -1;
    for (var i = 0; i < tileTypes; i++) {
      if (counts[i] > 0) {
        first = i;
        break;
      }
    }
    if (first < 0) return true;
    if (counts[first] >= 3) {
      counts[first] -= 3;
      final ok = _canFormMelds(counts);
      counts[first] += 3;
      if (ok) return true;
    }
    final rank = first % 9;
    final suit = first ~/ 9;
    if (rank <= 6 &&
        counts[first + 1] > 0 &&
        counts[first + 2] > 0 &&
        (first + 2) ~/ 9 == suit) {
      counts[first]--;
      counts[first + 1]--;
      counts[first + 2]--;
      final ok = _canFormMelds(counts);
      counts[first]++;
      counts[first + 1]++;
      counts[first + 2]++;
      if (ok) return true;
    }
    return false;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! int) return false;
    if (!hands[_side].contains(move)) return false;
    return true;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    _history.add(_snapshot());
    final tile = move as int;
    hands[_side].remove(tile);
    _lastDiscard = tile;
    _moveCount++;
    _side = 1 - _side;
    _drawFor(_side);
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    hands[0] = List<int>.of(s.hand0);
    hands[1] = List<int>.of(s.hand1);
    _wall = List<int>.of(s.wall);
    _side = s.side;
    _winner = s.winner;
    _lastDiscard = s.lastDiscard;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final hand = hands[_side];
    if (hand.isEmpty) return null;
    final counts = <int, int>{};
    for (final tile in hand) {
      counts[tile] = (counts[tile] ?? 0) + 1;
    }
    final scored = <(int, int)>[];
    for (final tile in hand) {
      final rank = tile % 9;
      var score = 0;
      final suit = tile ~/ 9;
      if (rank > 0 && counts.containsKey(tile - 1)) score += 3;
      if (rank < 8 && counts.containsKey(tile + 1)) score += 3;
      if (counts[tile]! >= 2) score += 4;
      if (counts[tile]! >= 3) score += 5;
      // Prefer discarding an isolated tile; avoid breaking sequences.
      score -= 10;
      if (rank > 1 &&
          suit == (tile - 2) ~/ 9 &&
          counts.containsKey(tile - 2)) {
        score -= 5;
      }
      if (rank < 7 &&
          suit == (tile + 2) ~/ 9 &&
          counts.containsKey(tile + 2)) {
        score -= 5;
      }
      if (level <= 0) score += _random.nextInt(10);
      scored.add((tile, score));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.first.$1;
  }

  _MahjongSnapshot _snapshot() => _MahjongSnapshot(
        List<int>.of(hands[0]),
        List<int>.of(hands[1]),
        List<int>.of(_wall),
        _side,
        _winner,
        _lastDiscard,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'hands': [List<int>.of(hands[0]), List<int>.of(hands[1])],
        'wall': List<int>.of(_wall),
        'side': _side,
        'winner': _winner,
        'lastDiscard': _lastDiscard,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['hands'] as List?) ?? const [];
    for (var side = 0; side < 2; side++) {
      final list = side < raw.length ? (raw[side] as List?)?.cast<num>() ?? const [] : const <num>[];
      hands[side] = list.map((e) => e.toInt()).toList()..sort();
    }
    final w = (json['wall'] as List?)?.cast<num>() ?? const [];
    _wall = w.map((e) => e.toInt()).toList();
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _lastDiscard = (json['lastDiscard'] as num?)?.toInt();
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => const [];

  @override
  String get llmState {
    final sb = StringBuffer(
      '麻将（二人简化版）：108 张牌，万/条/筒各 1-9，每种 4 张。'
      '每人 13 张，轮流摸一张、打一张；没有吃碰杠。四组顺子/刻子加一对将，或七对，即胡牌。\n',
    );
    sb.write('红方：${hands[0].map(labelOf).join(' ')}\n');
    sb.write('蓝方：${hands[1].map(labelOf).join(' ')}\n');
    sb.write('轮到${sideName(_side)}；牌墙 ${_wall.length} 张。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! int) return '$move';
    return labelOf(move);
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
    return MahjongBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      viewerSide: _viewerSide,
    );
  }
}

class _MahjongSnapshot {
  final List<int> hand0;
  final List<int> hand1;
  final List<int> wall;
  final int side;
  final int? winner;
  final int? lastDiscard;
  final int moveCount;

  _MahjongSnapshot(this.hand0, this.hand1, this.wall, this.side, this.winner,
      this.lastDiscard, this.moveCount);
}

class MahjongBoard extends StatelessWidget {
  final MahjongGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final int viewerSide;

  const MahjongBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    required this.viewerSide,
  });

  @override
  Widget build(BuildContext context) {
    final hand = game.hands[viewerSide];
    final canAct = interactive && game.side == viewerSide && !game.isOver;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF183B32), Color(0xFF081713)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${game.sideName(1 - viewerSide)} · ${game.hands[1 - viewerSide].length} 张',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFB9A58A)),
                  ),
                  const Spacer(),
                  Text(
                    '牌墙 ${game._wall.length}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF7F968B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: game._lastDiscard == null
                      ? const Text('等待出牌',
                          style: TextStyle(fontSize: 11, color: Color(0xFF7F968B)))
                      : _MahjongTile(
                          tile: game._lastDiscard!,
                          size: 48,
                          highlighted: true,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '你的手牌 · ${hand.length} 张 · 点击一张打出',
                style: const TextStyle(fontSize: 9, color: Color(0xFF7F968B)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 70,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final tile in hand)
                        GestureDetector(
                          onTap: canAct ? () => onMove(tile) : null,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: _MahjongTile(
                              tile: tile,
                              size: 56,
                              highlighted: game._lastDiscard == tile,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MahjongTile extends StatelessWidget {
  final int tile;
  final double size;
  final bool highlighted;

  const _MahjongTile({
    required this.tile,
    required this.size,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final suit = tile ~/ 9;
    return Container(
      width: size * 0.76,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF0C8) : const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(size * 0.08),
        border: Border.all(
          color: highlighted ? const Color(0xFFE7BC6C) : const Color(0xFFC9BFAE),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            MahjongGame._numbers[tile % 9],
            style: TextStyle(
              fontSize: size * 0.24,
              height: 1,
              fontWeight: FontWeight.w800,
              color: suit == 0
                  ? const Color(0xFFB53D32)
                  : suit == 1
                      ? const Color(0xFF3D6B54)
                      : const Color(0xFF315B8A),
            ),
          ),
          Text(
            MahjongGame._suits[suit],
            style: TextStyle(
              fontSize: size * 0.18,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: suit == 0
                  ? const Color(0xFFB53D32)
                  : suit == 1
                      ? const Color(0xFF3D6B54)
                      : const Color(0xFF315B8A),
            ),
          ),
        ],
      ),
    );
  }
}
