import 'dart:math';

import 'package:flutter/material.dart';

import '../account/account_manager.dart';
import '../account/account_models.dart';
import '../account/login_screen.dart';
import '../account/profile_screen.dart';
import '../ai/ai_bridge.dart';
import '../core/chess.dart';
import '../game/models.dart';
import '../online/identity.dart';
import '../online/matchmaking_screen.dart';
import '../ui/theme.dart';
import '../ui/sound.dart';
import 'game_screen.dart';
import 'widgets/piece_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameMode _mode = GameMode.ai;
  Difficulty _difficulty = Difficulty.casual;
  int _sideChoice = white; // -1 = random
  SavedGame? _saved;
  bool _loadingSaved = true;
  bool _localModel = true;
  bool _localModelChecking = true;
  bool _localModelAvailable = false;
  String? _localModelName;
  String? _playerName;

  @override
  void initState() {
    super.initState();
    AccountManager.instance.addListener(_onAccountChanged);
    _load();
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AccountManager.instance.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      GameStorage.loadGame(),
      GameStorage.loadSound(),
      GameStorage.loadLocalModel(),
      OnlineIdentity.loadOrCreate(),
    ]);
    if (!mounted) return;
    final localModel = results[2] as bool;
    AiBridge.enabled = localModel;
    setState(() {
      _saved = results[0] as SavedGame?;
      AppSound.enabled = results[1] as bool;
      _localModel = localModel;
      _playerName = results[3] as String;
      _loadingSaved = false;
      _localModelChecking = localModel;
    });
    if (!localModel) return;
    final available = await AiBridge.check(force: true);
    if (!mounted) return;
    setState(() {
      _localModelAvailable = available;
      _localModelName = AiBridge.model;
      _localModelChecking = false;
    });
  }

  Future<void> _toggleLocalModel(bool value) async {
    setState(() {
      _localModel = value;
      AiBridge.enabled = value;
      _localModelChecking = value;
      if (!value) _localModelAvailable = false;
    });
    await GameStorage.saveLocalModel(value);
    if (!value) return;
    AiBridge.resetAvailability();
    final available = await AiBridge.check(force: true);
    if (!mounted) return;
    setState(() {
      _localModelAvailable = available;
      _localModelName = AiBridge.model;
      _localModelChecking = false;
    });
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

  Future<void> _editPlayerName() async {
    final user = AccountManager.instance.user;
    if (user == null) {
      _openAccount();
      return;
    }
    if (!mounted) return;
    _openAccount();
  }

  Future<void> _startGame() async {
    if (_mode == GameMode.online) {
      await _startOnlineMatch();
      return;
    }
    final humanSide = _mode == GameMode.ai
        ? (_sideChoice == -1 ? Random().nextInt(2) : _sideChoice)
        : white;
    final config = GameConfig(
      mode: _mode,
      difficulty: _difficulty,
      humanSide: humanSide,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: config,
          soundEnabled: AppSound.enabled,
        ),
      ),
    );
    _reloadSaved();
  }

  Future<void> _startOnlineMatch() async {
    if (!AccountManager.instance.isLoggedIn) {
      final user = await Navigator.of(context).push<AccountUser>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (user == null || !mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          game: 'chess',
          title: '国际象棋',
          builder: (session) {
            if (session.isBot) {
              final level = (session.opponent?.botLevel ?? 1).clamp(0, 3);
              return GameScreen(
                config: GameConfig(
                  mode: GameMode.ai,
                  difficulty: Difficulty.values[level],
                  humanSide: session.mySide ?? white,
                ),
                onlineSession: session,
                opponentAlias: session.opponent?.name,
                onlineBotMatch: true,
                soundEnabled: AppSound.enabled,
              );
            }
            return GameScreen(
              config: GameConfig(
                mode: GameMode.online,
                difficulty: Difficulty.master,
                humanSide: session.mySide ?? white,
              ),
              onlineSession: session,
              soundEnabled: AppSound.enabled,
            );
          },
        ),
      ),
    );
    _reloadSaved();
  }

  Future<void> _resumeGame(SavedGame saved) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: saved.config,
          resume: saved,
          soundEnabled: AppSound.enabled,
        ),
      ),
    );
    _reloadSaved();
  }

  Future<void> _reloadSaved() async {
    final saved = await GameStorage.loadGame();
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  void _toggleSound() {
    setState(() {
      AppSound.enabled = !AppSound.enabled;
    });
    GameStorage.saveSound(AppSound.enabled);
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: '弈境国际象棋',
      applicationVersion: '1.2.1',
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
      applicationLegalese: '棋子矢量图形：Cburnett / Wikimedia Commons, CC BY-SA 3.0',
      children: const [
        SizedBox(height: 16),
        Text(
          '一款专注于纯粹对弈体验的国际象棋应用。支持人机对战、双人对弈、'
          'AI 自动对弈观战、公网联机、账号系统，以及大师级 AI 托管。'
          'AI 可由本机 Ollama 大模型驱动，也可回退到内置引擎。',
          style: TextStyle(height: 1.7, fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final startLabel = _mode == GameMode.aiVsAi
        ? '开始观战'
        : _mode == GameMode.online
            ? '开始匹配'
            : '开始对局';
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 18),
                            const _Crest(),
                            const SizedBox(height: 22),
                            const Text(
                              '国际象棋',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 7,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '执子入局 · 在方寸棋盘间推演胜负',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 30),
                            const _SectionLabel('对局模式'),
                            const SizedBox(height: 10),
                            _buildModeSelector(),
                            const SizedBox(height: 24),
                            if (_mode == GameMode.ai ||
                                _mode == GameMode.aiVsAi) ...[
                              const _SectionLabel('AI 棋力'),
                              const SizedBox(height: 10),
                              _buildDifficultySelector(),
                              const SizedBox(height: 10),
                              _LocalModelTile(
                                enabled: _localModel,
                                checking: _localModelChecking,
                                available: _localModelAvailable,
                                model: _localModelName ?? 'qwen2.5:1.5b',
                                onChanged: _toggleLocalModel,
                              ),
                              if (_mode == GameMode.ai) ...[
                                const SizedBox(height: 22),
                                const _SectionLabel('执子'),
                                const SizedBox(height: 10),
                                _buildSideSelector(),
                              ],
                              const SizedBox(height: 26),
                            ] else if (_mode == GameMode.online) ...[
                              const _SectionLabel('你的游戏名称'),
                              const SizedBox(height: 10),
                              _buildPlayerNameRow(),
                              const SizedBox(height: 14),
                              _buildOnlineHint(),
                              const SizedBox(height: 26),
                            ] else ...[
                              _buildLocalHint(),
                              const SizedBox(height: 26),
                            ],
                            if (_mode == GameMode.aiVsAi) ...[
                              _buildAiVsAiHint(),
                              const SizedBox(height: 26),
                            ],
                            if (_saved != null && !_loadingSaved) ...[
                              _ResumeBanner(
                                saved: _saved!,
                                onTap: () => _resumeGame(_saved!),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StartButton(
                          label: startLabel,
                          onPressed: _startGame,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '弈境 · 国际象棋  v1.2.1',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.4,
                            color: AppColors.muted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (Navigator.of(context).canPop()) ...[
          _RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: '返回棋牌合集',
          ),
          const SizedBox(width: 8),
        ],
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
                'YIJING CHESS',
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
        const SizedBox(width: 8),
        _RoundIconButton(
          icon: AccountManager.instance.isLoggedIn
              ? Icons.person_rounded
              : Icons.person_outline_rounded,
          onTap: _openAccount,
          tooltip: AccountManager.instance.isLoggedIn
              ? AccountManager.instance.displayName
              : '登录账号',
          highlight: AccountManager.instance.isLoggedIn,
        ),
        const SizedBox(width: 8),
        _RoundIconButton(
          icon: Icons.info_outline_rounded,
          onTap: _showAbout,
          tooltip: '关于',
        ),
        const SizedBox(width: 8),
        _RoundIconButton(
          icon: AppSound.enabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onTap: _toggleSound,
          tooltip: AppSound.enabled ? '关闭音效' : '开启音效',
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                title: '人机对战',
                subtitle: '挑战 AI 引擎',
                icon: Icons.smart_toy_rounded,
                selected: _mode == GameMode.ai,
                onTap: () => setState(() => _mode = GameMode.ai),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                title: '双人对弈',
                subtitle: '同屏轮流落子',
                icon: Icons.people_alt_rounded,
                selected: _mode == GameMode.twoPlayers,
                onTap: () => setState(() => _mode = GameMode.twoPlayers),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                title: 'AI 对战',
                subtitle: '双 AI 观战',
                icon: Icons.smart_display_rounded,
                selected: _mode == GameMode.aiVsAi,
                onTap: () => setState(() => _mode = GameMode.aiVsAi),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                title: '联机对战',
                subtitle: '匹配在线玩家',
                icon: Icons.public_rounded,
                selected: _mode == GameMode.online,
                onTap: () => setState(() => _mode = GameMode.online),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerNameRow() {
    final user = AccountManager.instance.user;
    final name = user?.nick ?? _playerName ?? '棋友';
    final subtitle = user == null
        ? '登录后设置游戏名称并联机对战'
        : '已登录 · ELO ${user.rating} · 点击修改';
    return GestureDetector(
      onTap: _editPlayerName,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: user == null
                ? AppColors.line
                : AppColors.success.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (user == null ? AppColors.gold : AppColors.success)
                    .withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                user == null
                    ? Icons.person_outline_rounded
                    : Icons.verified_user_rounded,
                size: 19,
                color: user == null ? AppColors.gold : AppColors.success,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '对局中显示的游戏名称',
                    style: TextStyle(
                      fontSize: 10,
                      color: user == null
                          ? AppColors.muted
                          : AppColors.success.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public_rounded, size: 17, color: AppColors.gold),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '通过公网匹配在线玩家，系统随机分配先后手。'
              '对局中可使用 AI 提示与大师级托管代下。',
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Row(
      children: [
        for (var i = 0; i < Difficulty.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _DifficultyCard(
              difficulty: Difficulty.values[i],
              selected: _difficulty == Difficulty.values[i],
              onTap: () => setState(
                  () => _difficulty = Difficulty.values[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSideSelector() {
    return Row(
      children: [
        Expanded(
          child: _SideChoice(
            label: '执白',
            subtitle: '先行',
            piece: (white << 3) | king,
            selected: _sideChoice == white,
            onTap: () => setState(() => _sideChoice = white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SideChoice(
            label: '执黑',
            subtitle: '后行',
            piece: (black << 3) | king,
            selected: _sideChoice == black,
            onTap: () => setState(() => _sideChoice = black),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SideChoice(
            label: '随机',
            subtitle: '听天由命',
            piece: null,
            selected: _sideChoice == -1,
            onTap: () => setState(() => _sideChoice = -1),
          ),
        ),
      ],
    );
  }

  Widget _buildAiVsAiHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_rounded, color: AppColors.gold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '两名 AI 自动对弈，你可以随时暂停、悔棋或复盘',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '白方先行，双方在同一设备上轮流落子',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalModelTile extends StatelessWidget {
  final bool enabled;
  final bool checking;
  final bool available;
  final String model;
  final ValueChanged<bool> onChanged;

  const _LocalModelTile({
    required this.enabled,
    required this.checking,
    required this.available,
    required this.model,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = !enabled
        ? '已关闭 · 使用内置引擎'
        : checking
            ? '正在连接 Ollama…'
            : available
                ? '$model · 已连接'
                : '未连接 · 自动回退内置引擎';
    final ok = enabled && available && !checking;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (ok ? AppColors.success : AppColors.gold)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.memory_rounded,
              size: 18,
              color: ok ? AppColors.success : AppColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '本地大模型 AI',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: ok
                            ? AppColors.success
                            : (checking
                                ? AppColors.gold
                                : AppColors.muted.withValues(alpha: 0.4)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: AppColors.gold.withValues(alpha: 0.55),
            activeThumbColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gold.withValues(alpha: 0.16),
                  AppColors.gold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 158,
            height: 158,
            child: CustomPaint(painter: _DashedRingPainter()),
          ),
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF283E38), Color(0xFF111D1A)],
              ),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  blurRadius: 40,
                ),
              ],
            ),
            child: const Center(
              child: PieceView(piece: (white << 3) | knight, size: 88),
            ),
          ),
          Positioned(
            left: 26,
            bottom: 18,
            child: Opacity(
              opacity: 0.55,
              child: Transform.rotate(
                angle: -0.18,
                child: const PieceView(piece: (black << 3) | pawn, size: 34),
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 16,
            child: Opacity(
              opacity: 0.7,
              child: Transform.rotate(
                angle: 0.2,
                child: const PieceView(piece: (white << 3) | pawn, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gold.withValues(alpha: 0.4);
    const ticks = 60;
    for (var i = 0; i < ticks; i++) {
      if (i % 5 == 0) continue;
      final angle = i * 2 * pi / ticks;
      final inner = Offset(
        center.dx + cos(angle) * (radius - 7),
        center.dy + sin(angle) * (radius - 7),
      );
      final outer = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      canvas.drawLine(inner, outer, paint);
    }
    canvas.drawCircle(
      center,
      radius - 13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.gold.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    AppColors.gold.withValues(alpha: 0.16),
                    AppColors.surfaceHigh.withValues(alpha: 0.85),
                  ]
                : [
                    AppColors.surface.withValues(alpha: 0.75),
                    AppColors.surface.withValues(alpha: 0.55),
                  ],
          ),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.75)
                : AppColors.line,
            width: selected ? 1.3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.09),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.gold.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? AppColors.gold : AppColors.muted,
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selected ? 1 : 0,
                  child: const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.gold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ivory,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final Difficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: selected
              ? AppColors.gold.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.55),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.8) : AppColors.line,
          ),
        ),
        child: Column(
          children: [
            Text(
              difficulty.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : AppColors.ivory,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${difficulty.rating}',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.5,
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.7)
                    : AppColors.muted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideChoice extends StatelessWidget {
  final String label;
  final String subtitle;
  final int? piece;
  final bool selected;
  final VoidCallback onTap;

  const _SideChoice({
    required this.label,
    required this.subtitle,
    required this.piece,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.gold.withValues(alpha: 0.13)
              : AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.75) : AppColors.line,
          ),
        ),
        child: Row(
          children: [
            if (piece != null)
              PieceView(piece: piece!, size: 26)
            else
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.line,
                  ),
                ),
                child: Icon(
                  Icons.shuffle_rounded,
                  size: 14,
                  color: selected ? AppColors.gold : AppColors.muted,
                ),
              ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.gold : AppColors.ivory,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 9.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  final SavedGame saved;
  final VoidCallback onTap;

  const _ResumeBanner({required this.saved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final moves = (saved.moves.length / 2).ceil();
    final mode = switch (saved.config.mode) {
      GameMode.ai => '人机对战',
      GameMode.twoPlayers => '双人对弈',
      GameMode.aiVsAi => 'AI 对战',
      GameMode.online => '联机对战',
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceHigh.withValues(alpha: 0.9),
              AppColors.surface.withValues(alpha: 0.7),
            ],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.history_rounded,
                  size: 19, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '继续上次对局',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '第 $moves 手 · $mode',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _StartButton({required this.onPressed, this.label = '开始对局'});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 17),
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF231A08),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 19),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool highlight;

  const _RoundIconButton({
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
