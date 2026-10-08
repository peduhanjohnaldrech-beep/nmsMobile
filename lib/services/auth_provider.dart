import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool       _loading = false;
  String?    _error;

  UserModel? get user      => _user;
  bool       get loading   => _loading;
  String?    get error     => _error;
  bool       get isLoggedIn => _user != null;

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _api     = ApiService();

  // -------------------------------------------------------
  // AUTO LOGIN
  // -------------------------------------------------------

  /// Called on app start — loads persisted token + user, then verifies with server.
  Future<bool> tryAutoLogin() async {
    try {
      final results = await Future.wait([
        _storage.read(key: AppConfig.tokenKey),
        _storage.read(key: AppConfig.userKey),
      ]).timeout(const Duration(seconds: 5));

      final token    = results[0];
      final userJson = results[1];

      if (token == null || userJson == null) return false;

      // Load cached user first so UI can proceed if offline
      _user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);

      // Verify token is still valid on server
      try {
        final me = await _api.getMe().timeout(const Duration(seconds: 8));
        if (me['success'] == true) {
          // Refresh user data from server
          final userData = me['data'] as Map<String, dynamic>;
          _user = UserModel.fromJson(userData);
          await _storage.write(key: AppConfig.userKey, value: jsonEncode(_user!.toJson()));
        } else {
          // Token rejected by server — clear and force re-login
          await _storage.delete(key: AppConfig.tokenKey);
          await _storage.delete(key: AppConfig.userKey);
          await _api.clearToken();
          _user = null;
          return false;
        }
      } catch (_) {
        // Network error / offline — proceed with cached user
      }

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------
  // LOGIN
  // -------------------------------------------------------

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final result = await _api.login(username, password, AppConfig.appName);

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        await _api.setToken(data['token'] as String);
        _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await _storage.write(key: AppConfig.userKey, value: jsonEncode(_user!.toJson()));
        // Save hashed credentials for offline login
        final hash = sha256.convert(utf8.encode(password)).toString();
        await _storage.write(
          key:   AppConfig.offlineCredsKey,
          value: jsonEncode({'username': username, 'hash': hash}),
        );
        _loading = false;
        _error   = null;
        notifyListeners();
        return true;
      } else {
        _error   = result['message'] as String? ?? 'Login failed';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // No internet — try offline login with cached credentials
      return await _tryOfflineLogin(username, password);
    }
  }

  Future<bool> _tryOfflineLogin(String username, String password) async {
    try {
      final credsJson = await _storage.read(key: AppConfig.offlineCredsKey);
      final userJson  = await _storage.read(key: AppConfig.userKey);
      if (credsJson == null || userJson == null) {
        _error   = 'No internet connection. Please connect to log in for the first time.';
        _loading = false;
        notifyListeners();
        return false;
      }
      final creds = jsonDecode(credsJson) as Map<String, dynamic>;
      final hash  = sha256.convert(utf8.encode(password)).toString();
      if (creds['username'] == username && creds['hash'] == hash) {
        _user    = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        _loading = false;
        _error   = null;
        notifyListeners();
        return true;
      }
      _error   = 'Incorrect username or password.';
      _loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error   = 'Cannot connect to server. Please check your internet connection.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // -------------------------------------------------------
  // LOGOUT
  // -------------------------------------------------------

  Future<void> logout() async {
    await _api.logout();
    await _storage.delete(key: AppConfig.userKey);
    // Keep offlineCredsKey and tokenKey so user can log back in without internet
    _user  = null;
    _error = null;
    notifyListeners();
  }

  // -------------------------------------------------------
  // CLEAR ERROR
  // -------------------------------------------------------

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
