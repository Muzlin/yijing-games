import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/main.dart';
import 'package:chess_app/ui/game_screen.dart';
import 'package:chess_app/ui/widgets/chess_board.dart';
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

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChessApp());
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> openChess(WidgetTester tester) async {
    await tester.tap(find.text('国际象棋'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('home screen renders on a phone', (tester) async {
    await pumpHome(tester, const Size(390, 844));
    expect(find.text('棋牌合集'), findsOneWidget);
    expect(find.text('国际象棋'), findsOneWidget);
    expect(find.text('中国象棋'), findsOneWidget);
    expect(find.text('军棋'), findsOneWidget);
    expect(find.text('蛇棋'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await openChess(tester);
    expect(find.text('开始对局'), findsOneWidget);
    expect(find.text('人机对战'), findsOneWidget);
  });

  testWidgets('home screen renders on a wide window', (tester) async {
    await pumpHome(tester, const Size(1080, 840));
    expect(find.text('棋牌合集'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await openChess(tester);
    expect(find.text('开始对局'), findsOneWidget);
  });

  testWidgets('about dialog is localized', (tester) async {
    await pumpHome(tester, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('弈境 · 棋牌合集'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('AI vs AI mode starts from home', (tester) async {
    await pumpHome(tester, const Size(420, 900));
    await openChess(tester);

    await tester.tap(find.text('AI 对战'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('开始观战'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, '开始观战'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(GameScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.text('观战'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Pause so the automatic play loop stops before the test framework checks
    // for pending timers.
    await tester.tap(find.text('暂停'));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('two player game accepts a move', (tester) async {
    await pumpHome(tester, const Size(420, 900));
    await openChess(tester);

    await tester.tap(find.text('双人对弈'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('开始对局'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('开始对局'));
    await tester.pumpAndSettle();

    expect(find.byType(ChessBoard), findsOneWidget);
    final board = tester.getRect(find.byType(ChessBoard));
    // The board widget includes a 6px frame, so work out the inner square.
    const frame = 6.0;
    final inner = board.width - frame * 2;
    final square = inner / 8;
    Offset center(int file, int rank) => Offset(
          board.left + frame + (file + 0.5) * square,
          board.top + frame + (7 - rank + 0.5) * square,
        );

    // e2 -> e4
    await tester.tapAt(center(4, 1));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tapAt(center(4, 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('第 1 手'), findsOneWidget);
    expect(find.text('黑方走棋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
