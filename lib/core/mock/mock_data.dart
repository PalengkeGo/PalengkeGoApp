import 'package:palengkego/features/vendors/domain/vendor_review.dart';

class MockDataService {
  static List<Map<String, dynamic>> featuredVendors = [
    {
      'id': 'v1',
      'name': 'Diosa Fruit Stand',
      'category': 'Fruits',
      'rating': 4.8,
      'isVerified': true,
      'distance': '1.2km',
      'imageUrl':
          'https://images.unsplash.com/photo-1488459716781-31db52582fe9?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Stall 4',
      'marketSection': 'Fruit Section',
      'reviewCount': 128,
      'topReviewText': 'Always fresh and sweet!',
    },
    {
      'id': 'v2',
      'name': 'William Del Rosario Meat Shop',
      'category': 'Meat',
      'tags': ['Beef', 'Pork'],
      'rating': 4.5,
      'isVerified': true,
      'distance': '0.8km',
      'imageUrl':
          'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Block 15 | Stall 2',
      'marketSection': 'Meat Section',
      'reviewCount': 245,
      'topReviewText': 'Best pork cuts in the market.',
    },
    {
      'id': 'v3',
      "name": "Paul's Meat Shop",
      'category': 'Chicken',
      'rating': 4.9,
      'isVerified': false,
      'isOpen': false,
      'distance': '2.1km',
      'imageUrl':
          'https://images.unsplash.com/photo-1587593810167-a84920ea0781?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Stall #33',
      'marketSection': 'Meat Section',
      'reviewCount': 89,
      'topReviewText': 'Clean and fast service.',
    },
    {
      'id': 'v4',
      'name': 'Merly Diego Dried Fish Store',
      'category': 'Dried Fish',
      'rating': 4.7,
      'isVerified': true,
      'distance': '1.5km',
      'imageUrl':
          'https://images.unsplash.com/photo-1599084993091-1cb5c0721cc6?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Block 3 | Stall 4',
      'marketSection': 'Fish Section',
      'reviewCount': 312,
      'topReviewText': 'My go-to for tuyo and daing.',
    },
    {
      'id': 'v5',
      'name': 'Aling Nena Vegetables',
      'category': 'Vegetables',
      'rating': 4.9,
      'isVerified': true,
      'distance': '0.9km',
      'imageUrl':
          'https://images.unsplash.com/photo-1540420773420-3366772f4999?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Block 7 | Stall 2',
      'marketSection': 'Vegetable Section',
      'reviewCount': 421,
      'topReviewText': 'Very affordable veggies.',
    },
    {
      'id': 'v6',
      'name': 'Mang Pedro Seafood',
      'category': 'Fresh Fish',
      'rating': 4.7,
      'isVerified': false,
      'distance': '1.8km',
      'imageUrl':
          'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Block 14 | Stall 2',
      'marketSection': 'Fish Section',
    },
    {
      'id': 'v7',
      'name': 'Aling Susan\'s Maritatas Corner',
      'category': 'Maritatas',
      'rating': 4.8,
      'isVerified': true,
      'distance': '0.5km',
      'imageUrl':
          'https://images.unsplash.com/photo-1566843972142-a7fcb70de55a?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Stall 12',
      'marketSection': 'Dry Section',
    },
    {
      'id': 'v8',
      'name': 'Nena\'s Sari-Sari Store',
      'category': 'Sari-Sari',
      'rating': 4.6,
      'isVerified': true,
      'distance': '0.3km',
      'imageUrl':
          'https://images.unsplash.com/photo-1578916171728-46686eac8d58?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Stall 25',
      'marketSection': 'Dry Section',
    },
    {
      'id': 'v9',
      'name': 'Baka Corner',
      'category': 'Meat',
      'tags': ['Beef'],
      'rating': 4.9,
      'isVerified': true,
      'distance': '0.7km',
      'imageUrl':
          'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Block 16 | Stall 5',
      'marketSection': 'Meat Section',
      'reviewCount': 102,
      'topReviewText': 'Premium cuts of beef.',
    },
    {
      'id': 'v10',
      'name': 'El Patron Walastik Pares Mami',
      'category': 'Pares',
      'rating': 5.0,
      'isVerified': true,
      'distance': '0.4km',
      'imageUrl':
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Block 1 | Stall 8',
      'marketSection': 'Cooked Food',
      'reviewCount': 350,
      'topReviewText': 'Best pares in town!',
    },
    {
      'id': 'v11',
      'name': 'Kanto Pares Naga',
      'category': 'Pares',
      'rating': 4.9,
      'isVerified': true,
      'distance': '0.9km',
      'imageUrl':
          'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Stall 14',
      'marketSection': 'Cooked Food',
      'reviewCount': 210,
    },
    {
      'id': 'v12',
      'name': 'Kuya J - Robinson Place',
      'category': 'Filipino Cuisine',
      'rating': 4.8,
      'isVerified': true,
      'distance': '1.1km',
      'imageUrl':
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400&auto=format&fit=crop',
      'stallNumber': 'Food Court 3',
      'marketSection': 'Restaurant',
      'reviewCount': 540,
    },
  ];

  static List<Map<String, dynamic>> products = [
    // v1 - Diosa Fruit Stand (fruits)
    {
      'id': 'p1',
      'vendorId': 'v1',
      'name': 'Sweet Mangoes',
      'price': 150.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱150/kg',
      'description': 'Sweet and ripe',
      'imageUrl':
          'https://images.unsplash.com/photo-1553279768-865429fa0078?w=300&h=300&fit=crop',
    },
    {
      'id': 'p2',
      'vendorId': 'v1',
      'name': 'Bananas',
      'price': 60.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱60/kg',
      'description': 'Saba variety',
      'imageUrl':
          'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=300&h=300&fit=crop',
    },
    {
      'id': 'p3',
      'vendorId': 'v1',
      'name': 'Papaya',
      'price': 40.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱40/kg',
      'description': 'Fresh and sweet',
      'imageUrl':
          'https://images.unsplash.com/photo-1517282009859-f000ec3b26fe?w=300&h=300&fit=crop',
    },
    {
      'id': 'p4',
      'vendorId': 'v1',
      'name': 'Pineapple',
      'price': 55.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱55/kg',
      'description': 'Queen variety',
      'imageUrl':
          'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?w=300&h=300&fit=crop',
    },
    // v2 - William Del Rosario Meat Shop
    {
      'id': 'p5',
      'vendorId': 'v2',
      'name': 'Pork Belly',
      'price': 280.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱280/kg',
      'description': 'Fresh cut',
      'imageUrl':
          'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=300&h=300&fit=crop',
    },
    {
      'id': 'p6',
      'vendorId': 'v2',
      'name': 'Chicken Breast',
      'price': 220.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱220/kg',
      'description': 'Boneless',
      'imageUrl':
          'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=300&h=300&fit=crop',
    },
    {
      'id': 'p7',
      'vendorId': 'v2',
      'name': 'Ground Beef',
      'price': 350.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱350/kg',
      'description': 'Lean cut',
      'imageUrl':
          'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?w=300&h=300&fit=crop',
    },
    // v3 - Paul's Meat Shop (chicken)
    {
      'id': 'p8',
      'vendorId': 'v3',
      'name': 'Whole Chicken',
      'price': 180.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱180/kg',
      'description': 'Native chicken',
      'imageUrl':
          'https://images.unsplash.com/photo-1587593810167-a84920ea0781?w=300&h=300&fit=crop',
    },
    {
      'id': 'p9',
      'vendorId': 'v3',
      'name': 'Chicken Wings',
      'price': 200.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱200/kg',
      'description': 'Party wings',
      'imageUrl':
          'https://images.unsplash.com/photo-1527477396000-e27163b4bbed?w=300&h=300&fit=crop',
    },
    // v4 - Merly Diego Dried Fish Store
    {
      'id': 'p10',
      'vendorId': 'v4',
      'name': 'Dried Squid',
      'price': 300.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱300/kg',
      'description': 'Sun-dried',
      'imageUrl':
          'https://images.unsplash.com/photo-1599084993091-1cb5c0721cc6?w=300&h=300&fit=crop',
    },
    {
      'id': 'p11',
      'vendorId': 'v4',
      'name': 'Dried Fish',
      'price': 250.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱250/kg',
      'description': 'Daing na bangus',
      'imageUrl':
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=300&h=300&fit=crop',
    },
    // v9 - Baka Corner
    {
      'id': 'p99',
      'vendorId': 'v9',
      'name': 'Premium Sirloin',
      'price': 420.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱420/kg',
      'description': 'Tender and fresh sirloin cut',
      'imageUrl':
          'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?w=300&h=300&fit=crop',
    },
    // v5 - Aling Nena Vegetables
    {
      'id': 'p12',
      'vendorId': 'v5',
      'name': 'Tomatoes',
      'price': 40.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱40/kg',
      'description': 'Kamatis',
      'imageUrl':
          'https://images.unsplash.com/photo-1546470427-e26264e9b5a4?w=300&h=300&fit=crop',
    },
    {
      'id': 'p13',
      'vendorId': 'v5',
      'name': 'Onions',
      'price': 100.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱100/kg',
      'description': 'Sibuyas',
      'imageUrl':
          'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=300&h=300&fit=crop',
    },
    {
      'id': 'p14',
      'vendorId': 'v5',
      'name': 'Potatoes',
      'price': 80.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱80/kg',
      'description': 'Patatas',
      'imageUrl':
          'https://images.unsplash.com/photo-1518977676601-b28f0b0f0f0f?w=300&h=300&fit=crop',
    },
    {
      'id': 'p25',
      'vendorId': 'v5',
      'name': 'Jackfruit',
      'price': 80.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱80/kg',
      'description': 'Langka slices',
      'imageUrl':
          'https://images.unsplash.com/photo-1550828553-61ab9da4d7c0?w=300&h=300&fit=crop',
    },
    // v6 - Mang Pedro Seafood
    {
      'id': 'p15',
      'vendorId': 'v6',
      'name': 'Tilapia',
      'price': 120.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱120/kg',
      'description': 'Fresh catch',
      'imageUrl':
          'https://images.unsplash.com/photo-1599084993091-1cb5c0721cc6?w=300&h=300&fit=crop',
    },
    {
      'id': 'p16',
      'vendorId': 'v6',
      'name': 'Bangus (Milkfish)',
      'price': 180.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱180/kg',
      'description': 'Boneless available',
      'imageUrl':
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=300&h=300&fit=crop',
    },
    {
      'id': 'p17',
      'vendorId': 'v6',
      'name': 'Tiger Prawns',
      'price': 350.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱350/kg',
      'description': 'Large size',
      'imageUrl':
          'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=300&h=300&fit=crop',
    },
    {
      'id': 'p18',
      'vendorId': 'v6',
      'name': 'Squid',
      'price': 280.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱280/kg',
      'description': 'Fresh daily',
      'imageUrl':
          'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?w=300&h=300&fit=crop',
    },
    // v7 - Aling Susan's Maritatas Corner
    {
      'id': 'p19',
      'vendorId': 'v7',
      'name': 'Kwek-Kwek',
      'price': 25.00,
      'unit': 'pc',
      'weight': '1 pc',
      'pricePerKg': '₱25/pc',
      'description':
          'Deep fried quail eggs in orange batter. 5 pcs per portion.',
      'imageUrl':
          'https://images.unsplash.com/photo-1562608262-f4728f3957a0?w=300&h=300&fit=crop',
    },
    {
      'id': 'p20',
      'vendorId': 'v7',
      'name': 'Fishballs',
      'price': 20.00,
      'unit': 'pc',
      'weight': '1 pc',
      'pricePerKg': '₱20/pc',
      'description':
          'Fried fishballs with sweet and sour sauce. 10 pcs per portion.',
      'imageUrl':
          'https://images.unsplash.com/photo-1562608262-f4728f3957a0?w=300&h=300&fit=crop',
    },
    {
      'id': 'p23',
      'vendorId': 'v7',
      'name': 'Spring Roll Wrappers',
      'price': 40.00,
      'unit': 'pack',
      'weight': '1 pack',
      'pricePerKg': '₱40/pack',
      'description': 'Lumpia wrappers, approx 50 pcs',
      'imageUrl':
          'https://images.unsplash.com/photo-1598514982205-f36b96d1e8d4?w=300&h=300&fit=crop',
    },
    // v8 - Nena's Sari-Sari Store
    {
      'id': 'p21',
      'vendorId': 'v8',
      'name': 'Lucky Me Instant Noodles',
      'price': 15.00,
      'unit': 'pc',
      'weight': '1 pc',
      'pricePerKg': '₱15/pc',
      'description': 'Pancit Canton Extra Hot Chili flavor.',
      'imageUrl':
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300&h=300&fit=crop',
    },
    {
      'id': 'p22',
      'vendorId': 'v8',
      'name': 'Canned Sardines',
      'price': 25.00,
      'unit': 'pc',
      'weight': '1 pc',
      'pricePerKg': '₱25/pc',
      'description': 'Sardines in tomato sauce with chili.',
      'imageUrl':
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=300&h=300&fit=crop',
    },
    {
      'id': 'p24',
      'vendorId': 'v8',
      'name': 'Brown Sugar',
      'price': 70.00,
      'unit': 'kg',
      'weight': '1kg',
      'pricePerKg': '₱70/kg',
      'description': 'Washed sugar',
      'imageUrl':
          'https://images.unsplash.com/photo-1581428982868-e410dd047a90?w=300&h=300&fit=crop',
    },
    // Grocery, Dairy & Pares Additions for Recipe Ingredients
    {
      'id': 'p30',
      'vendorId': 'v8',
      'name': 'Alaska Sweetened Condensed Milk',
      'price': 65.00,
      'unit': 'can',
      'weight': '300ml',
      'pricePerKg': '₱65/can',
      'description': 'Rich and creamy condensed milk for desserts & shakes.',
      'imageUrl':
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300&h=300&fit=crop',
    },
    {
      'id': 'p31',
      'vendorId': 'v7',
      'name': 'Carnation Condensed Milk',
      'price': 58.00,
      'unit': 'can',
      'weight': '300ml',
      'pricePerKg': '₱58/can',
      'description': 'Sweetened condensed milk.',
      'imageUrl':
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300&h=300&fit=crop',
    },
    {
      'id': 'p32',
      'vendorId': 'v8',
      'name': 'M.Y. San Crushed Graham Crackers',
      'price': 75.00,
      'unit': 'pack',
      'weight': '200g',
      'pricePerKg': '₱75/pack',
      'description': 'Perfect for mango float and shakes.',
      'imageUrl':
          'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=300&h=300&fit=crop',
    },
    {
      'id': 'p33',
      'vendorId': 'v8',
      'name': 'Fresh Whole Milk',
      'price': 95.00,
      'unit': 'liter',
      'weight': '1L',
      'pricePerKg': '₱95/L',
      'description': '100% Pure Fresh Milk.',
      'imageUrl':
          'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=300&h=300&fit=crop',
    },
    {
      'id': 'p34',
      'vendorId': 'v8',
      'name': 'Purified Tube Ice',
      'price': 35.00,
      'unit': 'bag',
      'weight': '3kg',
      'pricePerKg': '₱35/bag',
      'description': 'Clean tube ice for beverages.',
      'imageUrl':
          'https://images.unsplash.com/photo-1517686469429-8bdb88b9f907?w=300&h=300&fit=crop',
    },
    {
      'id': 'p35',
      'vendorId': 'v10',
      'name': 'Beef Pares Rice',
      'price': 125.00,
      'unit': 'serving',
      'weight': '1 meal',
      'pricePerKg': '₱125/meal',
      'description': 'Tender beef stew with garlic rice and bone marrow soup.',
      'imageUrl':
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=300&h=300&fit=crop',
    },
    {
      'id': 'p36',
      'vendorId': 'v10',
      'name': 'Pares',
      'price': 110.00,
      'unit': 'serving',
      'weight': '1 meal',
      'pricePerKg': '₱110/meal',
      'description': 'Classic braised beef brisket pares.',
      'imageUrl':
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300&h=300&fit=crop',
    },
    {
      'id': 'p37',
      'vendorId': 'v11',
      'name': 'Beef Pares (Salo)',
      'price': 280.00,
      'unit': 'order',
      'weight': '2-3 servings',
      'pricePerKg': '₱280/order',
      'description': 'Family size braised beef pares.',
      'imageUrl':
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=300&h=300&fit=crop',
    },
    {
      'id': 'p38',
      'vendorId': 'v12',
      'name': 'Crispy Dinuguan',
      'price': 240.00,
      'unit': 'order',
      'weight': '1 serving',
      'pricePerKg': '₱240/order',
      'description':
          'Signature deep fried pork belly in savory dinuguan sauce.',
      'imageUrl':
          'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=300&h=300&fit=crop',
    },
    {
      'id': 'p39',
      'vendorId': 'v8',
      'name': 'Knorr Sinigang sa Sampalok Mix',
      'price': 22.00,
      'unit': 'pack',
      'weight': '44g',
      'pricePerKg': '₱22/pack',
      'description': 'Real tamarind taste for sinigang.',
      'imageUrl':
          'https://images.unsplash.com/photo-1599084993091-1cb5c0721cc6?w=300&h=300&fit=crop',
    },
  ];

  static List<Map<String, dynamic>> getProductsForVendor(String vendorId) {
    final vendor = featuredVendors.firstWhere(
      (v) => v['id'] == vendorId,
      orElse: () => {},
    );
    final vendorCategory = vendor['category'] ?? '';

    return products.where((p) => p['vendorId'] == vendorId).map((p) {
      if (p.containsKey('category')) return p;
      return {...p, 'category': vendorCategory};
    }).toList();
  }

  static List<Map<String, dynamic>> getDiscountedProducts() {
    return products
        .where((p) {
          final discount = p['discountPercentage'];
          // Guard: skip products where discountPercentage is null or not a number
          if (discount == null) return false;
          return (discount as num) > 0;
        })
        .map((p) {
          final vendor = featuredVendors.firstWhere(
            (v) => v['id'] == p['vendorId'],
            orElse: () => {},
          );
          final vendorCategory = vendor['category'] ?? '';
          if (p.containsKey('category')) return p;
          return {...p, 'category': vendorCategory};
        })
        .toList();
  }

  static void addProduct(Map<String, dynamic> product) {
    products.add(product);
  }

  static void updateProduct(Map<String, dynamic> product) {
    final index = products.indexWhere((p) => p['id'] == product['id']);
    if (index != -1) {
      products[index] = product;
    }
  }

  static void deleteProduct(String productId) {
    products.removeWhere((p) => p['id'] == productId);
  }

  static List<Map<String, dynamic>> reviews = [
    {
      'id': 'r1',
      'vendorId': 'v1',
      'customerName': 'Maria Santos',
      'rating': 5.0,
      'comment':
          'Always fresh and sweet! The mangoes are the best in the market.',
      'date': '2023-10-25T08:30:00Z',
      'reviewType': 'product',
      'productName': 'Sweet Mangoes',
    },
    {
      'id': 'r2',
      'vendorId': 'v1',
      'customerName': 'Juan Dela Cruz',
      'rating': 4.5,
      'comment':
          'Good quality fruits, but sometimes the bananas are a bit too ripe.',
      'date': '2023-10-20T10:15:00Z',
      'reviewType': 'product',
      'productName': 'Bananas',
    },
    {
      'id': 'r3',
      'vendorId': 'v1',
      'customerName': 'Elena Reyes',
      'rating': 5.0,
      'comment': 'My go-to stall for fresh papayas. Highly recommended!',
      'date': '2023-10-18T09:45:00Z',
      'reviewType': 'product',
      'productName': 'Papaya',
    },
    {
      'id': 'r4',
      'vendorId': 'v2',
      'customerName': 'Pedro Gomez',
      'rating': 4.0,
      'comment': 'Best pork cuts in the market. Very clean stall.',
      'date': '2023-10-22T07:20:00Z',
      'reviewType': 'product',
      'productName': 'Pork Belly',
    },
    {
      'id': 'r5',
      'vendorId': 'v2',
      'customerName': 'Ana Lim',
      'rating': 5.0,
      'comment': 'Meat is always fresh. The vendor is very accommodating.',
      'date': '2023-10-15T08:00:00Z',
      'reviewType': 'vendor',
    },
    {
      'id': 'r6',
      'vendorId': 'v2',
      'customerName': 'Carlos Cruz',
      'rating': 4.5,
      'comment': 'Reasonable prices and good quality beef.',
      'date': '2023-10-10T11:30:00Z',
      'reviewType': 'product',
      'productName': 'Ground Beef',
    },
    {
      'id': 'r7',
      'vendorId': 'v3',
      'customerName': 'Liza Soberano',
      'rating': 5.0,
      'comment': 'Clean and fast service. Chicken is fresh.',
      'date': '2023-10-24T08:45:00Z',
      'reviewType': 'vendor',
    },
    {
      'id': 'r8',
      'vendorId': 'v4',
      'customerName': 'Nadine Lustre',
      'rating': 4.5,
      'comment': 'My go-to for tuyo and daing. Not too salty!',
      'date': '2023-10-21T09:10:00Z',
      'reviewType': 'product',
      'productName': 'Dried Fish',
    },
    {
      'id': 'r9',
      'vendorId': 'v5',
      'customerName': 'Kathryn Bernardo',
      'rating': 5.0,
      'comment': 'Very affordable veggies. Always crisp and fresh.',
      'date': '2023-10-23T07:50:00Z',
      'reviewType': 'vendor',
    },
    {
      'id': 'r10',
      'vendorId': 'v1',
      'customerName': 'Dingdong Dantes',
      'rating': 4.0,
      'comment': 'Friendly vendor and good variety of fruits.',
      'date': '2023-10-19T10:05:00Z',
      'reviewType': 'vendor',
    },
    {
      'id': 'r11',
      'vendorId': 'v1',
      'customerName': 'Bea Alonzo',
      'rating': 5.0,
      'comment':
          'The pineapples are incredibly sweet and fresh. Will buy again!',
      'date': '2023-10-17T11:00:00Z',
      'reviewType': 'product',
      'productName': 'Pineapple',
    },
    {
      'id': 'r12',
      'vendorId': 'v1',
      'customerName': 'Richard Gomez',
      'rating': 3.0,
      'comment':
          'Fruits were okay but not as fresh as usual. Maybe just an off day.',
      'date': '2023-10-12T08:10:00Z',
      'reviewType': 'vendor',
    },
    {
      'id': 'r13',
      'vendorId': 'v1',
      'customerName': 'Sharon Cuneta',
      'rating': 5.0,
      'comment':
          'Always consistent quality. My family loves the mangoes from here!',
      'date': '2023-10-08T09:30:00Z',
      'reviewType': 'product',
      'productName': 'Sweet Mangoes',
    },
    {
      'id': 'r14',
      'vendorId': 'v1',
      'customerName': 'Piolo Pascual',
      'rating': 4.5,
      'comment': 'Very fresh produce. Vendor is always polite and helpful.',
      'date': '2023-10-05T07:45:00Z',
      'reviewType': 'vendor',
    },
  ];

  static void decreaseProductStockByName(
    String productName,
    String vendorName,
    double quantity,
  ) {
    // Find the vendor ID first
    final vendor = featuredVendors.firstWhere(
      (v) => v['name'] == vendorName,
      orElse: () => {'id': ''},
    );
    final vendorId = vendor['id'] as String;
    if (vendorId.isEmpty) return;

    final productIndex = products.indexWhere(
      (p) => p['name'] == productName && p['vendorId'] == vendorId,
    );
    if (productIndex != -1) {
      final currentStock =
          (products[productIndex]['stockQuantity'] as num?)?.toDouble() ?? 15.0;
      // Seed initialStockQuantity the first time we see this product
      if (products[productIndex]['initialStockQuantity'] == null) {
        products[productIndex]['initialStockQuantity'] = currentStock;
      }
      final newStock = (currentStock - quantity).clamp(0.0, 9999.0);
      products[productIndex]['stockQuantity'] = newStock;
      // Auto-disable In Stock toggle when stock reaches 0
      if (newStock <= 0) {
        products[productIndex]['isActive'] = false;
      }
    }
  }

  /// Maps the demo stall account's uid/stallId ('stall holder-001') to the
  /// mock catalog vendor id ('v1') that keys its reviews and profile.
  static String resolveMockVendorId(String stallIdOrUid) {
    return stallIdOrUid == 'stall holder-001' ? 'v1' : stallIdOrUid;
  }

  static void addReview(Map<String, dynamic> review) {
    reviews.add(review);
  }

  static List<Map<String, dynamic>> getReviewsForVendor(String vendorId) {
    return reviews.where((r) => r['vendorId'] == vendorId).toList();
  }

  /// Returns typed [VendorReview] objects for a given vendor.
  static List<VendorReview> getReviewsAsObjects(String vendorId) {
    return getReviewsForVendor(vendorId).map((r) {
      final isProduct = r['reviewType'] == 'product';
      return VendorReview(
        id: r['id'] as String? ?? '',
        vendorId: r['vendorId'] as String? ?? '',
        customerId: r['customerId'] as String? ?? '',
        customerName: r['customerName'] as String? ?? '',
        rating: (r['rating'] as num).toDouble(),
        comment: r['comment'] as String,
        date: DateTime.parse(r['date'] as String),
        reviewType: isProduct ? ReviewType.product : ReviewType.vendor,
        productName: isProduct ? r['productName'] as String? : null,
      );
    }).toList();
  }
}
