import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../account/account_manager.dart';
import '../../ai/ai_bridge.dart';
import '../../online/online_session.dart';
import '../../ui/sound.dart';
import '../../ui/theme.dart';
import '../core/game_core.dart';
import '../core/registry.dart';
import 'game_board_ui.dart';

class GenericGameScreen extends StatefulWidget {
  final GameMatchConfig config;
  final OnlineSession? onlineSession;
  final String? opponentAlias;
  final bool onlineBotMatch;

  const GenericGameScreen({
    super.key,
    required this.config,
    this.onlineSession,
    this.opponentAlias,
    this.onlineBotMatch = false,
  });

  @override
  State<GenericGameScreen> createState() => _GenericGameScreenState();
}

class _GenericGameScreenState extends State<GenericGameScreen> {
  late TurnGame game;
  late final GameMatchConfig config;
  OnlineSession? session;

  int boardVersion = 0;
  bool thinking = false;
  bool assisted = false;
  bool paused = false;
  bool manualOverride = false;
  bool flipped = false;
  Object? hint;
  int? _forcedWinner;
  String? _forcedReason;
  bool _resultReported = false;
  bool _resultDismissed = false;
  bool _disposed = false;
  int _aiGeneration = 0;
  bool _applyingRemote = false;

  bool get _isOnlineReal => config.mode == PlayMode.online;
  bool get _isOnlineLike =>
      _isOnlineReal || widget.onlineBotMatch || widget.opponentAlias != null;
  bool get _isOver => game.isOver || _forcedWinner != null;
  int? get _winner => _forcedWinner ?? game.winner;
  String get _opponentName =>
      widget.opponentAlias ?? session?.opponent?.name ?? '在线对手';
  bool get _canHumanMove =>
      !thinking &&
      !_isOver &&
      !assisted &&
      !paused &&
      switch (config.mode) {
        PlayMode.local => true,
        PlayMode.ai => game.side == config.humanSide,
        PlayMode.online => game.side == config.humanSide,
        PlayMode.aiVsAi => manualOverride,
      };

  @override
  void initState() {
    super.initState();
    config = widget.config;
    game = GameRegistry.create(
      config.meta.kind,
      boardSize: config.boardSize,
    );
    session = widget.onlineSession;
    if (session != null && _isOnlineReal) {
      session!.onRemoteMove = _onRemoteState;
      session!.onOpponentLeft = () =>
          _forceEnd(config.humanSide, '对手已离线');
      session!.onOpponentResigned = () =>
          _forceEnd(config.humanSide, '对手认输');
      session!.onConnectionLost = () =>
          _forceEnd(config.humanSide, '网络中断');
      session!.onRatingUpdate = (rating, delta) {
        AccountManager.instance.applyRating(rating);
        if (!mounted || delta == 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(delta > 0 ? 'ELO +$delta' : 'ELO $delta')),
        );
      };
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAi());
  }

  @override
  void dispose() {
    _disposed = true;
    _aiGeneration++;
    session?.dispose();
    super.dispose();
  }

  void _onRemoteState(Map<String, dynamic> payload) {
    final raw = payload['state'];
    if (raw is! Map) return;
    _aiGeneration++;
    thinking = false;
    hint = null;
    _applyingRemote = true;
    game.loadJson(Map<String, Object?>.from(raw));
    _applyingRemote = false;
    boardVersion++;
    if (!mounted) return;
    setState(() {});
    if (_isOver) return;
    if (assisted && game.side == config.humanSide) {
      _maybeAi();
    }
  }

  void _forceEnd(int winner, String reason) {
    if (_isOver) return;
    _forcedWinner = winner;
    _forcedReason = reason;
    _resultReported = true;
    _aiGeneration++;
    thinking = false;
    if (mounted) setState(() {});
  }

  Future<void> _maybeAi() async {
    if (_disposed || thinking || _isOver || paused || manualOverride) return;
    final should = switch (config.mode) {
      PlayMode.local => false,
      PlayMode.ai => game.side != config.humanSide || assisted,
      PlayMode.aiVsAi => true,
      PlayMode.online => assisted && game.side == config.humanSide,
    };
    if (!should) return;
    if (assisted && config.mode == PlayMode.ai && game.side == config.humanSide) {
      // Assisted human move.
    }
    final generation = ++_aiGeneration;
    setState(() => thinking = true);
    final delay = widget.onlineBotMatch
        ? 550 + Random().nextInt(750)
        : 260 + Random().nextInt(120);
    await Future<void>.delayed(Duration(milliseconds: delay));
    if (_disposed || generation != _aiGeneration || _isOver) return;

    Object? move;
    try {
      move = game.aiMove(assisted ? 3 : config.level);
    } catch (_) {
      move = null;
    }
    if (_disposed || generation != _aiGeneration) return;
    // Let the 32B local model choose among the engine's best move and a few
    // legal alternatives. The server adds the rules for the specific game.
    if (config.useLlm &&
        game.llmSupported &&
        !assisted &&
        move != null &&
        !_isOver) {
      final level = assisted ? 3 : config.level;
      final candidates = <Object?>[];
      final seen = <String>{};
      void addCandidate(Object? candidate) {
        if (candidate == null) return;
        final label = game.describeMove(candidate);
        if (seen.add(label)) candidates.add(candidate);
      }

      addCandidate(move);
      final engineLabel = game.describeMove(move);
      final pool = game.llmMoves
          .where((m) => game.describeMove(m) != engineLabel)
          .toList()
        ..shuffle(Random());
      for (final candidate in pool) {
        addCandidate(candidate);
        if (candidates.length >= 8) break;
      }
      if (candidates.length > 1) {
        final options = <AiMoveOption>[
          for (var i = 0; i < candidates.length; i++)
            AiMoveOption(
              id: 'm$i',
              label: game.describeMove(candidates[i]),
            ),
        ];
        final chosenId = await AiBridge.chooseMove(
          game: config.meta.kind.name,
          state: game.llmState,
          moves: options,
          player: game.side,
          level: level,
        );
        if (_disposed || generation != _aiGeneration || _isOver) return;
        if (chosenId != null && chosenId.startsWith('m')) {
          final index = int.tryParse(chosenId.substring(1));
          if (index != null &&
              index >= 0 &&
              index < candidates.length &&
              game.isLegal(candidates[index])) {
            move = candidates[index];
          }
        }
      }
    }

    thinking = false;
    if (move != null && !_isOver && game.isLegal(move)) {
      game.apply(move);
      boardVersion++;
      AppSound.move();
    }
    if (!mounted) return;
    setState(() {});
    _afterMove(local: true);
  }

  void _afterMove({required bool local}) {
    if (local && _isOnlineReal && !_applyingRemote) {
      session?.sendMove({'state': game.toJson()});
    }
    if (_isOver) {
      _reportResult();
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    setState(() {});
    if (config.mode == PlayMode.aiVsAi) {
      if (!manualOverride && !paused) _maybeAi();
    } else if (config.mode == PlayMode.ai) {
      if (assisted || game.side != config.humanSide) _maybeAi();
    } else if (config.mode == PlayMode.online) {
      if (assisted && game.side == config.humanSide) _maybeAi();
    }
  }

  void _reportResult() {
    if (!_isOnlineReal || _resultReported || _forcedWinner != null) return;
    _resultReported = true;
    session?.sendResult(_winner ?? 2);
  }

  void _onBoardMove(Object? move) {
    if (!_canHumanMove || !game.isLegal(move)) return;
    game.apply(move);
    hint = null;
    boardVersion++;
    if (manualOverride) manualOverride = false;
    AppSound.move();
    setState(() {});
    _afterMove(local: true);
  }

  void _primaryAction() {
    if (!_canHumanMove) return;
    game.primaryAction();
    hint = null;
    boardVersion++;
    if (manualOverride) manualOverride = false;
    AppSound.move();
    setState(() {});
    _afterMove(local: true);
  }

  void _assistOnce() {
    if (!_canHumanMove) return;
    final move = game.aiMove(3);
    if (move == null || !game.isLegal(move)) return;
    game.apply(move);
    hint = null;
    boardVersion++;
    AppSound.move();
    setState(() {});
    _afterMove(local: true);
  }

  void _undo() {
    if (_isOnlineReal) return;
    _aiGeneration++;
    thinking = false;
    hint = null;
    if (config.mode == PlayMode.aiVsAi) {
      paused = true;
      if (game.canUndo) game.undo();
    } else if (config.mode == PlayMode.ai) {
      if (game.canUndo) game.undo();
      if (game.canUndo && game.side != config.humanSide) game.undo();
      if (game.side != config.humanSide && !assisted) {
        _maybeAi();
      }
    } else {
      if (game.canUndo) game.undo();
    }
    boardVersion++;
    setState(() {});
  }

  void _toggleAssisted() {
    if (config.mode != PlayMode.ai && config.mode != PlayMode.online) return;
    assisted = !assisted;
    if (!assisted) {
      _aiGeneration++;
      thinking = false;
    }
    setState(() {});
    if (assisted && game.side == config.humanSide) _maybeAi();
  }

  void _togglePaused() {
    if (config.mode != PlayMode.aiVsAi) return;
    paused = !paused;
    if (paused) {
      _aiGeneration++;
      thinking = false;
      manualOverride = false;
    }
    setState(() {});
    if (!paused) _maybeAi();
  }

  void _toggleManualOverride() {
    if (config.mode != PlayMode.aiVsAi || _isOver) return;
    if (manualOverride) {
      manualOverride = false;
      setState(() {});
      _maybeAi();
      return;
    }
    _aiGeneration++;
    thinking = false;
    paused = false;
    manualOverride = true;
    setState(() {});
  }

  void _newGame() {
    if (_isOnlineReal) {
      _leaveOnline();
      return;
    }
    _aiGeneration++;
    game = GameRegistry.create(config.meta.kind, boardSize: config.boardSize);
    boardVersion++;
    thinking = false;
    assisted = false;
    paused = false;
    manualOverride = false;
    hint = null;
    _forcedWinner = null;
    _forcedReason = null;
    _resultReported = false;
    _resultDismissed = false;
    setState(() {});
    _maybeAi();
  }

  Future<void> _leaveOnline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('离开对局？'),
        content: const Text(
          '离开后本局将结束，对手会收到离线提示。',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续下棋',
                style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('离开'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() async {
    if (_isOnlineLike && !_isOver) {
      await _leaveOnline();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String get _modeLabel {
    if (_isOnlineLike) return '联机对战 · 在线';
    return switch (config.mode) {
      PlayMode.ai =>
        '人机对战 · ${_difficultyLabel(config.level)}',
      PlayMode.local => '双人对弈 · 同屏',
      PlayMode.aiVsAi => 'AI 对战 · ${_difficultyLabel(config.level)}',
      PlayMode.online => '联机对战 · 在线',
    };
  }

  String _difficultyLabel(int level) =>
      const ['入门', '业余', '高手', '大师'][level.clamp(0, 3)];

  String get _statusText {
    if (_isOver) return _resultTitle;
    if (thinking) return '思考中…';
    if (paused) return '已暂停';
    if (manualOverride) return '你来走一步';
    return game.statusText;
  }

  String get _resultTitle {
    if (_forcedWinner != null) {
      return '${game.sideName(_forcedWinner!)}胜';
    }
    return game.resultTitle;
  }

  String get _resultSubtitle => _forcedReason ?? game.resultSubtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780 &&
                  constraints.maxWidth > constraints.maxHeight;
              return Stack(
                children: [
                  wide
                      ? _buildWide(context, constraints)
                      : _buildNarrow(context, constraints),
                  if (_isOver && !_resultDismissed)
                    _ResultOverlay(
                      title: _resultTitle,
                      subtitle: _resultSubtitle,
                      winnerBadge: _winner == null
                          ? const Icon(Icons.handshake_rounded,
                              size: 38, color: AppColors.gold)
                          : game.sideBadge(_winner!, 58),
                      stats:
                          '共 ${game.moveCount} 步 · $_modeLabel',
                      onlineLike: _isOnlineLike,
                      onRematch: () {
                        if (_isOnlineLike) {
                          Navigator.of(context).pop();
                        } else {
                          _newGame();
                        }
                      },
                      onViewBoard: () =>
                          setState(() => _resultDismissed = true),
                      onHome: () => Navigator.of(context).pop(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context, BoxConstraints constraints) {
    const headerHeight = 58.0;
    const playerHeight = 56.0;
    const controlsHeight = 62.0;
    const gap = 10.0;
    final availableH = constraints.maxHeight -
        headerHeight -
        controlsHeight -
        playerHeight * 2 -
        gap * 3 -
        20;
    final availableW = constraints.maxWidth - 28;
    final aspect = config.meta.aspectRatio;
    var boardH = availableH;
    var boardW = boardH * aspect;
    if (boardW > availableW) {
      boardW = availableW;
      boardH = boardW / aspect;
    }

    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: _buildHeader(),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    height: playerHeight,
                    child: _buildPlayerBar(1 - _bottomSide),
                  ),
                ),
                const SizedBox(height: gap),
                SizedBox(
                  width: boardW,
                  height: boardH,
                  child: GameBoardFrame(
                    child: KeyedSubtree(
                      key: ValueKey('${boardVersion}_$flipped'),
                      child: game.buildBoard(
                        interactive: _canHumanMove,
                        onMove: _onBoardMove,
                        hint: hint,
                        flipped: flipped,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: gap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    height: playerHeight,
                    child: _buildPlayerBar(_bottomSide),
                  ),
                ),
                if (_isOver && _resultDismissed) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _resultDismissed = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '$_resultTitle · 点击查看结果',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.gold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          height: controlsHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildControls(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildWide(BuildContext context, BoxConstraints constraints) {
    const sideWidth = 330.0;
    const playerHeight = 60.0;
    const gap = 10.0;
    final boardMaxH = constraints.maxHeight - 100;
    final boardMaxW = constraints.maxWidth - sideWidth - 56;
    final aspect = config.meta.aspectRatio;
    var boardH = min(boardMaxH, boardMaxW / aspect);
    var boardW = boardH * aspect;
    if (boardW > boardMaxW) {
      boardW = boardMaxW;
      boardH = boardW / aspect;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      child: Column(
        children: [
          SizedBox(height: 54, child: _buildHeader()),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: boardW,
                      height: boardH,
                      child: GameBoardFrame(
                        child: KeyedSubtree(
                          key: ValueKey('${boardVersion}_$flipped'),
                          child: game.buildBoard(
                            interactive: _canHumanMove,
                            onMove: _onBoardMove,
                            hint: hint,
                            flipped: flipped,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: sideWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: playerHeight,
                        child: _buildPlayerBar(1 - _bottomSide),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        height: playerHeight,
                        child: _buildPlayerBar(_bottomSide),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(),
                      const SizedBox(height: 12),
                      SizedBox(height: 62, child: _buildControls()),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                AppColors.surface.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '对局信息',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _infoRow('对局', config.meta.title),
                              const SizedBox(height: 8),
                              _infoRow('模式', _modeLabel),
                              const SizedBox(height: 8),
                              _infoRow('手数', '${game.moveCount}'),
                              if (hint != null) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  '提示：金色标记为 AI 建议的落点',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_isOver && _resultDismissed) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () =>
                              setState(() => _resultDismissed = false),
                          child: const Text('查看结果',
                              style: TextStyle(color: AppColors.gold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  int get _bottomSide {
    if (config.mode == PlayMode.ai || config.mode == PlayMode.online) {
      return config.humanSide;
    }
    return flipped ? 1 : 0;
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: _handleBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _modeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _isOver ? AppColors.gold : AppColors.ivory,
                      ),
                    ),
                  ),
                  if (thinking) ...[
                    const SizedBox(width: 8),
                    const _ThinkingDots(size: 4),
                  ],
                  if (_isOnlineLike && !_isOver) ...[
                    const SizedBox(width: 8),
                    _Tag(
                      text: '在线',
                      color: AppColors.success,
                      background:
                          AppColors.success.withValues(alpha: 0.12),
                    ),
                  ] else if (manualOverride && !_isOver) ...[
                    const SizedBox(width: 8),
                    _Tag(
                      text: '你来走',
                      color: AppColors.gold,
                      background:
                          AppColors.gold.withValues(alpha: 0.13),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        _CircleButton(
          icon: Icons.flip_rounded,
          onTap: () => setState(() => flipped = !flipped),
        ),
      ],
    );
  }

  Widget _buildPlayerBar(int side) {
    final active = game.side == side && !_isOver;
    final isOnlineOpponent = _isOnlineLike && side != config.humanSide;
    final isAi = (config.mode == PlayMode.ai && side != config.humanSide) ||
        config.mode == PlayMode.aiVsAi;
    final isHuman = !isOnlineOpponent &&
        (config.mode == PlayMode.local || side == config.humanSide);
    final name = isOnlineOpponent
        ? '在线对手 · $_opponentName'
        : config.mode == PlayMode.aiVsAi
            ? '电脑'
            : config.mode == PlayMode.ai
                ? (side == config.humanSide
                    ? '你'
                    : '电脑 · ${_difficultyLabel(config.level)}')
                : config.mode == PlayMode.online
                    ? (side == config.humanSide ? '你' : '在线对手')
                    : game.sideName(side);
    final subtitle = thinking && active
        ? '思考中…'
        : _isOver
            ? game.sideName(side)
            : paused
                ? '已暂停'
                : assisted && side == config.humanSide
                    ? 'AI 托管中 · 自动落子'
                    : manualOverride && active
                        ? '你来帮它走一步'
                        : active
                            ? (isHuman ? '该你落子' : '正在落子')
                            : '等待';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? [
                  config.meta.accent.withValues(alpha: 0.15),
                  AppColors.surfaceHigh.withValues(alpha: 0.92),
                ]
              : [
                  AppColors.surface.withValues(alpha: 0.72),
                  AppColors.surface.withValues(alpha: 0.55),
                ],
        ),
        border: Border.all(
          color: active ? config.meta.accent.withValues(alpha: 0.55) : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 38,
            child: Center(child: game.sideBadge(side, 32)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isAi && !isOnlineOpponent) ...[
                      const SizedBox(width: 6),
                      _Tag(
                        text: 'AI',
                        color: AppColors.gold,
                        background:
                            AppColors.gold.withValues(alpha: 0.13),
                      ),
                    ],
                    if (active) ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: config.meta.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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
          if (thinking && active)
            const _ThinkingDots(size: 4.5)
          else
            Text(
              game.scoreText(side),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                config.meta.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                thinking ? '电脑思考中' : (paused ? '已暂停' : '进行中'),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            config.meta.subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final buttons = <Widget>[];
    buttons.add(_Control(
      icon: Icons.undo_rounded,
      label: '悔棋',
      enabled: !_isOnlineLike &&
          !_isOver &&
          !assisted &&
          game.canUndo &&
          !thinking,
      onTap: _undo,
    ));
    if (game.primaryActionLabel != null) {
      buttons.add(_Control(
        icon: game.primaryActionIcon,
        label: game.primaryActionLabel!,
        enabled: _canHumanMove,
        onTap: _primaryAction,
      ));
    }
    buttons.add(_Control(
      icon: Icons.auto_awesome_rounded,
      label: 'AI 代下',
      enabled: _canHumanMove,
      onTap: _assistOnce,
    ));
    if (config.mode == PlayMode.aiVsAi) {
      buttons.add(_Control(
        icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
        label: paused ? '继续' : '暂停',
        active: paused,
        onTap: _togglePaused,
      ));
      buttons.add(_Control(
        icon: Icons.person_pin_circle_rounded,
        label: manualOverride ? '协助中' : '接管',
        active: manualOverride,
        onTap: _toggleManualOverride,
      ));
    } else if (config.mode == PlayMode.ai || _isOnlineReal) {
      buttons.add(_Control(
        icon: Icons.smart_toy_rounded,
        label: assisted ? '托管中' : '托管',
        active: assisted,
        enabled: !_isOver,
        onTap: _toggleAssisted,
      ));
    }
    buttons.add(_Control(
      icon: _isOnlineLike ? Icons.logout_rounded : Icons.add_rounded,
      label: _isOnlineLike ? '离开' : '新局',
      onTap: _isOnlineLike ? _leaveOnline : _newGame,
    ));
    return Row(
      children: [
        for (final button in buttons) Expanded(child: button),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isEnabled ? onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: active
                  ? AppColors.gold.withValues(alpha: 0.16)
                  : AppColors.surface.withValues(alpha: isEnabled ? 0.85 : 0.35),
              border: Border.all(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.55)
                    : isEnabled
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: active
                  ? AppColors.gold
                  : isEnabled
                      ? AppColors.ivory
                      : AppColors.muted.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: active
                  ? AppColors.gold
                  : isEnabled
                      ? AppColors.muted
                      : AppColors.muted.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: 0.72),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 17, color: AppColors.ivory),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _Tag({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  final double size;

  const _ThinkingDots({required this.size});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.45),
                child: Opacity(
                  opacity: 0.25 +
                      0.75 *
                          (0.5 +
                              0.5 *
                                  sin(
                                    (_controller.value * 2 * pi) - i * 0.9,
                                  )),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget winnerBadge;
  final String stats;
  final bool onlineLike;
  final VoidCallback onRematch;
  final VoidCallback onViewBoard;
  final VoidCallback onHome;

  const _ResultOverlay({
    required this.title,
    required this.subtitle,
    required this.winnerBadge,
    required this.stats,
    required this.onlineLike,
    required this.onRematch,
    required this.onViewBoard,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.68),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Container(
            width: 336,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1D2E2B), Color(0xFF101B1E)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.32)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 50,
                  offset: Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.28),
                        AppColors.gold.withValues(alpha: 0.03),
                      ],
                    ),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: Center(child: winnerBadge),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    stats,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRematch,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF231A08),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(onlineLike ? '返回大厅' : '再来一局'),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: onViewBoard,
                      child: const Text(
                        '查看棋盘',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                    TextButton(
                      onPressed: onHome,
                      child: const Text(
                        '返回首页',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
