import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';

class FilterStateNotifier extends ChangeNotifier {
  FilterState _filterState = FilterState.defaultFilters();

  FilterState get value => _filterState;

  set value(FilterState newState) {
    if (_filterState != newState) {
      _filterState = newState;
      notifyListeners();
    }
  }
}
