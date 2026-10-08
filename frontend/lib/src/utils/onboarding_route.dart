import 'package:jewelry_nafisa/src/models/user_profile.dart';

/// The onboarding screen that picks up where [profile] left off.
String onboardingRouteFor(UserProfile profile) {
  switch (profile.onboardingStage) {
    case 0:
      return '/onboarding/location';
    case 1:
      return '/onboarding/gender';
    default:
      return '/onboarding/categories';
  }
}
