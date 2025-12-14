/// Input validation utilities for security and data integrity.
/// All validators return null if valid, or an error message if invalid.

class Validators {
  // Email validation
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validates email format
  /// Returns null if valid, error message if invalid
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    if (email.length > 254) {
      return 'Email is too long';
    }
    if (!_emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password strength
  /// Requirements: minimum 8 chars, at least 1 uppercase, 1 lowercase, 1 number
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (password.length > 128) {
      return 'Password is too long';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    // Check for common weak passwords
    final commonPasswords = [
      'password', 'password1', '12345678', 'qwerty123',
      'admin123', 'letmein', 'welcome1', 'monkey123',
    ];
    if (commonPasswords.contains(password.toLowerCase())) {
      return 'This password is too common. Please choose a stronger one';
    }
    return null;
  }

  /// Validates password confirmation matches
  static String? validatePasswordConfirmation(String? password, String? confirmation) {
    if (confirmation == null || confirmation.isEmpty) {
      return 'Please confirm your password';
    }
    if (password != confirmation) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates username format
  /// Requirements: 3-30 chars, alphanumeric and underscores only
  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 30) {
      return 'Username must be less than 30 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    // Prevent SQL injection attempts in usernames
    if (_containsSqlKeywords(username)) {
      return 'Username contains invalid characters';
    }
    return null;
  }

  /// Validates phone number format (basic validation)
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }
    // Remove common formatting characters for validation
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleanPhone.length < 10 || cleanPhone.length > 15) {
      return 'Please enter a valid phone number';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanPhone)) {
      return 'Phone number can only contain digits';
    }
    return null;
  }

  /// Validates birthdate format and reasonable range
  static String? validateBirthdate(String? birthdate) {
    if (birthdate == null || birthdate.isEmpty) {
      return 'Birthdate is required';
    }
    try {
      final date = DateTime.parse(birthdate);
      final now = DateTime.now();
      final minAge = now.subtract(const Duration(days: 365 * 13)); // 13 years old minimum
      final maxAge = now.subtract(const Duration(days: 365 * 120)); // 120 years old maximum
      
      if (date.isAfter(minAge)) {
        return 'You must be at least 13 years old';
      }
      if (date.isBefore(maxAge)) {
        return 'Please enter a valid birthdate';
      }
      if (date.isAfter(now)) {
        return 'Birthdate cannot be in the future';
      }
    } catch (e) {
      return 'Please enter a valid date format (YYYY-MM-DD)';
    }
    return null;
  }

  /// Validates GST number format (Indian GST)
  static String? validateGstNumber(String? gst) {
    if (gst == null || gst.isEmpty) {
      return null; // GST is optional
    }
    // Indian GST format: 2 digits state code + 10 character PAN + 1 entity code + Z + 1 checksum
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(gst.toUpperCase())) {
      return 'Please enter a valid GST number';
    }
    return null;
  }

  /// Validates business name
  static String? validateBusinessName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Business name is required';
    }
    if (name.length < 2) {
      return 'Business name is too short';
    }
    if (name.length > 100) {
      return 'Business name is too long';
    }
    // Prevent script injection
    if (_containsScriptTags(name)) {
      return 'Business name contains invalid characters';
    }
    return null;
  }

  /// Validates address
  static String? validateAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Address is required';
    }
    if (address.length < 10) {
      return 'Please enter a complete address';
    }
    if (address.length > 500) {
      return 'Address is too long';
    }
    // Prevent script injection
    if (_containsScriptTags(address)) {
      return 'Address contains invalid characters';
    }
    return null;
  }

  /// Validates referral code format
  static String? validateReferralCode(String? code) {
    if (code == null || code.isEmpty) {
      return null; // Referral code is optional
    }
    if (code.length < 4 || code.length > 20) {
      return 'Invalid referral code';
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code)) {
      return 'Referral code can only contain letters and numbers';
    }
    return null;
  }

  /// Check for common SQL keywords (basic protection)
  static bool _containsSqlKeywords(String input) {
    final sqlKeywords = [
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'UNION',
      'ALTER', 'CREATE', 'TRUNCATE', '--', ';', '/*', '*/',
      'OR 1=1', 'OR 1 = 1', "' OR '", '" OR "',
    ];
    final upperInput = input.toUpperCase();
    return sqlKeywords.any((keyword) => upperInput.contains(keyword));
  }

  /// Check for script tags (XSS prevention)
  static bool _containsScriptTags(String input) {
    final patterns = [
      '<script', '</script', 'javascript:', 'onerror=', 'onload=',
      'onclick=', 'onmouseover=', '<iframe', '<object', '<embed',
    ];
    final lowerInput = input.toLowerCase();
    return patterns.any((pattern) => lowerInput.contains(pattern));
  }
}

/// Result class for validation
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;

  factory ValidationResult.from(String? error) {
    if (error == null) {
      return const ValidationResult.valid();
    }
    return ValidationResult.invalid(error);
  }
}

