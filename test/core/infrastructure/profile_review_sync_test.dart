import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/data/supabase_auth_repository.dart';
import 'package:palengkego/features/vendors/application/vendor_reviews_provider.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_reviews_screen.dart';
import 'supabase_connections_test.dart' as helpers;

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User(true);
}

class _User extends Fake implements User {
  _User(this.verified);
  final bool verified;
  @override
  String get uid => 'uid';
  @override
  String get email => 'new@example.com';
  @override
  bool get emailVerified => verified;
  @override
  List<UserInfo> get providerData => [];
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    return 'verified-token';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final verified in [false, true]) {
    test('email sync only runs for verified identity: $verified', () async {
      var syncs = 0;
      final client = helpers.clientFor((request) async {
        if (request.url.path.endsWith('/users')) {
          return helpers.json({
            'user_id': 'uid',
            'email': 'old@example.com',
            'full_name': 'Saved Name',
            'phone_number': '09123456789',
            'role': 'customer',
          });
        }
        if (request.url.path.endsWith('/stall_holders')) {
          return helpers.json({'is_kyc_approved': false});
        }
        expect(request.url.path, '/functions/v1/sync-profile-email');
        expect(request.headers['Authorization'], 'Bearer verified-token');
        syncs++;
        return helpers.json({'email': 'new@example.com'});
      });
      addTearDown(client.dispose);
      final user = await SupabaseAuthRepository(
        auth: _Auth(),
        client: client,
      ).resolveUser(_User(verified));
      expect(syncs, verified ? 1 : 0);
      expect(user.email, verified ? 'new@example.com' : 'old@example.com');
      expect(user.displayName, 'Saved Name');
      expect(user.phoneNumber, '09123456789');
    });
  }
  test('review reload uses backend names and retains stall scoping', () async {
    final ticks = StreamController<int>();
    addTearDown(ticks.close);
    var reads = 0;
    final client = helpers.clientFor((request) async {
      expect(request.url.path, '/rest/v1/rpc/read_stall_reviews');
      expect(request.body, contains('stall-a'));
      reads++;
      return helpers.json([
        {
          'rating_id': 'r',
          'stall_holder_id': 'stall-a',
          'customer_id': 'c',
          'customer_name': 'Actual Name',
          'score': 4,
          'comment': 'Fresh',
          'created_at': '2026-10-11T00:00:00Z',
          'order_id': 'o',
        },
      ]);
    });
    addTearDown(client.dispose);
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        reviewRefreshTickProvider.overrideWith((ref) => ticks.stream),
      ],
    );
    addTearDown(container.dispose);
    final provider = vendorReviewsFamilyProvider('stall-a');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(provider.future)).single.customerName,
      'Actual Name',
    );
    ticks.add(1);
    await container.pump();
    await container.read(provider.future);
    expect(reads, 2);
  });
  testWidgets('review errors show retry instead of an empty review list', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorReviewsFamilyProvider(
            'stall',
          ).overrideWith((ref) async => throw StateError('offline')),
        ],
        child: const MaterialApp(home: VendorReviewsScreen(vendorId: 'stall')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load reviews'), findsOneWidget);
    expect(find.byTooltip('Refresh reviews'), findsOneWidget);
  });
}
