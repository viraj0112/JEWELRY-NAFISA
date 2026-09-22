import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/referral_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/referral_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'referral_screen_test.mocks.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  SupabaseQueryBuilder, // Added this class to the mocks
  PostgrestClient,
  PostgrestFilterBuilder,
  User,
])
void main() {
  // Instances of our mocks
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockSupabaseQueryBuilder mockSupabaseQueryBuilder;
  late MockPostgrestFilterBuilder<List<Map<String, dynamic>>>
      mockPostgrestFilterBuilder;
  late MockUser mockUser;
  late UserProfileProvider userProfileProvider;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockSupabaseQueryBuilder = MockSupabaseQueryBuilder();
    mockPostgrestFilterBuilder =
        MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
    mockUser = MockUser();
    // Inject the mock. Previously this constructed the provider with no
    // client, so it reached for the uninitialised global Supabase instance and
    // every test died in setUp() before reaching an expectation.
    userProfileProvider = UserProfileProvider(client: mockSupabaseClient);

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');

    // thenAnswer, not thenReturn: every postgrest builder implements Future,
    // and mockito refuses thenReturn for Future-typed returns.
    when(mockSupabaseClient.from(any)).thenAnswer((_) => mockSupabaseQueryBuilder);
    when(mockSupabaseQueryBuilder.select(any))
        .thenAnswer((_) => mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.eq(any, any))
        .thenAnswer((_) => mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.order(any,
            ascending: anyNamed('ascending')))
        .thenAnswer((_) => mockPostgrestFilterBuilder);
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => userProfileProvider),
        Provider<SupabaseClient>.value(value: mockSupabaseClient),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ReferralScreen(client: mockSupabaseClient),
        ),
      ),
    );
  }

  testWidgets('Displays loading indicator while fetching history',
      (WidgetTester tester) async {
    // `await builder` calls builder.then(onValue, onError:) and only resumes
    // when onValue is INVOKED. Returning the rows from the stub (as this used
    // to) leaves the await hanging forever, which is why the screen sat on its
    // spinner and pumpAndSettle timed out. Invoke the callback instead.
    when(mockPostgrestFilterBuilder.then(any, onError: anyNamed('onError')))
        .thenAnswer((invocation) async {
      final onValue = invocation.positionalArguments[0] as Function;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return onValue(<Map<String, dynamic>>[]);
    });

    await tester.pumpWidget(createTestWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('Displays referral history when data is available',
      (WidgetTester tester) async {
    final referralData = [
      {
        'credits_awarded': 2,
        'created_at': '2025-09-17T10:00:00Z',
        'referred': {'username': 'testuser1'}
      },
    ];
    when(mockPostgrestFilterBuilder.then(any, onError: anyNamed('onError')))
        .thenAnswer((invocation) async {
      final onValue = invocation.positionalArguments[0] as Function;
      return onValue(referralData);
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('testuser1 joined!'), findsOneWidget);
    expect(find.text('+2 Credits'), findsOneWidget);
    expect(find.text('No referrals yet. Share your code to get started!'),
        findsNothing);
  });

  testWidgets('Displays empty message when there is no referral history',
      (WidgetTester tester) async {
    when(mockPostgrestFilterBuilder.then(any, onError: anyNamed('onError')))
        .thenAnswer((invocation) async {
      final onValue = invocation.positionalArguments[0] as Function;
      return onValue(<Map<String, dynamic>>[]);
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('No referrals yet. Share your code to get started!'),
        findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
