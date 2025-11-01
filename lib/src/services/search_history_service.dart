import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService with ChangeNotifier {
  late SharedPreferences _prefs;
  List<String> _recentSearches = [];
  static const _key = 'recent_searches';
  static const _maxHistoryLength = 10; 

  List<String> get recentSearches => _recentSearches;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _recentSearches = _prefs.getStringList(_key) ?? [];
    notifyListeners();
  }

  Future<void> addSearchTerm(String term) async {
    final sanitizedTerm = term.trim().toLowerCase();

    if (sanitizedTerm.isEmpty || sanitizedTerm.length < 2) return;
    _recentSearches.removeWhere((t) => t.toLowerCase() == sanitizedTerm);
    _recentSearches.insert(0, sanitizedTerm);
    if (_recentSearches.length > _maxHistoryLength) {
      _recentSearches = _recentSearches.sublist(0, _maxHistoryLength);
    }
    await _prefs.setStringList(_key, _recentSearches);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _recentSearches = [];
    await _prefs.remove(_key);
    notifyListeners();
  }
}