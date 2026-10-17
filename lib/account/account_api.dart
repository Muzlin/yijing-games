import 'dart:convert';

import 'package:http/http.dart' as http;

import '../online/config.dart';
import 'account_models.dart';

class AccountApi {
  static String get baseUrl => OnlineConfig.accountUrl;

  static Future<AccountUser> register({
    required String phone,
    required String password,
    required String nick,
  }) async {
    final data = await _post('/acc-register', {
      'u': phone,
      'p': password,
      'nick': nick,
    });
    return _user(data, token: data['token']?.toString());
  }

  static Future<AccountUser> login({
    required String phone,
    required String password,
  }) async {
    final data = await _post('/acc-login', {'u': phone, 'p': password});
    return _user(data, token: data['token']?.toString());
  }

  static Future<AccountUser> validate(String token) async {
    final data = await _post('/acc-token', {'tk': token});
    return _user(data, token: token);
  }

  static Future<AccountUser> setNick({
    required String token,
    required String nick,
  }) async {
    final data = await _post('/acc-set-nick', {'tk': token, 'nick': nick});
    return _user(data, token: data['token']?.toString() ?? token);
  }

  static AccountUser _user(Map<String, dynamic> data, {String? token}) {
    final uid = data['uid']?.toString();
    final nick = data['nick']?.toString();
    if (uid == null || nick == null || token == null || token.isEmpty) {
      throw const AccountException('账号服务返回的数据不完整');
    }
    return AccountUser(
      uid: uid,
      phone: data['phone']?.toString() ?? data['u']?.toString() ?? '',
      nick: nick,
      token: token,
      rating: (data['rating'] as num?)?.toInt() ?? 1200,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      draws: (data['draws'] as num?)?.toInt() ?? 0,
      created: (data['created'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const AccountException('无法连接账号服务器，请检查网络或服务器地址');
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException();
      }
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw AccountException(
        '账号服务异常（HTTP ${response.statusCode}）',
        response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['ok'] != true) {
      throw AccountException(
        data['error']?.toString() ?? '操作失败，请稍后再试',
        response.statusCode,
      );
    }
    return data;
  }
}
