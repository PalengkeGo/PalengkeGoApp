import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/vendors/data/firebase_vendor_repository.dart';
import 'package:palengkego/features/vendors/data/mock_vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  final firebaseEnabled = ref.watch(firebaseEnabledProvider);
  if (firebaseEnabled) {
    final firestore = ref.watch(firestoreProvider);
    final functions = ref.watch(firebaseFunctionsProvider);
    return FirebaseVendorRepository(firestore, functions);
  }
  return MockVendorRepository();
});

final vendorProfileProvider = FutureProvider.family<VendorProfile, String>((
  ref,
  vendorId,
) async {
  final repository = ref.read(vendorRepositoryProvider);
  return repository.getVendorProfile(vendorId);
});

final vendorProductsProvider =
    FutureProvider.family<List<VendorProduct>, String>((ref, vendorId) async {
      final repository = ref.read(vendorRepositoryProvider);
      return repository.getVendorProducts(vendorId);
    });

/// Full stall record for the given stallId (vendor-facing).
final vendorStallByIdProvider = FutureProvider.family<VendorStall, String>((
  ref,
  stallId,
) async {
  return ref.read(vendorRepositoryProvider).getVendorStall(stallId);
});

class VendorProductsManager {
  final Ref ref;
  final String vendorId;

  VendorProductsManager(this.ref, this.vendorId);

  Future<void> addProduct(VendorProduct product) async {
    final repository = ref.read(vendorRepositoryProvider);
    await repository.addVendorProduct(product);
    ref.invalidate(vendorProductsProvider(vendorId));
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> updateProduct(VendorProduct product) async {
    final repository = ref.read(vendorRepositoryProvider);
    await repository.updateVendorProduct(product);
    ref.invalidate(vendorProductsProvider(vendorId));
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> deleteProduct(String productId) async {
    final repository = ref.read(vendorRepositoryProvider);
    await repository.deleteVendorProduct(vendorId, productId);
    ref.invalidate(vendorProductsProvider(vendorId));
    ref.read(dataRefreshSignal.notifier).notify();
  }
}

final vendorProductsManagerProvider =
    Provider.family<VendorProductsManager, String>((ref, vendorId) {
      return VendorProductsManager(ref, vendorId);
    });
