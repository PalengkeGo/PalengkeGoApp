import 'package:flutter/services.dart';

/// Forces all typed characters to lowercase — used on email fields.
class LowercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toLowerCase());
}

/// Formats a PH phone number as "xxx xxx xxxx" while typing.
class PhoneSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 10) text = text.substring(0, 10);
    var formatted = '';
    for (var i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) formatted += ' ';
      formatted += text[i];
    }

    // Attempt to maintain cursor position
    int cursor = newValue.selection.baseOffset;
    if (cursor > formatted.length) {
      cursor = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
