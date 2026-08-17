/// Formats a quantity + unit pair into a human-readable label.
/// Handles fractional kg values (1/8, 1/4, etc.) and integer pc values.
String formatQuantityLabel(double quantity, String unit) {
  if (unit == 'kg') {
    final int whole = quantity.truncate();
    final double fraction = (quantity - whole).abs();
    String fractionStr = '';

    if ((fraction - 0.125).abs() < 0.005) {
      fractionStr = '1/8';
    } else if ((fraction - 0.25).abs() < 0.005) {
      fractionStr = '1/4';
    } else if ((fraction - 0.375).abs() < 0.005) {
      fractionStr = '3/8';
    } else if ((fraction - 0.5).abs() < 0.005) {
      fractionStr = '1/2';
    } else if ((fraction - 0.625).abs() < 0.005) {
      fractionStr = '5/8';
    } else if ((fraction - 0.75).abs() < 0.005) {
      fractionStr = '3/4';
    } else if ((fraction - 0.875).abs() < 0.005) {
      fractionStr = '7/8';
    } else if (fraction > 0.01) {
      final String fullStr = quantity
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      return '$fullStr kg';
    }

    final String val = whole == 0
        ? (fractionStr.isNotEmpty ? fractionStr : '0')
        : (fractionStr.isNotEmpty ? '$whole $fractionStr' : whole.toString());
    return '$val kg';
  }
  final String qtyStr = quantity.truncateToDouble() == quantity
      ? quantity.toInt().toString()
      : quantity.toString();
  return '$qtyStr $unit';
}
