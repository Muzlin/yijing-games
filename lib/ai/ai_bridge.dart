import 'dart:convert';

import 'package:http/http.dart' as http;

import '../online/config.dart';

class AiMoveOption {
  final String id;
  final String label;

  const AiMoveOption({required this.id, required this.label});
}

/// Client for the optional local-model bridge (Ollama).
///
/// The bridge only picks from the legal moves supplied by the rules engine, so
/// a weak or malformed model response can never create an illegal position.
class AiBridge {
  static bool enabled = true;
  static bool available = false;
  static String? model;
  static DateTime? lastCheck;

  static Future<bool> check({bool force = false}) async {
    if (!enabled) {
      available = false;
      return false;
    }
    if (!force &&
        lastCheck != null &&
        DateTime.now().difference(lastCheck!) < const Duration(seconds: 20)) {
      return available;
    }
    lastCheck = DateTime.now();
    try {
      final response = await http
          .get(Uri.parse('${OnlineConfig.aiBridgeUrl}/ai/health'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        available = false;
        return false;
      }
      final data = jsonDecode(response.body);
      available = data is Map && data['ok'] == true;
      if (data is Map && data['model'] is String) {
        model = data['model'] as String;
      }
      return available;
    } catch (_) {
      available = false;
      return false;
    }
  }

  static void resetAvailability() {
    lastCheck = null;
    available = false;
  }

  static Future<String?> chooseMove({
    required String game,
    required String state,
    required List<AiMoveOption> moves,
    required int player,
    required int level,
  }) async {
    if (!enabled || moves.isEmpty) return null;
    if (!available && !await check()) return null;
    try {
      final response = await http
          .post(
            Uri.parse('${OnlineConfig.aiBridgeUrl}/ai/move'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'game': game,
              'state': state,
              'player': player,
              'level': level,
              'model': OnlineConfig.aiModel,
              'legalMoves': [
                for (final move in moves) {'id': move.id, 'label': move.label},
              ],
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final move = data['move'];
      if (move is! Map) return null;
      final id = move['id']?.toString();
      if (id == null) return null;
      for (final option in moves) {
        if (option.id == id) return id;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
