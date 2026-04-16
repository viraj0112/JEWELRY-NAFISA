import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves location data for the currently authenticated user.
///
/// Strategy:
///   1. Read `country` and `zip_code` from `public.users` (set during onboarding).
///   2. If a zip_code exists, look it up in `pincode_regions` to get state/district.
///   3. Return a [LocationData] record with all available fields.
///
/// All fields are nullable — never block an action because location is unavailable.
class LocationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static LocationData? _cached;

  /// Returns the location for the current user.
  /// Reads from cache if already fetched this session.
  static Future<LocationData> forCurrentUser() async {
    if (_cached != null) return _cached!;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return const LocationData();

    try {
      // 1. Fetch country + zip from users table
      final userRow = await _supabase
          .from('users')
          .select('country, zip_code')
          .eq('id', uid)
          .maybeSingle();

      if (userRow == null) return const LocationData();

      final country = userRow['country'] as String?;
      final pincode = userRow['zip_code'] as String?;

      String? state;
      String? district;

      // 2. Resolve state/district via pincode_regions (India-specific)
      if (pincode != null && pincode.isNotEmpty) {
        try {
          final regionRow = await _supabase
              .from('pincode_regions')
              .select('state, district')
              .eq('pincode', pincode)
              .maybeSingle();

          state = regionRow?['state'] as String?;
          district = regionRow?['district'] as String?;
        } catch (e) {
          debugPrint('LocationService: pincode lookup failed — $e');
        }
      }

      _cached = LocationData(
        country: country,
        state: state,
        pincode: pincode,
        district: district,
      );
      return _cached!;
    } catch (e) {
      debugPrint('LocationService.forCurrentUser error: $e');
      return const LocationData();
    }
  }

  /// Call this when user signs out so the next user gets fresh location data.
  static void clearCache() => _cached = null;
}

/// Immutable value object holding all resolved location fields.
class LocationData {
  final String? country;
  final String? state;
  final String? pincode;
  final String? district;

  const LocationData({
    this.country,
    this.state,
    this.pincode,
    this.district,
  });

  /// Returns only the columns that are non-null,
  /// ready to be merged into a Supabase insert map.
  Map<String, dynamic> toInsertMap() {
    return {
      if (country != null) 'country': country,
      if (state != null) 'state': state,
      if (pincode != null) 'pincode': pincode,
    };
  }

  @override
  String toString() =>
      'LocationData(country: $country, state: $state, pincode: $pincode, district: $district)';
}
