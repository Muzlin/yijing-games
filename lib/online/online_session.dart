import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

enum OnlinePhase { idle, connecting, queued, matched, error, closed }

class OnlineOpponent {
  final String name;
  final int rating;
  final bool isBot;
  final int botLevel;

  const OnlineOpponent({
    required this.name,
    required this.rating,
    this.isBot = false,
    this.botLevel = 1,
  });
}

/// A single matchmaking session.
///
/// The session owns the WebSocket and relays opaque move payloads between the
/// two clients. Game rules and legality checks stay on the clients.
class OnlineSession extends ChangeNotifier {
  OnlineSession({
    required this.game,
    required this.playerName,
    this.serverUrl = OnlineConfig.serverUrl,
    this.token,
  });

  final String game;
  final String playerName;
  final String serverUrl;
  final String? token;

  OnlinePhase phase = OnlinePhase.idle;
  String? error;
  String? roomId;
  int? mySide;
  OnlineOpponent? opponent;
  bool transportClosed = false;

  void Function(Map<String, dynamic> payload)? onRemoteMove;
  void Function()? onOpponentLeft;
  void Function()? onOpponentResigned;
  void Function()? onConnectionLost;
  void Function(int rating, int delta)? onRatingUpdate;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  bool _disposed = false;

  bool get isMatched => phase == OnlinePhase.matched && opponent != null;
  bool get isBot => opponent?.isBot ?? false;
  bool get isBusy => phase == OnlinePhase.connecting || phase == OnlinePhase.queued;

  Future<void> findMatch({bool allowBot = true}) async {
    if (phase == OnlinePhase.connecting || phase == OnlinePhase.queued) return;
    phase = OnlinePhase.connecting;
    error = null;
    _safeNotify();
    try {
      final base = Uri.parse(serverUrl);
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'game': game,
        'name': playerName,
        if (token != null && token!.isNotEmpty) 'token': token!,
      });
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 8));
      _subscription = channel.stream.listen(
        _onMessage,
        onError: _onTransportError,
        onDone: _onTransportDone,
        cancelOnError: false,
      );
      _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
        _send({'type': 'ping'});
      });
      _send({
        'type': 'queue',
        'game': game,
        'name': playerName,
        'allowBot': allowBot,
      });
      phase = OnlinePhase.queued;
      _safeNotify();
    } catch (e) {
      _fail(_friendlyError(e));
    }
  }

  void cancelMatch() {
    if (phase == OnlinePhase.queued || phase == OnlinePhase.connecting) {
      _send({'type': 'cancel'});
    }
    _closeTransport();
    phase = OnlinePhase.closed;
    _safeNotify();
  }

  void sendMove(Map<String, dynamic> payload) {
    if (!isMatched || isBot || transportClosed) return;
    _send({'type': 'move', 'payload': payload});
  }

  void sendResult(int winner) {
    if (!isMatched || isBot || transportClosed) return;
    _send({'type': 'result', 'winner': winner});
  }

  void resign() {
    if (!isMatched) return;
    if (!isBot && !transportClosed) {
      _send({'type': 'resign'});
    }
    _closeTransport();
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return;
      message = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    switch (message['type']) {
      case 'hello':
      case 'pong':
        break;
      case 'queued':
        phase = OnlinePhase.queued;
        _safeNotify();
        break;
      case 'matched':
        _handleMatched(message);
        break;
      case 'move':
        final payload = message['payload'];
        if (payload is Map) {
          onRemoteMove?.call(Map<String, dynamic>.from(payload));
        }
        break;
      case 'opponentLeft':
        onOpponentLeft?.call();
        _closeTransport();
        break;
      case 'opponentResigned':
        onOpponentResigned?.call();
        _closeTransport();
        break;
      case 'ratingUpdate':
        final rating = (message['rating'] as num?)?.toInt();
        if (rating != null) {
          onRatingUpdate?.call(
            rating,
            (message['delta'] as num?)?.toInt() ?? 0,
          );
        }
        break;
      case 'left':
        phase = OnlinePhase.closed;
        _safeNotify();
        break;
      case 'error':
        _fail(message['message']?.toString() ?? '服务器返回错误');
        break;
      default:
        break;
    }
  }

  void _handleMatched(Map<String, dynamic> message) {
    final rawOpponent = message['opponent'];
    final opponentMap =
        rawOpponent is Map ? Map<String, dynamic>.from(rawOpponent) : const {};
    final isBot = message['bot'] == true;
    mySide = (message['color'] as num?)?.toInt() ?? 0;
    roomId = message['roomId']?.toString();
    opponent = OnlineOpponent(
      name: opponentMap['name']?.toString() ?? '在线棋友',
      rating: (opponentMap['rating'] as num?)?.toInt() ?? 1200,
      isBot: isBot,
      botLevel: ((message['botLevel'] as num?)?.toInt() ?? 1).clamp(0, 3),
    );
    phase = OnlinePhase.matched;
    if (isBot) {
      // A bot match is played locally with the on-device AI. Keep the match
      // information (name, side) but free the socket.
      _closeTransport();
    }
    _safeNotify();
  }

  void _onTransportError(Object error) {
    if (_disposed) return;
    if (phase == OnlinePhase.matched) {
      onConnectionLost?.call();
    } else {
      _fail('网络连接失败，请检查服务器地址');
    }
  }

  void _onTransportDone() {
    if (_disposed) return;
    if (phase == OnlinePhase.matched) {
      onConnectionLost?.call();
    } else if (phase != OnlinePhase.closed) {
      _fail('与服务器的连接已断开');
    }
  }

  void _fail(String message) {
    error = message;
    phase = OnlinePhase.error;
    _safeNotify();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('TimeoutException')) return '连接服务器超时';
    if (text.contains('WebSocketException') ||
        text.contains('SocketException')) {
      return '无法连接联机服务器';
    }
    return '联机服务暂不可用';
  }

  void _send(Map<String, dynamic> message) {
    if (transportClosed) return;
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void _closeTransport() {
    transportClosed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeTransport();
    super.dispose();
  }
}
