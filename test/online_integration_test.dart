import 'dart:io';
import 'dart:async';

import 'package:chess_app/account/account_api.dart';
import 'package:chess_app/games/impl/gomoku_game.dart';
import 'package:chess_app/online/online_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enabled = Platform.environment['YIJING_ONLINE_TEST'] == '1';

  test('account register/login/token', () async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final phone = '19${suffix.substring(suffix.length - 9)}';
    final account = await AccountApi.register(
      phone: phone,
      password: 'test123456',
      nick: '集成测试${suffix.substring(suffix.length - 4)}',
    );
    expect(account.uid, isNotEmpty);
    expect(account.rating, greaterThanOrEqualTo(100));

    final login = await AccountApi.login(phone: phone, password: 'test123456');
    expect(login.uid, account.uid);
    final validated = await AccountApi.validate(login.token);
    expect(validated.uid, account.uid);
    final renamed = await AccountApi.setNick(
      token: login.token,
      nick: '改名${suffix.substring(suffix.length - 4)}',
    );
    expect(renamed.nick, startsWith('改名'));
  }, skip: !enabled);

  test('two online sessions match and relay a move', () async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final a = await AccountApi.register(
      phone: '18${suffix.substring(suffix.length - 9)}',
      password: 'test123456',
      nick: '联机甲${suffix.substring(suffix.length - 3)}',
    );
    final b = await AccountApi.register(
      phone: '17${suffix.substring(suffix.length - 9)}',
      password: 'test123456',
      nick: '联机乙${suffix.substring(suffix.length - 3)}',
    );

    final sessionA = OnlineSession(
      game: 'chess',
      playerName: a.nick,
      token: a.token,
    );
    final sessionB = OnlineSession(
      game: 'chess',
      playerName: b.nick,
      token: b.token,
    );
    final matchedA = Completer<int>();
    final matchedB = Completer<int>();
    final receivedB = Completer<Map<String, dynamic>>();
    sessionA.onRemoteMove = (payload) {};
    sessionB.onRemoteMove = (payload) {
      if (!receivedB.isCompleted) receivedB.complete(payload);
    };
    sessionA.addListener(() {
      if (sessionA.isMatched && !matchedA.isCompleted) {
        matchedA.complete(sessionA.mySide ?? 0);
      }
    });
    sessionB.addListener(() {
      if (sessionB.isMatched && !matchedB.isCompleted) {
        matchedB.complete(sessionB.mySide ?? 0);
      }
    });

    await sessionA.findMatch(allowBot: false);
    await sessionB.findMatch(allowBot: false);
    await matchedA.future.timeout(const Duration(seconds: 8));
    await matchedB.future.timeout(const Duration(seconds: 8));
    expect(sessionA.isMatched, isTrue);
    expect(sessionB.isMatched, isTrue);
    expect(sessionA.opponent?.name, b.nick);
    expect(sessionB.opponent?.name, a.nick);

    sessionA.sendMove({'move': 264143});
    final payload = await receivedB.future.timeout(const Duration(seconds: 5));
    expect(payload['move'], 264143);

    sessionA.dispose();
    sessionB.dispose();
  }, skip: !enabled);

  test('gomoku state is relayed between two online sessions', () async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final a = await AccountApi.register(
      phone: '16${suffix.substring(suffix.length - 9)}',
      password: 'test123456',
      nick: '棋甲${suffix.substring(suffix.length - 3)}',
    );
    final b = await AccountApi.register(
      phone: '15${suffix.substring(suffix.length - 9)}',
      password: 'test123456',
      nick: '棋乙${suffix.substring(suffix.length - 3)}',
    );
    final sessionA = OnlineSession(
      game: 'gomoku',
      playerName: a.nick,
      token: a.token,
    );
    final sessionB = OnlineSession(
      game: 'gomoku',
      playerName: b.nick,
      token: b.token,
    );
    final received = Completer<Map<String, dynamic>>();
    sessionB.onRemoteMove = (payload) {
      if (!received.isCompleted) received.complete(payload);
    };
    final matchedA = Completer<void>();
    final matchedB = Completer<void>();
    sessionA.addListener(() {
      if (sessionA.isMatched && !matchedA.isCompleted) matchedA.complete();
    });
    sessionB.addListener(() {
      if (sessionB.isMatched && !matchedB.isCompleted) matchedB.complete();
    });
    await sessionA.findMatch(allowBot: false);
    await sessionB.findMatch(allowBot: false);
    await matchedA.future.timeout(const Duration(seconds: 8));
    await matchedB.future.timeout(const Duration(seconds: 8));

    final game = GomokuGame()..apply(112);
    sessionA.sendMove({'state': game.toJson()});
    final payload = await received.future.timeout(const Duration(seconds: 5));
    final loaded = GomokuGame()
      ..loadJson(Map<String, Object?>.from(payload['state'] as Map));
    expect(loaded.board[112], 1);
    expect(loaded.side, 1);

    sessionA.dispose();
    sessionB.dispose();
  }, skip: !enabled);
}
