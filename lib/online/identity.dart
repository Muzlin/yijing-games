import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A friendly, persistent nickname used when matching with other players.
class OnlineIdentity {
  static const _key = 'yijing.online.name.v1';

  static const List<String> _prefixes = [
    '清风',
    '明月',
    '长安',
    '听雨',
    '松下',
    '江畔',
    '云间',
    '竹影',
    '闲云',
    '孤舟',
    '北窗',
    '南山',
    '半山',
    '落子',
    '手谈',
    '一局',
  ];

  static const List<String> _suffixes = [
    '棋客',
    '少年',
    '老友',
    '小卒',
    '观棋',
    '半子',
    '棋友',
    '同学',
    '先生',
    '姑娘',
  ];

  static Future<String> loadOrCreate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_key);
      if (existing != null && existing.trim().isNotEmpty) return existing;
      final generated = _generate();
      await prefs.setString(_key, generated);
      return generated;
    } catch (_) {
      return _generate();
    }
  }

  static Future<void> save(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, name.trim().isEmpty ? _generate() : name.trim());
    } catch (_) {}
  }

  static String _generate() {
    final random = Random();
    final prefix = _prefixes[random.nextInt(_prefixes.length)];
    final suffix = _suffixes[random.nextInt(_suffixes.length)];
    final number = 10 + random.nextInt(90);
    return '$prefix$suffix$number';
  }
}
