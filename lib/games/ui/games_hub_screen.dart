import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../account/account_manager.dart';
import '../../account/login_screen.dart';
import '../../ai/ai_bridge.dart';
import '../../account/profile_screen.dart';
import '../../core/chess.dart';
import '../../game/models.dart';
import '../../online/matchmaking_screen.dart';
import '../../ui/home_screen.dart';
import '../../ui/sound.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/piece_view.dart';
import '../core/game_core.dart';
import 'game_board_ui.dart';
import 'game_setup_sheet.dart';
import 'generic_game_screen.dart';

class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

enum _HubFilter { all, classic, fresh, cards }

class _GamesHubScreenState extends State<GamesHubScreen> {
  _HubFilter _filter = _HubFilter.all;

  bool _isTable(GameKind kind) =>
      kind == GameKind.doudizhu ||
      kind == GameKind.mahjong ||
      kind == GameKind.tycoon ||
      kind == GameKind.flyingChess ||
      kind == GameKind.backgammon;

  bool _matchesFilter(GameMeta meta) {
    final kind = meta.kind;
    final isClassic = kind.index <= GameKind.gomoku.index;
    return switch (_filter) {
      _HubFilter.all => true,
      _HubFilter.classic => isClassic,
      _HubFilter.fresh => !isClassic && !_isTable(kind),
      _HubFilter.cards => _isTable(kind),
    };
  }

  @override
  void initState() {
    super.initState();
    AccountManager.instance.addListener(_onAccountChanged);
    _loadSound();
    unawaited(AiBridge.check());
  }

  Future<void> _loadSound() async {
    final enabled = await GameStorage.loadSound();
    if (!mounted) return;
    setState(() => AppSound.enabled = enabled);
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AccountManager.instance.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _openAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountManager.instance.isLoggedIn
            ? const ProfileScreen()
            : const LoginScreen(),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: '弈境 · 棋牌合集',
      applicationVersion: '2.0.1',
      applicationIcon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A4240), Color(0xFF101C1E)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(6),
        child: const PieceView(piece: (white << 3) | knight, size: 40),
      ),
      applicationLegalese:
          '棋子矢量图形：Cburnett / Wikimedia Commons, CC BY-SA 3.0',
      children: const [
        SizedBox(height: 16),
        Text(
          '21 款经典棋牌，支持人机、双人、AI 对战、公网联机、账号系统、'
          'AI 托管与本地 Ollama 大模型。',
          style: TextStyle(height: 1.7, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _openGame(GameMeta meta) async {
    if (meta.kind == GameKind.chess) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }
    final config = await showGameSetupSheet(context, meta);
    if (config == null || !mounted) return;

    if (config.mode == PlayMode.online) {
      if (!AccountManager.instance.isLoggedIn) {
        final user = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (user == null || !mounted) return;
      }
      await _startOnline(meta, config);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenericGameScreen(config: config),
      ),
    );
  }

  Future<void> _startOnline(GameMeta meta, GameMatchConfig config) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          game: meta.kind.name,
          title: meta.title,
          builder: (session) {
            if (session.isBot) {
              final level = (session.opponent?.botLevel ?? 1).clamp(0, 3);
              return GenericGameScreen(
                config: GameMatchConfig(
                  meta: meta,
                  mode: PlayMode.ai,
                  level: level,
                  humanSide: session.mySide ?? 0,
                  boardSize: config.boardSize,
                  useLlm: config.useLlm,
                ),
                onlineSession: session,
                opponentAlias: session.opponent?.name,
                onlineBotMatch: true,
              );
            }
            return GenericGameScreen(
              config: GameMatchConfig(
                meta: meta,
                mode: PlayMode.online,
                level: 3,
                humanSide: session.mySide ?? 0,
                boardSize: config.boardSize,
              ),
              onlineSession: session,
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleSound() async {
    setState(() => AppSound.enabled = !AppSound.enabled);
    await GameStorage.saveSound(AppSound.enabled);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AccountManager.instance.isLoggedIn;
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(isLoggedIn),
                    const SizedBox(height: 30),
                    const Text(
                      '棋牌合集',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '21 款经典棋牌 · 联机 / AI / 双人 / 托管',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in _HubFilter.values) ...[
                            _FilterChip(
                              label: switch (filter) {
                                _HubFilter.all => '全部',
                                _HubFilter.classic => '经典棋',
                                _HubFilter.fresh => '策略新棋',
                                _HubFilter.cards => '牌桌 / 掷骰',
                              },
                              count: GameCatalog.all
                                  .where((meta) => switch (filter) {
                                        _HubFilter.all => true,
                                        _HubFilter.classic =>
                                          meta.kind.index <= GameKind.gomoku.index,
                                        _HubFilter.fresh =>
                                          meta.kind.index > GameKind.gomoku.index &&
                                              !_isTable(meta.kind),
                                        _HubFilter.cards => _isTable(meta.kind),
                                      })
                                  .length,
                              selected: _filter == filter,
                              accent: AppColors.gold,
                              onTap: () => setState(() => _filter = filter),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width > 780 ? 4 : (width > 560 ? 3 : 2);
                        final cardWidth =
                            (width - 12 * (columns - 1)) / columns;
                        final games =
                            GameCatalog.all.where(_matchesFilter).toList();
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final meta in games)
                              SizedBox(
                                width: cardWidth,
                                child: _GameCard(
                                  meta: meta,
                                  onTap: () => _openGame(meta),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 16, color: AppColors.gold),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '账号通用 · 联机匹配 · 机器人兜底 · AI 托管 · 本地大模型选择合法着法',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '弈境 · 棋牌合集  v2.0.1',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLoggedIn) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFF263B36), Color(0xFF14211F)],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
          ),
          padding: const EdgeInsets.all(5),
          child: const PieceView(piece: (white << 3) | knight, size: 30),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '弈境',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'YIJING GAMES',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 2.2,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _RoundButton(
          icon: isLoggedIn
              ? Icons.person_rounded
              : Icons.person_outline_rounded,
          onTap: _openAccount,
          tooltip: isLoggedIn ? AccountManager.instance.displayName : '登录账号',
          highlight: isLoggedIn,
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: Icons.info_outline_rounded,
          onTap: _showAbout,
          tooltip: '关于',
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: AppSound.enabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onTap: _toggleSound,
          tooltip: AppSound.enabled ? '关闭音效' : '开启音效',
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? accent : AppColors.muted,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 9,
                color: selected
                    ? accent.withValues(alpha: 0.75)
                    : AppColors.muted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameMeta meta;
  final VoidCallback onTap;

  const _GameCard({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 152,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              meta.accent.withValues(alpha: 0.16),
              AppColors.surface.withValues(alpha: 0.76),
            ],
          ),
          border: Border.all(
            color: meta.accent.withValues(alpha: 0.34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GameArt(meta: meta),
                const Spacer(),
                const _Tag(text: 'AI'),
                const SizedBox(width: 4),
                const _Tag(text: '联机'),
              ],
            ),
            const Spacer(),
            Text(
              meta.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              meta.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 8,
          letterSpacing: 0.4,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _GameArt extends StatelessWidget {
  final GameMeta meta;

  const _GameArt({required this.meta});

  @override
  Widget build(BuildContext context) {
    final size = 54.0;
    switch (meta.kind) {
      case GameKind.chess:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2C423C), Color(0xFF101C1E)],
            ),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45)),
          ),
          padding: const EdgeInsets.all(5),
          child: const PieceView(piece: (white << 3) | knight, size: 44),
        );
      case GameKind.xiangqi:
        return GameDisc(
          label: '帅',
          color: const Color(0xFFC94F43),
          size: size,
          fontSize: 24,
        );
      case GameKind.junqi:
        return GameDisc(
          label: '军',
          color: const Color(0xFFC9A26B),
          size: size,
          fontSize: 22,
        );
      case GameKind.jungle:
        return GameDisc(
          label: '狮',
          color: const Color(0xFF79B36B),
          size: size,
          fontSize: 22,
        );
      case GameKind.draughts:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-6, -5),
                child: GameDisc(
                  label: '',
                  color: const Color(0xFFF4EEE2),
                  background: const Color(0xFFF4EEE2),
                  filled: true,
                  size: 34,
                ),
              ),
              Transform.translate(
                offset: const Offset(7, 6),
                child: GameDisc(
                  label: '王',
                  color: const Color(0xFF20262A),
                  background: const Color(0xFF20262A),
                  filled: true,
                  size: 36,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      case GameKind.snakes:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: const _SnakeArtPainter()),
        );
      case GameKind.go:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-7, 4),
                child: GameStone(white: false, size: 34),
              ),
              Transform.translate(
                offset: const Offset(8, -4),
                child: GameStone(white: true, size: 34),
              ),
            ],
          ),
        );
      case GameKind.gomoku:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Transform.translate(
                  offset: Offset(-18.0 + i * 9, (i.isEven ? -4 : 4).toDouble()),
                  child: GameStone(white: i.isOdd, size: 17),
                ),
            ],
          ),
        );
      case GameKind.reversi:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-7, -4),
                child: GameStone(white: true, size: 34),
              ),
              Transform.translate(
                offset: const Offset(8, 5),
                child: GameStone(white: false, size: 34),
              ),
            ],
          ),
        );
      case GameKind.connect4:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF203A5B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-7, 5),
                child: GameDisc(
                  label: '',
                  color: const Color(0xFFD95B4E),
                  background: const Color(0xFFD95B4E),
                  filled: true,
                  size: 30,
                ),
              ),
              Transform.translate(
                offset: const Offset(8, -5),
                child: GameDisc(
                  label: '',
                  color: const Color(0xFFE9C45C),
                  background: const Color(0xFFE9C45C),
                  filled: true,
                  size: 30,
                ),
              ),
            ],
          ),
        );
      case GameKind.nineMensMorris:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.scale(
                  scale: 1 - i * 0.24,
                  child: Container(
                    width: size * 0.78,
                    height: size * 0.78,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFC9A26B),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              const Positioned(
                top: 12,
                child: GameStone(white: false, size: 17),
              ),
              const Positioned(
                bottom: 12,
                child: GameStone(white: true, size: 17),
              ),
            ],
          ),
        );
      case GameKind.amazons:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GameDisc(
                label: '♛',
                color: const Color(0xFF1B1F22),
                background: const Color(0xFF1B1F22),
                filled: true,
                size: 34,
                fontSize: 20,
              ),
              Transform.translate(
                offset: const Offset(17, 13),
                child: Transform.rotate(
                  angle: 0.785,
                  child: Container(
                    width: 13,
                    height: 13,
                    color: const Color(0xFF4A2E1F),
                  ),
                ),
              ),
            ],
          ),
        );
      case GameKind.chineseCheckers:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 10; i++)
                Transform.translate(
                  offset: Offset(
                    cos(i * pi / 5) * 22,
                    sin(i * pi / 5) * 22,
                  ),
                  child: GameDisc(
                    label: '',
                    color: i.isEven
                        ? const Color(0xFFD95B4E)
                        : const Color(0xFF6C9BD8),
                    background: i.isEven
                        ? const Color(0xFFD95B4E)
                        : const Color(0xFF6C9BD8),
                    filled: true,
                    size: 11,
                  ),
                ),
            ],
          ),
        );
      case GameKind.mahjong:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.translate(
                  offset: Offset((i - 1) * 12.0, (i - 1) * 3.0),
                  child: Container(
                    width: 24,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F0E4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFC9BFAE)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      const ['万', '条', '筒'][i],
                      style: TextStyle(
                        color: const [
                          Color(0xFFB53D32),
                          Color(0xFF3D6B54),
                          Color(0xFF315B8A),
                        ][i],
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      case GameKind.doudizhu:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.translate(
                  offset: Offset((i - 1) * 10.0, (i - 1) * 3.0),
                  child: Transform.rotate(
                    angle: (i - 1) * 0.16,
                    child: Container(
                      width: 26,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F0E4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFC9BFAE)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        const ['3', 'J', '王'][i],
                        style: TextStyle(
                          color: i == 2
                              ? const Color(0xFFB53D32)
                              : const Color(0xFF1B1F22),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      case GameKind.tycoon:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.68,
                height: size * 0.68,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C3D35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD7A74E), width: 2),
                ),
              ),
              const Icon(Icons.home_work_rounded,
                  color: Color(0xFFD7A74E), size: 30),
              Transform.translate(
                offset: const Offset(20, 20),
                child: Transform.rotate(
                  angle: 0.2,
                  child: const Icon(Icons.casino_rounded,
                      color: Color(0xFFE7BC4E), size: 24),
                ),
              ),
            ],
          ),
        );
      case GameKind.shogi:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.translate(
                  offset: Offset((i - 1) * 18.0, (i.isEven ? -6 : 6).toDouble()),
                  child: GameDisc(
                    label: const ['歩', '金', '玉'][i],
                    color: const Color(0xFF1B1F22),
                    background: const Color(0xFFE7C994),
                    size: 26,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        );
      case GameKind.backgammon:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.78,
                height: size * 0.58,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A3523),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC9A26B)),
                ),
              ),
              for (var i = 0; i < 6; i++)
                Positioned(
                  left: size * 0.15 + i * size * 0.115,
                  bottom: size * 0.24 + (i.isEven ? 0 : 5),
                  child: GameStone(white: i.isEven, size: 18),
                ),
            ],
          ),
        );
      case GameKind.flyingChess:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 12; i++)
                Transform.rotate(
                  angle: i * pi / 6,
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? const Color(0xFFD95B4E)
                            : const Color(0xFF6C9BD8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              const Icon(Icons.flight_rounded, color: Color(0xFFE7BC6C), size: 24),
            ],
          ),
        );
      case GameKind.tiger:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GameDisc(
                label: '虎',
                color: const Color(0xFFD95B4E),
                background: const Color(0xFFD95B4E),
                filled: true,
                size: 38,
                fontSize: 20,
              ),
              for (final p in const [Offset(-22, 15), Offset(0, 21), Offset(22, 15)])
                Transform.translate(
                  offset: p,
                  child: GameDisc(
                    label: '犬',
                    color: const Color(0xFFE0B76A),
                    background: const Color(0xFFE0B76A),
                    filled: true,
                    size: 20,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        );
      case GameKind.connect6:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 6; i++)
                Transform.translate(
                  offset: Offset(-20.0 + i * 8, (i.isEven ? -3 : 3).toDouble()),
                  child: GameStone(white: i.isOdd, size: 15),
                ),
            ],
          ),
        );
    }
  }
}

class _SnakeArtPainter extends CustomPainter {
  const _SnakeArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B3052), Color(0xFF211A33)],
        ).createShader(rect),
    );
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.18)
      ..cubicTo(
        size.width * 0.9,
        size.height * 0.28,
        size.width * 0.1,
        size.height * 0.68,
        size.width * 0.84,
        size.height * 0.82,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8FC47A),
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.18),
      4.5,
      Paint()..color = const Color(0xFFC5E3A8),
    );
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.6 + i * 0.1);
      final y = size.height * (0.2 + i * 0.13);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 8, y + 14),
        Paint()
          ..color = const Color(0xFFD8B87A)
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool highlight;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlight
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.surface.withValues(alpha: 0.6),
            border: Border.all(
              color: highlight
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.line,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: highlight ? AppColors.success : AppColors.ivory,
          ),
        ),
      ),
    );
  }
}
