import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth so the rest of the app can treat biometrics
/// as unavailable on platforms without a plugin/hardware.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static bool? _available;

  static Future<bool> isAvailable({bool refresh = false}) async {
    if (!refresh && _available != null) return _available!;
    try {
      final supported = await _auth
          .isDeviceSupported()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      final canCheck = await _auth
          .canCheckBiometrics
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      _available = supported && canCheck;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  static Future<bool> authenticate({
    String reason = '验证指纹以登录弈境棋牌',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
