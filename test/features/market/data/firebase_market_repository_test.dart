import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/data/firebase_market_repository.dart';
import 'package:palengkego/features/market/data/mock_market_repository.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

void main() {
  group('stallToMarketVendor', () {
    test('maps a Firestore stall document to a MarketVendor', () {
      final vendor = stallToMarketVendor('stall-1', {
        'name': 'Diosa Fruit Stand',
        'category': 'Fruits',
        'averageRating': 4.8,
        'totalRatings': 129,
        'isKYCApproved': true,
        'isOpen': false,
        'bannerImage': 'https://example.com/banner.jpg',
        'stallNumber': 'A-12',
        'marketSection': 'Section A',
        'distance': '1.2 km',
        'tags': ['fruits', 'organic'],
      });

      expect(vendor.id, 'stall-1');
      expect(vendor.name, 'Diosa Fruit Stand');
      expect(vendor.category, 'Fruits');
      expect(vendor.rating, 4.8);
      expect(vendor.reviewCount, 129);
      expect(vendor.isVerified, isTrue);
      expect(vendor.isOpen, isFalse);
      expect(vendor.imageUrl, 'https://example.com/banner.jpg');
      expect(vendor.stallNumber, 'A-12');
      expect(vendor.marketSection, 'Section A');
      expect(vendor.distance, '1.2 km');
      expect(vendor.tags, ['fruits', 'organic']);
    });

    test('defaults missing fields to documented empty state', () {
      final vendor = stallToMarketVendor('stall-2', {});

      expect(vendor.name, '');
      expect(vendor.category, '');
      expect(vendor.rating, 0);
      expect(vendor.isVerified, isFalse);
      expect(vendor.isOpen, isTrue);
      expect(vendor.imageUrl, '');
      expect(vendor.distance, '');
      expect(vendor.tags, isNull);
    });

    test('never falls back to mock vendor rows (T6.5)', () {
      // A stall id that only exists in mock data still maps to the empty
      // live profile — no MockDataService lookups happen here.
      final vendor = stallToMarketVendor('stall-holder-001', {'name': ''});
      expect(vendor.id, 'stall-holder-001');
      expect(vendor.name, '');
    });
  });

  group('productFromStorageDoc', () {
    test('maps a Firestore product document to a VendorProduct', () {
      final product = productFromStorageDoc('prod-1', {
        'vendorId': 'stall-1',
        'name': 'Sweet Mangoes',
        'description': 'Carabao mangoes',
        'category': 'Fruits',
        'price': 150.0,
        'unit': 'kg',
        'imageUrl': 'https://example.com/mango.jpg',
        'isActive': true,
        'stockQuantity': 24.0,
        'initialStockQuantity': 40.0,
        'discountPercentage': 10.0,
      });

      expect(product.id, 'prod-1');
      expect(product.vendorId, 'stall-1');
      expect(product.name, 'Sweet Mangoes');
      expect(product.price, 150.0);
      expect(product.unit, 'kg');
      expect(product.stockQuantity, 24.0);
      expect(product.discountPercentage, 10);
      expect(product.hasDiscount, isTrue);
    });

    test('maps missing pricing/stock to zero, not mock values', () {
      final product = productFromStorageDoc('prod-2', {'name': 'Untitled'});
      expect(product.price, 0);
      expect(product.stockQuantity, 0);
      expect(product.discountPercentage, isNull);
      expect(product.hasDiscount, isFalse);
    });
  });

  MarketVendor vendor(String category) => MarketVendor(
    id: 'v1',
    name: 'Vendor',
    category: category,
    rating: 4,
    isVerified: true,
    distance: '',
    imageUrl: '',
  );

  VendorProduct product(String category) => VendorProduct(
    id: 'p1',
    vendorId: 'v1',
    name: 'Product',
    description: '',
    category: category,
    price: 10,
    unit: 'kg',
    imageUrl: '',
  );

  group('vendorMatchesCategory', () {
    test('matches by stall category', () {
      expect(vendorMatchesCategory(vendor('Fruits'), const [], 'Fruits'), true);
    });

    test("'All' is short-circuited by the repository, not the matcher", () {
      // The repository returns every vendor before the matcher runs, so the
      // matcher on 'All' matches nothing extra.
      expect(vendorMatchesCategory(vendor('Fruits'), const [], 'All'), isFalse);
    });

    test(
      'matches Maritatas through the rice/grain/spice/condiment buckets',
      () {
        expect(
          vendorMatchesCategory(vendor('Grains & Rice'), const [], 'Maritatas'),
          isTrue,
        );
        expect(
          vendorMatchesCategory(vendor('Fruits'), [
            product('Spices'),
          ], 'Sari-Sari'),
          isTrue,
        );
      },
    );

    test('does not match unrelated categories', () {
      expect(
        vendorMatchesCategory(vendor('Fruits'), [
          product('Vegetables'),
        ], 'Meat'),
        isFalse,
      );
    });
  });

  group('marketRepositoryProvider backend switch', () {
    test('firebase disabled resolves to the mock market', () {
      final container = ProviderContainer(
        overrides: [firebaseEnabledProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(marketRepositoryProvider),
        isA<MockMarketRepository>(),
      );
    });
  });
}
