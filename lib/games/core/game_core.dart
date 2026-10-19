import 'package:flutter/material.dart';

import '../../ui/theme.dart';

enum GameKind {
  chess,
  xiangqi,
  junqi,
  jungle,
  draughts,
  snakes,
  go,
  gomoku,
  reversi,
  connect4,
  connect6,
  nineMensMorris,
  amazons,
  tiger,
  chineseCheckers,
  flyingChess,
  backgammon,
  shogi,
  tycoon,
  doudizhu,
  mahjong,
  ticTacToe,
  fiveFieldKono,
  hex,
  dotsBoxes,
  mancala,
  oware,
  hareHounds,
  foxGeese,
  quoridor,
  twelveMensMorris,
  sixMensMorris,
  threeMensMorris,
  quarto,
  yote,
  onitama,
}

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
  final bool useLlm;
  final bool systemMouse;

  const GameMatchConfig({
    required this.meta,
    required this.mode,
    this.level = 1,
    this.humanSide = 0,
    this.boardSize = 0,
    this.opponentName,
    this.useLlm = false,
    this.systemMouse = false,
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

  /// Whether the 32B local model can meaningfully choose a move (Snakes only
  /// rolls dice, so it is excluded).
  bool get llmSupported => true;

  /// All legal moves, used as candidates for the 32B model.
  List<Object?> get llmMoves => const [];

  /// A human-readable board state for the 32B prompt (rules are supplied by
  /// the bridge on the server).
  String get llmState => '';

  /// Human-readable move description used as the option label.
  String describeMove(Object? move) => '$move';

  /// Extra game-specific controls.
  List<TurnGameAction> get actions => const [];

  /// Some card games hide the opponent's hand. The generic screen sets this
  /// to the local viewer before building the board.
  void setViewerSide(int side) {}
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

  static const reversi = GameMeta(
    kind: GameKind.reversi,
    title: '黑白棋',
    subtitle: '翻转 · 奥赛罗',
    en: 'REVERSI',
    accent: Color(0xFF8FB36A),
    sideLabels: ['黑方', '白方'],
  );

  static const connect4 = GameMeta(
    kind: GameKind.connect4,
    title: '四子棋',
    subtitle: '重力落子 · 连四',
    en: 'CONNECT FOUR',
    accent: Color(0xFFD95B4E),
    sideLabels: ['红方', '黄方'],
    aspectRatio: 7 / 6,
  );

  static const connect6 = GameMeta(
    kind: GameKind.connect6,
    title: '六子棋',
    subtitle: '双落子 · 连六',
    en: 'CONNECT6',
    accent: Color(0xFF6C9BD8),
    sideLabels: ['黑方', '白方'],
  );

  static const nineMensMorris = GameMeta(
    kind: GameKind.nineMensMorris,
    title: '九子棋',
    subtitle: '三子成线 · 九子',
    en: "NINE MEN'S MORRIS",
    accent: Color(0xFFB78A54),
    sideLabels: ['黑方', '白方'],
  );

  static const amazons = GameMeta(
    kind: GameKind.amazons,
    title: '亚马逊棋',
    subtitle: '皇后 · 射箭封锁',
    en: 'AMAZONS',
    accent: Color(0xFFC9855A),
    sideLabels: ['黑方', '白方'],
  );

  static const tiger = GameMeta(
    kind: GameKind.tiger,
    title: '老虎棋',
    subtitle: '虎吃四犬 · 围虎',
    en: 'TIGER',
    accent: Color(0xFFD58A4E),
    sideLabels: ['虎方', '犬方'],
  );

  static const chineseCheckers = GameMeta(
    kind: GameKind.chineseCheckers,
    title: '中国跳棋',
    subtitle: '连跳 · 十子入营',
    en: 'CHINESE CHECKERS',
    accent: Color(0xFF6C9BD8),
    sideLabels: ['红方', '蓝方'],
  );

  static const flyingChess = GameMeta(
    kind: GameKind.flyingChess,
    title: '飞行棋',
    subtitle: '掷骰 · 四机归巢',
    en: 'FLYING CHESS',
    accent: Color(0xFFD95B4E),
    sideLabels: ['红方', '蓝方'],
  );

  static const backgammon = GameMeta(
    kind: GameKind.backgammon,
    title: '双陆棋',
    subtitle: '掷骰 · 十五子离盘',
    en: 'BACKGAMMON',
    accent: Color(0xFFB78A54),
    sideLabels: ['白方', '黑方'],
    aspectRatio: 1.3,
  );

  static const shogi = GameMeta(
    kind: GameKind.shogi,
    title: '将棋',
    subtitle: '升变 · 持驹落子',
    en: 'SHOGI',
    accent: Color(0xFFC4955A),
    sideLabels: ['黑方', '白方'],
  );

  static const tycoon = GameMeta(
    kind: GameKind.tycoon,
    title: '地产大亨',
    subtitle: '掷骰 · 买地收租',
    en: 'TYCOON',
    accent: Color(0xFFD7A74E),
    sideLabels: ['红方', '蓝方'],
  );

  static const doudizhu = GameMeta(
    kind: GameKind.doudizhu,
    title: '斗地主',
    subtitle: '二人 · 地主先手',
    en: 'DOU DIZHU',
    accent: Color(0xFFD7A74E),
    sideLabels: ['地主', '农民'],
  );

  static const mahjong = GameMeta(
    kind: GameKind.mahjong,
    title: '麻将',
    subtitle: '二人 · 摸牌胡',
    en: 'MAHJONG',
    accent: Color(0xFF79B36B),
    sideLabels: ['红方', '蓝方'],
  );

  static const ticTacToe = GameMeta(
    kind: GameKind.ticTacToe,
    title: '井字棋',
    subtitle: '三子成线 · 3×3',
    en: 'TIC-TAC-TOE',
    accent: Color(0xFFD95B4E),
    sideLabels: ['X 方', 'O 方'],
  );

  static const fiveFieldKono = GameMeta(
    kind: GameKind.fiveFieldKono,
    title: '五子飞',
    subtitle: '五子换营 · 竞速',
    en: 'FIVE FIELD KONO',
    accent: Color(0xFF8FB36A),
    sideLabels: ['红方', '蓝方'],
  );

  static const hex = GameMeta(
    kind: GameKind.hex,
    title: '六角棋',
    subtitle: 'Hex · 上下对左右',
    en: 'HEX',
    accent: Color(0xFF6C9BD8),
    sideLabels: ['黑方', '白方'],
  );

  static const dotsBoxes = GameMeta(
    kind: GameKind.dotsBoxes,
    title: '点格棋',
    subtitle: '画线围格 · 6×6 点',
    en: 'DOTS & BOXES',
    accent: Color(0xFFD7A74E),
    sideLabels: ['红方', '蓝方'],
  );

  static const mancala = GameMeta(
    kind: GameKind.mancala,
    title: '曼卡拉',
    subtitle: 'Kalah · 播种与俘获',
    en: 'MANCALA',
    accent: Color(0xFFC9855A),
    sideLabels: ['红方', '蓝方'],
  );

  static const oware = GameMeta(
    kind: GameKind.oware,
    title: '播棋',
    subtitle: 'Oware · 2×6 坑',
    en: 'OWARE',
    accent: Color(0xFFB78A54),
    sideLabels: ['红方', '蓝方'],
  );

  static const hareHounds = GameMeta(
    kind: GameKind.hareHounds,
    title: '兔与猎犬',
    subtitle: '三犬围兔 · 7×7',
    en: 'HARE & HOUNDS',
    accent: Color(0xFF79B36B),
    sideLabels: ['野兔', '猎犬'],
  );

  static const foxGeese = GameMeta(
    kind: GameKind.foxGeese,
    title: '狐狸与鹅',
    subtitle: '狐吃五鹅 · 十字棋盘',
    en: 'FOX & GEESE',
    accent: Color(0xFFD58A4E),
    sideLabels: ['狐狸', '鹅群'],
  );

  static const quoridor = GameMeta(
    kind: GameKind.quoridor,
    title: '墙棋',
    subtitle: '竞速 · 单格墙',
    en: 'QUORIDOR',
    accent: Color(0xFF6FB7B1),
    sideLabels: ['红方', '蓝方'],
  );

  static const twelveMensMorris = GameMeta(
    kind: GameKind.twelveMensMorris,
    title: '十二子棋',
    subtitle: '十二子 · 三连吃子',
    en: "TWELVE MEN'S MORRIS",
    accent: Color(0xFFB78A54),
    sideLabels: ['黑方', '白方'],
  );

  static const sixMensMorris = GameMeta(
    kind: GameKind.sixMensMorris,
    title: '六子冲',
    subtitle: '十六点 · 六子三连',
    en: "SIX MEN'S MORRIS",
    accent: Color(0xFFB78A54),
    sideLabels: ['黑方', '白方'],
  );

  static const threeMensMorris = GameMeta(
    kind: GameKind.threeMensMorris,
    title: '三三棋',
    subtitle: '3×3 · 三子成线',
    en: "THREE MEN'S MORRIS",
    accent: Color(0xFFC9855A),
    sideLabels: ['黑方', '白方'],
  );

  static const quarto = GameMeta(
    kind: GameKind.quarto,
    title: '夸托',
    subtitle: '四属性 · 四子连线',
    en: 'QUARTO',
    accent: Color(0xFFD7A74E),
    sideLabels: ['红方', '蓝方'],
  );

  static const yote = GameMeta(
    kind: GameKind.yote,
    title: '约特棋',
    subtitle: '5×6 · 布子与跳吃',
    en: 'YOTÉ',
    accent: Color(0xFF79B36B),
    sideLabels: ['红方', '蓝方'],
    aspectRatio: 1.15,
  );

  static const onitama = GameMeta(
    kind: GameKind.onitama,
    title: '鬼将棋',
    subtitle: '移动卡 · 主将对决',
    en: 'ONITAMA',
    accent: Color(0xFFD58A4E),
    sideLabels: ['红方', '蓝方'],
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
    reversi,
    connect4,
    connect6,
    nineMensMorris,
    amazons,
    tiger,
    chineseCheckers,
    flyingChess,
    backgammon,
    shogi,
    tycoon,
    doudizhu,
    mahjong,
    ticTacToe,
    fiveFieldKono,
    hex,
    dotsBoxes,
    mancala,
    oware,
    hareHounds,
    foxGeese,
    quoridor,
    twelveMensMorris,
    sixMensMorris,
    threeMensMorris,
    quarto,
    yote,
    onitama,
  ];

  static GameMeta of(GameKind kind) =>
      all.firstWhere((meta) => meta.kind == kind);
}
