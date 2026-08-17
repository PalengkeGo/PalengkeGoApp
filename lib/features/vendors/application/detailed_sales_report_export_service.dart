import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';

class DetailedSalesReportExportService {
  const DetailedSalesReportExportService._();

  static String buildFilename(DateTime timestamp, String stallName) {
    final cleanStall = stallName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
    final formattedTimestamp = DateFormat(
      'yyyy-MM-dd_HHmmss',
    ).format(timestamp);
    return '${cleanStall}_detailed_sales_report_$formattedTimestamp';
  }

  static String _formatP(double amount) {
    return 'P ${NumberFormat('#,##0.00').format(amount)}';
  }

  static String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Customer';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static Future<Uint8List> buildPdf(
    List<MarketOrder> orders,
    DateTime timestamp,
    String stallName,
  ) async {
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final pdf = pw.Document(theme: theme, compress: false);

    final dateHeaderStr = DateFormat('yyyy-MM-dd').format(timestamp);
    final totalOrdersCount = orders.length;
    final deliveryCount = orders
        .where(
          (o) => o.fulfillmentMethod.name.toLowerCase().contains('delivery'),
        )
        .length;
    final pickupCount = totalOrdersCount - deliveryCount;
    final subtotalSales = orders.fold(0.0, (sum, o) => sum + o.subtotal);
    final deliveryFees = orders.fold(0.0, (sum, o) => sum + o.deliveryFee);
    final grandTotalSales = orders.fold(0.0, (sum, o) => sum + o.total);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Column(
            children: [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF0B372B),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PalengkeGo Market',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Detailed Order Sales History Report',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFA7F3D0),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Stall: $stallName',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Export Date: $dateHeaderStr',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFD1D5DB),
                            fontSize: 8,
                          ),
                        ),
                        pw.Text(
                          'Export Filter: All Fulfillment Types',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFD1D5DB),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'PalengkeGo Stall Holder Detailed Sales Report | Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          );
        },
        build: (context) {
          return [
            // Report Summary Bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFECFDF5),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFA7F3D0),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'Report Summary: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF064E3B),
                    ),
                  ),
                  pw.Text(
                    'Total Orders: $totalOrdersCount  |  Delivery: $deliveryCount  |  Pickup: $pickupCount  |  Total Volume: ${_formatP(grandTotalSales)}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Itemized Data Table
            pw.TableHelper.fromTextArray(
              context: context,
              columnWidths: {
                0: const pw.FixedColumnWidth(65), // Date / Time
                1: const pw.FixedColumnWidth(60), // Order ID
                2: const pw.FixedColumnWidth(75), // Customer
                3: const pw.FixedColumnWidth(50), // Type
                4: const pw.FixedColumnWidth(55), // Payment
                5: const pw.FlexColumnWidth(1), // Items Purchased
                6: const pw.FixedColumnWidth(65), // Total Amount
              },
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0B372B),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.topLeft,
              data: <List<dynamic>>[
                [
                  'DATE /\nTIME',
                  'ORDER\nID',
                  'CUSTOMER',
                  'TYPE',
                  'PAYMENT',
                  'ITEMS PURCHASED (QTY/WEIGHT x PRICE)',
                  'TOTAL\nAMOUNT',
                ],
                ...orders.map((o) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(o.placedAt);
                  final timeStr =
                      '${DateFormat('HH:mm').format(o.placedAt)} PST';

                  final isDelivery = o.fulfillmentMethod.name
                      .toLowerCase()
                      .contains('delivery');
                  final typeText = isDelivery ? 'Delivery' : 'Pickup';
                  final paymentText =
                      '${o.paymentStatus.name.toUpperCase()}\nPaid';

                  final itemsListStr = o.items
                      .map((i) {
                        final unitStr = i.unit.toLowerCase().contains('kg')
                            ? 'kg'
                            : 'pc';
                        final pricePerUnit = _formatP(i.unitPrice);
                        final lineTotal = _formatP(i.unitPrice * i.quantity);
                        return ' - ${i.productName}: ${i.quantity.toStringAsFixed(2)} $unitStr @ $pricePerUnit/$unitStr = $lineTotal';
                      })
                      .join('\n');

                  return [
                    '$dateStr\n$timeStr',
                    '#PG-${o.id}',
                    _firstName(o.customerName),
                    typeText,
                    paymentText,
                    itemsListStr.isEmpty ? ' - Items Breakdown' : itemsListStr,
                    _formatP(o.total),
                  ];
                }),
              ],
            ),

            pw.SizedBox(height: 16),

            // Totals Summary Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFECFDF5),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFA7F3D0),
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Subtotal Sales:',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFF374151),
                        ),
                      ),
                      pw.Text(
                        _formatP(subtotalSales),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Delivery Fees Collected:',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFF374151),
                        ),
                      ),
                      pw.Text(
                        _formatP(deliveryFees),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(
                    color: const PdfColor.fromInt(0xFFA7F3D0),
                    thickness: 0.8,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Grand Total Sales:',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF064E3B),
                        ),
                      ),
                      pw.Text(
                        _formatP(grandTotalSales),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF064E3B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Uint8List buildExcel(
    List<MarketOrder> orders,
    DateTime timestamp,
    String stallName,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel['Sales Report'];
    excel.setDefaultSheet('Sales Report');

    // Title Row 1
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('PalengkeGo - Daily Stall Sales Report');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#0B372B'),
    );

    // Subtitle Row 2
    final dateStr = DateFormat('MMMM dd, yyyy').format(timestamp);
    final subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
    subtitleCell.value = TextCellValue('Stall: $stallName    Date: $dateStr');
    subtitleCell.cellStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#64748B'),
    );

    // Table Header Row 4
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0B372B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    final headers = [
      'Order ID',
      'Customer Name',
      'Items Purchased',
      'Order Time',
      'Payment Method',
      'Status',
      'Total Amount (PHP)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Data Rows starting Row 5 (index 4)
    double totalDailySales = 0.0;
    int rowIndex = 4;

    for (final o in orders) {
      final itemsStr = o.items
          .map(
            (i) =>
                '${i.quantity.toStringAsFixed(1)} ${i.unit} ${i.productName}',
          )
          .join(', ');
      final timeStr = DateFormat('hh:mm a').format(o.placedAt);
      final orderIdStr =
          'ORD-${DateFormat('yyyyMMdd').format(o.placedAt)}-${o.id.padLeft(3, '0')}';
      final totalStr = _formatP(o.total);
      totalDailySales += o.total;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        orderIdStr,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        _firstName(o.customerName),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        itemsStr,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(
        timeStr,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(
        o.paymentStatus.name.toUpperCase(),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(
        'Completed',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(
        totalStr,
      );

      rowIndex++;
    }

    // Total Row
    final totalRowStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#ECFDF5'),
      fontColorHex: ExcelColor.fromHexString('#064E3B'),
    );

    final totalLabelCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    totalLabelCell.value = TextCellValue('Total Sales (Daily)');
    totalLabelCell.cellStyle = totalRowStyle;

    final totalValCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
    );
    totalValCell.value = TextCellValue(_formatP(totalDailySales));
    totalValCell.cellStyle = totalRowStyle;

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 35);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 20);

    return Uint8List.fromList(excel.encode() ?? const []);
  }
}
