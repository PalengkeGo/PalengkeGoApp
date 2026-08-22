import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';

/// Reviews for the logged-in vendor's stall, resolved from the stall's own
/// [VendorStall.stallId] (never its display name, which can change).
///
/// Firebase mode reads the `ratings` collection (written by the `addReview`
/// callable); mock mode serves the seeded demo reviews.
final vendorReviewsProvider = FutureProvider<List<VendorReview>>((ref) async {
  final stall = ref.watch(vendorStallProvider);
  return _loadReviews(ref, stall.stallId);
});

/// Reads and returns all typed [VendorReview] objects for a given vendor stall ID.
final vendorReviewsFamilyProvider =
    FutureProvider.family<List<VendorReview>, String>((ref, vendorId) {
  return _loadReviews(ref, vendorId);
});

Future<List<VendorReview>> _loadReviews(Ref ref, String stallId) async {
  if (ref.watch(firebaseEnabledProvider)) {
    return ref.read(vendorRepositoryProvider).getReviews(stallId);
  }
  // Mock mode: map the (possibly real) stall id onto the seeded demo vendors.
  return MockDataService.getReviewsAsObjects(
    MockDataService.resolveMockVendorId(stallId),
  );
}
