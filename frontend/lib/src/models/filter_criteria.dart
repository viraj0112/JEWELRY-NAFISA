import 'package:flutter/material.dart';

class FilterCriteria {
  String? location;
  DateTimeRange? dateRange;

  // Free-text search: matches SKU, product title, product type and category.
  String? searchText;

  // Advanced Filters (Single selection for simplicity based on chips in image,
  // but could be Set<String> if multi-select needed. 'ChoiceChip' implies single)
  String? productType;
  String? category;
  String? metalType;
  String? demandLevel;

  // Category Sub-filters
  String? category1;
  String? category2;
  String? category3;

  FilterCriteria({
    this.location,
    this.dateRange,
    this.searchText,
    this.productType,
    this.category,
    this.metalType,
    this.demandLevel,
    this.category1,
    this.category2,
    this.category3,
  });

  bool get isEmpty {
    return location == null &&
        dateRange == null &&
        (searchText == null || searchText!.trim().isEmpty) &&
        productType == null &&
        category == null &&
        metalType == null &&
        demandLevel == null &&
        category1 == null &&
        category2 == null &&
        category3 == null;
  }

  /// A copy with the given fields replaced. Pass [clearDateRange] to remove
  /// the date range (a null [dateRange] means "keep the current one").
  FilterCriteria copyWith({
    String? location,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? searchText,
    bool clearSearchText = false,
    String? productType,
    String? category,
    String? metalType,
    String? demandLevel,
    String? category1,
    String? category2,
    String? category3,
  }) =>
      FilterCriteria(
        location: location ?? this.location,
        dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
        searchText: clearSearchText ? null : (searchText ?? this.searchText),
        productType: productType ?? this.productType,
        category: category ?? this.category,
        metalType: metalType ?? this.metalType,
        demandLevel: demandLevel ?? this.demandLevel,
        category1: category1 ?? this.category1,
        category2: category2 ?? this.category2,
        category3: category3 ?? this.category3,
      );

  /// Start of the range's first day (local time), or null without a range.
  DateTime? get rangeStart => dateRange == null
      ? null
      : DateTime(dateRange!.start.year, dateRange!.start.month,
          dateRange!.start.day);

  /// Start of the day AFTER the range's last day. The date picker returns the
  /// end day at midnight, so comparing against it directly would drop
  /// everything created during the last day.
  DateTime? get rangeEndExclusive => dateRange == null
      ? null
      : DateTime(dateRange!.end.year, dateRange!.end.month, dateRange!.end.day)
          .add(const Duration(days: 1));

  /// Whether [moment] falls inside the date range (always true without one).
  /// An unknown date can't be shown to match, so it is excluded.
  bool includesDate(DateTime? moment) {
    if (dateRange == null) return true;
    if (moment == null) return false;
    final local = moment.toLocal();
    return !local.isBefore(rangeStart!) && local.isBefore(rangeEndExclusive!);
  }
}
