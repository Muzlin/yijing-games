import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../account/account_manager.dart';
import '../account/account_models.dart';
import '../ui/theme.dart';
import 'identity.dart';
import 'nickname_dialog.dart';
import 'online_session.dart';

/// Public matchmaking screen. It connects to the relay server, shows a radar
/// while searching, and then replaces itself with the actual game screen.
class MatchmakingScreen extends StatefulWidget {
  final String game;
  final String title;
  final Widget Function(OnlineSession session) builder;

  const MatchmakingScreen({
    super.key,
    required this.game,
    required this.title,
    required this.builder,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;
  OnlineSession? _session;
  String? _playerName;
  int? _playerRating;
  bool _loadingName = true;
  bool _handedOff = false;
  bool _transitioning = false;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _prepare();
  }

  Future<void> _prepare() async {
    final account = AccountManager.instance.user;
    final name = account?.nick ?? await OnlineIdentity.loadOrCreate();
    if (!mounted) return;
    final session = OnlineSession(
      game: widget.game,
      playerName: name,
      token: account?.token,
    )..addListener(_onSessionChanged);
    _session = session;
    setState(() {
      _playerName = name;
      _playerRating = account?.rating;
      _loadingName = false;
    });
    session.findMatch();
  }

  Future<void> _editName() async {
    if (_transitioning || (_session?.isMatched ?? false)) return;
    final current = _playerName ?? '棋友';
    final nick = await showNicknameDialog(context, current);
    if (nick == null || nick == current || !mounted) return;

    final account = AccountManager.instance.user;
    String? token;
    String name = nick;
    int? rating = _playerRating;
    if (account != null) {
      try {
        final updated = await AccountManager.instance.updateNick(nick);
        name = updated.nick;
        token = updated.token;
        rating = updated.rating;
      } on AccountException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }
    } else {
      await OnlineIdentity.save(nick);
    }
    if (!mounted) return;

    final old = _session;
    old?.removeListener(_onSessionChanged);
    old?.cancelMatch();
    old?.dispose();
    final session = OnlineSession(
      game: widget.game,
      playerName: name,
      token: token,
    )..addListener(_onSessionChanged);
    setState(() {
      _session = session;
      _playerName = name;
      _playerRating = rating;
      _transitioning = false;
    });
    await session.findMatch();
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null || !mounted) return;
    setState(() {});
    if (session.phase == OnlinePhase.matched && !_transitioning) {
      _transitioning = true;
      setState(() {});
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _handedOff = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.builder(session)),
        );
      });
    }
  }

  Future<void> _cancel() async {
    _session?.cancelMatch();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _retry() async {
    final session = _session;
    if (session == null) return;
    session.phase = OnlinePhase.idle;
    session.error = null;
    await session.findMatch();
  }

  @override
  void dispose() {
    _radar.dispose();
    _session?.removeListener(_onSessionChanged);
    if (!_handedOff) {
      _session?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final matched = session?.isMatched ?? false;
    final error = session?.error;

    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.close_rounded,
                      onTap: _cancel,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '联机对战',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${widget.title} · 公网匹配',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Tag(
                      text: _loadingName ? '连接中' : '在线',
                      color: AppColors.success,
                      background:
                          AppColors.success.withValues(alpha: 0.12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 210,
                          height: 210,
                          child: AnimatedBuilder(
                            animation: _radar,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _RadarPainter(
                                  progress: _radar.value,
                                  active: !matched && error == null,
                                  matched: matched,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 82,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF2A4240),
                                          Color(0xFF101C1E),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.45),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.12),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      matched
                                          ? Icons.check_rounded
                                          : (error != null
                                              ? Icons.wifi_off_rounded
                                              : Icons.public_rounded),
                                      size: 34,
                                      color: matched
                                          ? AppColors.success
                                          : AppColors.gold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          error != null
                              ? '联机服务暂不可用'
                              : matched
                                  ? '已找到在线对手'
                                  : '正在寻找在线对手…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error ??
                              (matched
                                  ? '对手已就位，即将进入对局'
                                  : '正在为你匹配棋力相近的在线玩家'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _PlayerPill(
                          label: '你',
                          name: _playerName ?? '加载中…',
                          color: AppColors.gold,
                          trailing: _playerRating?.toString(),
                          onEdit: _editName,
                        ),
                        if (matched && session?.opponent != null) ...[
                          const SizedBox(height: 10),
                          _PlayerPill(
                            label: '对手',
                            name: session!.opponent!.name,
                            color: AppColors.success,
                            trailing:
                                '${session.opponent!.rating}',
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('重新匹配'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: const Color(0xFF231A08),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 13),
                            ),
                          ),
                        ],
                        if (!matched && error == null) ...[
                          const SizedBox(height: 24),
                          const _SearchHint(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('取消匹配'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: AppColors.gold),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              '匹配通常在 5–15 秒内完成',
              style: TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPill extends StatelessWidget {
  final String label;
  final String name;
  final Color color;
  final String? trailing;
  final VoidCallback? onEdit;

  const _PlayerPill({
    required this.label,
    required this.name,
    required this.color,
    this.trailing,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.muted,
              ),
            ),
          ],
          if (onEdit != null) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

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
        child: Icon(icon, size: 18, color: AppColors.ivory),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final bool active;
  final bool matched;

  _RadarPainter({
    required this.progress,
    required this.active,
    required this.matched,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width * 0.48;
    final color = matched ? AppColors.success : AppColors.gold;

    canvas.drawCircle(
      center,
      maxRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      maxRadius * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.12),
    );

    if (active) {
      for (var i = 0; i < 3; i++) {
        final t = (progress + i / 3) % 1.0;
        final radius = maxRadius * (0.22 + 0.78 * t);
        final opacity = (1 - t) * 0.45;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = color.withValues(alpha: opacity),
        );
      }
      final angle = progress * 2 * math.pi;
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          startAngle: angle - 0.9,
          endAngle: angle,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.28),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
      canvas.drawCircle(
        center,
        maxRadius * 0.82,
        sweepPaint..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
