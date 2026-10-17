// Dev-only entrypoint used to render deterministic screenshots of each screen.
import 'package:chess_app/account/login_screen.dart';
import 'package:chess_app/account/profile_screen.dart';
import 'package:chess_app/core/chess.dart';
import 'package:chess_app/games/core/game_core.dart';
import 'package:chess_app/games/ui/generic_game_screen.dart';
import 'package:chess_app/game/models.dart';
import 'package:chess_app/main.dart';
import 'package:chess_app/ui/game_screen.dart';
import 'package:chess_app/ui/theme.dart';
import 'package:flutter/material.dart';

SavedGame buildSaved(List<String> sans, GameConfig config) {
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
    config: config,
    fens: fens,
    moves: moves,
    sans: played,
    savedAt: DateTime.now(),
  );
}

void main() {
  final scene = Uri.base.queryParameters['scene'] ?? 'home';
  if (scene == 'home') {
    runApp(const ChessApp());
    return;
  }
  const gameScenes = {
    'xiangqi': GameKind.xiangqi,
    'junqi': GameKind.junqi,
    'jungle': GameKind.jungle,
    'draughts': GameKind.draughts,
    'snakes': GameKind.snakes,
    'go': GameKind.go,
    'gomoku': GameKind.gomoku,
  };
  final gameKind = gameScenes[scene];
  if (gameKind != null) {
    final meta = GameCatalog.of(gameKind);
    runApp(MaterialApp(
      theme: AppTheme.build(),
      debugShowCheckedModeBanner: false,
      home: GenericGameScreen(
        config: GameMatchConfig(
          meta: meta,
          mode: PlayMode.local,
          boardSize: meta.defaultBoardSize,
        ),
      ),
    ));
    return;
  }
  if (scene == 'login') {
    runApp(MaterialApp(
      theme: AppTheme.build(),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(startInRegister: true),
    ));
    return;
  }
  if (scene == 'profile') {
    runApp(MaterialApp(
      theme: AppTheme.build(),
      debugShowCheckedModeBanner: false,
      home: const ProfileScreen(),
    ));
    return;
  }

  const gameConfig = GameConfig(
    mode: GameMode.ai,
    difficulty: Difficulty.skilled,
    humanSide: white,
  );

  late final SavedGame saved;
  if (scene == 'aivsai') {
    saved = buildSaved(
      [
        'e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'c3', 'Nf6',
        'd4', 'exd4', 'cxd4', 'Bb4+', 'Nc3', 'Nxe4', 'O-O', 'Bxc3',
        'bxc3', 'd5', 'Ba3', 'dxc4', 'Re1', 'Be6',
      ],
      const GameConfig(
        mode: GameMode.aiVsAi,
        difficulty: Difficulty.casual,
      ),
    );
  } else if (scene == 'checkmate') {
    saved = buildSaved(
      ['f3', 'e5', 'g4', 'Qh4#'],
      const GameConfig(
        mode: GameMode.ai,
        difficulty: Difficulty.skilled,
        humanSide: white,
      ),
    );
  } else {
    saved = buildSaved(
      [
        'e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'c3', 'Nf6',
        'd4', 'exd4', 'cxd4', 'Bb4+', 'Nc3', 'Nxe4', 'O-O', 'Bxc3',
        'bxc3', 'd5', 'Ba3', 'dxc4', 'Re1', 'Be6',
      ],
      gameConfig,
    );
  }

  runApp(MaterialApp(
    theme: AppTheme.build(),
    debugShowCheckedModeBanner: false,
    home: GameScreen(config: saved.config, resume: saved, soundEnabled: false),
  ));
}
