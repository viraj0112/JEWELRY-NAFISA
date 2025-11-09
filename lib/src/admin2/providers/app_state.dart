import "package:flutter/material.dart";

class AppState extends ChangeNotifier {
  String _activeView = 'dashboard';
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();
  String _selectedTimeRange = 'Last 30 Days';
  List<String> _activeFilters = [];
  
  // Theme mode
  ThemeMode _themeMode = ThemeMode.light;
  
  // Advanced filter panel state
  bool _isFilterPanelOpen = false;
  String? _selectedMetalType;
  String? _selectedMetalColor;
  String? _selectedStoneType;
  String? _selectedCategory;
  String? _selectedSubCategory;
  RangeValues _priceRange = const RangeValues(0, 100000);
  
  // Live data mode
  bool _isLiveDataEnabled = false;

  String get activeView => _activeView;
  DateTime get selectedStartDate => _selectedStartDate;
  DateTime get selectedEndDate => _selectedEndDate;
  String get selectedTimeRange => _selectedTimeRange;
  List<String> get activeFilters => _activeFilters;
  ThemeMode get themeMode => _themeMode;
  bool get isFilterPanelOpen => _isFilterPanelOpen;
  String? get selectedMetalType => _selectedMetalType;
  String? get selectedMetalColor => _selectedMetalColor;
  String? get selectedStoneType => _selectedStoneType;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubCategory => _selectedSubCategory;
  RangeValues get priceRange => _priceRange;
  bool get isLiveDataEnabled => _isLiveDataEnabled;

  void setActiveView(String view) {
    _activeView = view;
    notifyListeners();
  }

  void setDateRange(DateTime startDate, DateTime endDate, String timeRange) {
    _selectedStartDate = startDate;
    _selectedEndDate = endDate;
    _selectedTimeRange = timeRange;
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
  
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
  
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  
  void toggleFilterPanel() {
    _isFilterPanelOpen = !_isFilterPanelOpen;
    notifyListeners();
  }
  
  void setMetalType(String? value) {
    _selectedMetalType = value;
    notifyListeners();
  }
  
  void setMetalColor(String? value) {
    _selectedMetalColor = value;
    notifyListeners();
  }
  
  void setStoneType(String? value) {
    _selectedStoneType = value;
    notifyListeners();
  }
  
  void setCategory(String? value) {
    _selectedCategory = value;
    notifyListeners();
  }
  
  void setSubCategory(String? value) {
    _selectedSubCategory = value;
    notifyListeners();
  }
  
  void setPriceRange(RangeValues range) {
    _priceRange = range;
    notifyListeners();
  }
  
  void applyAdvancedFilters() {
    // Construct filter strings
    _activeFilters.clear();
    if (_selectedMetalType != null) {
      _activeFilters.add('Metal: $_selectedMetalType');
    }
    if (_selectedMetalColor != null) {
      _activeFilters.add('Color: $_selectedMetalColor');
    }
    if (_selectedStoneType != null) {
      _activeFilters.add('Stone: $_selectedStoneType');
    }
    if (_selectedCategory != null) {
      _activeFilters.add('Category: $_selectedCategory');
    }
    if (_selectedSubCategory != null) {
      _activeFilters.add('SubCategory: $_selectedSubCategory');
    }
    if (_priceRange.start > 0 || _priceRange.end < 100000) {
      _activeFilters.add('Price: \$${_priceRange.start.toInt()}-\$${_priceRange.end.toInt()}');
    }
    notifyListeners();
  }
  
  void resetAdvancedFilters() {
    _selectedMetalType = null;
    _selectedMetalColor = null;
    _selectedStoneType = null;
    _selectedCategory = null;
    _selectedSubCategory = null;
    _priceRange = const RangeValues(0, 100000);
    _activeFilters.clear();
    notifyListeners();
  }
  
  void toggleLiveData() {
    _isLiveDataEnabled = !_isLiveDataEnabled;
    notifyListeners();
  }
}