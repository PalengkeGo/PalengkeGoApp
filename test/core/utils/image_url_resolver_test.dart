import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';

void main() {
  group('resolveImageUrl', () {
    test('returns null for null, empty for empty', () {
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl(''), '');
      expect(resolveImageUrl('   '), '');
    });

    test('transforms Google Drive view URL to direct lh3 CDN endpoint', () {
      const driveUrl =
          'https://drive.google.com/file/d/1hgCQchY5rzpAjpK_Z7iQTQTgTJWJsqIh/view?usp=drive_link';
      expect(
        resolveImageUrl(driveUrl),
        'https://lh3.googleusercontent.com/d/1hgCQchY5rzpAjpK_Z7iQTQTgTJWJsqIh',
      );
    });

    test('transforms Google Drive uc / open URL to direct lh3 CDN endpoint', () {
      const driveUcUrl =
          'https://drive.google.com/uc?id=1hgCQchY5rzpAjpK_Z7iQTQTgTJWJsqIh&export=download';
      expect(
        resolveImageUrl(driveUcUrl),
        'https://lh3.googleusercontent.com/d/1hgCQchY5rzpAjpK_Z7iQTQTgTJWJsqIh',
      );
    });

    test('preserves direct web URLs', () {
      const webUrl = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c';
      expect(resolveImageUrl(webUrl), webUrl);
    });

    test('prepends supabaseUrl to relative storage path', () {
      const relPath = '/storage/v1/object/public/recipes/tuna_kilawin.png';
      expect(
        resolveImageUrl(relPath, supabaseUrl: 'https://test.supabase.co'),
        'https://test.supabase.co/storage/v1/object/public/recipes/tuna_kilawin.png',
      );
    });

    test('resolves bucket/path with supabaseUrl', () {
      const bucketPath = 'recipes/tuna_kilawin.png';
      expect(
        resolveImageUrl(bucketPath, supabaseUrl: 'https://test.supabase.co'),
        'https://test.supabase.co/storage/v1/object/public/recipes/tuna_kilawin.png',
      );
    });

    test('resolves bare filename to recipes bucket with supabaseUrl', () {
      const filename = 'tuna_kilawin.png';
      expect(
        resolveImageUrl(filename, supabaseUrl: 'https://test.supabase.co'),
        'https://test.supabase.co/storage/v1/object/public/recipes/tuna_kilawin.png',
      );
    });
  });
}
