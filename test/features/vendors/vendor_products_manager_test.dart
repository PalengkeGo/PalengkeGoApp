import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

void main() {
  test('VendorProductsManager adds product and vendorProductsProvider reflects it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const testVendorId = 'test_vendor_999';
    final initial = await container.read(vendorProductsProvider(testVendorId).future);
    expect(initial, isEmpty);

    final manager = container.read(vendorProductsManagerProvider(testVendorId));
    final newProduct = VendorProduct(
      id: 'p_test_1',
      vendorId: testVendorId,
      name: 'Fresh Mangoes',
      description: 'Sweet carabao mangoes',
      category: 'Fruits',
      price: 120.0,
      unit: 'kg',
      imageUrl: 'https://example.com/mango.jpg',
      isActive: true,
      stockQuantity: 20.0,
    );

    await manager.addProduct(newProduct);

    final updated = await container.read(vendorProductsProvider(testVendorId).future);
    expect(updated.any((p) => p.name == 'Fresh Mangoes'), isTrue);
  });
}
