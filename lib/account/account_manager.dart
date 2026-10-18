import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_api.dart';
import 'account_models.dart';
import 'biometric_service.dart';

/// Owns the signed-in account, the optional biometric quick-login record, and
/// persists them between launches.
class AccountManager extends ChangeNotifier {
  AccountManager._();

  static final AccountManager instance = AccountManager._();
  static const _storageKey = 'yijing.account.v1';
  static const _biometricKey = 'yijing.account.biometric.v1';
  static const _biometricUserKey = 'yijing.account.biometric_user.v1';

  AccountUser? _user;
  AccountUser? _biometricUser;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _locked = false;
  bool _loading = false;
  String? _error;

  AccountUser? get user => _user;
  AccountUser? get biometricUser => _biometricUser;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  String? get error => _error;
  String get displayName => _user?.nick ?? '游客';
  String? get token => _user?.token;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;
  bool get hasBiometricLogin =>
      _biometricEnabled && _biometricUser != null;
  bool get locked => _locked;

  Future<void> loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_biometricKey) ?? false;
      final bioRaw = prefs.getString(_biometricUserKey);
      AccountUser? bioUser;
      if (bioRaw != null) {
        final decoded = jsonDecode(bioRaw);
        if (decoded is Map<String, dynamic>) {
          bioUser = AccountUser.fromJson(decoded);
        }
      }
      _biometricEnabled = enabled && bioUser != null;
      _biometricUser = _biometricEnabled ? bioUser : null;

      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _user = AccountUser.fromJson(decoded);
        }
      }
      _biometricAvailable = await BiometricService.isAvailable();
      _locked = _user != null && _biometricEnabled;
      notifyListeners();
      if (_user != null) unawaited(refresh());
    } catch (_) {}
  }

  Future<void> refresh() async {
    final current = _user;
    if (current == null) return;
    try {
      final fresh = await AccountApi.validate(current.token);
      _user = fresh;
      _error = null;
      await _persistActive(fresh);
      if (_biometricEnabled) {
        _biometricUser = fresh;
        await _persistBiometric(fresh);
      }
      notifyListeners();
    } on AccountException catch (error) {
      if (error.statusCode == 401) {
        await logout();
      } else {
        _error = error.message;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<AccountUser> login({
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final user = await AccountApi.login(phone: phone, password: password);
      _user = user;
      _locked = false;
      _error = null;
      await _persistActive(user);
      if (_biometricEnabled) {
        _biometricUser = user;
        await _persistBiometric(user);
      }
      notifyListeners();
      return user;
    } finally {
      _setLoading(false);
    }
  }

  Future<AccountUser> register({
    required String phone,
    required String password,
    required String nick,
  }) async {
    _setLoading(true);
    try {
      final user = await AccountApi.register(
        phone: phone,
        password: password,
        nick: nick,
      );
      _user = user;
      _locked = false;
      _error = null;
      await _persistActive(user);
      if (_biometricEnabled) {
        _biometricUser = user;
        await _persistBiometric(user);
      }
      notifyListeners();
      return user;
    } finally {
      _setLoading(false);
    }
  }

  Future<AccountUser> updateNick(String nick) async {
    final current = _user;
    if (current == null) {
      throw const AccountException('请先登录账号');
    }
    final updated = await AccountApi.setNick(token: current.token, nick: nick);
    _user = updated;
    await _persistActive(updated);
    if (_biometricEnabled) {
      _biometricUser = updated;
      await _persistBiometric(updated);
    }
    notifyListeners();
    return updated;
  }

  Future<void> applyRating(int rating) async {
    final current = _user;
    if (current == null || current.rating == rating) return;
    _user = current.copyWith(rating: rating);
    await _persistActive(_user!);
    if (_biometricEnabled) {
      _biometricUser = _user;
      await _persistBiometric(_user!);
    }
    notifyListeners();
  }

  /// Turns on Touch ID / Face ID / fingerprint quick login for the current
  /// account. The user must pass a biometric check first.
  Future<bool> enableBiometric() async {
    final current = _user;
    if (current == null) {
      _error = '请先登录账号';
      notifyListeners();
      return false;
    }
    _biometricAvailable =
        await BiometricService.isAvailable(refresh: true);
    if (!_biometricAvailable) {
      _error = '当前设备不支持指纹或未录入指纹';
      notifyListeners();
      return false;
    }
    final ok = await BiometricService.authenticate(
      reason: '开启指纹一键登录弈境棋牌',
    );
    if (!ok) {
      _error = '未通过指纹验证';
      notifyListeners();
      return false;
    }
    _biometricEnabled = true;
    _biometricUser = current;
    _error = null;
    await _persistBiometric(current);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricKey, true);
    } catch (_) {}
    notifyListeners();
    return true;
  }

  Future<void> disableBiometric() async {
    _biometricEnabled = false;
    _biometricUser = null;
    _locked = false;
    await _removeBiometric();
    notifyListeners();
  }

  /// Binds the current account to biometric login after the caller has
  /// already completed a successful biometric verification.
  Future<void> bindBiometricAfterAuthentication() async {
    final current = _user;
    if (current == null) return;
    _biometricEnabled = true;
    _biometricUser = current;
    _error = null;
    await _persistBiometric(current);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricKey, true);
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> biometricLogin() async {
    final saved = _biometricUser;
    if (saved == null || !_biometricEnabled) return false;
    _biometricAvailable =
        await BiometricService.isAvailable(refresh: true);
    if (!_biometricAvailable) {
      _error = '指纹不可用，请使用密码登录';
      notifyListeners();
      return false;
    }
    final ok = await BiometricService.authenticate(
      reason: '指纹一键登录弈境棋牌',
    );
    if (!ok) {
      _error = '未通过指纹验证';
      notifyListeners();
      return false;
    }
    try {
      final fresh = await AccountApi.validate(saved.token);
      _user = fresh;
      _locked = false;
      _error = null;
      await _persistActive(fresh);
      _biometricUser = fresh;
      await _persistBiometric(fresh);
      notifyListeners();
      return true;
    } on AccountException catch (error) {
      if (error.statusCode == 401) {
        _error = '登录已过期，请使用密码登录';
        _biometricEnabled = false;
        _biometricUser = null;
        await _removeBiometric();
        notifyListeners();
        return false;
      }
      // Network problem: keep the cached account so the user can still enter;
      // online requests will simply retry later.
      _user = saved;
      _locked = false;
      _error = null;
      await _persistActive(saved);
      notifyListeners();
      return true;
    } catch (_) {
      _user = saved;
      _locked = false;
      _error = null;
      await _persistActive(saved);
      notifyListeners();
      return true;
    }
  }

  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// Logging out ends the active session. The biometric record is kept unless
  /// [keepBiometric] is false, so the login screen can offer one-tap return.
  Future<void> logout({bool keepBiometric = true}) async {
    _user = null;
    _error = null;
    _locked = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      if (!keepBiometric) {
        _biometricEnabled = false;
        _biometricUser = null;
        await prefs.remove(_biometricKey);
        await prefs.remove(_biometricUserKey);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persistActive(AccountUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> _persistBiometric(AccountUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_biometricUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> _removeBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricKey);
      await prefs.remove(_biometricUserKey);
    } catch (_) {}
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
