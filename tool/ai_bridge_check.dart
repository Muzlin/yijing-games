// ignore_for_file: avoid_print
import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/core/chess.dart';

Future<void> main() async {
  AiBridge.enabled = true;
  final ok = await AiBridge.check(force: true);
  print('health: $ok model=${AiBridge.model}');
  final position = Position.initial();
  final legal = position.legalMoves();
  final id = await AiBridge.chooseMove(
    game: 'chess',
    state: 'FEN: ${position.toFen()}',
    moves: [
      for (final m in legal) AiMoveOption(id: uciForMove(m), label: position.sanFor(m)),
    ],
    player: white,
    level: 1,
  );
  print('choice: $id');
  if (id != null) {
    final move = legal.firstWhere((m) => uciForMove(m) == id);
    print('san: ${position.sanFor(move)}');
  }
}
