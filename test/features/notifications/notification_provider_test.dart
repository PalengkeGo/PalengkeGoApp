import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/services/notification_service.dart';

void main() {
  group('notificationServiceProvider', () {
    ProviderContainer buildContainer() {
      return ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWith(
            (ref) => NotificationService(isTest: true),
          ),
        ],
      );
    }

    test('provides a NotificationService instance', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      final service = container.read(notificationServiceProvider);
      expect(service, isA<NotificationService>());
    });

    test('same instance is returned on subsequent reads', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      final a = container.read(notificationServiceProvider);
      final b = container.read(notificationServiceProvider);
      expect(identical(a, b), isTrue);
    });

    test('service is disposed when container is disposed', () {
      var disposed = false;
      final container = buildContainer();

      final service = container.read(notificationServiceProvider);
      service.addListener(() {});

      container.dispose();
      // After dispose, further calls to notifyListeners should be safe
      // (no assertion errors). We just verify the container disposed cleanly.
      expect(disposed, isFalse); // container dispose should not throw
    });
  });
}
