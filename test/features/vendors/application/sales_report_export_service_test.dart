import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/vendors/application/detailed_sales_report_export_service.dart';
import 'package:palengkego/features/vendors/application/sales_report_export_service.dart';

MarketOrder _order({
  required String id,
  required DateTime placedAt,
  required OrderStatus status,
  FulfillmentMethod fulfillment = FulfillmentMethod.delivery,
  String customerName = 'Juan Dela Cruz',
  double subtotal = 100,
  double deliveryFee = 0,
}) {
  final item = OrderLineItem(
    productId: 'p-$id',
    productName: 'Mango',
    quantity: subtotal,
    unitPrice: 1.0,
  );
  return MarketOrder(
    id: id,
    stallId: 'stall-diosa',
    vendorName: 'Diosa Fruit Stand',
    vendorImage: '',
    customerName: customerName,
    status: status,
    paymentStatus: PaymentStatus.paid,
    fulfillmentMethod: fulfillment,
    placedAt: placedAt,
    items: [item],
    deliveryAddress: '123 Main St, Manila',
    deliveryFee: deliveryFee,
    serviceFee: 10,
  );
}

List<String> _allCellValues(Sheet sheet) {
  final values = <String>[];
  for (final row in sheet.rows) {
    for (final cell in row) {
      values.add(cell?.value.toString() ?? '');
    }
  }
  return values;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stallName = 'Diosa Fruit Stand';
  final timestamp = DateTime(2026, 6, 25, 9, 8, 7);

  // Fixtures relative to "now" so period buckets stay deterministic.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  // completed, delivery: subtotal 300 + fee 50 + service 10 = 360
  final completedToday = _order(
    id: 'o1',
    placedAt: today,
    status: OrderStatus.completed,
    subtotal: 300,
    deliveryFee: 50,
  );
  // completed yesterday, delivery: 200 + 40 + 10 = 250
  final completedYesterday = _order(
    id: 'o2',
    placedAt: now.subtract(const Duration(days: 1)),
    status: OrderStatus.completed,
    subtotal: 200,
    deliveryFee: 40,
  );
  // completed 3 days ago, pickup: 240 + 0 + 10 = 250
  final completedThreeDaysAgo = _order(
    id: 'o3',
    placedAt: now.subtract(const Duration(days: 3)),
    status: OrderStatus.completed,
    fulfillment: FulfillmentMethod.pickup,
    subtotal: 240,
  );
  // completed 9 days ago: still inside the 7-day week window, but falls
  // in the previous calendar month (excluded from month-to-date)
  final completedNineDaysAgo = _order(
    id: 'o4',
    placedAt: now.subtract(const Duration(days: 9)),
    status: OrderStatus.completed,
    subtotal: 200,
    deliveryFee: 50,
  );
  // pending today — must never appear in reports
  final pendingToday = _order(
    id: 'o5',
    placedAt: now.subtract(const Duration(hours: 2)),
    status: OrderStatus.pending,
    subtotal: 999,
    deliveryFee: 50,
  );
  // completed last month — excluded from monthly report
  final completedLastMonth = _order(
    id: 'o6',
    placedAt: now.subtract(const Duration(days: 35)),
    status: OrderStatus.completed,
    fulfillment: FulfillmentMethod.pickup,
    subtotal: 490,
  );

  final fixtures = [
    completedToday,
    completedYesterday,
    completedThreeDaysAgo,
    completedNineDaysAgo,
    pendingToday,
    completedLastMonth,
  ];

  // Expected totals are derived from the service's own period rules
  // (Mon-Sun week, calendar month) so the assertions hold on any date.
  // The previous hardcoded P 860.00 only matched Thu-Sun with day <= 9
  // of the month: Monday excludes "now - 1 day", and "now - 9 days"
  // stays inside the month once the day-of-month exceeds 9.
  final (weekStart, weekEnd) = SalesReportExportService.periodBounds(
    'week',
    now,
  );
  final weekOrders = SalesReportExportService.completedInRange(
    fixtures,
    weekStart,
    weekEnd,
  );
  final (monthStart, monthEnd) = SalesReportExportService.periodBounds(
    'month',
    now,
  );
  final monthOrders = SalesReportExportService.completedInRange(
    fixtures,
    monthStart,
    monthEnd,
  );

  String fmt(double amount) => 'P ${NumberFormat('#,##0.00').format(amount)}';
  final weekExpected = fmt(weekOrders.fold(0.0, (sum, o) => sum + o.total));
  final monthExpected = fmt(monthOrders.fold(0.0, (sum, o) => sum + o.total));

  group('SalesReportExportService', () {
    test('buildFilename normalizes the report period and stall name', () {
      final name = SalesReportExportService.buildFilename(
        'This Week',
        timestamp,
        stallName,
      );

      expect(
        name,
        'diosa_fruit_stand_earnings_report_this week_2026-06-25_090807',
      );
    });

    test('buildPdf returns a valid PDF byte stream from real orders', () async {
      final bytes = await SalesReportExportService.buildPdf(
        'Week',
        stallName,
        fixtures,
      );
      final header = ascii.decode(bytes.take(4).toList());

      expect(bytes, isNotEmpty);
      expect(header, '%PDF');
      expect(bytes.length, greaterThan(1000));
    });

    test('buildExcel derives daily/weekly/monthly totals from orders', () {
      final bytes = SalesReportExportService.buildExcel(
        'Week',
        stallName,
        fixtures,
      );
      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook['Sales Report'];

      String? textAt(String cell) {
        return sheet.cell(CellIndex.indexByString(cell)).value?.toString();
      }

      expect(bytes, isNotEmpty);
      expect(textAt('A1'), 'PalengkeGo - Stall Earnings Report');
      expect(textAt('A4'), 'Summary Category');
      expect(textAt('A5'), 'Earnings Today');
      expect(textAt('B5'), 'P 360.00');
      expect(textAt('A6'), 'Earnings This Period');
      expect(textAt('B6'), weekExpected);
      expect(textAt('A7'), 'Total Monthly Earnings');
      expect(textAt('B7'), monthExpected);
    });

    test('buildExcel monthly report uses month-to-date totals only', () {
      final bytes = SalesReportExportService.buildExcel(
        'Month',
        stallName,
        fixtures,
      );
      final sheet = Excel.decodeBytes(bytes)['Sales Report'];

      String? textAt(String cell) {
        return sheet.cell(CellIndex.indexByString(cell)).value?.toString();
      }

      expect(textAt('A5'), 'Total Monthly Earnings');
      expect(textAt('B5'), monthExpected);
    });

    test('reports exclude non-completed orders', () {
      final bytes = SalesReportExportService.buildExcel(
        'Today',
        stallName,
        fixtures,
      );
      final values = _allCellValues(Excel.decodeBytes(bytes)['Sales Report']);

      expect(values.any((v) => v.contains('o5')), isFalse);
      expect(values.any((v) => v.contains('999.00')), isFalse);
    });

    test('reports contain no contact PII', () {
      final bytes = SalesReportExportService.buildExcel(
        'Week',
        stallName,
        fixtures,
      );
      final values = _allCellValues(Excel.decodeBytes(bytes)['Sales Report']);
      final asString = values.join(' ');

      expect(asString.contains('0917'), isFalse);
      expect(RegExp(r'09\d{9}').hasMatch(asString), isFalse);
    });
  });

  group('DetailedSalesReportExportService', () {
    test('buildPdf embeds real data and anonymizes the customer', () async {
      final bytes = await DetailedSalesReportExportService.buildPdf(
        fixtures,
        timestamp,
        stallName,
      );
      final header = ascii.decode(bytes.take(4).toList());
      final text = latin1.decode(bytes);

      expect(bytes, isNotEmpty);
      expect(header, '%PDF');
      expect(bytes.length, greaterThan(1000));

      // The export date comes from the passed timestamp, not a hardcoded date.
      expect(text.contains('2026-06-25'), isTrue);
      // Real order money is embedded (o1 grand total), proof it is not the
      // old fixed July-2026 placeholder report.
      expect(text.contains('360'), isTrue);
      // First name shown, but never surname, address, or phone fragments.
      expect(text.contains('Juan'), isTrue);
      expect(text.contains('Dela Cruz'), isFalse);
      expect(text.contains('123 Main St'), isFalse);
      expect(text.contains('0917'), isFalse);
    });

    test('customer column is anonymized to first name only', () {
      final bytes = DetailedSalesReportExportService.buildExcel(
        fixtures,
        timestamp,
        stallName,
      );
      final values = _allCellValues(Excel.decodeBytes(bytes)['Sales Report']);

      expect(values.contains('Juan'), isTrue);
      expect(values.any((v) => v.contains('Dela Cruz')), isFalse);
      expect(values.any((v) => v.contains('123 Main St')), isFalse);
    });
  });
}
