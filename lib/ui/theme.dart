import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF091014);
  static const backgroundAlt = Color(0xFF0E1A1D);
  static const surface = Color(0xFF142126);
  static const surfaceHigh = Color(0xFF1B2C31);
  static const gold = Color(0xFFE7BC6C);
  static const goldDeep = Color(0xFFC79643);
  static const ivory = Color(0xFFF4EEDF);
  static const muted = Color(0xFF93A5A0);
  static const line = Color(0x1FFFFFFF);
  static const boardLight = Color(0xFFEDE2CB);
  static const boardDark = Color(0xFF6F8F7B);
  static const danger = Color(0xFFE4796E);
  static const success = Color(0xFF7DC9A3);
  static const whitePiece = Color(0xFFF8F3E7);
  static const blackPiece = Color(0xFF20262A);
}

class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: Color(0xFF211705),
      secondary: AppColors.success,
      surface: AppColors.surface,
      onSurface: AppColors.ivory,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.ivory,
            displayColor: AppColors.ivory,
          )
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              height: 1.1,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.ivory,
            ),
            bodySmall: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.muted,
            ),
            labelLarge: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
      iconTheme: const IconThemeData(color: AppColors.ivory, size: 22),
      dividerColor: AppColors.line,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.ivory),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF241A08),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Decorative page background: deep teal gradient with warm glows.
class PageBackground extends StatelessWidget {
  final Widget child;
  final bool showGrid;

  const PageBackground({super.key, required this.child, this.showGrid = true});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0C161A),
            AppColors.background,
            Color(0xFF0A1216),
          ],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -140,
            right: -100,
            child: _Glow(color: Color(0x2EE7BC6C), size: 380),
          ),
          const Positioned(
            bottom: -180,
            left: -120,
            child: _Glow(color: Color(0x1F4F9C86), size: 420),
          ),
          if (showGrid)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.028)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const cell = 54.0;
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, size.height), paint);
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(size.width, r * cell), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
