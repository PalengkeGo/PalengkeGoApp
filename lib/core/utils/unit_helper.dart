class UnitHelper {
  static bool isPieceUnit(String name, [String description = '']) {
    name = name.toLowerCase();
    description = description.toLowerCase();
    return name.contains('latundan') ||
        name.contains('banana') ||
        name.contains('mango') ||
        name.contains('papaya') ||
        name.contains('pineapple') ||
        name.contains('tomato') ||
        name.contains('onion') ||
        name.contains('potato') ||
        name.contains('calamansi') ||
        name.contains('garlic') ||
        name.contains('ginger') ||
        name.contains('pepper') ||
        name.contains('chili') ||
        name.contains('cabbage') ||
        name.contains('carrot') ||
        name.contains('eggplant') ||
        name.contains('corn') ||
        name.contains('apple') ||
        name.contains('orange') ||
        name.contains('grapes') ||
        name.contains('watermelon') ||
        name.contains('lemon') ||
        name.contains('lime') ||
        name.contains('melon') ||
        name.contains('pear') ||
        name.contains('strawberry') ||
        name.contains('egg') ||
        name.contains('pc') ||
        description.contains('fruit') ||
        description.contains('vegetable') ||
        description.contains('piece') ||
        description.contains('maritatas') ||
        description.contains('sari-sari') ||
        description.contains('sari sari') ||
        description.contains('pc');
  }

  static bool isPieceProduct(dynamic product) {
    if (product.unit == 'pc') return true;
    if (product.unit == 'kg') return false;
    return isPieceUnit(product.name, product.description);
  }

  static String getUnitString(bool isPiece) {
    return isPiece ? 'pc' : 'kg';
  }
}
