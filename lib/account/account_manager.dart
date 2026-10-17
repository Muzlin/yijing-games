import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_api.dart';
import 'account_models.dart';

/// Owns the signed-in account and persists it between launches.
class AccountManager extends ChangeNotifier {
  AccountManager._();

  static final AccountManager instance = AccountManager._();
  static const _storageKey = 'yijing.account.v1';

  AccountUser? _user;
  bool _loading = false;
  String? _error;

  AccountUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  String? get error => _error;
  String get displayName => _user?.nick ?? '游客';
  String? get token => _user?.token;

  Future<void> loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final user = AccountUser.fromJson(decoded);
      if (user != null) {
        _user = user;
        notifyListeners();
        unawaited(refresh());
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    final current = _user;
    if (current == null) return;
    try {
      final fresh = await AccountApi.validate(current.token);
      _user = fresh;
      _error = null;
      await _persist(fresh);
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
      _error = null;
      await _persist(user);
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
      _error = null;
      await _persist(user);
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
    await _persist(updated);
    notifyListeners();
    return updated;
  }

  Future<void> applyRating(int rating) async {
    final current = _user;
    if (current == null || current.rating == rating) return;
    _user = current.copyWith(rating: rating);
    await _persist(_user!);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist(AccountUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
