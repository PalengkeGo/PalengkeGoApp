class AppCategories {
  /// Stall types — used in VendorStall.category and market browsing filters.
  /// Matches ERD: vendorStalls/{stallId}.category
  static const List<String> stall = [
    'Fresh Fish',
    'Dried Fish',
    'Meat',
    'Chicken',
    'Fruits',
    'Vegetables',
    'Maritatas',
    'Sari-Sari',
  ];

  /// Product types — used in VendorProduct.category.
  /// Per FINAL_FIXES_BLUEPRINT: Maritatas & Sari-Sari are stall types, NOT product tags.
  static const List<String> product = [
    'Fresh Fish',
    'Dried Fish',
    'Meat',
    'Chicken',
    'Fruits',
    'Vegetables',
  ];

  /// Alias — market browsing shows all stall categories.
  static const List<String> all = stall;
}
