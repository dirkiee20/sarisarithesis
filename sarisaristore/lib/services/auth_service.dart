import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local auth state for the SaaS app.
/// Stores JWT tokens and user/tenant info in SharedPreferences.
class AuthService extends ChangeNotifier {
  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyUserRole = 'auth_user_role';
  static const _keyTenantId = 'auth_tenant_id';
  static const _keyTenantName = 'auth_tenant_name';
  static const _keyOnboarded = 'auth_onboarded';

  String? _token;
  String? _refreshToken;
  String? _userName;
  String? _userEmail;
  String? _userRole;
  String? _tenantId;
  String? _tenantName;
  bool _onboarded = false;
  bool _initialized = false;

  // ─── Getters ─────────────────────────────────
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isOnboarded => _onboarded;
  bool get initialized => _initialized;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole;
  String? get tenantId => _tenantId;
  String? get tenantName => _tenantName;

  // ─── Initialization ───────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _refreshToken = prefs.getString(_keyRefreshToken);
    _userName = prefs.getString(_keyUserName);
    _userEmail = prefs.getString(_keyUserEmail);
    _userRole = prefs.getString(_keyUserRole);
    _tenantId = prefs.getString(_keyTenantId);
    _tenantName = prefs.getString(_keyTenantName);
    _onboarded = prefs.getBool(_keyOnboarded) ?? false;
    _initialized = true;
    notifyListeners();
  }

  // ─── Save session after login/register ────────
  Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String userName,
    required String userEmail,
    required String userRole,
    required String tenantId,
    required String tenantName,
  }) async {
    _token = token;
    _refreshToken = refreshToken;
    _userName = userName;
    _userEmail = userEmail;
    _userRole = userRole;
    _tenantId = tenantId;
    _tenantName = tenantName;
    _onboarded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyUserEmail, userEmail);
    await prefs.setString(_keyUserRole, userRole);
    await prefs.setString(_keyTenantId, tenantId);
    await prefs.setString(_keyTenantName, tenantName);
    await prefs.setBool(_keyOnboarded, true);

    notifyListeners();
  }

  // ─── Logout ───────────────────────────────────
  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    _userName = null;
    _userEmail = null;
    _userRole = null;
    _tenantId = null;
    _tenantName = null;
    _onboarded = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyTenantId);
    await prefs.remove(_keyTenantName);
    await prefs.setBool(_keyOnboarded, false);

    notifyListeners();
  }

  // ─── Update token (on refresh) ────────────────
  Future<void> updateToken(String newToken) async {
    _token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, newToken);
    notifyListeners();
  }
}
