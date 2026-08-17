import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/home/application/announcement_provider.dart';
import 'package:palengkego/features/home/data/mock_announcement_repository.dart';

void main() {
  test('without Firebase resolves to the mock announcement repository', () {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(const AppConfig())],
    );
    addTearDown(container.dispose);

    expect(
      container.read(announcementRepositoryProvider),
      isA<MockAnnouncementRepository>(),
    );
  });

  test(
    'customer role receives general and customer announcements only',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig()),
authStateProvider.overrideWithValue(
          const AsyncValue.data(
            AppUser(
              uid: 'cust-1',
              email: 'customer@example.com',
              displayName: 'Customer',
              role: UserRole.customer,
            ),
          ),
        ),
        ],
      );
      addTearDown(container.dispose);

      final announcements = await container.read(
        activeAnnouncementsProvider.future,
      );
      final titles = announcements.map((a) => a.title).toList();

      expect(titles, contains('🎉 Grand Opening Sale!'));
      expect(titles, contains('🚚 Delivery Now Available!'));
      expect(titles, isNot(contains('📋 KYC Renewal Reminder')));
    },
  );

  test(
    'vendor role receives general and stallholder announcements only',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig()),
authStateProvider.overrideWithValue(
          const AsyncValue.data(
            AppUser(
              uid: 'vendor-1',
              email: 'vendor@example.com',
              displayName: 'Stall Holder',
              role: UserRole.vendor,
            ),
          ),
        ),
        ],
      );
      addTearDown(container.dispose);

      final announcements = await container.read(
        activeAnnouncementsProvider.future,
      );
      final titles = announcements.map((a) => a.title).toList();

      expect(titles, contains('🎉 Grand Opening Sale!'));
      expect(titles, contains('📋 KYC Renewal Reminder'));
      expect(titles, isNot(contains('🚚 Delivery Now Available!')));
    },
  );
}
