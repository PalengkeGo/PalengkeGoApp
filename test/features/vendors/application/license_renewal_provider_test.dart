import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/vendors/application/license_renewal_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/data/mock_license_renewal_repository.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/license_renewal_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stall = VendorStall(
    stallId: 'stall-test-1',
    ownerUid: 'vendor-001',
    name: 'Test Stall',
    description: 'Test description',
    category: 'Vegetables',
    location: 'Stall 1',
  );

  LicenseRenewal renewalWith({
    required LicenseRenewalStatus status,
    Duration? offset,
  }) {
    final now = DateTime.now();
    return LicenseRenewal(
      renewalId: 'ren-test',
      stallId: stall.stallId,
      vendorUid: 'vendor-001',
      vendorName: 'Test Stall',
      periodStart: now.subtract(const Duration(days: 300)),
      periodEnd: offset == null
          ? now.add(const Duration(days: 365))
          : now.add(offset),
      amountPaid: 5000,
      paymentMethod: 'cash_at_office',
      submittedAt: now,
      status: status,
    );
  }

  ProviderContainer containerWith({
    LicenseRenewal? activeRenewal,
    LicenseRenewalRepository? repository,
  }) {
    return ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig()),
        vendorStallProvider.overrideWith(() => _StubStallNotifier(stall)),
        if (activeRenewal != null)
          activeRenewalProvider.overrideWith((ref) async => activeRenewal),
        if (repository != null)
          licenseRenewalRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  group('licenseRenewalRepositoryProvider backend switch', () {
    test('without Firebase resolves to the mock renewal repository', () {
      final container = containerWith();
      addTearDown(container.dispose);

      expect(
        container.read(licenseRenewalRepositoryProvider),
        isA<MockLicenseRenewalRepository>(),
      );
    });
  });

  group('computedLicenseStatusProvider', () {
    test('no renewal on file keeps license active', () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig()),
          vendorStallProvider.overrideWith(() => _StubStallNotifier(stall)),
          activeRenewalProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(activeRenewalProvider.future);
      expect(
        container.read(computedLicenseStatusProvider),
        LicenseStatus.active,
      );
    });

    test('pending renewal reports pending license', () async {
      final container = containerWith(
        activeRenewal: renewalWith(status: LicenseRenewalStatus.pending),
      );
      addTearDown(container.dispose);

      await container.read(activeRenewalProvider.future);
      expect(
        container.read(computedLicenseStatusProvider),
        LicenseStatus.pending,
      );
    });

    test('approved renewal expiring far out reports active', () async {
      final container = containerWith(
        activeRenewal: renewalWith(
          status: LicenseRenewalStatus.approved,
          offset: const Duration(days: 60),
        ),
      );
      addTearDown(container.dispose);

      await container.read(activeRenewalProvider.future);
      expect(
        container.read(computedLicenseStatusProvider),
        LicenseStatus.active,
      );
    });

    test(
      'approved renewal expiring within 30 days reports expiring soon',
      () async {
        final container = containerWith(
          activeRenewal: renewalWith(
            status: LicenseRenewalStatus.approved,
            offset: const Duration(days: 15),
          ),
        );
        addTearDown(container.dispose);

        await container.read(activeRenewalProvider.future);
        expect(
          container.read(computedLicenseStatusProvider),
          LicenseStatus.expiringSoon,
        );
      },
    );

    test('renewal expired within the last 30 days reports expired', () async {
      final container = containerWith(
        activeRenewal: renewalWith(
          status: LicenseRenewalStatus.approved,
          offset: const Duration(days: -15),
        ),
      );
      addTearDown(container.dispose);

      await container.read(activeRenewalProvider.future);
      expect(
        container.read(computedLicenseStatusProvider),
        LicenseStatus.expired,
      );
    });

    test('renewal expired more than 30 days ago reports suspended', () async {
      final container = containerWith(
        activeRenewal: renewalWith(
          status: LicenseRenewalStatus.approved,
          offset: const Duration(days: -45),
        ),
      );
      addTearDown(container.dispose);

      await container.read(activeRenewalProvider.future);
      expect(
        container.read(computedLicenseStatusProvider),
        LicenseStatus.suspended,
      );
    });
  });

  group('activeRenewalProvider / renewalHistoryProvider', () {
    test(
      'fetches the seeded renewal data for the logged-in vendor stall',
      () async {
        final seeded = renewalWith(status: LicenseRenewalStatus.approved);
        final repository = _RecordingRenewalRepository(seed: [seeded]);
        final container = containerWith(repository: repository);
        addTearDown(container.dispose);

        final active = await container.read(activeRenewalProvider.future);
        final history = await container.read(renewalHistoryProvider.future);

        expect(repository.queriedStallIds, ['stall-test-1', 'stall-test-1']);
        expect(active, seeded);
        expect(history, [seeded]);
      },
    );
  });

  group('LicenseRenewalProcessor.submitAndPay', () {
    test('submits the renewal and refreshes the fetched providers', () async {
      final repository = _RecordingRenewalRepository();
      final container = containerWith(repository: repository);
      addTearDown(container.dispose);

      final before = await container.read(renewalHistoryProvider.future);
      expect(before, isEmpty);

      final renewal = renewalWith(
        status: LicenseRenewalStatus.pending,
        offset: const Duration(days: 365),
      );
      await container
          .read(licenseRenewalProcessorProvider.notifier)
          .submitAndPay(renewal);

      expect(repository.submittedRenewals, [renewal]);

      final after = await container.read(renewalHistoryProvider.future);
      expect(after, hasLength(1));
      expect(after.first.status, LicenseRenewalStatus.pending);
    });

    test('repository failure is swallowed and nothing is recorded', () async {
      final repository = _RecordingRenewalRepository(throwOnSubmit: true);
      final container = containerWith(repository: repository);
      addTearDown(container.dispose);

      final renewal = renewalWith(status: LicenseRenewalStatus.pending);

      await container
          .read(licenseRenewalProcessorProvider.notifier)
          .submitAndPay(renewal);

      expect(repository.submittedRenewals, isEmpty);
    });
  });
}

class _StubStallNotifier extends VendorStallNotifier {
  _StubStallNotifier(this.stall);

  final VendorStall stall;

  @override
  VendorStall build() => stall;
}

class _RecordingRenewalRepository implements LicenseRenewalRepository {
  _RecordingRenewalRepository({
    this.throwOnSubmit = false,
    List<LicenseRenewal>? seed,
  }) : renewals = List.of(seed ?? const []);

  final bool throwOnSubmit;
  final List<LicenseRenewal> renewals;
  final List<String> queriedStallIds = [];

  List<LicenseRenewal> get submittedRenewals =>
      renewals.where((r) => r.renewalId == 'ren-test').toList();

  @override
  Future<LicenseRenewal> submitRenewal(LicenseRenewal renewal) async {
    if (throwOnSubmit) {
      throw Exception('renewal backend unreachable');
    }
    renewals.add(renewal);
    return renewal;
  }

  @override
  Future<LicenseRenewal?> getActiveRenewal(String stallId) async {
    queriedStallIds.add(stallId);
    return renewals.isEmpty ? null : renewals.last;
  }

  @override
  Future<List<LicenseRenewal>> getRenewalHistory(String stallId) async {
    queriedStallIds.add(stallId);
    return List.of(renewals);
  }

  @override
  Future<void> updateRenewalStatus(
    String renewalId,
    LicenseRenewalStatus status, {
    String? rejectionReason,
    String? reviewedBy,
  }) async {}
}
