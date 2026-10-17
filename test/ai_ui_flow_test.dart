import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/games/core/game_core.dart';
import 'package:chess_app/games/impl/gomoku_game.dart';
import 'package:chess_app/games/ui/generic_game_screen.dart';
import 'package:chess_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _screen(GameKind kind) {
  return MaterialApp(
    theme: AppTheme.build(),
    home: GenericGameScreen(
      config: GameMatchConfig(
        meta: GameCatalog.of(kind),
        mode: PlayMode.ai,
        level: 1,
        humanSide: 0,
      ),
    ),
  );
}

void main() {
  setUp(() {
    AiBridge.enabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('gomoku human vs AI: AI answers the human move', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_screen(GameKind.gomoku));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('该你落子'), findsOneWidget);

    final board = tester.getRect(find.byType(GomokuBoard));
    await tester.tapAt(board.center);
    await tester.pump(const Duration(milliseconds: 1500));
    // The AI answered, so black is to move again.
    expect(find.text('黑方落子'), findsOneWidget);
    expect(find.text('1 子'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('snakes human vs AI: AI rolls automatically', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_screen(GameKind.snakes));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('掷骰子'), findsOneWidget);

    await tester.tap(find.text('掷骰子'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('第 0 格'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
