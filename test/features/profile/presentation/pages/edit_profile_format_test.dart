import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/home/presentation/widgets/home_header.dart';
import 'package:palengkego/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:palengkego/features/profile/presentation/pages/profile_screen.dart';

void main() {
  group('formatJoinedSince', () {
    test('renders month and year in English short form', () {
      expect(
        formatJoinedSince(DateTime(2026, 8, 20)),
        'Aug 2026',
      );
      expect(
        formatJoinedSince(DateTime(2023, 10, 1)),
        'Oct 2023',
      );
    });

    test('handles a null date', () {
      expect(formatJoinedSince(null), '—');
    });
  });

  group('formatFirstName (Home Screen Header)', () {
    test('extracts first name from full name with middle initial', () {
      expect(formatFirstName('Rosario B Britanico'), 'Rosario');
    });

    test('extracts first name from single or two-word names', () {
      expect(formatFirstName('Rosario Britanico'), 'Rosario');
      expect(formatFirstName('Rosario'), 'Rosario');
    });

    test('handles empty or whitespace strings', () {
      expect(formatFirstName(''), '');
      expect(formatFirstName('   '), '');
    });
  });

  group('formatFirstAndLastName (Profile Screen)', () {
    test('extracts first and last name, omitting middle initial/name', () {
      expect(formatFirstAndLastName('Rosario B Britanico'), 'Rosario Britanico');
      expect(formatFirstAndLastName('Rosario B. Britanico'), 'Rosario Britanico');
    });

    test('handles names that already only have first and last name', () {
      expect(formatFirstAndLastName('Rosario Britanico'), 'Rosario Britanico');
    });

    test('handles single word name', () {
      expect(formatFirstAndLastName('Rosario'), 'Rosario');
    });

    test('handles empty string', () {
      expect(formatFirstAndLastName(''), '');
    });
  });
}