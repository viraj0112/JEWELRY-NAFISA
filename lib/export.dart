import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/admin2/screens/main_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_gender.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_age.dart'; 
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_1_location.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_occasions.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_categories.dart';
import 'package:jewelry_nafisa/src/b2b/b2b_shell.dart';

