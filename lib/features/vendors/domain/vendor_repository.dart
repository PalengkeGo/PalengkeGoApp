import 'package:palengkego/features/vendors/domain/sales_summary.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

abstract class VendorRepository {
  // ── Market listing (customer-facing) ────────────────────────────────────────
  Future<VendorProfile> getVendorProfile(String id);
  Future<List<VendorProduct>> getVendorProducts(String vendorId);

  // ── Product management (vendor-facing) ──────────────────────────────────────
  Future<VendorProduct> addVendorProduct(VendorProduct product);
  Future<VendorProduct> updateVendorProduct(VendorProduct product);

  /// Deletes [productId] from [stallId]'s catalog. Firestore rules enforce
  /// that only the stall owner can delete — the repository targets the doc
  /// directly and lets the rules deny anyone else.
  Future<void> deleteVendorProduct(String stallId, String productId);

  // ── Stall management ────────────────────────────────────────────────────────
  /// Get the full VendorStall record for the logged-in vendor.
  Future<VendorStall> getVendorStall(String stallId);

  /// Persist changes to stall info (name, schedule, delivery settings, etc.).
  Future<void> updateVendorStall(VendorStall stall);

  // ── Reviews ─────────────────────────────────────────────────────────────────
  Future<List<VendorReview>> getReviews(String stallId);
  Future<void> addReview(VendorReview review);

  // ── Sales / Earnings ────────────────────────────────────────────────────────
  /// Daily sales summaries between [from] and [to] (inclusive).
  Future<List<SalesSummary>> getSalesSummary(
    String stallId, {
    required DateTime from,
    required DateTime to,
  });
}
