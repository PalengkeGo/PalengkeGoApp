import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';

const _samplePngDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  testWidgets(
    'AdaptiveImage reuses decoded Base64 bytes across widgets and enables gaplessPlayback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AdaptiveImage(_samplePngDataUri, width: 40, height: 40),
                AdaptiveImage(_samplePngDataUri, width: 40, height: 40),
              ],
            ),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      expect(images[0].gaplessPlayback, isTrue);
      expect(images[1].gaplessPlayback, isTrue);

      final firstProvider = images[0].image;
      final secondProvider = images[1].image;
      expect(firstProvider, isA<ResizeImage>());
      expect(secondProvider, isA<ResizeImage>());
      final firstResized = firstProvider as ResizeImage;
      final secondResized = secondProvider as ResizeImage;
      expect(firstResized.width, isNotNull);
      expect(firstResized.height, isNull);
      final firstBytes = (firstResized.imageProvider as MemoryImage).bytes;
      final secondBytes = (secondResized.imageProvider as MemoryImage).bytes;
      expect(identical(firstBytes, secondBytes), isTrue);
    },
  );

  testWidgets(
    'AdaptiveImage sets single-axis decode cache width and strips Supabase signed tokens from cacheKey',
    (tester) async {
      late Widget builtSigned;
      late Widget builtCapped;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2.0),
            child: Builder(
              builder: (context) {
                builtSigned = const AdaptiveImage(
                  'https://example.supabase.co/storage/v1/object/sign/products/mango.jpg?token=secret-jwt-123',
                  width: 120,
                  height: 120,
                ).build(context);

                builtCapped = const AdaptiveImage(
                  'https://example.supabase.co/storage/v1/object/sign/products/stall.jpg?token=secret-jwt-456',
                  width: 120,
                  maxCacheWidth: 480,
                ).build(context);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(builtSigned, isA<CachedNetworkImage>());
      final signedWidget = builtSigned as CachedNetworkImage;
      expect(
        signedWidget.cacheKey,
        'https://example.supabase.co/storage/v1/object/sign/products/mango.jpg',
      );
      expect(signedWidget.memCacheWidth, 240);
      expect(signedWidget.memCacheHeight, isNull);

      expect(builtCapped, isA<CachedNetworkImage>());
      final cappedWidget = builtCapped as CachedNetworkImage;
      expect(cappedWidget.memCacheWidth, 480);
      expect(cappedWidget.memCacheHeight, isNull);
    },
  );
}
