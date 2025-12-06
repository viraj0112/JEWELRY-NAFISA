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
import 'package:jewelry_nafisa/src/ui/screens/jewelry_detail_screen.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/product_page_loader.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/services/quote_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jewelry_nafisa/src/services/search_history_service.dart';
import 'package:universal_html/html.dart' as html;
// NEW ONBOARDING IMPORTS
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_1_location.dart'; // Add this
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_occasions.dart'; // Add this
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_categories.dart'; // Add this
final supabaseClient = Supabase.instance.client;
final _router = GoRouter(
  initialLocation: '/',
  // observers: [_analyticsObserver],
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
      path: '/home',
      builder: (context, state) => const MainShell(),
    ),
    GoRoute(
      path: '/designer',
      builder: (context, state) => const DesignerShell(),
    ),
    // GoRoute(
    //   path: '/admin',
    //   builder: (context, state) => const AdminShell(),
    // ),
    // Onboarding Routes
    GoRoute(
      path: '/onboarding/location',
      builder: (context, state) => const OnboardingScreen1Location(),
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
    // Handle both slug-based and ID-based product routes
    GoRoute(
      path: '/product/:identifier',
      builder: (context, state) {
        final identifier = state.pathParameters['identifier'];
        if (identifier == null || identifier.isEmpty) {
          return const AuthGate();
        }

        // If identifier contains hyphens or letters, treat as slug
        // Otherwise treat as numeric ID
        final isSlug = identifier.contains('-') ||
            identifier.contains(RegExp(r'[a-zA-Z]'));

        if (isSlug) {
          return ProductPageLoader(productSlug: identifier);
        } else {
          return ProductDetailLoader(productId: identifier);
        }
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
// await dotenv.load(fileName: ".env");
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

  runApp(
    ProviderScope(
      child: provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider(create: (context) => AppState()),
          provider_pkg.ChangeNotifierProvider(
              create: (_) => SearchHistoryService()..init()),
          provider_pkg.ChangeNotifierProvider(
              create: (context) => UserProfileProvider()),
          provider_pkg.ChangeNotifierProvider(
              create: (context) => ThemeProvider()),
          provider_pkg.ChangeNotifierProvider(
              create: (context) => BoardsProvider()),

          provider_pkg.Provider<JewelryService>(
            create: (_) => JewelryService(supabaseClient),
          ),

          provider_pkg.Provider<QuoteService>(create: (_) => QuoteService()),
          // Provider<SupabaseAuthService>(create: (_) => authService),
          // Provider<JewelryService>(create: (_) => JewelryService(supabase)),
          // Provider<QuoteService>(create: (_) => QuoteService(supabase)),
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
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Dagina Designs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
    );
  }
}

class ProductDetailLoader extends StatelessWidget {
  final String productId;
  const ProductDetailLoader({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    // --- FIXED: Use the existing provider instead of creating a new instance ---
    final jewelryService = provider_pkg.Provider.of<JewelryService>(context, listen: false);

    return FutureBuilder<JewelryItem?>(
      future: jewelryService.getJewelryItem(productId),
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
