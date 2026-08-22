import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/vendors/application/vendor_reviews_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';

void main() {
  test(
    'vendorReviewsProvider returns typed reviews for current vendor stall',
    () async {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => _VendorAuthNotifier())],
      );
      addTearDown(container.dispose);

      final reviews = await container.read(vendorReviewsProvider.future);

      expect(reviews, isNotEmpty);
      expect(reviews, everyElement(isA<VendorReview>()));
      expect(reviews.map((review) => review.vendorId).toSet(), {'v1'});
    },
  );

  test('vendorReviewsFamilyProvider returns reviews for any vendor ID', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final v2Reviews =
        await container.read(vendorReviewsFamilyProvider('v2').future);
    expect(v2Reviews, isNotEmpty);
    expect(v2Reviews.every((r) => r.vendorId == 'v2'), isTrue);
  });
}

class _VendorAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() {
    return const AppUser(
      uid: 'stall holder-001', // mock demo vendor account
      email: 'vendor@example.com',
      displayName: 'Diosa Fruit Stand',
      role: UserRole.vendor,
    );
  }
}
