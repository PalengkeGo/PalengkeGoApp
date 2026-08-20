import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/profile/presentation/pages/edit_profile_screen.dart';

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
}