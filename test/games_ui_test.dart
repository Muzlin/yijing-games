import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/games/impl/connect_six_game.dart';
import 'package:chess_app/games/impl/gomoku_game.dart';
import 'package:chess_app/games/ui/generic_game_screen.dart';
import 'package:chess_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AiBridge.enabled = false;
    SharedPreferences.setMockInitialValues({
      'yijing.local_model.v1': false,
    });
  });

  testWidgets('every new game opens in local two-player mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChessApp());
    await tester.pump(const Duration(milliseconds: 700));

    for (final title in [
      '中国象棋',
      '军棋',
      '斗兽棋',
      '国际跳棋',
      '蛇棋',
      '围棋',
      '五子棋',
      '黑白棋',
      '四子棋',
      '六子棋',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();

      await tester.tap(find.text('双人同屏'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('开始对局'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        find.byType(GenericGameScreen),
        findsOneWidget,
        reason: '$title should open the generic game screen',
      );
      expect(tester.takeException(), isNull, reason: title);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('gomoku places stones by tapping the board', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChessApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('五子棋'));
    await tester.tap(find.text('五子棋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('双人同屏'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('开始对局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final board = tester.getRect(find.byType(GomokuBoard));
    final cell = board.width / 15;
    final center = board.center;
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('白方落子'), findsOneWidget);
    expect(find.text('1 子'), findsOneWidget);

    await tester.tapAt(center + Offset(cell * 2, cell * 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('黑方落子'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connect six keeps the turn for the second stone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChessApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('六子棋'));
    await tester.tap(find.text('六子棋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('双人同屏'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('开始对局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final board = tester.getRect(find.byType(ConnectSixBoard));
    await tester.tapAt(board.center);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('白方落子 · 可下 2 手'), findsOneWidget);
    await tester.tapAt(board.center + const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('白方落子 · 本回合最后一手'), findsOneWidget);
    await tester.tapAt(board.center + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('黑方落子 · 可下 2 手'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('snakes dice action advances the turn', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChessApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('蛇棋'));
    await tester.tap(find.text('蛇棋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('双人同屏'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('开始对局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('掷骰子'), findsOneWidget);
    await tester.tap(find.text('掷骰子'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('第 '), findsNWidgets(2));
  });

  testWidgets('gomoku AI vs AI auto-plays and pauses', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ChessApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('五子棋'));
    await tester.tap(find.text('五子棋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 对战'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('开始观战'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byType(GenericGameScreen), findsOneWidget);
    await tester.tap(find.text('暂停'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('继续'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
