import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/idea.dart';

class IdeasProvider extends ChangeNotifier {
  static const String _baseUrl =
      'https://lab6-c6647-default-rtdb.firebaseio.com/';

  final List<Idea> _ideas = [];
  String? _authToken;
  String? _authUserId;

  bool _isLoading = false;
  bool _didInit = false;

  List<Idea> get ideas => List.unmodifiable(_ideas);
  bool get isLoading => _isLoading;

  String get _cacheKey => _authUserId == null
      ? 'ideas_cache'
      : 'ideas_cache_${_authUserId!}';

  void updateAuth({
    required String? token,
    required String? userId,
  }) {
    final tokenChanged = _authToken != token;
    final userChanged = _authUserId != userId;

    _authToken = token;
    _authUserId = userId;

    if (token == null || userId == null) {
      _ideas.clear();
      _didInit = false;
      notifyListeners();
      return;
    }

    if (tokenChanged || userChanged) {
      _ideas.clear();
      _didInit = false;
      notifyListeners();
    }
  }

  void _ensureAuthenticated() {
    if (_authToken == null || _authUserId == null) {
      throw Exception('You must be logged in to perform this action.');
    }
  }

  Uri _ideasUri({String? ideaId}) {
    _ensureAuthenticated();

    final path = ideaId == null ? '/ideas.json' : '/ideas/$ideaId.json';
    final base = Uri.parse('$_baseUrl$path');
    return base.replace(queryParameters: {'auth': _authToken!});
  }

  String _responseSnippet(String body) {
    if (body.length <= 200) {
      return body;
    }
    return '${body.substring(0, 200)}...';
  }

  Future<void> initialize() async {
    _ensureAuthenticated();

    if (_didInit) {
      return;
    }

    _didInit = true;
    await loadFromCache();
    try {
      await fetchIdeas();
    } catch (_) {
      // Keep cached data visible if remote fetch fails on startup.
    }
  }

  Future<void> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);

    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return;
    }

    _ideas
      ..clear()
      ..addAll(
        decoded
            .whereType<Map>()
            .map((item) => Idea.fromCacheMap(Map<String, dynamic>.from(item))),
      );

    notifyListeners();
  }

  Future<void> fetchIdeas() async {
    _ensureAuthenticated();

    _isLoading = true;
    notifyListeners();

    try {
      final uri = _ideasUri();
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 400) {
        throw Exception(
          'Fetch failed (${response.statusCode}). Response: '
          '${_responseSnippet(response.body)}',
        );
      }

      final decoded = jsonDecode(response.body);
      final List<Idea> loadedIdeas = [];

      if (decoded is Map) {
        decoded.forEach((id, value) {
          if (value is Map<String, dynamic>) {
            loadedIdeas.add(Idea.fromFirebase(id.toString(), value));
            return;
          }

          if (value is Map) {
            loadedIdeas.add(
              Idea.fromFirebase(id.toString(), Map<String, dynamic>.from(value)),
            );
          }
        });
      }

      _ideas
        ..clear()
        ..addAll(loadedIdeas.reversed);

      await _saveCache();
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Server communication failed while fetching ideas.');
    } on FormatException {
      throw Exception('Invalid data received from server.');
    } on TimeoutException {
      throw Exception('Request timed out while fetching ideas.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addIdea({
    required String title,
    required String description,
  }) async {
    _ensureAuthenticated();

    final uri = _ideasUri();
    final response = await http
        .post(
      uri,
      body: jsonEncode(
        {
          'title': title,
          'description': description,
          'userId': _authUserId,
        },
      ),
    )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception(
        'Add failed (${response.statusCode}). Response: '
        '${_responseSnippet(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['name'] == null) {
      throw Exception('Invalid server response while creating idea.');
    }

    final newIdea = Idea(
      id: decoded['name'].toString(),
      title: title,
      description: description,
      userId: _authUserId!,
    );

    _ideas.insert(0, newIdea);
    notifyListeners();
    await _saveCache();
  }

  Future<void> deleteIdea(String id) async {
    final uri = _ideasUri(ideaId: id);
    final response =
        await http.delete(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception(
        'Delete failed (${response.statusCode}). Response: '
        '${_responseSnippet(response.body)}',
      );
    }

    _ideas.removeWhere((idea) => idea.id == id);
    notifyListeners();
    await _saveCache();
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_ideas.map((idea) => idea.toCacheMap()).toList());
    await prefs.setString(_cacheKey, encoded);
  }
}
