class ActivityLog {
  final String id;
  final DateTime timestamp;
  final String? userId;
  final String? adminId;
  final String? actionType;
  final String? details;
  final String? category;
  final String? severity;
  final String? ipAddress;
  final String? userAgent;
  final String? exportType;
  final String? format;
  final int? recordCount;
  final String? fileSize;
  final String? status;
  final String? logType;

  ActivityLog({
    required this.id,
    required this.timestamp,
    this.userId,
    this.adminId,
    this.actionType,
    this.details,
    this.category,
    this.severity,
    this.ipAddress,
    this.userAgent,
    this.exportType,
    this.format,
    this.recordCount,
    this.fileSize,
    this.status,
    this.logType,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'] ?? '',
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        userId: json['user_id'],
        adminId: json['admin_id'],
        actionType: json['action_type'],
        details: json['details'],
        category: json['category'],
        severity: json['severity'],
        ipAddress: json['ip_address'],
        userAgent: json['user_agent'],
        exportType: json['export_type'],
        format: json['format'],
        recordCount: json['record_count']?.toInt(),
        fileSize: json['file_size'],
        status: json['status'],
        logType: json['log_type'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'admin_id': adminId,
        'action_type': actionType,
        'details': details,
        'category': category,
        'severity': severity,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'export_type': exportType,
        'format': format,
        'record_count': recordCount,
        'file_size': fileSize,
        'status': status,
        'log_type': logType,
      };
}

class ActivitySummary {
  final int adminActions;
  final int userActivities;
  final int exportsGenerated;
  final double systemHealth;
  final int adminActionsToday;
  final int userActivitiesToday;
  final int exportsToday;

  ActivitySummary({
    required this.adminActions,
    required this.userActivities,
    required this.exportsGenerated,
    required this.systemHealth,
    required this.adminActionsToday,
    required this.userActivitiesToday,
    required this.exportsToday,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) => ActivitySummary(
        adminActions: json['admin_actions']?.toInt() ?? 0,
        userActivities: json['user_activities']?.toInt() ?? 0,
        exportsGenerated: json['exports_generated']?.toInt() ?? 0,
        systemHealth: json['system_health']?.toDouble() ?? 98.7,
        adminActionsToday: json['admin_actions_today']?.toInt() ?? 0,
        userActivitiesToday: json['user_activities_today']?.toInt() ?? 0,
        exportsToday: json['exports_today']?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'admin_actions': adminActions,
        'user_activities': userActivities,
        'exports_generated': exportsGenerated,
        'system_health': systemHealth,
        'admin_actions_today': adminActionsToday,
        'user_activities_today': userActivitiesToday,
        'exports_today': exportsToday,
      };
}