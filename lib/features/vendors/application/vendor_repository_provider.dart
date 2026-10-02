import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/data/mock_vendor_repository.dart';

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return MockVendorRepository(prefs);
  } catch (_) {
    return MockVendorRepository();
  }
});
