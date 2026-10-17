import 'package:flutter/material.dart';

import '../../core/chess.dart';
import '../../vectors/pieces.dart';

/// Renders one of the twelve chess pieces using the bundled vector artwork.
class PieceView extends StatelessWidget {
  final int piece;
  final double size;
  final bool withShadow;

  const PieceView({
    super.key,
    required this.piece,
    required this.size,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (piece == 0) return SizedBox.square(dimension: size);
    return SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: vectorPiece(piece, size, shadow: withShadow),
      ),
    );
  }
}

Widget vectorPiece(int piece, double size, {bool shadow = true}) {
  final type = typeOf(piece);
  final isWhite = colorOf(piece) == white;

  switch (type) {
    case pawn:
      return isWhite
          ? WhitePawn(size: size)
          : BlackPawn(size: size);
    case knight:
      return isWhite
          ? WhiteKnight(size: size)
          : BlackKnight(size: size);
    case bishop:
      return isWhite
          ? WhiteBishop(size: size)
          : BlackBishop(size: size);
    case rook:
      return isWhite
          ? WhiteRook(size: size)
          : BlackRook(size: size);
    case queen:
      return isWhite
          ? WhiteQueen(size: size)
          : BlackQueen(size: size);
    case king:
      return isWhite
          ? WhiteKing(size: size)
          : BlackKing(size: size);
    default:
      return SizedBox.square(dimension: size);
  }
}

/// A simple round avatar badge with a king/pawn silhouette.
class PieceBadge extends StatelessWidget {
  final int piece;
  final double size;
  final Color background;
  final Color border;

  const PieceBadge({
    super.key,
    required this.piece,
    required this.size,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.2),
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: PieceView(piece: piece, size: size * 0.68),
    );
  }
}
