import 'dart:io';
import 'dart:ui' as ui;

import 'package:chess_app/core/chess.dart';
import 'package:chess_app/ui/widgets/piece_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if ((r + c).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          Paint()..color = Colors.white.withValues(alpha: 0.035),
        );
      }
    }
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.width * 0.40,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFC79643).withValues(alpha: 0.30),
            const Color(0xFFC79643).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.40)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _crest(double size, {required bool transparent}) {
  return SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (!transparent)
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.4),
                  radius: 1.1,
                  colors: [Color(0xFF2C4B41), Color(0xFF0B1518)],
                ),
              ),
            ),
          ),
        if (!transparent)
          const Positioned.fill(child: CustomPaint(painter: _BackdropPainter())),
        Container(
          width: size * 0.76,
          height: size * 0.76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE7BC6C).withValues(alpha: 0.55),
              width: size * 0.006,
            ),
          ),
        ),
        Container(
          width: size * 0.62,
          height: size * 0.62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE7BC6C).withValues(alpha: 0.18),
              width: size * 0.003,
            ),
          ),
        ),
        PieceView(
          piece: (white << 3) | knight,
          size: size * 0.56,
        ),
      ],
    ),
  );
}

Future<void> _save(WidgetTester tester, Widget widget, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(key: key, child: Center(child: widget)),
  );
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render app icon', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _save(tester, _crest(512, transparent: false), 'assets/icon/app_icon.png');
    await _save(
      tester,
      _crest(512, transparent: true),
      'assets/icon/app_icon_foreground.png',
    );
  });
}
