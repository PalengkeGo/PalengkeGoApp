import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';

/// Reviews for the logged-in vendor's stall, resolved from the stall's own
/// [VendorStall.stallId] (never its display name, which can change).
///
/// When a real backend is added, swap MockDataService for an API call here.
final vendorReviewsProvider = Provider<List<VendorReview>>((ref) {
  final stall = ref.watch(vendorStallProvider);
  final vendorId = MockDataService.resolveMockVendorId(stall.stallId);
  return MockDataService.getReviewsAsObjects(vendorId);
});

/// Reads and returns all typed [VendorReview] objects for a given vendor stall ID.
final vendorReviewsFamilyProvider = Provider.family<List<VendorReview>, String>(
  (ref, vendorId) {
    return MockDataService.getReviewsAsObjects(vendorId);
  },
);
