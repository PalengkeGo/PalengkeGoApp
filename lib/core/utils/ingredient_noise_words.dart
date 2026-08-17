/// Words stripped from ingredient/product names before token matching.
///
/// Shared by the recipe purchase matcher (`recipe_purchases_provider.dart`)
/// and the market ingredient recommender (`market_provider.dart`) so both
/// features tokenize and filter identically.
const ingredientNoiseWords = <String>{
  'fresh',
  'sweet',
  'large',
  'medium',
  'small',
  'pack',
  'can',
  'bag',
  'kg',
  'g',
  'ml',
  'l',
  'pcs',
  'piece',
  'pieces',
  'tbsp',
  'tsp',
  'cup',
  'cups',
  'sliced',
  'crushed',
  'whole',
  'with',
  'and',
  'sa',
  'na',
  'mix',
};
