import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/chess.dart';
import '../account/account_manager.dart';
import '../game/chess_game.dart';
import '../game/models.dart';
import '../online/online_session.dart';
import 'sound.dart';
import 'theme.dart';
import 'widgets/chess_board.dart';
import 'widgets/piece_view.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  final SavedGame? resume;
  final bool soundEnabled;
  final OnlineSession? onlineSession;
  final String? opponentAlias;
  final bool onlineBotMatch;

  const GameScreen({
    super.key,
    required this.config,
    this.resume,
    this.soundEnabled = true,
    this.onlineSession,
    this.opponentAlias,
    this.onlineBotMatch = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ChessGame game;
  late int orientation;
  GameStatus _lastStatus = GameStatus.playing;
  bool _resultDismissed = false;
  bool _resultReported = false;

  @override
  void initState() {
    super.initState();
    game = ChessGame(
      config: widget.config,
      resume: widget.resume,
      sound: widget.soundEnabled,
    );
    game.botMatch = widget.onlineBotMatch;
    final session = widget.onlineSession;
    if (session != null && widget.config.mode == GameMode.online) {
      game.onLocalMove = (move) => session.sendMove({'move': move});
      session.onRemoteMove = (payload) {
        final move = payload['move'];
        if (move is int) game.applyRemoteMove(move);
      };
      session.onOpponentLeft = () =>
          _handleForfeit('对手已离线，你获胜', '对手离线');
      session.onOpponentResigned = () =>
          _handleForfeit('对手认输，你获胜', '对手认输');
      session.onConnectionLost = () =>
          _handleForfeit('网络连接中断，你获胜', '网络中断');
      session.onRatingUpdate = (rating, delta) {
        AccountManager.instance.applyRating(rating);
        if (!mounted || delta == 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(delta > 0 ? 'ELO +$delta' : 'ELO $delta'),
          ),
        );
      };
    }
    orientation = widget.config.humanSide == black ? black : white;
    _lastStatus = game.status;
    game.addListener(_onGameChanged);
  }

  bool get _isOnlineMatch => widget.config.mode == GameMode.online;
  bool get _isOnlineOpponent =>
      _isOnlineMatch || widget.opponentAlias != null;

  void _handleForfeit(String message, String reason) {
    if (!mounted || game.status.isOver) return;
    _resultReported = true;
    game.endWithForfeit(game.humanSide, reason: reason);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onGameChanged() {
    if (game.status != _lastStatus) {
      _resultDismissed = false;
      _lastStatus = game.status;
      if (game.status.isOver) _reportOnlineResult();
    }
    if (!game.status.isOver) _resultDismissed = false;
  }

  void _reportOnlineResult() {
    if (!_isOnlineMatch || _resultReported) return;
    _resultReported = true;
    final status = game.status;
    int winner;
    if (status == GameStatus.checkmate) {
      winner = game.position.side == white ? black : white;
    } else if (status == GameStatus.forfeit) {
      winner = game.forfeitWinner ?? game.humanSide;
    } else {
      winner = 2;
    }
    widget.onlineSession?.sendResult(winner);
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    game.dispose();
    widget.onlineSession?.dispose();
    super.dispose();
  }

  void _flip() {
    setState(() => orientation = 1 - orientation);
  }

  Future<void> _confirmNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('开始新对局？'),
        content: const Text(
          '当前对局将被结束，已结束的对局无法恢复。',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消',
                style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF231A08),
            ),
            child: const Text('开始'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      game.startNewGame();
      setState(() {
        _resultDismissed = false;
        _lastStatus = game.status;
      });
    }
  }

  Future<void> _confirmLeaveOnline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('离开联机对局？'),
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

  Future<void> _showMoves() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MoveHistorySheet(
          sans: game.sanMoves,
          statusText: game.status.isOver
              ? '${game.resultTitle} · ${game.resultSubtitle}'
              : game.turnText,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        showGrid: false,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: game,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 780 &&
                      constraints.maxWidth > constraints.maxHeight;
                  final layout = wide
                      ? _buildWide(context, constraints)
                      : _buildNarrow(context, constraints);

                  return Stack(
                    children: [
                      layout,
                      if (game.promotionMoves.isNotEmpty)
                        _PromotionOverlay(
                          side: game.position.side,
                          onSelect: game.completePromotion,
                          onCancel: game.cancelPromotion,
                        ),
                      if (game.status.isOver && !_resultDismissed)
                        _ResultOverlay(
                          game: game,
                          opponentName: widget.opponentAlias ??
                              widget.onlineSession?.opponent?.name,
                          isOnlineMatch: _isOnlineMatch,
                          onRematch: () {
                            if (_isOnlineOpponent) {
                              Navigator.of(context).pop();
                              return;
                            }
                            game.startNewGame();
                            setState(() {
                              _resultDismissed = false;
                              _lastStatus = game.status;
                            });
                          },
                          onViewBoard: () =>
                              setState(() => _resultDismissed = true),
                          onHome: () => Navigator.of(context).pop(),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Layouts
  // -------------------------------------------------------------------------

  Widget _buildNarrow(BuildContext context, BoxConstraints constraints) {
    const headerHeight = 58.0;
    const cardHeight = 62.0;
    const controlsHeight = 60.0;
    const gap = 10.0;

    final availableHeight =
        constraints.maxHeight - headerHeight - controlsHeight - 26;
    final boardSize = math.max(
      170.0,
      math.min(
        constraints.maxWidth - 28,
        availableHeight - cardHeight * 2 - gap * 3,
      ),
    );

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
                    height: cardHeight,
                    child: _buildPlayerCard(1 - orientation),
                  ),
                ),
                const SizedBox(height: gap),
                SizedBox.square(
                  dimension: boardSize,
                  child: _buildBoard(),
                ),
                const SizedBox(height: gap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    height: cardHeight,
                    child: _buildPlayerCard(orientation),
                  ),
                ),
                if (game.status.isOver && _resultDismissed) ...[
                  const SizedBox(height: 8),
                  _resultBanner(),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          height: controlsHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildControls(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildWide(BuildContext context, BoxConstraints constraints) {
    const sideWidth = 330.0;
    final boardSize = math.min(
      constraints.maxHeight - 84,
      constraints.maxWidth - sideWidth - 24,
    );

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
                    child: SizedBox.square(
                      dimension: boardSize,
                      child: _buildBoard(),
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
                        height: 64,
                        child: _buildPlayerCard(1 - orientation),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 64,
                        child: _buildPlayerCard(orientation),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(),
                      const SizedBox(height: 12),
                      SizedBox(height: 62, child: _buildControls()),
                      const SizedBox(height: 12),
                      Expanded(child: _buildMovePanel()),
                      if (game.status.isOver && _resultDismissed) ...[
                        const SizedBox(height: 10),
                        _resultBanner(),
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

  // -------------------------------------------------------------------------
  // Pieces of the screen
  // -------------------------------------------------------------------------

  Widget _buildHeader() {
    final mode = widget.config.mode;
    final subtitle = _isOnlineOpponent
        ? '联机对战 · 在线'
        : mode == GameMode.ai
            ? '人机对战 · ${widget.config.difficulty.label}'
            : mode == GameMode.aiVsAi
                ? 'AI 对战 · ${widget.config.difficulty.label}'
                : '双人对弈 · 同屏';
    final waitingForOnlineOpponent = _isOnlineMatch &&
        !game.isHumanTurn &&
        !game.status.isOver &&
        !game.thinking;
    final statusText = game.status.isOver
        ? game.resultTitle
        : game.paused
            ? '已暂停'
            : waitingForOnlineOpponent
                ? '等待对手落子'
                : game.turnText;

    return Row(
      children: [
        _CircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    game.moveCount == 0
                        ? '开局'
                        : '第 ${((game.moveCount + 1) / 2).ceil()} 手',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.muted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: game.status.isOver
                            ? AppColors.gold
                            : AppColors.ivory,
                      ),
                    ),
                  ),
                  if (game.thinking) ...[
                    const SizedBox(width: 8),
                    const _ThinkingDots(size: 4),
                  ],
                  if (_isOnlineOpponent &&
                      !game.status.isOver) ...[
                    const SizedBox(width: 8),
                    _Tag(
                      text: '在线',
                      color: AppColors.success,
                      background: AppColors.success.withValues(alpha: 0.12),
                    ),
                  ],
                  if (mode == GameMode.aiVsAi &&
                      !game.status.isOver &&
                      !game.paused) ...[
                    const SizedBox(width: 8),
                    _Tag(
                      text: game.manualOverride ? '你来走' : '观战',
                      color: AppColors.gold,
                      background: AppColors.gold.withValues(alpha: 0.13),
                    ),
                  ],
                  if (game.position.isInCheck() &&
                      !game.status.isOver) ...[
                    const SizedBox(width: 8),
                    _Tag(
                      text: '将军',
                      color: AppColors.danger,
                      background: AppColors.danger.withValues(alpha: 0.15),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        _CircleButton(
          icon: AppSound.enabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onTap: () => game.setSound(!AppSound.enabled),
        ),
        const SizedBox(width: 8),
        _CircleButton(
          icon: Icons.refresh_rounded,
          onTap: _confirmNewGame,
        ),
      ],
    );
  }

  Widget _buildBoard() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ChessBoard(
          position: game.position,
          orientation: orientation,
          selectedSquare: game.selectedSquare,
          legalMoves: game.selectedMoves,
          lastMove: game.lastMove,
          hintMove: game.hintMove,
          checkSquare: game.checkSquare,
          moveSerial: game.moveSerial,
          interactive: game.canInteract,
          onTap: game.select,
        ),
        if (game.paused)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_rounded,
                          size: 15, color: AppColors.gold),
                      SizedBox(width: 6),
                      Text(
                        '已暂停',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerCard(int color) {
    final mode = widget.config.mode;
    final isOnlineOpponent =
        _isOnlineOpponent && color != game.humanSide;
    final isAi = mode == GameMode.aiVsAi ||
        (mode == GameMode.ai && color == game.aiSide) ||
        (widget.onlineBotMatch && color != game.humanSide);
    final active = game.position.side == color && !game.status.isOver;
    final captured = game.capturedPiecesFor(color);
    final diff = game.whiteMaterial - game.blackMaterial;
    final advantage = color == white ? diff : -diff;
    const titleStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    final onlineName = widget.opponentAlias ??
        widget.onlineSession?.opponent?.name ??
        '在线棋友';
    final name = isOnlineOpponent
        ? '在线对手 · $onlineName'
        : mode == GameMode.aiVsAi
            ? (color == white ? '白方电脑' : '黑方电脑')
            : mode == GameMode.ai
                ? (isAi ? '电脑 · ${widget.config.difficulty.label}' : '你')
                : (color == white ? '白方' : '黑方');
    final assistantActive =
        game.isAssisted && mode == GameMode.ai && color == game.humanSide;
    final subtitle = game.thinking && game.thinkingSide == color
        ? (_isOnlineOpponent ? '正在思考…' : '正在推演…')
        : game.status.isOver
            ? (color == white ? '白方' : '黑方')
            : game.paused
                ? '已暂停'
                : assistantActive
                    ? 'AI 托管中 · 自动落子'
                    : mode == GameMode.aiVsAi
                        ? (game.manualOverride && active
                            ? '你来帮它走一步'
                            : '自动对弈')
                        : isOnlineOpponent
                            ? (active ? '正在落子…' : '等待对手')
                            : (active ? '该你落子' : '等待对手');

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
                  AppColors.gold.withValues(alpha: 0.13),
                  AppColors.surfaceHigh.withValues(alpha: 0.92),
                ]
              : [
                  AppColors.surface.withValues(alpha: 0.72),
                  AppColors.surface.withValues(alpha: 0.55),
                ],
        ),
        border: Border.all(
          color: active
              ? AppColors.gold.withValues(alpha: 0.6)
              : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          PieceBadge(
            piece: makePiece(color, king),
            size: 40,
            background: color == white
                ? const Color(0xFFEDE6D4)
                : const Color(0xFF1A2226),
            border: active
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 10),
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
                        style: titleStyle,
                      ),
                    ),
                    if (isOnlineOpponent) ...[
                      const SizedBox(width: 6),
                      _Tag(
                        text: '在线',
                        color: AppColors.success,
                        background: AppColors.success.withValues(alpha: 0.12),
                      ),
                    ] else if (isAi && mode != GameMode.aiVsAi) ...[
                      const SizedBox(width: 6),
                      _Tag(
                        text: 'AI',
                        color: AppColors.gold,
                        background: AppColors.gold.withValues(alpha: 0.13),
                      ),
                    ],
                    if (active) ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 18,
                  child: captured.isEmpty
                      ? Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: [
                              for (final piece in captured)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 1.5),
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: PieceView(piece: piece, size: 17),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (game.thinking && game.thinkingSide == color)
            const _ThinkingDots(size: 4.5)
          else if (advantage > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '+$advantage',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final diff = game.whiteMaterial - game.blackMaterial;
    final total = math.max(1, game.whiteMaterial + game.blackMaterial);
    final whiteShare = game.whiteMaterial / total;
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
              const Text(
                '对局信息',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                game.thinking
                    ? '引擎思考中'
                    : game.paused
                        ? '已暂停'
                        : game.isAiVsAi
                            ? 'AI 自动对弈'
                            : (game.aiNote ??
                                (game.isAiMode ? '引擎已就绪' : '同屏对弈')),
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppColors.muted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (whiteShare * 1000).round().clamp(1, 999).toInt(),
                    child: Container(color: AppColors.boardLight),
                  ),
                  Expanded(
                    flex: ((1 - whiteShare) * 1000).round().clamp(1, 999).toInt(),
                    child: Container(color: const Color(0xFF2A363B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                '白方 ${game.whiteMaterial}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.muted),
              ),
              const Spacer(),
              if (diff != 0)
                Text(
                  diff > 0 ? '白方 +$diff' : '黑方 +${-diff}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Text(
                  '子力均衡',
                  style:
                      TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              const Spacer(),
              Text(
                '黑方 ${game.blackMaterial}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final canHint = !game.thinking &&
        !game.hintLoading &&
        !game.status.isOver &&
        !game.assisted &&
        !game.isAiVsAi &&
        game.isHumanTurn &&
        game.promotionMoves.isEmpty;

    final buttons = <Widget>[
      _ActionButton(
        icon: Icons.undo_rounded,
        label: '悔棋',
        onTap: game.moveCount == 0 || _isOnlineOpponent ? null : game.undo,
      ),
      if (game.isAiVsAi) ...[
        _ActionButton(
          icon: game.paused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          label: game.paused ? '继续' : '暂停',
          active: game.paused,
          onTap: game.status.isOver ? null : game.togglePaused,
        ),
        _ActionButton(
          icon: Icons.person_pin_circle_rounded,
          label: game.manualOverride ? '协助中' : '接管',
          active: game.manualOverride,
          onTap: game.status.isOver ? null : game.toggleManualOverride,
        ),
      ] else
        _ActionButton(
          icon: Icons.lightbulb_outline_rounded,
          label: '提示',
          onTap: canHint ? game.requestHint : null,
          loading: game.hintLoading,
        ),
      _ActionButton(
        icon: Icons.format_list_bulleted_rounded,
        label: '棋谱',
        onTap: _showMoves,
      ),
      _ActionButton(
        icon: Icons.flip_rounded,
        label: '翻转',
        onTap: _flip,
      ),
      if (widget.config.mode == GameMode.ai ||
          widget.config.mode == GameMode.online)
        _ActionButton(
          icon: Icons.smart_toy_rounded,
          label: game.assisted ? '托管中' : '托管',
          active: game.assisted,
          onTap: game.status.isOver ? null : game.toggleAssisted,
        ),
      _ActionButton(
        icon: _isOnlineOpponent ? Icons.logout_rounded : Icons.add_rounded,
        label: _isOnlineOpponent ? '离开' : '新局',
        onTap: _isOnlineOpponent ? _confirmLeaveOnline : _confirmNewGame,
      ),
    ];

    return Row(
      children: [
        for (final button in buttons) Expanded(child: button),
      ],
    );
  }

  Widget _resultBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: () => setState(() => _resultDismissed = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${game.resultTitle} · ${game.resultSubtitle}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const Text(
                '查看结果',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovePanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text(
                  '棋谱',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${game.moveCount} 手',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _MoveList(
              sans: game.sanMoves,
              emptyText: '落子后，棋谱会显示在这里',
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
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
                  : AppColors.surface.withValues(alpha: enabled ? 0.85 : 0.35),
              border: Border.all(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.55)
                    : enabled
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.transparent,
              ),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppColors.gold,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 17,
                      color: active
                          ? AppColors.gold
                          : enabled
                              ? AppColors.ivory
                              : AppColors.muted.withValues(alpha: 0.4),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.5,
              color: active
                  ? AppColors.gold
                  : enabled
                      ? AppColors.muted
                      : AppColors.muted.withValues(alpha: 0.35),
            ),
          ),
        ],
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
                                  math.sin(
                                    (_controller.value * 2 * math.pi) -
                                        i * 0.9,
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

class _MoveList extends StatefulWidget {
  final List<String> sans;
  final String emptyText;
  final EdgeInsets padding;

  const _MoveList({
    required this.sans,
    required this.emptyText,
    required this.padding,
  });

  @override
  State<_MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<_MoveList> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant _MoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sans.length != oldWidget.sans.length) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sans = widget.sans;
    if (sans.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    final rows = (sans.length / 2).ceil();
    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      itemCount: rows,
      itemBuilder: (context, index) {
        final whiteMove = sans[index * 2];
        final blackMove = index * 2 + 1 < sans.length ? sans[index * 2 + 1] : '';
        final isLastRow = index == rows - 1;
        final lastIsWhite = sans.length.isOdd;
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isLastRow
                ? AppColors.gold.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted.withValues(alpha: 0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  whiteMove,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: lastIsWhite && isLastRow
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: lastIsWhite && isLastRow
                        ? AppColors.gold
                        : AppColors.ivory.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  blackMove,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: !lastIsWhite && isLastRow
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: !lastIsWhite && isLastRow
                        ? AppColors.gold
                        : AppColors.ivory.withValues(alpha: 0.9),
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

class _MoveHistorySheet extends StatelessWidget {
  final List<String> sans;
  final String statusText;

  const _MoveHistorySheet({
    required this.sans,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.66,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Text(
                  '棋谱',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _MoveList(
              sans: sans,
              emptyText: '还没有落子',
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

class _PromotionOverlay extends StatelessWidget {
  final int side;
  final ValueChanged<int> onSelect;
  final VoidCallback onCancel;

  const _PromotionOverlay({
    required this.side,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (queen, '后'),
      (rook, '车'),
      (bishop, '象'),
      (knight, '马'),
    ];
    return Positioned.fill(
      child: GestureDetector(
        onTap: onCancel,
        child: Container(
          color: Colors.black.withValues(alpha: 0.68),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Opacity(opacity: value.clamp(0.0, 1.0).toDouble(), child: child),
              ),
              child: Container(
                width: 320,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.32)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '兵的升变',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '选择一枚棋子继续对局',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final option in options) ...[
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => onSelect(option.$1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.white
                                      .withValues(alpha: 0.045),
                                  border: Border.all(
                                      color: AppColors.line),
                                ),
                                child: Column(
                                  children: [
                                    PieceView(
                                      piece: makePiece(side, option.$1),
                                      size: 46,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      option.$2,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (option != options.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onCancel,
                      child: const Text(
                        '取消',
                        style: TextStyle(color: AppColors.muted),
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
}

class _ResultOverlay extends StatelessWidget {
  final ChessGame game;
  final String? opponentName;
  final bool isOnlineMatch;
  final VoidCallback onRematch;
  final VoidCallback onViewBoard;
  final VoidCallback onHome;

  const _ResultOverlay({
    required this.game,
    required this.onRematch,
    required this.onViewBoard,
    required this.onHome,
    this.opponentName,
    this.isOnlineMatch = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDraw = game.status.isDraw;
    final humanWon = game.humanWon;
    final isHumanGame = game.config.mode == GameMode.ai ||
        game.config.mode == GameMode.online;
    final isAiVsAi = game.isAiVsAi;
    final isOnlineLike = isOnlineMatch || opponentName != null;

    String title;
    if (isDraw) {
      title = '和棋';
    } else if (!isHumanGame) {
      title = game.resultTitle;
    } else {
      title = humanWon ? '你赢了' : '惜败';
    }

    String subtitle;
    if (isOnlineLike) {
      final name = opponentName ?? '在线对手';
      subtitle = humanWon
          ? '击败了在线对手 · $name'
          : '$name 获胜 · ${game.resultSubtitle}';
      if (game.status == GameStatus.forfeit) {
        subtitle = game.resultSubtitle;
      }
    } else if (isAiVsAi) {
      subtitle = isDraw
          ? 'AI 对战 · ${game.resultSubtitle}'
          : 'AI 对战 · ${game.config.difficulty.label} · ${game.resultSubtitle}';
    } else if (isHumanGame && !isDraw) {
      subtitle = humanWon
          ? '击败了 ${game.config.difficulty.label} AI · ${game.resultSubtitle}'
          : '${game.resultSubtitle} · 再战一局？';
    } else {
      subtitle = game.resultSubtitle;
    }

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
                  child: Center(
                    child: isDraw
                        ? const Icon(Icons.handshake_rounded,
                            size: 38, color: AppColors.gold)
                        : PieceView(
                            piece: makePiece(
                              game.position.side == white ? black : white,
                              king,
                            ),
                            size: 56,
                          ),
                  ),
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
                    '共 ${game.moveCount} 手'
                    '${!isOnlineLike && game.aiNote != null ? ' · ${game.aiNote}' : ''}',
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
                    child: Text(isOnlineLike ? '返回大厅' : '再来一局'),
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
