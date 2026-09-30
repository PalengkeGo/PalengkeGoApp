import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
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
  ref.watch(dataRefreshSignal);
  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    final rows = await client
        .from('ratings')
        .select()
        .eq('stall_holder_id', stallId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => VendorReview(
            id: row['rating_id'] as String,
            vendorId: row['stall_holder_id'] as String,
            customerId: row['customer_id'] as String,
            customerName: 'Customer',
            rating: (row['score'] as num).toDouble(),
            comment: row['comment'] as String? ?? '',
            date: DateTime.parse(row['created_at'] as String),
            orderId: row['order_id'] as String,
          ),
        )
        .toList();
  }

  if (ref.watch(firebaseEnabledProvider)) {
    return ref.read(vendorRepositoryProvider).getReviews(stallId);
  }
  // Mock mode: map the (possibly real) stall id onto the seeded demo vendors.
  return MockDataService.getReviewsAsObjects(
    MockDataService.resolveMockVendorId(stallId),
  );
}

Future<void> submitVendorReview(WidgetRef ref, VendorReview review) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) {
    await ref.read(vendorRepositoryProvider).addReview(review);
  } else {
    final token = await ref
        .read(firebaseAuthProvider)
        .currentUser
        ?.getIdToken();
    if (token == null) throw StateError('Sign in to submit a review.');
    await client.functions.invoke(
      'add-review',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'orderId': review.orderId,
        'stallId': review.vendorId,
        'rating': review.rating,
        'comment': review.comment,
      },
    );
  }
  ref.read(dataRefreshSignal.notifier).notify();
}
