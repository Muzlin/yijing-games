import 'dart:io';
import 'dart:ui' as ui;

import 'package:chess_app/ai/ai_bridge.dart';
import 'package:chess_app/core/chess.dart';
import 'package:chess_app/game/models.dart';
import 'package:chess_app/main.dart';
import 'package:chess_app/ui/game_screen.dart';
import 'package:chess_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedGame buildGame({required List<String> sans, GameConfig? config}) {
  final position = Position.initial();
  final fens = <String>[position.toFen()];
  final moves = <int>[];
  final played = <String>[];
  for (final san in sans) {
    final move = position.legalMoves().firstWhere(
          (m) => position.sanFor(m) == san,
          orElse: () => throw StateError('No legal move for $san'),
        );
    position.makeMove(move);
    fens.add(position.toFen());
    moves.add(move);
    played.add(san);
  }
  return SavedGame(
    config: config ??
        const GameConfig(
          mode: GameMode.ai,
          difficulty: Difficulty.skilled,
          humanSide: white,
        ),
    fens: fens,
    moves: moves,
    sans: played,
    savedAt: DateTime.now(),
  );
}

Future<void> capture(
    WidgetTester tester, GlobalKey boundaryKey, String path) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiBridge.enabled = false;
  });

  testWidgets('capture home screen', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: const ChessApp()));
    await tester.pump(const Duration(milliseconds: 900));
    await capture(tester, key, '/tmp/shot_home_phone.png');
  });

  testWidgets('capture wide home', (tester) async {
    tester.view.physicalSize = const Size(1080 * 2, 840 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: const ChessApp()));
    await tester.pump(const Duration(milliseconds: 900));
    await capture(tester, key, '/tmp/shot_home_wide.png');
  });

  testWidgets('capture game screen (phone)', (tester) async {
    final saved = buildGame(sans: [
      'e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'c3', 'Nf6',
      'd4', 'exd4', 'cxd4', 'Bb4+', 'Nc3', 'Nxe4', 'O-O', 'Bxc3',
      'bxc3', 'd5', 'Ba3', 'dxc4', 'Re1', 'Be6',
    ]);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: AppTheme.build(),
        debugShowCheckedModeBanner: false,
        home: GameScreen(
          config: saved.config,
          resume: saved,
          soundEnabled: false,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await capture(tester, key, '/tmp/shot_game_phone.png');
  });

  testWidgets('capture game screen (wide)', (tester) async {
    final saved = buildGame(sans: [
      'e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'c3', 'Nf6',
      'd4', 'exd4', 'cxd4', 'Bb4+', 'Nc3', 'Nxe4', 'O-O', 'Bxc3',
      'bxc3', 'd5', 'Ba3', 'dxc4', 'Re1', 'Be6',
    ]);
    tester.view.physicalSize = const Size(1080 * 2, 840 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: AppTheme.build(),
        debugShowCheckedModeBanner: false,
        home: GameScreen(
          config: saved.config,
          resume: saved,
          soundEnabled: false,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await capture(tester, key, '/tmp/shot_game_wide.png');
  });

  testWidgets('capture checkmate overlay', (tester) async {
    final saved = buildGame(sans: ['f3', 'e5', 'g4', 'Qh4#']);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: AppTheme.build(),
        debugShowCheckedModeBanner: false,
        home: GameScreen(
          config: saved.config,
          resume: saved,
          soundEnabled: false,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    await capture(tester, key, '/tmp/shot_checkmate.png');
  });
}
