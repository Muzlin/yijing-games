import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/chess.dart';

enum GameMode { ai, twoPlayers, aiVsAi, online }

enum Difficulty { beginner, casual, skilled, master }

extension DifficultyX on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.beginner:
        return '入门';
      case Difficulty.casual:
        return '业余';
      case Difficulty.skilled:
        return '高手';
      case Difficulty.master:
        return '大师';
    }
  }

  String get subtitle {
    switch (this) {
      case Difficulty.beginner:
        return '轻松上手';
      case Difficulty.casual:
        return '棋力均衡';
      case Difficulty.skilled:
        return '步步紧逼';
      case Difficulty.master:
        return '全力应战';
    }
  }

  int get rating {
    switch (this) {
      case Difficulty.beginner:
        return 600;
      case Difficulty.casual:
        return 1100;
      case Difficulty.skilled:
        return 1600;
      case Difficulty.master:
        return 2100;
    }
  }
}

class GameConfig {
  final GameMode mode;
  final Difficulty difficulty;
  final int humanSide;

  const GameConfig({
    this.mode = GameMode.ai,
    this.difficulty = Difficulty.casual,
    this.humanSide = white,
  });
}

class SavedGame {
  final GameConfig config;
  final List<String> fens;
  final List<int> moves;
  final List<String> sans;
  final DateTime savedAt;

  const SavedGame({
    required this.config,
    required this.fens,
    required this.moves,
    required this.sans,
    required this.savedAt,
  });

  Map<String, Object?> toJson() => {
        'mode': config.mode.name,
        'difficulty': config.difficulty.name,
        'humanSide': config.humanSide,
        'fens': fens,
        'moves': moves,
        'sans': sans,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  static SavedGame? fromJson(Map<String, dynamic> json) {
    try {
      final fens = (json['fens'] as List).cast<String>();
      final moves = (json['moves'] as List).cast<int>();
      final sans = (json['sans'] as List).cast<String>();
      final mode = GameMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => GameMode.ai,
      );
      final difficulty = Difficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => Difficulty.casual,
      );
      final humanSide = (json['humanSide'] as int?) ?? white;
      return SavedGame(
        config: GameConfig(
          mode: mode,
          difficulty: difficulty,
          humanSide: humanSide,
        ),
        fens: fens,
        moves: moves,
        sans: sans,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['savedAt'] as int?) ?? 0,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class GameStorage {
  static const _gameKey = 'yijing.saved_game.v1';
  static const _soundKey = 'yijing.sound.v1';
  static const _localModelKey = 'yijing.local_model.v1';

  static Future<SavedGame?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_gameKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final game = SavedGame.fromJson(decoded);
      if (game == null) return null;
      if (game.fens.length < 2 || game.fens.length != game.moves.length + 1) {
        return null;
      }
      // Validate every position so a corrupted save cannot break the app.
      for (final fen in game.fens) {
        Position.fromFen(fen);
      }
      final position = Position.fromFen(game.fens.last);
      if (position.computeStatus().isOver) return null;
      return game;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveGame(SavedGame game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gameKey, jsonEncode(game.toJson()));
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  static Future<void> clearGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gameKey);
    } catch (_) {}
  }

  static Future<bool> loadSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_soundKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveSound(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundKey, enabled);
    } catch (_) {}
  }

  static Future<bool> loadLocalModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_localModelKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveLocalModel(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localModelKey, enabled);
    } catch (_) {}
  }
}
