import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/home/presentation/widgets/discounted_item_card.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

void main() {
  const product = MarketProduct(
    id: 'p1',
    vendorId: 'v1',
    name: 'Sweet Mangoes',
    price: 200,
    unit: 'kg',
    description: 'Fresh mangoes',
    category: 'Fruits',
    imageUrl: '',
    stockQuantity: 8,
    discountPercentage: 25,
  );

  testWidgets('DiscountedItemCard shows discount label and discounted price', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorRepositoryProvider.overrideWithValue(_FakeVendorRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DiscountedItemCard(product: product, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('25% OFF'), findsOneWidget);
    expect(find.text('Sweet Mangoes'), findsOneWidget);
    expect(find.text('Fruits'), findsOneWidget);
    expect(find.textContaining('200'), findsOneWidget);
    expect(find.textContaining('150'), findsOneWidget);
    expect(find.text('Diosa Fruit Stand'), findsOneWidget);
  });
}

class _FakeVendorRepository implements VendorRepository {
  @override
  Future<VendorProfile> getVendorProfile(String id) async {
    return const VendorProfile(
      id: 'v1',
      name: 'Diosa Fruit Stand',
      category: 'Fruits',
      rating: 4.8,
      reviewCount: 120,
      isOpen: true,
      stallLocation: 'A1',
      imageUrl: '',
      avatarUrl: '',
    );
  }

  @override
  Future<List<VendorProduct>> getVendorProducts(String vendorId) async => [];

  @override
  Future<VendorProduct> addVendorProduct(VendorProduct product) async =>
      product;

  @override
  Future<VendorProduct> updateVendorProduct(VendorProduct product) async {
    return product;
  }

  @override
  Future<void> deleteVendorProduct(String productId) async {}

  @override
  Future<VendorStall> getVendorStall(String stallId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateVendorStall(VendorStall stall) async {}

  @override
  Future<List<VendorReview>> getReviews(String stallId) async => [];

  @override
  Future<void> addReview(VendorReview review) async {}

  @override
  Future<List<SalesSummary>> getSalesSummary(
    String stallId, {
    required DateTime from,
    required DateTime to,
  }) async {
    return [];
  }
}
