import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/vendors/data/supabase_kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';
import '../../core/infrastructure/supabase_connections_test.dart' as helpers;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'registered Beef and Pork survive Supabase loading and market filters',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final stalls = <Map<String, dynamic>>[];
      final client = helpers.clientFor((request) async {
        if (request.url.path.endsWith('/stall_holders')) {
          if (request.method == 'POST') {
            stalls.add(Map<String, dynamic>.from(jsonDecode(request.body)));
            return helpers.json({});
          }
          return helpers.json(stalls);
        }
        if (request.url.path.endsWith('/kyc_submissions')) {
          return helpers.json(jsonDecode(request.body));
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      addTearDown(client.dispose);
      final repo = SupabaseKycRepository(client);
      for (final type in ['Beef', 'Pork']) {
        await repo.submitKyc(
          KycSubmission(
            kycId: type,
            stallHolderId: type,
            stallName: '$type stall',
            category: 'Meat',
            meatType: type,
            submittedAt: DateTime(2026),
          ),
        );
      }
      expect(stalls.map((s) => s['tags']), [
        ['Beef'],
        ['Pork'],
      ]);
      await expectLater(
        repo.submitKyc(
          KycSubmission(
            kycId: 'bad',
            stallHolderId: 'bad',
            category: 'Meat',
            submittedAt: DateTime(2026),
          ),
        ),
        throwsArgumentError,
      );
      expect(stalls.length, 2);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(filteredVendorsProvider('Meat'), (_, _) {});
      addTearDown(sub.close);
      await container.read(vendorsByCategoryProvider('Meat').future);
      await container.pump();
      expect(
        container.read(filteredVendorsProvider('Meat')).requireValue.length,
        2,
      );
      for (final type in ['Beef', 'Pork']) {
        container
            .read(selectedSubcategoryProvider.notifier)
            .setSubcategory(type);
        expect(
          container
              .read(filteredVendorsProvider('Meat'))
              .requireValue
              .map((v) => v.id),
          [type],
        );
      }
      await container.read(vendorsByCategoryProvider('All').future);
      expect(
        container.read(filteredVendorsProvider('All')).requireValue.length,
        2,
      );
    },
  );
}
