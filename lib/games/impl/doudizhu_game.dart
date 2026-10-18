import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class DoudizhuPlay {
  final List<int> cards;
  DoudizhuPlay(List<int> cards) : cards = List<int>.of(cards)..sort();
}

class DoudizhuPass {
  const DoudizhuPass();
}

class _Combo {
  final int type;
  final int rank;
  final int length;
  const _Combo(this.type, this.rank, this.length);

  static const int single = 1;
  static const int pair = 2;
  static const int triple = 3;
  static const int tripleSingle = 4;
  static const int triplePair = 5;
  static const int straight = 6;
  static const int doubleStraight = 7;
  static const int bomb = 8;
  static const int rocket = 9;

  bool beats(_Combo? other) {
    if (other == null) return true;
    if (type == rocket) return other.type != rocket;
    if (other.type == rocket) return false;
    if (type == bomb && other.type != bomb) return true;
    if (other.type == bomb && type != bomb) return false;
    if (type != other.type || length != other.length) return false;
    if (type == bomb) return rank > other.rank;
    return rank > other.rank;
  }
}

class DouDizhuGame extends TurnGame {
  static const int deckSize = 54;
  static const List<String> _rankLabels = [
    '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2',
  ];

  final List<List<int>> hands = [[], []];
  final List<_DouSnapshot> _history = [];
  final Random _random = Random();
  int _side = 0;
  int? _winner;
  List<int> _lastCards = const [];
  int? _lastSide;
  _Combo? _lastCombo;
  int _moveCount = 0;
  int _viewerSide = 0;

  DouDizhuGame() {
    _deal();
  }

  void _deal() {
    final deck = List<int>.generate(deckSize, (i) => i)..shuffle(_random);
    hands[0] = deck.sublist(0, 17)..sort();
    hands[1] = deck.sublist(17, 34)..sort();
    final bottom = deck.sublist(34, 37);
    hands[0].addAll(bottom);
    hands[0].sort();
    _side = 0; // landlord
    _winner = null;
    _lastCards = const [];
    _lastSide = null;
    _lastCombo = null;
    _moveCount = 0;
    _history.clear();
  }

  @override
  GameMeta get meta => GameCatalog.doudizhu;

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
  String sideName(int side) => side == 0 ? '地主' : '农民';

  static int rankOf(int card) {
    if (card >= 52) return card == 52 ? 16 : 17;
    return card % 13 + 3;
  }

  static String labelOf(int card) {
    if (card == 52) return '小王';
    if (card == 53) return '大王';
    return _rankLabels[rankOf(card) - 3];
  }

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    if (_lastCards.isEmpty) return '${sideName(_side)}出牌';
    return '${sideName(_side)}出牌 · 上家 ${_lastCards.length} 张';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    return _winner == 0 ? '地主胜' : '农民胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return '先出完手牌';
  }

  @override
  String scoreText(int side) => '${hands[side].length} 张';

  _Combo? _parse(List<int> cards) {
    if (cards.isEmpty) return null;
    final ranks = cards.map(rankOf).toList()..sort();
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    if (ranks.length == 2 && ranks[0] == 16 && ranks[1] == 17) {
      return const _Combo(_Combo.rocket, 17, 2);
    }
    if (ranks.length == 4 && counts.length == 1) {
      return _Combo(_Combo.bomb, ranks.first, 4);
    }
    if (ranks.length == 1) return _Combo(_Combo.single, ranks.first, 1);
    if (ranks.length == 2 && counts.length == 1) {
      return _Combo(_Combo.pair, ranks.first, 2);
    }
    if (ranks.length == 3 && counts.length == 1) {
      return _Combo(_Combo.triple, ranks.first, 3);
    }
    if (ranks.length == 4 && counts.length == 2 && counts.containsValue(3)) {
      final triple = counts.entries.firstWhere((e) => e.value == 3).key;
      return _Combo(_Combo.tripleSingle, triple, 4);
    }
    if (ranks.length == 5 &&
        counts.length == 2 &&
        counts.containsValue(3) &&
        counts.containsValue(2)) {
      final triple = counts.entries.firstWhere((e) => e.value == 3).key;
      return _Combo(_Combo.triplePair, triple, 5);
    }
    if (ranks.length >= 5 && counts.length == ranks.length) {
      if (ranks.last <= 14 && _consecutive(ranks)) {
        return _Combo(_Combo.straight, ranks.last, ranks.length);
      }
    }
    if (ranks.length >= 6 &&
        ranks.length.isEven &&
        counts.length == ranks.length ~/ 2 &&
        counts.values.every((v) => v == 2)) {
      final unique = counts.keys.toList()..sort();
      if (unique.last <= 14 && _consecutive(unique)) {
        return _Combo(_Combo.doubleStraight, unique.last, unique.length);
      }
    }
    return null;
  }

  bool _consecutive(List<int> values) {
    for (var i = 1; i < values.length; i++) {
      if (values[i] != values[i - 1] + 1) return false;
    }
    return true;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver) return false;
    if (move is DoudizhuPass) {
      return _lastCards.isNotEmpty && _lastSide != _side;
    }
    if (move is! DoudizhuPlay) return false;
    final cards = move.cards;
    if (cards.isEmpty || cards.toSet().length != cards.length) return false;
    for (final card in cards) {
      if (!hands[_side].contains(card)) return false;
    }
    final combo = _parse(cards);
    if (combo == null) return false;
    if (_lastCombo == null) return true;
    return combo.beats(_lastCombo);
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    _history.add(_snapshot());
    if (move is DoudizhuPass) {
      _lastCards = const [];
      _lastSide = null;
      _lastCombo = null;
      _moveCount++;
      _side = 1 - _side;
      return;
    }
    final play = move as DoudizhuPlay;
    for (final card in play.cards) {
      hands[_side].remove(card);
    }
    _lastCards = List<int>.of(play.cards);
    _lastSide = _side;
    _lastCombo = _parse(play.cards);
    _moveCount++;
    if (hands[_side].isEmpty) {
      _winner = _side;
      return;
    }
    _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    hands[0] = List<int>.of(s.hand0);
    hands[1] = List<int>.of(s.hand1);
    _side = s.side;
    _winner = s.winner;
    _lastCards = List<int>.of(s.lastCards);
    _lastSide = s.lastSide;
    _lastCombo = s.lastCombo;
    _moveCount = s.moveCount;
  }

  List<DoudizhuPlay> _candidates() {
    final hand = hands[_side];
    final counts = <int, List<int>>{};
    for (final card in hand) {
      counts.putIfAbsent(rankOf(card), () => []).add(card);
    }
    final result = <DoudizhuPlay>[];
    final seen = <String>{};
    void add(List<int> cards) {
      final key = (List<int>.of(cards)..sort()).join(',');
      if (seen.add(key)) result.add(DoudizhuPlay(cards));
    }

    for (final entry in counts.entries) {
      final list = entry.value;
      add([list.first]);
      if (list.length >= 2) add(list.take(2).toList());
      if (list.length >= 3) add(list.take(3).toList());
      if (list.length >= 4) add(list.take(4).toList());
    }
    if (counts.containsKey(16) && counts.containsKey(17)) {
      add([counts[16]!.first, counts[17]!.first]);
    }
    for (final entry in counts.entries) {
      if (entry.value.length < 3) continue;
      final triple = entry.value.take(3).toList();
      for (final other in counts.entries) {
        if (other.key == entry.key) continue;
        add([...triple, other.value.first]);
        if (other.value.length >= 2) {
          add([...triple, ...other.value.take(2)]);
        }
      }
    }
    // Straights.
    for (var start = 3; start <= 10; start++) {
      final cards = <int>[];
      var rank = start;
      while (rank <= 14 && counts.containsKey(rank)) {
        cards.add(counts[rank]!.first);
        if (cards.length >= 5) add(List<int>.of(cards));
        rank++;
      }
    }
    // Double straights.
    for (var start = 3; start <= 12; start++) {
      final cards = <int>[];
      var rank = start;
      while (rank <= 14 &&
          counts.containsKey(rank) &&
          counts[rank]!.length >= 2) {
        cards.addAll(counts[rank]!.take(2));
        if (cards.length >= 6 && cards.length.isEven) add(List<int>.of(cards));
        rank++;
      }
    }
    return result;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final all = _candidates();
    final legal = _lastCombo == null
        ? all
        : all.where((p) => (_parse(p.cards)?.beats(_lastCombo) ?? false)).toList();
    if (legal.isEmpty) return const DoudizhuPass();
    legal.sort((a, b) {
      final ca = _parse(a.cards)!;
      final cb = _parse(b.cards)!;
      if (ca.type != cb.type) return ca.type.compareTo(cb.type);
      return ca.rank.compareTo(cb.rank);
    });
    if (level <= 0) return legal[_random.nextInt(legal.length)];
    // Prefer a cheap response; when leading, shed a larger group first.
    if (_lastCombo == null) {
      legal.sort((a, b) => b.cards.length.compareTo(a.cards.length));
      return legal.first;
    }
    return legal.first;
  }

  _DouSnapshot _snapshot() => _DouSnapshot(
        List<int>.of(hands[0]),
        List<int>.of(hands[1]),
        _side,
        _winner,
        List<int>.of(_lastCards),
        _lastSide,
        _lastCombo,
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'hands': [List<int>.of(hands[0]), List<int>.of(hands[1])],
        'side': _side,
        'winner': _winner,
        'lastCards': List<int>.of(_lastCards),
        'lastSide': _lastSide,
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['hands'] as List?) ?? const [];
    for (var side = 0; side < 2; side++) {
      final list = side < raw.length ? (raw[side] as List?)?.cast<num>() ?? const [] : const <num>[];
      hands[side] = list.map((e) => e.toInt()).toList()..sort();
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    final lc = (json['lastCards'] as List?)?.cast<num>() ?? const [];
    _lastCards = lc.map((e) => e.toInt()).toList();
    _lastSide = (json['lastSide'] as num?)?.toInt();
    _lastCombo = _lastCards.isEmpty ? null : _parse(_lastCards);
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves => const [];

  @override
  String get llmState {
    final sb = StringBuffer(
      '斗地主（二人简化版）：54 张牌，地主 20 张、农民 17 张，地主先出。'
      '牌型：单张、对子、三张、三带一、三带二、顺子、连对、炸弹、王炸。'
      '出完手牌者胜。\n',
    );
    sb.write('地主手牌：${hands[0].map(labelOf).join(' ')}\n');
    sb.write('农民手牌：${hands[1].map(labelOf).join(' ')}\n');
    sb.write('轮到${sideName(_side)}。');
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is DoudizhuPass) return '不出';
    if (move is DoudizhuPlay) return move.cards.map(labelOf).join(' ');
    return '$move';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '地' : '农',
        color: side == 0 ? const Color(0xFFD7A74E) : const Color(0xFF79B36B),
        background:
            side == 0 ? const Color(0xFFD7A74E) : const Color(0xFF79B36B),
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
    return DouDizhuBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      viewerSide: _viewerSide,
    );
  }
}

class _DouSnapshot {
  final List<int> hand0;
  final List<int> hand1;
  final int side;
  final int? winner;
  final List<int> lastCards;
  final int? lastSide;
  final _Combo? lastCombo;
  final int moveCount;

  _DouSnapshot(this.hand0, this.hand1, this.side, this.winner, this.lastCards,
      this.lastSide, this.lastCombo, this.moveCount);
}

class DouDizhuBoard extends StatefulWidget {
  final DouDizhuGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final int viewerSide;

  const DouDizhuBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    required this.viewerSide,
  });

  @override
  State<DouDizhuBoard> createState() => _DouDizhuBoardState();
}

class _DouDizhuBoardState extends State<DouDizhuBoard> {
  final Set<int> selected = {};

  @override
  void didUpdateWidget(covariant DouDizhuBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.side != widget.game.side) selected.clear();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final viewer = widget.viewerSide;
    final canAct = widget.interactive && game.side == viewer;
    final hand = game.hands[viewer];
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
              colors: [Color(0xFF1B3B32), Color(0xFF0A1915)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${game.sideName(1 - viewer)} · ${game.hands[1 - viewer].length} 张',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFB9A58A)),
                  ),
                  const Spacer(),
                  Text(
                    game.isOver ? game.resultTitle : '${game.sideName(game.side)}回合',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE7BC6C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: game._lastCards.isEmpty
                      ? const Text('等待出牌',
                          style: TextStyle(fontSize: 11, color: Color(0xFF7F968B)))
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final card in game._lastCards)
                              _CardChip(card: card, size: 34),
                          ],
                        ),
                ),
              ),
              Text(
                '你的手牌 · ${hand.length} 张',
                style: const TextStyle(fontSize: 9, color: Color(0xFF7F968B)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 78,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final card in hand)
                        GestureDetector(
                          onTap: canAct
                              ? () {
                                  setState(() {
                                    if (!selected.add(card)) selected.remove(card);
                                  });
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Transform.translate(
                              offset: Offset(0, selected.contains(card) ? -8 : 0),
                              child: _CardChip(
                                card: card,
                                size: 48,
                                selected: selected.contains(card),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canAct
                          ? () {
                              widget.onMove(const DoudizhuPass());
                              setState(selected.clear);
                            }
                          : null,
                      child: const Text('不出'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: canAct &&
                              selected.isNotEmpty &&
                              game.isLegal(DoudizhuPlay(selected.toList()))
                          ? () {
                              widget.onMove(DoudizhuPlay(selected.toList()));
                              setState(selected.clear);
                            }
                          : null,
                      child: const Text('出牌'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardChip extends StatelessWidget {
  final int card;
  final double size;
  final bool selected;

  const _CardChip({
    required this.card,
    required this.size,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final rank = DouDizhuGame.rankOf(card);
    final red = card == 53 || (card < 52 && (card ~/ 13 == 1 || card ~/ 13 == 3));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size * 0.7,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF0C8) : const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(size * 0.09),
        border: Border.all(
          color: selected ? const Color(0xFFE7BC6C) : const Color(0xFFC9BFAE),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        DouDizhuGame.labelOf(card),
        style: TextStyle(
          fontSize: rank >= 16 ? size * 0.20 : size * 0.30,
          fontWeight: FontWeight.w800,
          color: red ? const Color(0xFFB53D32) : const Color(0xFF1B1F22),
        ),
      ),
    );
  }
}
