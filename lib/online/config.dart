/// Public deployment settings.
///
/// Build with:
///   flutter build apk --dart-define=ONLINE_SERVER_URL=wss://your-host/ws \
///                     --dart-define=AI_BRIDGE_URL=https://your-host
class OnlineConfig {
  static const String serverUrl = String.fromEnvironment(
    'ONLINE_SERVER_URL',
    defaultValue: 'ws://127.0.0.1:8787/ws',
  );

  static const String aiBridgeUrl = String.fromEnvironment(
    'AI_BRIDGE_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  static const String aiModel = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'qwen2.5:1.5b',
  );

  /// Account API lives on the same host as the relay by default.
  static const String accountUrl = String.fromEnvironment(
    'ACCOUNT_SERVER_URL',
    defaultValue: aiBridgeUrl,
  );
}
