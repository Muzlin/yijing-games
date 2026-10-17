import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/games/core/game_core.dart';
import 'package:chess_app/games/impl/draughts_game.dart';
import 'package:chess_app/games/impl/go_game.dart';
import 'package:chess_app/games/impl/jungle_game.dart';
import 'package:chess_app/games/impl/junqi_game.dart';
import 'package:chess_app/games/impl/xiangqi_game.dart';
import 'package:chess_app/games/ui/generic_game_screen.dart';
import 'package:chess_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _screen(GameKind kind, {int humanSide = 0}) {
  return MaterialApp(
    theme: AppTheme.build(),
    home: GenericGameScreen(
      config: GameMatchConfig(
        meta: GameCatalog.of(kind),
        mode: PlayMode.ai,
        level: 1,
        humanSide: humanSide,
      ),
    ),
  );
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    AiBridge.enabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ai moves first when human plays second in gomoku', (tester) async {
    _size(tester);
    await tester.pumpWidget(_screen(GameKind.gomoku, humanSide: 1));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('1 子'), findsOneWidget);
    expect(find.text('思考中…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('xiangqi human move gets an AI reply', (tester) async {
    _size(tester);
    await tester.pumpWidget(_screen(GameKind.xiangqi));
    await tester.pump(const Duration(milliseconds: 700));
    final rect = tester.getRect(find.byType(XiangqiBoard));
    final cell = rect.width / 9;
    final padding = cell * 0.5;
    Offset at(int row, int col) => Offset(
          rect.left + padding + col * cell,
          rect.top + padding + row * cell,
        );
    await tester.tapAt(at(9, 1)); // red horse
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(at(7, 2)); // horse move
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('思考中…'), findsNothing);
    expect(find.textContaining('红方'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jungle human move gets an AI reply', (tester) async {
    _size(tester);
    await tester.pumpWidget(_screen(GameKind.jungle));
    await tester.pump(const Duration(milliseconds: 700));
    final rect = tester.getRect(find.byType(JungleBoard));
    final cw = rect.width / 7;
    final ch = rect.height / 9;
    await tester.tapAt(Offset(rect.left + cw * 0.5, rect.top + ch * 8.5));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(Offset(rect.left + cw * 1.5, rect.top + ch * 8.5));
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('思考中…'), findsNothing);
    expect(find.textContaining('红方'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('junqi human move gets an AI reply', (tester) async {
    _size(tester);
    await tester.pumpWidget(_screen(GameKind.junqi));
    await tester.pump(const Duration(milliseconds: 700));
    final rect = tester.getRect(find.byType(JunqiBoard));
    final cw = rect.width / 5;
    final ch = rect.height / 10;
    await tester.tapAt(Offset(rect.left + cw * 0.5, rect.top + ch * 7.5));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(Offset(rect.left + cw * 0.5, rect.top + ch * 6.5));
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('思考中…'), findsNothing);
    expect(find.textContaining('红方'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draughts human move gets an AI reply', (tester) async {
    _size(tester);
    await tester.pumpWidget(_screen(GameKind.draughts));
    await tester.pump(const Duration(milliseconds: 700));
    final rect = tester.getRect(find.byType(DraughtsBoard));
    final cell = rect.width / 8;
    await tester.tapAt(Offset(rect.left + cell * 0.5, rect.top + cell * 5.5));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(Offset(rect.left + cell * 1.5, rect.top + cell * 4.5));
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('思考中…'), findsNothing);
    expect(find.textContaining('白方'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('go human move gets an AI reply or pass', (tester) async {
    _size(tester);
    await tester.pumpWidget(_screen(GameKind.go));
    await tester.pump(const Duration(milliseconds: 700));
    final rect = tester.getRect(find.byType(GoBoard));
    await tester.tapAt(rect.center);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('思考中…'), findsNothing);
    expect(find.textContaining('黑方'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
