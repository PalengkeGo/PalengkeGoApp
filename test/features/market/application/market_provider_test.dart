import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/market/application/market_provider.dart';

void main() {
  group('product search providers', () {
    test('allProductsProvider returns products across vendors', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final products = await container.read(allProductsProvider.future);

      expect(products, isNotEmpty);
      expect(
        products.map((product) => product.vendorId).toSet().length,
        greaterThan(1),
      );
    });

    test(
      'searchProductsProvider returns no results for an empty query',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(allProductsProvider.future);

        expect(
          await container.read(searchProductsProvider('').future),
          isEmpty,
        );
        expect(
          await container.read(searchProductsProvider('   ').future),
          isEmpty,
        );
      },
    );

    test(
      'searchProductsProvider filters products by name and category',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(allProductsProvider.future);

        final mangoResults = await container.read(
          searchProductsProvider('mango').future,
        );
        final fruitResults = await container.read(
          searchProductsProvider('fruit').future,
        );

        expect(mangoResults, isNotEmpty);
        expect(
          mangoResults.every(
            (product) => product.name.toLowerCase().contains('mango'),
          ),
          isTrue,
        );
        expect(fruitResults, isNotEmpty);
        expect(
          fruitResults.every(
            (product) =>
                product.name.toLowerCase().contains('fruit') ||
                product.category.toLowerCase().contains('fruit'),
          ),
          isTrue,
        );
      },
    );

    test('searchProductsProvider caps results for the dropdown', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(allProductsProvider.future);

      final results = await container.read(searchProductsProvider('a').future);

      expect(results.length, lessThanOrEqualTo(8));
    });
  });
}
