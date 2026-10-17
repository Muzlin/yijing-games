import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chess.dart';
import '../theme.dart';
import 'piece_view.dart';

class ChessBoard extends StatefulWidget {
  final Position position;
  final int orientation;
  final int? selectedSquare;
  final List<int> legalMoves;
  final int? lastMove;
  final int? hintMove;
  final int? checkSquare;
  final int moveSerial;
  final bool interactive;
  final ValueChanged<int> onTap;

  const ChessBoard({
    super.key,
    required this.position,
    required this.orientation,
    required this.selectedSquare,
    required this.legalMoves,
    required this.lastMove,
    required this.hintMove,
    required this.checkSquare,
    required this.moveSerial,
    required this.interactive,
    required this.onTap,
  });

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _animMove;
  int? _hiddenSquare;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _animMove = null;
            _hiddenSquare = null;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moveSerial != oldWidget.moveSerial &&
        widget.lastMove != null) {
      final move = widget.lastMove!;
      if (movePromotion(move) == 0) {
        _animMove = move;
        _hiddenSquare = moveTo(move);
        _controller.forward(from: 0);
      } else {
        _animMove = null;
        _hiddenSquare = null;
      }
    }
    if (widget.position.hash != oldWidget.position.hash &&
        widget.moveSerial == oldWidget.moveSerial) {
      _controller.stop();
      _animMove = null;
      _hiddenSquare = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _squareOffset(int square, int orientation, double squareSize) {
    final file = square & 7;
    final rank = square >> 3;
    final col = orientation == white ? file : 7 - file;
    final row = orientation == white ? 7 - rank : rank;
    return Offset(col * squareSize, row * squareSize);
  }

  int _squareAt(Offset local, double squareSize, int orientation) {
    final col = (local.dx / squareSize).floor().clamp(0, 7);
    final row = (local.dy / squareSize).floor().clamp(0, 7);
    if (orientation == white) return (7 - row) * 8 + col;
    return row * 8 + 7 - col;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final outer = math.min(constraints.maxWidth, constraints.maxHeight);
        const frame = 6.0;
        final inner = math.max(0.0, outer - frame * 2);
        final squareSize = inner / 8;

        return SizedBox.square(
          dimension: outer,
          child: Container(
            padding: const EdgeInsets.all(frame),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF34473F), Color(0xFF16211E)],
              ),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.28),
                width: 1,
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
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.interactive
                    ? (details) {
                        final sq = _squareAt(
                            details.localPosition, squareSize, widget.orientation);
                        widget.onTap(sq);
                      }
                    : null,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BoardPainter(
                              orientation: widget.orientation,
                              selected: widget.selectedSquare,
                              legalMoves: widget.legalMoves,
                              lastMove: widget.lastMove,
                              hintMove: widget.hintMove,
                              checkSquare: widget.checkSquare,
                              position: widget.position,
                            ),
                          ),
                        ),
                        ..._buildPieces(squareSize),
                        if (_animMove != null) _buildAnimatedPiece(squareSize),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPieces(double squareSize) {
    final widgets = <Widget>[];
    for (var sq = 0; sq < 64; sq++) {
      if (sq == _hiddenSquare) continue;
      final piece = widget.position.pieceAt(sq);
      if (piece == 0) continue;
      final offset =
          _squareOffset(sq, widget.orientation, squareSize);
      widgets.add(Positioned(
        left: offset.dx,
        top: offset.dy,
        width: squareSize,
        height: squareSize,
        child: IgnorePointer(
          child: PieceView(piece: piece, size: squareSize),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildAnimatedPiece(double squareSize) {
    final move = _animMove!;
    final from = _squareOffset(moveFrom(move), widget.orientation, squareSize);
    final to = _squareOffset(moveTo(move), widget.orientation, squareSize);
    final t = Curves.easeOutCubic.transform(_controller.value);
    final offset = Offset.lerp(from, to, t)!;
    final piece = widget.position.pieceAt(moveTo(move));
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: squareSize,
      height: squareSize,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 + 0.05 * math.sin(t * math.pi),
          child: PieceView(piece: piece, size: squareSize),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final int orientation;
  final int? selected;
  final List<int> legalMoves;
  final int? lastMove;
  final int? hintMove;
  final int? checkSquare;
  final Position position;

  _BoardPainter({
    required this.orientation,
    required this.selected,
    required this.legalMoves,
    required this.lastMove,
    required this.hintMove,
    required this.checkSquare,
    required this.position,
  });

  Offset _center(int sq, double squareSize) {
    final file = sq & 7;
    final rank = sq >> 3;
    final col = orientation == white ? file : 7 - file;
    final row = orientation == white ? 7 - rank : rank;
    return Offset((col + 0.5) * squareSize, (row + 0.5) * squareSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 8;
    final rect = Offset.zero & size;

    // Base squares
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final boardRank = orientation == white ? 7 - row : row;
        final boardFile = orientation == white ? col : 7 - col;
        final isLight = (boardRank + boardFile) % 2 == 1;
        final paint = Paint()
          ..color = isLight ? AppColors.boardLight : AppColors.boardDark;
        canvas.drawRect(
          Rect.fromLTWH(col * squareSize, row * squareSize, squareSize,
              squareSize),
          paint,
        );
      }
    }

    // Gentle diagonal light so the board is not perfectly flat.
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.06),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sheen);

    // Last move
    if (lastMove != null) {
      final fill = Paint()..color = AppColors.gold.withValues(alpha: 0.32);
      for (final sq in [moveFrom(lastMove!), moveTo(lastMove!)]) {
        final file = sq & 7;
        final rank = sq >> 3;
        final col = orientation == white ? file : 7 - file;
        final row = orientation == white ? 7 - rank : rank;
        canvas.drawRect(
          Rect.fromLTWH(
              col * squareSize, row * squareSize, squareSize, squareSize),
          fill,
        );
      }
    }

    // Check glow
    if (checkSquare != null) {
      final center = _center(checkSquare!, squareSize);
      final radius = squareSize * 0.78;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.72),
              AppColors.danger.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Selected square
    if (selected != null) {
      final file = selected! & 7;
      final rank = selected! >> 3;
      final col = orientation == white ? file : 7 - file;
      final row = orientation == white ? 7 - rank : rank;
      final selRect = Rect.fromLTWH(
          col * squareSize, row * squareSize, squareSize, squareSize);
      canvas.drawRect(
          selRect, Paint()..color = AppColors.gold.withValues(alpha: 0.42));
      canvas.drawRRect(
        RRect.fromRectAndRadius(selRect.deflate(1.2), const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = AppColors.gold.withValues(alpha: 0.95),
      );
    }

    // Hint arrow
    if (hintMove != null) {
      _drawArrow(canvas, hintMove!, squareSize);
    }

    // Legal move markers
    for (final move in legalMoves) {
      final to = moveTo(move);
      final center = _center(to, squareSize);
      final occupied = position.pieceAt(to) != 0 || moveIsEnPassant(move);
      if (occupied) {
        canvas.drawCircle(
          center,
          squareSize * 0.36,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = squareSize * 0.07
            ..color = const Color(0xFF17231E).withValues(alpha: 0.42),
        );
      } else {
        canvas.drawCircle(
          center,
          squareSize * 0.13,
          Paint()..color = const Color(0xFF17231E).withValues(alpha: 0.36),
        );
      }
    }

    // Coordinates
    _drawCoordinates(canvas, squareSize);

    // Inner hairline
    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  void _drawArrow(Canvas canvas, int move, double squareSize) {
    final from = _center(moveFrom(move), squareSize);
    final to = _center(moveTo(move), squareSize);
    final delta = to - from;
    final distance = delta.distance;
    if (distance < 1) return;
    final dir = delta / distance;
    final start = from + dir * (squareSize * 0.32);
    final end = to - dir * (squareSize * 0.30);
    final width = squareSize * 0.11;

    final glowPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.35)
      ..strokeWidth = width * 2.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(start, end, glowPaint);

    final line = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0.65),
          AppColors.gold,
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, line);

    final head = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - dir.dx * squareSize * 0.24 - dir.dy * squareSize * 0.16,
        end.dy - dir.dy * squareSize * 0.24 + dir.dx * squareSize * 0.16,
      )
      ..lineTo(
        end.dx - dir.dx * squareSize * 0.24 + dir.dy * squareSize * 0.16,
        end.dy - dir.dy * squareSize * 0.24 - dir.dx * squareSize * 0.16,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = AppColors.gold);
  }

  void _drawCoordinates(Canvas canvas, double squareSize) {
    final fontSize = squareSize * 0.17;
    final boardSize = squareSize * 8;
    for (var i = 0; i < 8; i++) {
      // File letters along the bottom edge.
      final boardFile = orientation == white ? i : 7 - i;
      final bottomRank = orientation == white ? 0 : 7;
      final fileLight = (bottomRank + boardFile) % 2 == 1;
      _text(
        canvas,
        String.fromCharCode(97 + boardFile),
        Offset((i + 1) * squareSize - fontSize * 0.85,
            boardSize - fontSize * 1.55),
        fontSize,
        fileLight ? const Color(0xFF3F5A4B) : const Color(0xFFE9E2D2),
      );

      // Rank numbers along the left edge.
      final boardRank = orientation == white ? 7 - i : i;
      final leftFile = orientation == white ? 0 : 7;
      final rankLight = (boardRank + leftFile) % 2 == 1;
      _text(
        canvas,
        '${boardRank + 1}',
        Offset(fontSize * 0.62, i * squareSize + fontSize * 0.4),
        fontSize,
        rankLight ? const Color(0xFF3F5A4B) : const Color(0xFFE9E2D2),
      );
    }
  }

  void _text(
      Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.62),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) {
    return old.orientation != orientation ||
        old.selected != selected ||
        old.lastMove != lastMove ||
        old.hintMove != hintMove ||
        old.checkSquare != checkSquare ||
        old.position.hash != position.hash ||
        !identical(old.legalMoves, legalMoves);
  }
}
