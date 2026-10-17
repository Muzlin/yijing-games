import 'package:flutter/material.dart';

import '../../ui/theme.dart';

class GameBoardFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const GameBoardFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34473F), Color(0xFF16211E)],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 6),
        child: child,
      ),
    );
  }
}

class GameStone extends StatelessWidget {
  final bool white;
  final double size;
  final double lift;

  const GameStone({
    super.key,
    required this.white,
    required this.size,
    this.lift = 0,
  });

  @override
  Widget build(BuildContext context) {
    final base = white ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22);
    final edge = white ? const Color(0xFFC9BFAE) : const Color(0xFF050708);
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.95,
            colors: white
                ? [const Color(0xFFFFFFFF), base, const Color(0xFFD8CDBA)]
                : [const Color(0xFF4E565B), base, const Color(0xFF060809)],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(color: edge.withValues(alpha: 0.65), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: white ? 0.28 : 0.45),
              blurRadius: size * 0.18,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
      ),
    );
  }
}

class GameDisc extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final double size;
  final bool selected;
  final bool dimmed;
  final double fontSize;
  final bool filled;
  final Color? borderColor;

  const GameDisc({
    super.key,
    required this.label,
    required this.color,
    required this.size,
    this.background = const Color(0xFFF0E5CE),
    this.selected = false,
    this.dimmed = false,
    this.fontSize = 16,
    this.filled = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? color.withValues(alpha: 0.8);
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : background,
          gradient: filled
              ? RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    Color.lerp(color, Colors.white, 0.18)!,
                    color,
                    Color.lerp(color, Colors.black, 0.18)!,
                  ],
                )
              : RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    background,
                    Color.lerp(background, Colors.black, 0.12)!,
                  ],
                ),
          border: Border.all(
            color: border,
            width: selected ? 2.6 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: size * 0.16,
              offset: Offset(0, size * 0.07),
            ),
            if (selected)
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.55),
                blurRadius: size * 0.35,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            color: filled ? Colors.white : color,
            fontFamily: null,
          ),
        ),
      ),
    );
  }
}

class BoardTapLayer extends StatelessWidget {
  final Widget child;
  final void Function(Offset local, Size size) onTap;
  final bool interactive;

  const BoardTapLayer({
    super.key,
    required this.child,
    required this.onTap,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: interactive
              ? (details) => onTap(details.localPosition, size)
              : null,
          child: child,
        );
      },
    );
  }
}
