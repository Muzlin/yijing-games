import 'package:flutter/material.dart';

import '../../ui/theme.dart';

enum GameKind { chess, xiangqi, junqi, jungle, draughts, snakes, go, gomoku }

enum PlayMode { ai, local, aiVsAi, online }

class GameMeta {
  final GameKind kind;
  final String title;
  final String subtitle;
  final String en;
  final Color accent;
  final List<String> sideLabels;
  final double aspectRatio;
  final bool supportsBoardSize;
  final List<int> boardSizes;
  final int defaultBoardSize;

  const GameMeta({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.en,
    required this.accent,
    required this.sideLabels,
    this.aspectRatio = 1,
    this.supportsBoardSize = false,
    this.boardSizes = const [],
    this.defaultBoardSize = 0,
  });
}

class GameMatchConfig {
  final GameMeta meta;
  final PlayMode mode;
  final int level;
  final int humanSide;
  final int boardSize;
  final String? opponentName;

  const GameMatchConfig({
    required this.meta,
    required this.mode,
    this.level = 1,
    this.humanSide = 0,
    this.boardSize = 0,
    this.opponentName,
  });

  bool get isOnline => mode == PlayMode.online;
  bool get isBotMatch => opponentName != null && mode == PlayMode.ai;
  bool get isOnlineLike => isOnline || isBotMatch;
}

abstract class TurnGame {
  GameMeta get meta;
  int get side;
  bool get isOver;
  int? get winner;
  String get resultTitle;
  String get resultSubtitle;
  String get statusText;
  int get moveCount;
  bool get canUndo;

  /// Applies one complete move (including multi-step moves).
  void apply(Object? move);
  void undo();
  bool isLegal(Object? move);
  Object? aiMove(int level);

  Map<String, Object?> toJson();
  void loadJson(Map<String, Object?> json);

  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  });

  Widget sideBadge(int side, double size);
  String sideName(int side);
  String scoreText(int side);

  /// A primary human action that is not a board tap (Go pass, Snakes dice).
  String? get primaryActionLabel => null;
  IconData get primaryActionIcon => Icons.touch_app_rounded;
  void primaryAction() {}

  /// Extra game-specific controls.
  List<TurnGameAction> get actions => const [];
}

class TurnGameAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const TurnGameAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
}

class GameCatalog {
  static const chess = GameMeta(
    kind: GameKind.chess,
    title: '国际象棋',
    subtitle: '经典 · 64 格',
    en: 'CHESS',
    accent: AppColors.gold,
    sideLabels: ['白方', '黑方'],
  );

  static const xiangqi = GameMeta(
    kind: GameKind.xiangqi,
    title: '中国象棋',
    subtitle: '将帅对垒 · 楚河汉界',
    en: 'XIANGQI',
    accent: Color(0xFFD96B5B),
    sideLabels: ['红方', '黑方'],
    aspectRatio: 9 / 10,
  );

  static const junqi = GameMeta(
    kind: GameKind.junqi,
    title: '军棋',
    subtitle: '明棋 · 司令与军旗',
    en: 'JUNQI',
    accent: Color(0xFFC9A26B),
    sideLabels: ['红方', '蓝方'],
    aspectRatio: 5 / 10,
  );

  static const jungle = GameMeta(
    kind: GameKind.jungle,
    title: '斗兽棋',
    subtitle: '象狮虎豹 · 鼠克象',
    en: 'JUNGLE',
    accent: Color(0xFF79B36B),
    sideLabels: ['红方', '蓝方'],
    aspectRatio: 7 / 9,
  );

  static const draughts = GameMeta(
    kind: GameKind.draughts,
    title: '国际跳棋',
    subtitle: '连吃 · 升王',
    en: 'CHECKERS',
    accent: Color(0xFFD89A5C),
    sideLabels: ['白方', '黑方'],
  );

  static const snakes = GameMeta(
    kind: GameKind.snakes,
    title: '蛇棋',
    subtitle: '掷骰子 · 爬梯滑蛇',
    en: 'SNAKES',
    accent: Color(0xFFA98BD8),
    sideLabels: ['红方', '蓝方'],
  );

  static const go = GameMeta(
    kind: GameKind.go,
    title: '围棋',
    subtitle: '围地 · 打劫 · 数子',
    en: 'GO',
    accent: Color(0xFF6FB7B1),
    sideLabels: ['黑方', '白方'],
    supportsBoardSize: true,
    boardSizes: [9, 13],
    defaultBoardSize: 9,
  );

  static const gomoku = GameMeta(
    kind: GameKind.gomoku,
    title: '五子棋',
    subtitle: '五子连珠 · 先手必胜?',
    en: 'GOMOKU',
    accent: Color(0xFF6C9BD8),
    sideLabels: ['黑方', '白方'],
  );

  static const all = [
    chess,
    xiangqi,
    junqi,
    jungle,
    draughts,
    snakes,
    go,
    gomoku,
  ];

  static GameMeta of(GameKind kind) =>
      all.firstWhere((meta) => meta.kind == kind);
}
