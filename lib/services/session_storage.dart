import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SavedSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<Map<String, dynamic>> products;

  SavedSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.products,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'status': status,
    'products': products,
  };

  factory SavedSession.fromJson(Map<String, dynamic> json) => SavedSession(
    id: json['id'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
    status: json['status'] as String,
    products: (json['products'] as List).cast<Map<String, dynamic>>(),
  );
}

class SessionStorage extends ChangeNotifier {
  static const _fileName = 'recount_sessions.json';
  List<SavedSession> _allSessions = [];
  String? _currentSessionId;

  List<SavedSession> get allSessions => List.unmodifiable(_allSessions);
  List<SavedSession> get pastSessions => _allSessions.where((s) => s.status == 'completed').toList();
  SavedSession? get currentSession {
    try {
      return _allSessions.firstWhere((s) => s.id == _currentSessionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        _currentSessionId = data['currentSessionId'] as String?;
        final sessions = (data['sessions'] as List?) ?? [];
        _allSessions = sessions.map((s) => SavedSession.fromJson(s as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('SessionStorage load error: $e');
    }
  }

  Future<void> _save() async {
    final file = await _getFile();
    final tempFile = File('${file.path}.tmp');
    final data = {
      'currentSessionId': _currentSessionId,
      'sessions': _allSessions.map((s) => s.toJson()).toList(),
    };
    await tempFile.writeAsString(json.encode(data));
    await tempFile.rename(file.path);
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<String> startNewSession() async {
    final id = 'SESSION_${DateTime.now().millisecondsSinceEpoch}';
    final session = SavedSession(
      id: id,
      startTime: DateTime.now(),
      status: 'active',
      products: [],
    );
    _allSessions.add(session);
    _currentSessionId = id;
    await _save();
    notifyListeners();
    return id;
  }

  Future<void> saveProducts(String sessionId, List<Map<String, dynamic>> products) async {
    final idx = _allSessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      _allSessions[idx] = SavedSession(
        id: _allSessions[idx].id,
        startTime: _allSessions[idx].startTime,
        status: 'active',
        products: List.from(products),
      );
      _currentSessionId = sessionId;
      await _save();
      notifyListeners();
    }
  }

  Future<void> completeSession(String sessionId, {DateTime? endTime}) async {
    final idx = _allSessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      _allSessions[idx] = SavedSession(
        id: _allSessions[idx].id,
        startTime: _allSessions[idx].startTime,
        endTime: endTime ?? DateTime.now(),
        status: 'completed',
        products: _allSessions[idx].products,
      );
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
      }
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    _allSessions.removeWhere((s) => s.id == sessionId);
    if (_currentSessionId == sessionId) {
      _currentSessionId = null;
    }
    await _save();
    notifyListeners();
  }
}
