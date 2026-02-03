import 'package:flutter/material.dart';

class FilterCriteria {
  String? location;
  DateTimeRange? dateRange;
  
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
           productType == null && 
           category == null && 
           metalType == null && 
           demandLevel == null &&
           category1 == null &&
           category2 == null &&
           category3 == null;
  }
}
