import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('vendor stall settings update reflects description, banner, and avatar on customer UI', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    // 1. Vendor updates stall settings
    await container.read(vendorStallProvider.notifier).updateStall(
      name: 'Fresh Organic Produce',
      description: 'Locally grown organic fruits and vegetables harvested daily.',
      bannerImage: 'https://example.com/banner.jpg',
      avatarImage: 'https://example.com/avatar.jpg',
      thumbnailImage: 'https://example.com/thumb.jpg',
    );

    // 2. Customer views stall on market screen (allVendorsProvider)
    final allVendors = await container.read(allVendorsProvider.future);
    final vendorCard = allVendors.firstWhere((v) => v.id == 'v1' || v.name == 'Fresh Organic Produce');
    expect(vendorCard.name, 'Fresh Organic Produce');
    expect(vendorCard.description, 'Locally grown organic fruits and vegetables harvested daily.');
    expect(vendorCard.imageUrl, contains('example.com'));

    // 3. Customer views vendor profile screen (vendorProfileProvider)
    final profile = await container.read(vendorProfileProvider(vendorCard.id).future);
    expect(profile.name, 'Fresh Organic Produce');
    expect(profile.description, 'Locally grown organic fruits and vegetables harvested daily.');
    expect(profile.imageUrl, 'https://example.com/banner.jpg');
    expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
  });
}
