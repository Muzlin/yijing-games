import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/core/chess.dart';
import 'package:chess_app/game/chess_game.dart';
import 'package:chess_app/game/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AiBridge.enabled = false;
  });

  testWidgets('AI vs AI starts and plays a move', (tester) async {
    final game = ChessGame(
      config: const GameConfig(
        mode: GameMode.aiVsAi,
        difficulty: Difficulty.beginner,
      ),
      sound: false,
    );
    // Fire the initial auto-play delay, then let the isolate search finish.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.moveCount, greaterThanOrEqualTo(1));
    expect(game.status, GameStatus.playing);
    expect(game.position.side, black);

    game.dispose();
    await tester.pump();
  });

  testWidgets('assist plays for the human side', (tester) async {
    final game = ChessGame(
      config: const GameConfig(
        mode: GameMode.ai,
        difficulty: Difficulty.beginner,
        humanSide: white,
      ),
      sound: false,
    );
    game.toggleAssisted();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.assisted, isTrue);
    expect(game.moveCount, greaterThanOrEqualTo(1));
    // The AI picked some legal opening move for White.
    expect(game.position.side, isNot(white));

    game.dispose();
    await tester.pump();
  });

  testWidgets('online chess applies local and remote moves', (tester) async {
    final game = ChessGame(
      config: const GameConfig(
        mode: GameMode.online,
        difficulty: Difficulty.master,
        humanSide: white,
      ),
      sound: false,
    );
    int? sent;
    game.onLocalMove = (move) => sent = move;

    game.select(12); // e2
    game.select(28); // e4
    await tester.pump(const Duration(milliseconds: 100));
    expect(sent, isNotNull);
    expect(game.moveCount, 1);
    expect(game.position.side, black);

    final e5 = game.position.legalMoves().firstWhere(
          (m) => moveFrom(m) == 52 && moveTo(m) == 36,
        );
    game.applyRemoteMove(e5);
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.moveCount, 2);
    expect(game.position.side, white);

    game.dispose();
    await tester.pump();
  });

  testWidgets('human can take over one AI-vs-AI turn', (tester) async {
    final game = ChessGame(
      config: const GameConfig(
        mode: GameMode.aiVsAi,
        difficulty: Difficulty.beginner,
      ),
      sound: false,
    );

    game.toggleManualOverride();
    expect(game.manualOverride, isTrue);
    expect(game.canInteract, isTrue);

    final move = game.position.legalMoves().firstWhere(
          (m) => moveFrom(m) == 12 && moveTo(m) == 28,
        );
    game.select(12);
    game.select(28);
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.moveCount, 1);
    expect(game.lastMove, move);
    expect(game.manualOverride, isFalse);

    game.dispose();
    await tester.pump();
  });
}
