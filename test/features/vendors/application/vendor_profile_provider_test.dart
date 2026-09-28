import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';

void main() {
  test('vendorProfileProvider resolves vendor from allVendorsProvider without Diosa hijacking', () async {
    final container = ProviderContainer(
      overrides: [
        allVendorsProvider.overrideWith((ref) async => [
          const MarketVendor(
            id: 'sh-britanico-123',
            name: 'Britanico Store',
            category: 'Vegetables',
            rating: 4.9,
            isVerified: true,
            distance: '0.4km',
            imageUrl: 'https://example.com/britanico.jpg',
            stallNumber: 'Block 2, Stall 3, Floor 2',
            marketSection: 'Vegetables Section',
            reviewCount: 42,
          ),
          const MarketVendor(
            id: 'v2',
            name: 'William Del Rosario Meat Shop',
            category: 'Meat',
            rating: 4.5,
            isVerified: true,
            distance: '0.8km',
            imageUrl: 'https://example.com/william.jpg',
            stallNumber: 'Block 15 | Stall 2',
            marketSection: 'Meat Section',
            reviewCount: 245,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    // 1. Check Britanico Store by id
    final britanicoProfile = await container.read(vendorProfileProvider('sh-britanico-123').future);
    expect(britanicoProfile.name, 'Britanico Store');
    expect(britanicoProfile.category, 'Vegetables');
    expect(britanicoProfile.stallLocation, 'Block 2, Stall 3, Floor 2');
    expect(britanicoProfile.rating, 4.9);
    expect(britanicoProfile.reviewCount, 42);

    // 2. Check Britanico Store by name
    final britanicoByName = await container.read(vendorProfileProvider('Britanico Store').future);
    expect(britanicoByName.name, 'Britanico Store');
    expect(britanicoByName.category, 'Vegetables');

    // 3. Check William Del Rosario Meat Shop
    final williamProfile = await container.read(vendorProfileProvider('v2').future);
    expect(williamProfile.name, 'William Del Rosario Meat Shop');
    expect(williamProfile.category, 'Meat');
    expect(williamProfile.stallLocation, 'Block 15 | Stall 2');
  });
}
