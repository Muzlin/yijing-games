import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../core/game_core.dart';

Future<GameMatchConfig?> showGameSetupSheet(
  BuildContext context,
  GameMeta meta,
) {
  return showModalBottomSheet<GameMatchConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GameSetupSheet(meta: meta),
  );
}

class _GameSetupSheet extends StatefulWidget {
  final GameMeta meta;

  const _GameSetupSheet({required this.meta});

  @override
  State<_GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends State<_GameSetupSheet> {
  PlayMode _mode = PlayMode.ai;
  int _level = 1;
  int _side = 0;
  int _boardSize = 0;

  @override
  void initState() {
    super.initState();
    _boardSize = widget.meta.defaultBoardSize;
  }

  void _start() {
    Navigator.pop(
      context,
      GameMatchConfig(
        meta: widget.meta,
        mode: _mode,
        level: _level,
        humanSide: _mode == PlayMode.ai ? _side : 0,
        boardSize: _mode == PlayMode.online
            ? (widget.meta.supportsBoardSize ? widget.meta.defaultBoardSize : 0)
            : _boardSize,
      ),
    );
  }

  String get _startLabel => switch (_mode) {
        PlayMode.online => '开始匹配',
        PlayMode.aiVsAi => '开始观战',
        _ => '开始对局',
      };

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    meta.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Label('对局模式'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Choice(
                          label: '人机对战',
                          icon: Icons.smart_toy_rounded,
                          selected: _mode == PlayMode.ai,
                          onTap: () => setState(() => _mode = PlayMode.ai),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Choice(
                          label: '双人同屏',
                          icon: Icons.people_alt_rounded,
                          selected: _mode == PlayMode.local,
                          onTap: () => setState(() => _mode = PlayMode.local),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Choice(
                          label: 'AI 对战',
                          icon: Icons.smart_display_rounded,
                          selected: _mode == PlayMode.aiVsAi,
                          onTap: () => setState(() => _mode = PlayMode.aiVsAi),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Choice(
                          label: '联机匹配',
                          icon: Icons.public_rounded,
                          selected: _mode == PlayMode.online,
                          onTap: () => setState(() {
                            _mode = PlayMode.online;
                            if (meta.supportsBoardSize) {
                              _boardSize = meta.defaultBoardSize;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_mode == PlayMode.ai || _mode == PlayMode.aiVsAi) ...[
                    const SizedBox(height: 18),
                    const _Label('AI 棋力'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _Choice(
                              label: const ['入门', '业余', '高手', '大师'][i],
                              selected: _level == i,
                              compact: true,
                              onTap: () => setState(() => _level = i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (_mode == PlayMode.ai) ...[
                    const SizedBox(height: 18),
                    const _Label('执子'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _Choice(
                            label: '执先 · ${meta.sideLabels[0]}',
                            selected: _side == 0,
                            onTap: () => setState(() => _side = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Choice(
                            label: '执后 · ${meta.sideLabels[1]}',
                            selected: _side == 1,
                            onTap: () => setState(() => _side = 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (meta.supportsBoardSize &&
                      _mode != PlayMode.online) ...[
                    const SizedBox(height: 18),
                    const _Label('棋盘'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final size in meta.boardSizes) ...[
                          Expanded(
                            child: _Choice(
                              label: '$size 路',
                              selected: _boardSize == size,
                              onTap: () => setState(() => _boardSize = size),
                            ),
                          ),
                          if (size != meta.boardSizes.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                  if (_mode == PlayMode.online) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.public_rounded,
                              size: 16, color: AppColors.gold),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '公网匹配在线玩家，随机分配先后手；可使用 AI 提示与大师级托管。',
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
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF231A08),
                      ),
                      child: Text(_startLabel),
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
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 2,
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 10 : 12,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.gold.withValues(alpha: 0.14)
              : AppColors.surfaceHigh.withValues(alpha: 0.5),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.7)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.gold : AppColors.muted,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.gold : AppColors.ivory,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
