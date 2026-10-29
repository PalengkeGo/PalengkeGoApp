import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

void main() {
  group('NotificationService', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService(isTest: true);
      // Seed two notifications: one customer-visible, one vendor-only.
      service.addNotification(
        AppNotification(
          id: 'seed-c',
          type: NotificationType.promo,
          target: NotificationTarget.customer,
          title: 'Organic Week!',
          body: '20% off leafy greens.',
          createdAt: DateTime(2026, 7, 7, 10),
        ),
      );
      service.addNotification(
        AppNotification(
          id: 'seed-v',
          type: NotificationType.review,
          target: NotificationTarget.vendor,
          title: 'New 5-Star Rating!',
          body: 'A customer left a review.',
          createdAt: DateTime(2026, 7, 8, 8),
        ),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('starts empty until notifications are added', () {
      final fresh = NotificationService(isTest: true);
      expect(fresh.all, isEmpty);
      fresh.dispose();
    });

    test('realtime account notices appear once in the in-app inbox', () async {
      final row = {
        'notification_id': 'moderation-1',
        'title': 'Account suspension',
        'body': 'Your account is temporarily suspended.',
        'type': 'system_announcement',
        'created_at': '2026-10-26T06:00:00Z',
        'is_read': false,
      };

      final notice = await service.acceptRemoteNotification(
        row,
        showDeviceNotification: false,
      );
      final duplicate = await service.acceptRemoteNotification(
        row,
        showDeviceNotification: false,
      );

      expect(notice?.title, 'Account suspension');
      expect(duplicate, isNull);
      expect(
        service.forCustomer.where((item) => item.id == 'moderation-1'),
        hasLength(1),
      );
    });

    test('realtime KYC rejection appears once with its reason', () async {
      final row = {
        'notification_id': 'kyc-rejected-1',
        'title': 'Application rejected',
        'body': 'MEPO rejected your application. Reason: Missing permit.',
        'type': 'kyc_update',
        'created_at': '2026-10-26T06:00:00Z',
        'is_read': false,
      };

      final notice = await service.acceptRemoteNotification(
        row,
        showDeviceNotification: false,
      );
      final duplicate = await service.acceptRemoteNotification(
        row,
        showDeviceNotification: false,
      );

      expect(notice?.title, 'Application rejected');
      expect(notice?.body, contains('Missing permit'));
      expect(duplicate, isNull);
      expect(
        service.forCustomer.where((item) => item.id == 'kyc-rejected-1'),
        hasLength(1),
      );
    });

    test('product price warnings arrive as account notifications', () async {
      final notice = await service.acceptRemoteNotification({
        'notification_id': 'price-warning-1',
        'title': 'Product price warning',
        'body':
            'Review your listed tomato price.\n\nMEPO weekly price monitoring: https://facebook.com/mepo/posts/123',
        'reference_id': 'tomato-product-1',
        'type': 'account_action',
        'created_at': '2026-10-27T06:00:00Z',
        'is_read': false,
      });

      expect(notice?.title, 'Product price warning');
      expect(notice?.referenceId, 'tomato-product-1');
      expect(notice?.mepoPricePostUri?.host, 'facebook.com');
      expect(
        notice?.displayBody,
        isNot(contains('MEPO weekly price monitoring')),
      );
      expect(
        service.forVendor.where((item) => item.id == 'price-warning-1'),
        hasLength(1),
      );
      expect(service.unacknowledgedWarnings, hasLength(1));
    });

    test(
      'customerUnreadCount only counts customer/both-targeted notifications',
      () {
        expect(service.customerUnreadCount, 1);
      },
    );

    test(
      'vendorUnreadCount only counts vendor/both-targeted notifications',
      () {
        expect(service.vendorUnreadCount, 1);
      },
    );

    test('markAsRead reduces unread customer count', () {
      final before = service.customerUnreadCount;
      service.markRead('seed-c');
      expect(service.customerUnreadCount, lessThan(before));
    });

    test('markAllRead zeroes out customer unread count', () {
      service.markAllRead(NotificationTarget.customer);
      expect(service.customerUnreadCount, 0);
    });

    test('markAllRead zeroes out vendor unread count', () {
      service.markAllRead(NotificationTarget.vendor);
      expect(service.vendorUnreadCount, 0);
    });

    test(
      'onOrderStatusChanged adds customer notification for order milestone',
      () {
        final beforeCount = service.all.length;
        service.onOrderStatusChanged(
          'TEST-001',
          'Test Stall',
          OrderStatus.preparing,
        );
        // Customer milestone notification added
        expect(service.all.length, beforeCount + 1);
        expect(service.all.first.target, NotificationTarget.customer);
      },
    );

    test('new notifications from onOrderStatusChanged are unread', () {
      service.onOrderStatusChanged(
        'NEW-ORDER',
        'Sample Vendor',
        OrderStatus.preparing,
      );

      final fresh = service.all
          .where((n) => n.id.startsWith('NEW-ORDER'))
          .toList();
      expect(fresh, hasLength(1));
      expect(fresh.every((n) => !n.isRead), isTrue);
    });

    test('notifyListeners is called on markRead', () {
      var called = false;
      service.addListener(() => called = true);

      service.markRead('seed-c');

      expect(called, isTrue);
    });

    test(
      'onOrderStatusChanged ready creates customer ready for pickup notification',
      () {
        service.onOrderStatusChanged(
          'ORDER-READY',
          'Lola Nena Fruits',
          OrderStatus.ready,
          isPickup: true,
        );

        final customerNotifs = service.forCustomer
            .where((n) => n.id.startsWith('ORDER-READY'))
            .toList();
        expect(customerNotifs, hasLength(1));
        expect(
          customerNotifs.first.title.toLowerCase(),
          contains('ready for pick-up'),
        );
        expect(customerNotifs.first.body, contains('pick-up'));
      },
    );

    test(
      'onOrderStatusChanged outForDelivery creates customer out for delivery notification',
      () {
        service.onOrderStatusChanged(
          'ORDER-DISPATCH',
          'Mang Juan Meats',
          OrderStatus.outForDelivery,
        );

        final customerNotifs = service.forCustomer
            .where((n) => n.id.startsWith('ORDER-DISPATCH'))
            .toList();
        expect(customerNotifs, hasLength(1));
        expect(
          customerNotifs.first.title.toLowerCase(),
          contains('out for delivery'),
        );
        expect(customerNotifs.first.body, contains('delivery address'));
      },
    );

    test(
      'onNewOrderArrived creates vendor notification with first and last name only and address',
      () async {
        await service.onNewOrderArrived(
          'V-001',
          'Rosario B Britanico',
          500.0,
          deliveryAddress: 'San Felipe, Naga City',
        );
        final vendorNotifs = service.forVendor
            .where((n) => n.referenceId == 'V-001')
            .toList();
        expect(vendorNotifs, hasLength(1));
        expect(vendorNotifs.first.target, NotificationTarget.vendor);
        expect(vendorNotifs.first.title, 'New Order Arrived! 🔔');
        expect(
          vendorNotifs.first.body,
          'An order has arrived from Rosario Britanico (San Felipe, Naga City).',
        );

        // Must NEVER appear in customer view
        final customerNotifs = service.forCustomer
            .where((n) => n.referenceId == 'V-001')
            .toList();
        expect(customerNotifs, isEmpty);
      },
    );

    test(
      'onNewOrderArrived formats pickup correctly and excludes from customer notifications',
      () async {
        await service.onNewOrderArrived(
          'V-002',
          'Maria Clara De Los Santos',
          300.0,
          isPickup: true,
        );
        final vendorNotifs = service.forVendor
            .where((n) => n.referenceId == 'V-002')
            .toList();
        expect(vendorNotifs, hasLength(1));
        expect(
          vendorNotifs.first.body,
          'An order has arrived from Maria Santos (Store Pick-Up).',
        );

        // Must NEVER appear in customer view
        expect(
          service.forCustomer.where((n) => n.referenceId == 'V-002'),
          isEmpty,
        );
      },
    );

    test(
      'onPrepTimeUpdated creates customer notification with pickup instructions',
      () async {
        await service.onPrepTimeUpdated(
          'ORDER-PREP',
          'Tindahan',
          DateTime(2026, 7, 7, 14, 30),
          isPickup: true,
        );
        final customerNotifs = service.forCustomer
            .where((n) => n.referenceId == 'ORDER-PREP')
            .toList();
        expect(customerNotifs, hasLength(1));
        expect(customerNotifs.first.title, contains('Pick-Up'));
      },
    );

    test('onSpecialOffer creates customer promo notification', () async {
      await service.onSpecialOffer(
        offerId: 'promo-1',
        stallName: 'Mang Juan Meats',
        title: 'Fresh Pork Belly 15% Off',
        body: 'Grab yours before noon!',
      );
      final customerNotifs = service.forCustomer
          .where(
            (n) => n.type == NotificationType.promo && n.id.contains('promo-1'),
          )
          .toList();
      expect(customerNotifs, hasLength(1));
      expect(customerNotifs.first.target, NotificationTarget.customer);
    });
  });
}
