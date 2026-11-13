import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firebase_auth_config.dart';

class AuthProvider extends ChangeNotifier {
  static const String _authDataKey = 'auth_data';
  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: firebaseWebApiKey,
    ),
  );

  String? _token;
  String? _userId;
  DateTime? _expiryDate;
  Timer? _authTimer;

  String? get token {
    if (_expiryDate != null &&
        _expiryDate!.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return null;
  }

  String? get userId => _userId;

  bool get isAuth => token != null;

  Future<void> signup({
    required String email,
    required String password,
  }) async {
    await _authenticate(
      email: email,
      password: password,
      segment: 'signUp',
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _authenticate(
      email: email,
      password: password,
      segment: 'signInWithPassword',
    );
  }

  Future<void> _authenticate({
    required String email,
    required String password,
    required String segment,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Missing Firebase API key. Set it in lib/config/firebase_auth_config.dart '
        'or pass one of these at run time:\n'
        '--dart-define=FIREBASE_WEB_API_KEY=YOUR_KEY\n'
        '--dart-define=FIREBASE_API_KEY=YOUR_KEY',
      );
    }

    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:$segment?key=$_apiKey',
    );

    final response = await http
        .post(
          uri,
          body: jsonEncode(
            {
              'email': email,
              'password': password,
              'returnSecureToken': true,
            },
          ),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(_firebaseAuthError(data));
    }

    if (data is! Map<String, dynamic> ||
        data['idToken'] == null ||
        data['localId'] == null ||
        data['expiresIn'] == null) {
      throw Exception('Invalid authentication response from server.');
    }

    _token = data['idToken'].toString();
    _userId = data['localId'].toString();
    _expiryDate = DateTime.now().add(
      Duration(seconds: int.tryParse(data['expiresIn'].toString()) ?? 3600),
    );

    _scheduleAutoLogout();
    notifyListeners();
    await _persistAuthData();
  }

  Future<bool> tryAutoLogin() async {
    if (isAuth) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authDataKey);

    if (raw == null || raw.isEmpty) {
      return false;
    }

    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      return false;
    }

    final expiryText = data['expiryDate']?.toString();
    final parsedExpiry =
        expiryText == null ? null : DateTime.tryParse(expiryText);

    if (parsedExpiry == null || parsedExpiry.isBefore(DateTime.now())) {
      return false;
    }

    _token = data['token']?.toString();
    _userId = data['userId']?.toString();
    _expiryDate = parsedExpiry;

    if (_token == null || _userId == null) {
      return false;
    }

    _scheduleAutoLogout();
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _expiryDate = null;

    _authTimer?.cancel();
    _authTimer = null;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authDataKey);
  }

  String _firebaseAuthError(dynamic data) {
    final dynamic errorData = data is Map<String, dynamic> ? data['error'] : null;
    final code = errorData is Map<String, dynamic>
      ? (errorData['message'] ?? '').toString()
      : '';

    switch (code) {
      case 'EMAIL_EXISTS':
        return 'This email is already in use.';
      case 'EMAIL_NOT_FOUND':
        return 'No user found with this email.';
      case 'INVALID_PASSWORD':
        return 'Invalid password.';
      case 'CONFIGURATION_NOT_FOUND':
        return 'Firebase Auth is not configured for this project. '
            'Enable Email/Password in Firebase Console > Authentication > Sign-in method.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email/Password sign-in is disabled for this project. '
            'Enable it in Firebase Console > Authentication > Sign-in method.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many attempts. Please try again later.';
      case 'USER_DISABLED':
        return 'This account has been disabled.';
      case 'INVALID_EMAIL':
        return 'Please enter a valid email address.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> _persistAuthData() async {
    if (_token == null || _userId == null || _expiryDate == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _authDataKey,
      jsonEncode(
        {
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate!.toIso8601String(),
        },
      ),
    );
  }

  void _scheduleAutoLogout() {
    _authTimer?.cancel();

    if (_expiryDate == null) {
      return;
    }

    final seconds = _expiryDate!.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) {
      unawaited(logout());
      return;
    }

    _authTimer = Timer(Duration(seconds: seconds), () {
      unawaited(logout());
    });
  }

  @override
  void dispose() {
    _authTimer?.cancel();
    super.dispose();
  }
}
