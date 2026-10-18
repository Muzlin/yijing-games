import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/games/core/game_core.dart';
import 'package:chess_app/games/ui/generic_game_screen.dart';
import 'package:chess_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _screen(GameKind kind) => MaterialApp(
      theme: AppTheme.build(),
      home: GenericGameScreen(
        config: GameMatchConfig(meta: GameCatalog.of(kind), mode: PlayMode.local),
      ),
    );

void main() {
  setUp(() {
    AiBridge.enabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  for (final kind in [GameKind.backgammon, GameKind.flyingChess, GameKind.tycoon]) {
    testWidgets('${kind.name} roll action works', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_screen(kind));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('掷骰子'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }
}
