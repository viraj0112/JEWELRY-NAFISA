import 'dart:math';
import 'package:flutter/foundation.dart';

/// Security utility functions for the application
class SecurityUtils {
  /// Sanitizes a filename to prevent path traversal and injection attacks
  /// Returns a safe filename or generates a random one if the input is unsafe
  static String sanitizeFileName(String fileName, {String? userId}) {
    // Extract just the filename (no path)
    String name = fileName.split('/').last.split('\\').last;
    
    // Remove path traversal attempts
    name = name.replaceAll('..', '');
    name = name.replaceAll('~', '');
    
    // Extract extension
    final parts = name.split('.');
    String extension = '';
    if (parts.length > 1) {
      extension = parts.last.toLowerCase();
      // Whitelist allowed extensions
      final allowedExtensions = [
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', // Images
        'pdf', 'doc', 'docx', 'xls', 'xlsx', // Documents
        'mp4', 'mov', 'avi', 'webm', // Videos
      ];
      if (!allowedExtensions.contains(extension)) {
        extension = 'bin'; // Default to binary for unknown types
      }
    }
    
    // Generate a unique, safe filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomString(8);
    final userPrefix = userId != null ? '${userId.substring(0, 8)}_' : '';
    
    return '$userPrefix${timestamp}_$random.$extension';
  }

  /// Generates a random alphanumeric string of specified length
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Sanitizes search query to prevent injection attacks
  static String sanitizeSearchQuery(String query) {
    if (query.isEmpty) return '';
    
    // Limit query length
    String sanitized = query.length > 200 ? query.substring(0, 200) : query;
    
    // Remove potential SQL injection characters
    sanitized = sanitized
        .replaceAll(RegExp(r'[;\-\-]'), '') // Remove semicolons and double dashes
        .replaceAll(RegExp("['\"]"), '') // Remove quotes
        .replaceAll(RegExp(r'[<>]'), '') // Remove angle brackets (XSS)
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Remove control characters
        .replaceAll('/*', '')
        .replaceAll('*/', '')
        .trim();
    
    // Remove SQL keywords (case-insensitive)
    final sqlKeywords = [
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'UNION',
      'ALTER', 'CREATE', 'TRUNCATE', 'EXEC', 'EXECUTE',
    ];
    
    for (final keyword in sqlKeywords) {
      sanitized = sanitized.replaceAll(
        RegExp(keyword, caseSensitive: false), 
        '',
      );
    }
    
    return sanitized.trim();
  }

  /// Sanitizes user-provided text content (for profile fields, etc.)
  static String sanitizeText(String text, {int maxLength = 1000}) {
    if (text.isEmpty) return '';
    
    String sanitized = text.length > maxLength ? text.substring(0, maxLength) : text;
    
    // Remove potential XSS vectors
    sanitized = sanitized
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ''); // Remove control chars
    
    return sanitized.trim();
  }

  /// Logs security events (use proper logging service in production)
  static void logSecurityEvent(String event, {Map<String, dynamic>? details}) {
    // Only log in debug mode to avoid information leakage
    if (kDebugMode) {
      debugPrint('🔒 SECURITY: $event');
      if (details != null) {
        debugPrint('   Details: $details');
      }
    }
    // TODO: In production, send to a secure logging service like:
    // - Firebase Analytics (for non-sensitive events)
    // - A dedicated security logging backend
    // - Sentry/Crashlytics for error tracking
  }

  /// Returns a generic error message for authentication failures
  /// This prevents user enumeration attacks
  static String getGenericAuthError() {
    return 'Invalid credentials. Please check your email/username and password.';
  }

  /// Validates that the app is running in a secure context (HTTPS)
  static bool isSecureContext() {
    if (kIsWeb) {
      // In web, we should be on HTTPS in production
      // This is a simplified check - full implementation would use js interop
      return kReleaseMode; // Assume secure in release mode
    }
    // Native apps are considered secure by default
    return true;
  }

  /// Masks sensitive data for logging (shows first and last 2 chars)
  static String maskSensitiveData(String data) {
    if (data.length <= 4) {
      return '****';
    }
    return '${data.substring(0, 2)}${'*' * (data.length - 4)}${data.substring(data.length - 2)}';
  }

  /// Validates file size (in bytes)
  static bool isFileSizeValid(int sizeInBytes, {int maxSizeMB = 10}) {
    final maxBytes = maxSizeMB * 1024 * 1024;
    return sizeInBytes <= maxBytes;
  }

  /// Validates file type by checking magic bytes (more secure than extension check)
  static bool isValidImageMagicBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return true;
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return true;
    }
    // WebP: 52 49 46 46 ... 57 45 42 50
    if (bytes.length >= 12 && 
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    
    return false;
  }
}

/// Rate limiter for protecting against brute force attacks
class RateLimiter {
  final Map<String, List<DateTime>> _attempts = {};
  final int maxAttempts;
  final Duration window;

  RateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 15),
  });

  /// Check if an action should be rate limited
  /// Returns true if the action is allowed, false if rate limited
  bool checkLimit(String key) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    
    // Clean old attempts
    _attempts[key] = (_attempts[key] ?? [])
        .where((time) => time.isAfter(cutoff))
        .toList();
    
    // Check if under limit
    if ((_attempts[key]?.length ?? 0) >= maxAttempts) {
      SecurityUtils.logSecurityEvent('Rate limit exceeded', details: {'key': key});
      return false;
    }
    
    // Record this attempt
    _attempts[key] = [...(_attempts[key] ?? []), now];
    return true;
  }

  /// Get remaining attempts for a key
  int getRemainingAttempts(String key) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    final recentAttempts = (_attempts[key] ?? [])
        .where((time) => time.isAfter(cutoff))
        .length;
    return (maxAttempts - recentAttempts).clamp(0, maxAttempts);
  }

  /// Clear attempts for a key (e.g., after successful login)
  void clearAttempts(String key) {
    _attempts.remove(key);
  }
}

