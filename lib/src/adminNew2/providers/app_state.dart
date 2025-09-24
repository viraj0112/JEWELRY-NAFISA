import 'package:flutter/material.dart';

class AppState with ChangeNotifier {
  String _activeView = 'dashboard';
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();
  final List<String> _activeFilters = [];

  String get activeView => _activeView;
  DateTime get selectedStartDate => _selectedStartDate;
  DateTime get selectedEndDate => _selectedEndDate;
  List<String> get activeFilters => _activeFilters;

  void setActiveView(String view) {
    _activeView = view;
    notifyListeners();
  }
  
  void setDateRange(DateTime start, DateTime end, String s) {
    _selectedStartDate = start;
    _selectedEndDate = end;
    notifyListeners();
  }

  void addFilter(String filter) {
    if (!_activeFilters.contains(filter)) {
      _activeFilters.add(filter);
      notifyListeners();
    }
  }

  void removeFilter(String filter) {
    _activeFilters.remove(filter);
    notifyListeners();
  }
  
  void clearFilters() {
    _activeFilters.clear();
    notifyListeners();
  }
}