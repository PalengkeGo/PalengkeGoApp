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

    test(
      'customerUnreadCount only counts customer/both-targeted notifications',
      () {
        expect(service.customerUnreadCount, 1);
      },
    );

    test('vendorUnreadCount only counts vendor/both-targeted notifications', () {
      expect(service.vendorUnreadCount, 1);
    });

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

    test('onOrderStatusChanged adds two notifications (customer + vendor)', () {
      final beforeCount = service.all.length;
      service.onOrderStatusChanged(
        'TEST-001',
        'Test Stall',
        OrderStatus.preparing,
      );
      // Should add one customer notification + one vendor notification
      expect(service.all.length, beforeCount + 2);
    });

    test('new notifications from onOrderStatusChanged are unread', () {
      service.onOrderStatusChanged(
        'NEW-ORDER',
        'Sample Vendor',
        OrderStatus.preparing,
      );

      final fresh = service.all
          .where((n) => n.id.startsWith('NEW-ORDER'))
          .toList();
      expect(fresh, hasLength(2));
      expect(fresh.every((n) => !n.isRead), isTrue);
    });

    test('notifyListeners is called on markRead', () {
      var called = false;
      service.addListener(() => called = true);

      service.markRead('seed-c');

      expect(called, isTrue);
    });

    test('onOrderStatusChanged ready creates customer ready for pickup notification', () {
      service.onOrderStatusChanged(
        'ORDER-READY',
        'Lola Nena Fruits',
        OrderStatus.ready,
      );

      final customerNotifs = service.forCustomer
          .where((n) => n.id.startsWith('ORDER-READY'))
          .toList();
      expect(customerNotifs, hasLength(1));
      expect(customerNotifs.first.title, contains('ready for pick-up'));
      expect(customerNotifs.first.body, contains('ready for pick-up'));
    });

    test('onOrderStatusChanged outForDelivery creates customer out for delivery notification', () {
      service.onOrderStatusChanged(
        'ORDER-DISPATCH',
        'Mang Juan Meats',
        OrderStatus.outForDelivery,
      );

      final customerNotifs = service.forCustomer
          .where((n) => n.id.startsWith('ORDER-DISPATCH'))
          .toList();
      expect(customerNotifs, hasLength(1));
      expect(customerNotifs.first.title, contains('out for delivery'));
      expect(customerNotifs.first.body, contains('delivery address'));
    });
  });
}
