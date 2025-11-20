import 'package:flutter/widgets.dart';

enum AdminSize {
  compact,
  cozy,
  comfy,
  expanded,
  ultra,
}

extension AdminSizeX on AdminSize {
  bool get isCompact => this == AdminSize.compact;
  bool get isCozy => this == AdminSize.cozy;
  bool get isComfy => this == AdminSize.comfy;
  bool get isExpanded => this == AdminSize.expanded;
  bool get isUltra => this == AdminSize.ultra;
}

class AdminBreakpoints {
  const AdminBreakpoints._();

  static const double compactMax = 768;
  static const double cozyMax = 1100;
  static const double comfyMax = 1440;
  static const double expandedMax = 1920;

  static AdminSize ofWidth(double width) {
    if (width < compactMax) return AdminSize.compact;
    if (width < cozyMax) return AdminSize.cozy;
    if (width < comfyMax) return AdminSize.comfy;
    if (width < expandedMax) return AdminSize.expanded;
    return AdminSize.ultra;
  }

  static AdminSize of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);

  static EdgeInsets pagePadding(AdminSize size) {
    switch (size) {
      case AdminSize.compact:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
      case AdminSize.cozy:
        return const EdgeInsets.symmetric(horizontal: 18, vertical: 16);
      case AdminSize.comfy:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
      case AdminSize.expanded:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 24);
      case AdminSize.ultra:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
  }

  static int columnsForWidth(
    double width, {
    int min = 1,
    int max = 4,
    double idealItemWidth = 280,
  }) {
    final calculated = (width / idealItemWidth).floor();
    return calculated.clamp(min, max);
  }

  static int columnsForContext(
    BuildContext context, {
    int min = 1,
    int max = 4,
    double idealItemWidth = 280,
  }) {
    return columnsForWidth(
      MediaQuery.sizeOf(context).width,
      min: min,
      max: max,
      idealItemWidth: idealItemWidth,
    );
  }
}
