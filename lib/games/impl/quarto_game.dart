import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_core.dart';
import '../ui/game_board_ui.dart';

class QuartoMove {
  final int piece;
  final int cell;
  const QuartoMove(this.piece, this.cell);
}

/// Simplified Quarto: on each turn a player selects any remaining piece and
/// places it. A line of four sharing an attribute wins.
class QuartoGame extends TurnGame {
  final List<int> board = List<int>.filled(16, -1);
  final List<bool> used = List<bool>.filled(16, false);
  final List<_QuartoSnapshot> _history = [];
  int _side = 0;
  int? _winner;
  int? _last;
  List<int> _winLine = const [];
  int _moveCount = 0;

  @override
  GameMeta get meta => GameCatalog.quarto;

  @override
  int get side => _side;
  @override
  bool get isOver => _winner != null;
  @override
  int? get winner => _winner;
  @override
  int get moveCount => _moveCount;
  @override
  bool get canUndo => _history.isNotEmpty;
  @override
  String sideName(int side) => side == 0 ? '红方' : '蓝方';

  @override
  String get statusText {
    if (_winner != null) return resultTitle;
    return '${sideName(_side)}选子落子';
  }

  @override
  String get resultTitle {
    if (_winner == null) return '';
    if (_winner == 2) return '和棋';
    return '${sideName(_winner!)}胜';
  }

  @override
  String get resultSubtitle {
    if (_winner == null) return '';
    return _winner == 2 ? '十六格已满' : '四子共享同一属性';
  }

  @override
  String scoreText(int side) => '${board.where((v) => v == side).length} 子';

  static const List<int> _lines = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15,
    0, 5, 10, 15, 3, 6, 9, 12,
  ];

  List<int>? _lineAt(int cell) {
    for (var start = 0; start < _lines.length; start += 4) {
      final line = _lines.sublist(start, start + 4);
      if (!line.contains(cell)) continue;
      final pieces = line.map((i) => board[i]).toList();
      if (pieces.any((v) => v < 0)) continue;
      for (var bit = 0; bit < 4; bit++) {
        final mask = 1 << bit;
        if (pieces.every((p) => (p & mask) != 0) ||
            pieces.every((p) => (p & mask) == 0)) {
          return line;
        }
      }
    }
    return null;
  }

  @override
  bool isLegal(Object? move) {
    if (isOver || move is! QuartoMove || move.cell < 0 || move.cell >= 16) return false;
    if (board[move.cell] >= 0) return false;
    if (move.piece < 0 || move.piece >= 16 || used[move.piece]) return false;
    return true;
  }

  @override
  void apply(Object? move) {
    if (!isLegal(move)) return;
    final m = move as QuartoMove;
    _history.add(_snapshot());
    board[m.cell] = m.piece;
    used[m.piece] = true;
    _last = m.cell;
    _moveCount++;
    final line = _lineAt(m.cell);
    if (line != null) {
      _winLine = line;
      _winner = _side;
      return;
    }
    if (_moveCount == 16) {
      _winner = 2;
      return;
    }
    _side = 1 - _side;
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    board.setAll(0, s.board);
    used.setAll(0, s.used);
    _side = s.side;
    _winner = s.winner;
    _last = s.last;
    _winLine = s.winLine;
    _moveCount = s.moveCount;
  }

  @override
  Object? aiMove(int level) {
    if (isOver) return null;
    final pieces = [for (var i = 0; i < 16; i++) if (!used[i]) i];
    final empties = [for (var i = 0; i < 16; i++) if (board[i] < 0) i];
    if (pieces.isEmpty || empties.isEmpty) return null;
    final random = Random();
    final scored = <(QuartoMove, int)>[];
    for (final p in pieces) {
      for (final c in empties) {
        board[c] = p;
        var score = _lineAt(c) != null ? 100000 : 0;
        board[c] = -1;
        if (level <= 0) score += random.nextInt(20);
        scored.add((QuartoMove(p, c), score));
      }
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.first.$1;
  }

  _QuartoSnapshot _snapshot() => _QuartoSnapshot(
        List<int>.of(board),
        List<bool>.of(used),
        _side,
        _winner,
        _last,
        List<int>.of(_winLine),
        _moveCount,
      );

  @override
  Map<String, Object?> toJson() => {
        'board': List<int>.of(board),
        'used': used.map((v) => v ? 1 : 0).toList(),
        'side': _side,
        'winner': _winner,
        'last': _last,
        'winLine': List<int>.of(_winLine),
        'moveCount': _moveCount,
      };

  @override
  void loadJson(Map<String, Object?> json) {
    final raw = (json['board'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 16; i++) {
      board[i] = i < raw.length ? raw[i].toInt() : -1;
    }
    final u = (json['used'] as List?)?.cast<num>() ?? const [];
    for (var i = 0; i < 16; i++) {
      used[i] = i < u.length && u[i].toInt() == 1;
    }
    _side = (json['side'] as num?)?.toInt() ?? 0;
    _winner = (json['winner'] as num?)?.toInt();
    _last = (json['last'] as num?)?.toInt();
    _winLine = (json['winLine'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? const [];
    _moveCount = (json['moveCount'] as num?)?.toInt() ?? 0;
    _history.clear();
  }

  @override
  List<Object?> get llmMoves {
    final pieces = [for (var i = 0; i < 16; i++) if (!used[i]) i];
    final empties = [for (var i = 0; i < 16; i++) if (board[i] < 0) i];
    return [
      for (final p in pieces)
        for (final c in empties) QuartoMove(p, c),
    ];
  }

  @override
  String get llmState {
    final sb = StringBuffer(
      '夸托（Quarto）4x4，16 枚棋子各有 4 个属性；每回合选一枚剩余棋子放到空格，'
      '四子共享任一属性（颜色/高低/形状/实心）即胜。\n',
    );
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        sb.write(board[r * 4 + c] < 0 ? '-- ' : '${board[r * 4 + c].toString().padLeft(2, '0')} ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String describeMove(Object? move) {
    if (move is! QuartoMove) return '$move';
    return '${move.piece + 1}号子 → (${move.cell % 4},${move.cell ~/ 4})';
  }

  @override
  Widget sideBadge(int side, double size) => GameDisc(
        label: side == 0 ? '红' : '蓝',
        color: side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        background:
            side == 0 ? const Color(0xFFD95B4E) : const Color(0xFF6C9BD8),
        filled: true,
        size: size,
        fontSize: size * 0.36,
      );

  @override
  Widget buildBoard({
    required bool interactive,
    required ValueChanged<Object?> onMove,
    Object? hint,
    bool flipped = false,
  }) {
    return QuartoBoard(
      game: this,
      interactive: interactive,
      onMove: onMove,
      flipped: flipped,
    );
  }
}

class _QuartoSnapshot {
  final List<int> board;
  final List<bool> used;
  final int side;
  final int? winner;
  final int? last;
  final List<int> winLine;
  final int moveCount;

  _QuartoSnapshot(this.board, this.used, this.side, this.winner, this.last,
      this.winLine, this.moveCount);
}

class QuartoBoard extends StatefulWidget {
  final QuartoGame game;
  final bool interactive;
  final ValueChanged<Object?> onMove;
  final bool flipped;

  const QuartoBoard({
    super.key,
    required this.game,
    required this.interactive,
    required this.onMove,
    this.flipped = false,
  });

  @override
  State<QuartoBoard> createState() => _QuartoBoardState();
}

class _QuartoBoardState extends State<QuartoBoard> {
  int? selectedPiece;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final boardSize = size * 0.72;
        final cell = boardSize / 4;
        final trayTop = boardSize + size * 0.03;
        final trayCell = (size - trayTop) / 2;
        final trayPiece = min(cell * 0.55, trayCell * 0.42);
        Offset boardPos(int i) {
          final r = i ~/ 4;
          final c = i % 4;
          final vx = widget.flipped ? 3 - c : c;
          final vy = widget.flipped ? 3 - r : r;
          return Offset(vx * cell + cell / 2, vy * cell + cell / 2);
        }

        Offset trayPos(int order) {
          final c = order % 8;
          final r = order ~/ 8;
          return Offset(c * (size / 8) + size / 16, trayTop + r * trayCell + trayCell / 2);
        }

        final boardPieces = <Widget>[];
        for (var i = 0; i < 16; i++) {
          final p = game.board[i];
          if (p < 0) continue;
          final pos = boardPos(i);
          boardPieces.add(Positioned(
            left: pos.dx - trayPiece,
            top: pos.dy - trayPiece,
            width: trayPiece * 2,
            height: trayPiece * 2,
            child: IgnorePointer(child: _QuartoTile(piece: p, size: trayPiece * 2)),
          ));
        }
        final remaining = [for (var i = 0; i < 16; i++) if (!game.used[i]) i];
        final tray = <Widget>[];
        for (var i = 0; i < remaining.length; i++) {
          final p = remaining[i];
          final pos = trayPos(i);
          tray.add(Positioned(
            left: pos.dx - trayPiece,
            top: pos.dy - trayPiece,
            width: trayPiece * 2,
            height: trayPiece * 2,
            child: GestureDetector(
              onTap: widget.interactive
                  ? () => setState(() => selectedPiece = p)
                  : null,
              child: _QuartoTile(
                piece: p,
                size: trayPiece * 2,
                selected: selectedPiece == p,
              ),
            ),
          ));
        }
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: boardSize,
                height: boardSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.interactive
                      ? (details) {
                          final x = (details.localPosition.dx / cell).floor().clamp(0, 3);
                          final y = (details.localPosition.dy / cell).floor().clamp(0, 3);
                          final vx = widget.flipped ? 3 - x : x;
                          final vy = widget.flipped ? 3 - y : y;
                          final index = vy * 4 + vx;
                          if (selectedPiece != null && game.isLegal(QuartoMove(selectedPiece!, index))) {
                            widget.onMove(QuartoMove(selectedPiece!, index));
                            setState(() => selectedPiece = null);
                          }
                        }
                      : null,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _QuartoPainter(game: game, cell: cell)),
                      ),
                      ...boardPieces,
                    ],
                  ),
                ),
              ),
              ...tray,
            ],
          ),
        );
      },
    );
  }
}

class _QuartoTile extends StatelessWidget {
  final int piece;
  final double size;
  final bool selected;

  const _QuartoTile({required this.piece, required this.size, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final tall = (piece & 1) != 0;
    final dark = (piece & 2) != 0;
    final round = (piece & 4) != 0;
    final hollow = (piece & 8) != 0;
    final color = dark ? const Color(0xFF1B1F22) : const Color(0xFFF6F0E4);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected
              ? const Color(0xFFE7BC6C)
              : const Color(0xFF9B7A50),
          width: selected ? 3 : 1,
        ),
        boxShadow: selected
            ? [BoxShadow(color: const Color(0xFFE7BC6C).withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * (round ? 0.38 : 0.46),
        height: size * (tall ? 0.56 : 0.40),
        decoration: BoxDecoration(
          color: hollow ? Colors.transparent : color,
          border: Border.all(color: dark ? const Color(0xFFF6F0E4) : const Color(0xFF1B1F22), width: 2),
          borderRadius: BorderRadius.circular(round ? 999 : 3),
        ),
      ),
    );
  }
}

class _QuartoPainter extends CustomPainter {
  final QuartoGame game;
  final double cell;

  _QuartoPainter({required this.game, required this.cell});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF203A33), Color(0xFF0E1D19)],
        ).createShader(Offset.zero & size),
    );
    final line = Paint()
      ..color = const Color(0xFFE7BC6C).withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    if (game._winLine.isNotEmpty) {
      for (final i in game._winLine) {
        final r = i ~/ 4;
        final c = i % 4;
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          Paint()..color = const Color(0xFFE7BC6C).withValues(alpha: 0.16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QuartoPainter oldDelegate) => true;
}
