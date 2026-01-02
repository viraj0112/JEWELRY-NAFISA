import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_gender.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_age.dart';
import 'firebase_options.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jewelry_nafisa/src/admin2/screens/main_screen.dart';
import 'package:jewelry_nafisa/src/auth/auth_callback_screen.dart';
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:jewelry_nafisa/src/admin2/providers/app_state.dart';
import 'package:jewelry_nafisa/src/ui/theme/app_theme.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/product_page_loader.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/services/quote_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jewelry_nafisa/src/services/search_history_service.dart';
import 'package:universal_html/html.dart' as html;
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_1_location.dart'; 
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_occasions.dart'; 
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_categories.dart'; 
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/boards_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/search_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/notifications_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';

final supabaseClient = Supabase.instance.client;

FirebaseAnalytics analytics = FirebaseAnalytics.instance;
FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

// Create a global key for the router to access auth state
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/', // Changed to root - AuthGate will handle routing
  observers: [observer],
  
  // Add redirect logic to check auth state
  redirect: (context, state) {
    final isLoggedIn = supabaseClient.auth.currentSession != null;
    final isGoingToAuth = state.matchedLocation == '/welcome' ||
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup';
    final isGoingToAuthCallback = state.matchedLocation == '/auth-callback';
    
    // Allow auth callback through
    if (isGoingToAuthCallback) {
      return null;
    }
    
    // If logged in and going to auth pages, redirect to home
    if (isLoggedIn && isGoingToAuth) {
      return '/home';
    }
    
    // If not logged in and not going to auth pages or root, redirect to welcome
    if (!isLoggedIn && !isGoingToAuth && state.matchedLocation != '/') {
      return '/welcome';
    }
    
    return null; // No redirect needed
  },
  
  // Add refresh listener to update routing when auth changes
  refreshListenable: GoRouterRefreshStream(
    supabaseClient.auth.onAuthStateChange,
  ),
  
  routes: [
    GoRoute(
      path: '/admin',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/designer',
      builder: (context, state) => const DesignerShell(),
    ),
    GoRoute(
      path: '/onboarding/location',
      builder: (context, state) => const OnboardingScreen1Location(),
    ),
    GoRoute(
      path: '/onboarding/gender',
      builder: (context, state) => const OnboardingScreen2Gender(),
    ),
    GoRoute(
      path: '/onboarding/age',
      builder: (context, state) => const OnboardingScreen3Age(),
    ),
    GoRoute(
      path: '/onboarding/occasions',
      builder: (context, state) => const OnboardingScreen2Occasions(),
    ),
    GoRoute(
      path: '/onboarding/categories',
      builder: (context, state) => const OnboardingScreen3Categories(),
    ),
    GoRoute(
      path: '/auth-callback',
      builder: (context, state) => const AuthCallbackScreen(),
    ),
    GoRoute(
      path: '/pending-approval',
      builder: (context, state) => const PendingApprovalScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/boards',
              builder: (context, state) => const BoardsScreen(),
              routes: [
                GoRoute(
                  path: 'detail/:id',
                  builder: (context, state) {
                    final boardId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    final boardName = state.extra as String? ?? 'Board Details';
                    return BoardDetailScreen(boardId: boardId, boardName: boardName);
                  },
                ),
              ]
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => SearchScreen(searchController: TextEditingController()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const SizedBox.shrink(), 
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/product/:identifier',
      builder: (context, state) {
        final identifier = state.pathParameters['identifier'];
        if (identifier == null || identifier.isEmpty) {
          return const AuthGate();
        }

        final isSlug = identifier.contains('-') ||
            identifier.contains(RegExp(r'[a-zA-Z]'));

        if (isSlug) {
          return ProductPageLoader(productSlug: identifier);
        } else {
          final isDesignerParam = state.uri.queryParameters['isDesigner'];
          final isDesigner = isDesignerParam == 'true';
          return ProductDetailLoader(productId: identifier, isDesigner: isDesigner);
        }
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
  ],
);

// Helper class to make GoRouter listen to auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (AuthState _) {
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final supabaseUrl =
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_URL')
          : dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  ).isNotEmpty
      ? const String.fromEnvironment('SUPABASE_ANON_KEY')
      : dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
        'Supabase URL and Anon Key are required. Provide them via --dart-define or .env file.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final searchHistoryService = SearchHistoryService();
  await searchHistoryService.init();
  setPathUrlStrategy();

  // Create UserProfileProvider and initialize if user is logged in
  final userProfileProvider = UserProfileProvider();
  if (supabaseClient.auth.currentUser != null) {
    print('🚀 Main: User is logged in, loading profile...');
    userProfileProvider.loadUserProfile();
  }

  runApp(
    ProviderScope(
      child: provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider(create: (context) => AppState()),
          provider_pkg.ChangeNotifierProvider(
              create: (_) => SearchHistoryService()..init()),
          provider_pkg.ChangeNotifierProvider.value(
              value: userProfileProvider),
          provider_pkg.ChangeNotifierProvider(
              create: (context) => ThemeProvider()),
          provider_pkg.ChangeNotifierProvider(
              create: (context) => BoardsProvider()),
          provider_pkg.Provider<JewelryService>(
            create: (_) => JewelryService(supabaseClient),
          ),
          provider_pkg.Provider<QuoteService>(create: (_) => QuoteService()),
        ],
        child: const MyApp(),
      ),
    ),
  );

  final loader = html.document.getElementById('loading_indicator');
  if (loader != null) {
    loader.remove();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dagina Designs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}

class ProductDetailLoader extends StatelessWidget {
  final String productId;
  final bool isDesigner;
  const ProductDetailLoader({super.key, required this.productId, this.isDesigner = false});

  @override
  Widget build(BuildContext context) {
    final jewelryService = provider_pkg.Provider.of<JewelryService>(context, listen: false);

    return FutureBuilder<JewelryItem?>(
      future: jewelryService.getJewelryItem(productId, isDesignerProduct: isDesigner),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("Product not found")),
          );
        }
        return JewelryDetailScreen(jewelryItem: snapshot.data!);
      },
    );
  }
}