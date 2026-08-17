import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

class SalesReportExportService {
  const SalesReportExportService._();

  static String buildFilename(
    String period,
    DateTime timestamp,
    String stallName,
  ) {
    final cleanStall = stallName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
    final cleanPeriod = period.toLowerCase().trim();
    final formattedTimestamp = DateFormat(
      'yyyy-MM-dd_HHmmss',
    ).format(timestamp);
    return '${cleanStall}_earnings_report_${cleanPeriod}_$formattedTimestamp';
  }

  // ── Report computation ───────────────────────────────────────────────────────

  /// Half-open [start, end) boundaries for a period label, from the device
  /// clock. Supports 'today', 'week' (Mon-Sun) and anything else (month).
  static (DateTime, DateTime) periodBounds(String period, DateTime now) {
    final startDay = DateTime(now.year, now.month, now.day);
    final lower = period.toLowerCase();
    if (lower == 'today') {
      return (startDay, startDay.add(const Duration(days: 1)));
    }
    if (lower == 'week') {
      final monday = startDay.subtract(Duration(days: now.weekday - 1));
      return (monday, monday.add(const Duration(days: 7)));
    }
    final monthStart = DateTime(now.year, now.month, 1);
    return (monthStart, DateTime(now.year, now.month + 1, 1));
  }

  static List<MarketOrder> completedInRange(
    List<MarketOrder> orders,
    DateTime start,
    DateTime end,
  ) {
    return orders
        .where(
          (o) =>
              o.status == OrderStatus.completed &&
              !o.placedAt.isBefore(start) &&
              o.placedAt.isBefore(end),
        )
        .toList();
  }

  static double _subtotal(List<MarketOrder> orders) =>
      orders.fold(0.0, (sum, o) => sum + o.total);

  static String _fmtDay(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  static String _fmtMoney(double amount) =>
      'P ${NumberFormat('#,##0.00').format(amount)}';

  /// Completed orders grouped by the calendar day they were placed on.
  static Map<DateTime, List<MarketOrder>> _byDay(List<MarketOrder> orders) {
    final map = <DateTime, List<MarketOrder>>{};
    for (final o in orders) {
      final day = DateTime(o.placedAt.year, o.placedAt.month, o.placedAt.day);
      map.putIfAbsent(day, () => []).add(o);
    }
    return map;
  }

  static Future<Uint8List> buildPdf(
    String period,
    String stallName,
    List<MarketOrder> orders,
  ) async {
    final now = DateTime.now();
    final (start, end) = periodBounds(period, now);
    final completed = completedInRange(orders, start, end);
    final generatedTime =
        'Generated: ${DateFormat('MMMM dd, yyyy HH:mm').format(now)}';

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final isDaily = period.toLowerCase() == 'today';
    final isWeekly = period.toLowerCase() == 'week';
    final periodRange = isDaily
        ? 'Period: ${_fmtDay(start)} - ${_fmtDay(end.subtract(const Duration(days: 1)))}'
        : isWeekly
        ? 'Week Period: ${_fmtDay(start)} - ${_fmtDay(end.subtract(const Duration(days: 1)))}'
        : 'Month: ${DateFormat('MMMM yyyy').format(start)}';

    final title = isDaily
        ? 'Stall Earnings Summary Report'
        : isWeekly
        ? 'Weekly Stall Earnings Report'
        : 'Monthly Stall Earnings Report';

    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Column(
            children: [
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
                          'PalengkeGo',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          title,
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
                          periodRange,
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFD1D5DB),
                            fontSize: 8,
                          ),
                        ),
                        pw.Text(
                          generatedTime,
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
              pw.SizedBox(height: 14),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 14),
            child: pw.Text(
              'Sales Report for $stallName | Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          );
        },
        build: (context) {
          if (isDaily) {
            return _buildDailyPdfContent(completed, now);
          } else if (isWeekly) {
            return _buildWeeklyPdfContent(completed, start);
          } else {
            return _buildMonthlyPdfContent(completed, start, end);
          }
        },
      ),
    );

    return pdf.save();
  }

  static List<pw.Widget> _buildDailyPdfContent(
    List<MarketOrder> orders,
    DateTime now,
  ) {
    final byDay = _byDay(orders);
    final today = DateTime(now.year, now.month, now.day);
    final todayOrders = byDay[today] ?? <MarketOrder>[];
    final monthOrders = orders
        .where(
          (o) => o.placedAt.year == now.year && o.placedAt.month == now.month,
        )
        .toList();

    final rows = <List<String>>[];
    for (var i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayOrders = byDay[dayStart] ?? <MarketOrder>[];
      rows.add([
        DateFormat('yyyy-MM-dd').format(dayStart),
        '${dayOrders.length}',
        _fmtMoney(_subtotal(dayOrders)),
      ]);
    }

    return [
      pw.Text(
        'Earnings Highlights',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0B372B),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          pw.Expanded(
            child: _buildHighlightCard(
              'TODAY\'S EARNINGS',
              _fmtMoney(_subtotal(todayOrders)),
              'Across ${todayOrders.length} completed orders',
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _buildHighlightCard(
              'TOTAL EARNINGS (THIS MONTH)',
              _fmtMoney(_subtotal(monthOrders)),
              'Across ${monthOrders.length} completed orders',
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Daily Sales & Earnings Log',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0B372B),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0B372B),
        ),
        cellStyle: const pw.TextStyle(fontSize: 9),
        data: <List<String>>[
          ['DATE', 'COMPLETED ORDERS', 'TOTAL EARNINGS'],
          ...rows,
        ],
      ),
      pw.SizedBox(height: 16),
      _buildTotalsBox([
        ['Total Orders Processed:', '${orders.length} Orders'],
        ['Total Stall Earnings:', _fmtMoney(_subtotal(orders))],
      ]),
    ];
  }

  static List<pw.Widget> _buildWeeklyPdfContent(
    List<MarketOrder> orders,
    DateTime start,
  ) {
    final byDay = _byDay(orders);
    final rows = <List<String>>[];
    var weekRevenue = 0.0;
    var weekCount = 0;
    DateTime? peakDay;
    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final dayOrders = byDay[day] ?? <MarketOrder>[];
      final dayRevenue = _subtotal(dayOrders);
      weekRevenue += dayRevenue;
      weekCount += dayOrders.length;
      if (dayOrders.isNotEmpty &&
          (peakDay == null ||
              dayRevenue > _subtotal(byDay[peakDay] ?? <MarketOrder>[]))) {
        peakDay = day;
      }
      rows.add([
        '${DateFormat('EEEE').format(day)} (${_fmtDay(day)})',
        '${dayOrders.length}',
        _fmtMoney(dayRevenue),
      ]);
    }
    final peakOrders = peakDay == null ? <MarketOrder>[] : byDay[peakDay]!;

    return [
      pw.Text(
        'Weekly Performance Highlights',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0B372B),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          pw.Expanded(
            child: _buildHighlightCard(
              'WEEKLY TOTAL EARNINGS',
              _fmtMoney(weekRevenue),
              'Across $weekCount orders',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _buildHighlightCard(
              'DAILY AVERAGE',
              _fmtMoney(weekRevenue / 7),
              '~${(weekCount / 7).toStringAsFixed(1)} orders / day',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _buildHighlightCard(
              'PEAK SALES DAY',
              peakDay == null ? '-' : DateFormat('EEEE').format(peakDay),
              peakDay == null ? '-' : _fmtMoney(_subtotal(peakOrders)),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Daily Breakdown (Current Week)',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0B372B),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0B372B),
        ),
        cellStyle: const pw.TextStyle(fontSize: 9),
        data: <List<String>>[
          ['DAY & DATE', 'COMPLETED ORDERS', 'TOTAL EARNINGS'],
          ...rows,
        ],
      ),
      pw.SizedBox(height: 16),
      _buildTotalsBox([
        ['Total Weekly Orders:', '$weekCount Orders'],
        [
          'Average Order Value (AOV):',
          weekCount == 0
              ? 'P 0.00 / order'
              : '${_fmtMoney(weekRevenue / weekCount)} / order',
        ],
        ['Total Weekly Stall Earnings:', _fmtMoney(weekRevenue)],
      ]),
    ];
  }

  static List<pw.Widget> _buildMonthlyPdfContent(
    List<MarketOrder> orders,
    DateTime start,
    DateTime end,
  ) {
    final byWeek = <int, List<MarketOrder>>{};
    for (final o in orders) {
      byWeek.putIfAbsent((o.placedAt.day - 1) ~/ 7, () => []).add(o);
    }

    final daysInMonth = end.difference(start).inDays;
    final elapsedDays = (end.subtract(const Duration(minutes: 1))).day;
    final weekCounts = byWeek.keys.length;
    final monthRevenue = _subtotal(orders);
    final projected = elapsedDays == 0
        ? 0.0
        : monthRevenue / elapsedDays * daysInMonth;

    final rows = <List<String>>[];
    for (var w = 0; w < weekCounts; w++) {
      final weekOrders = byWeek[w] ?? <MarketOrder>[];
      final firstDay = DateTime(start.year, start.month, w * 7 + 1);
      rows.add([
        'Week ${w + 1} (${_fmtDay(firstDay)})',
        '${weekOrders.length}',
        _fmtMoney(_subtotal(weekOrders)),
      ]);
    }

    return [
      pw.Text(
        'Monthly Performance Highlights',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0B372B),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          pw.Expanded(
            child: _buildHighlightCard(
              'MONTH-TO-DATE EARNINGS',
              _fmtMoney(monthRevenue),
              'Across ${orders.length} orders',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _buildHighlightCard(
              'WEEKLY AVERAGE',
              _fmtMoney(weekCounts == 0 ? 0 : monthRevenue / weekCounts),
              '~${(orders.length / (weekCounts == 0 ? 1 : weekCounts)).round()} orders / week',
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _buildHighlightCard(
              'EST. MONTH-END (RUN RATE)',
              _fmtMoney(projected),
              'Based on $elapsedDays-day run rate',
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Weekly Breakdown (${DateFormat('MMMM yyyy').format(start)})',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0B372B),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0B372B),
        ),
        cellStyle: const pw.TextStyle(fontSize: 9),
        data: <List<String>>[
          ['WEEK RANGE', 'TOTAL ORDERS', 'WEEKLY EARNINGS'],
          ...rows,
          ['Month-to-Date', '${orders.length}', _fmtMoney(monthRevenue)],
        ],
      ),
      pw.SizedBox(height: 16),
      _buildTotalsBox([
        ['Total Orders Processed (MTD):', '${orders.length} Orders'],
        [
          'Average Daily Revenue:',
          elapsedDays == 0
              ? 'P 0.00 / day'
              : '${_fmtMoney(monthRevenue / elapsedDays)} / day',
        ],
        ['Total Month-to-Date Earnings:', _fmtMoney(monthRevenue)],
      ]),
    ];
  }

  static pw.Widget _buildHighlightCard(
    String title,
    String amount,
    String subtitle,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFECFDF5),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFA7F3D0)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColor.fromInt(0xFF374151),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF064E3B),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColor.fromInt(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalsBox(List<List<String>> items) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFECFDF5),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFA7F3D0)),
      ),
      child: pw.Column(
        children: items.map((pair) {
          final isLast = pair == items.last;
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pair[0],
                  style: pw.TextStyle(
                    fontSize: isLast ? 11 : 9,
                    fontWeight: isLast
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: isLast
                        ? const PdfColor.fromInt(0xFF064E3B)
                        : const PdfColor.fromInt(0xFF374151),
                  ),
                ),
                pw.Text(
                  pair[1],
                  style: pw.TextStyle(
                    fontSize: isLast ? 11 : 9,
                    fontWeight: pw.FontWeight.bold,
                    color: isLast
                        ? const PdfColor.fromInt(0xFF064E3B)
                        : const PdfColor.fromInt(0xFF1F2937),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static Uint8List buildExcel(
    String period,
    String stallName,
    List<MarketOrder> orders,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel['Sales Report'];
    excel.setDefaultSheet('Sales Report');

    final now = DateTime.now();
    final (start, end) = periodBounds(period, now);
    final completed = completedInRange(orders, start, end);
    final byDay = _byDay(completed);
    final isDaily = period.toLowerCase() == 'today';
    final isWeekly = period.toLowerCase() == 'week';

    final periodRange = isDaily
        ? 'Period: ${_fmtDay(start)} - ${_fmtDay(end.subtract(const Duration(days: 1)))}'
        : isWeekly
        ? 'Week Period: ${_fmtDay(start)} - ${_fmtDay(end.subtract(const Duration(days: 1)))}'
        : 'Month: ${DateFormat('MMMM yyyy').format(start)}';

    final today = DateTime(now.year, now.month, now.day);
    final todayOrders = byDay[today] ?? <MarketOrder>[];
    final monthOrders = orders
        .where(
          (o) =>
              o.status == OrderStatus.completed &&
              o.placedAt.year == now.year &&
              o.placedAt.month == now.month,
        )
        .toList();
    final monthRevenue = _subtotal(monthOrders);

    final daysInMonth = end.difference(start).inDays;
    final elapsedDays = (end.subtract(const Duration(minutes: 1))).day;
    final projected = elapsedDays == 0
        ? 0.0
        : monthRevenue / elapsedDays * daysInMonth;

    final List<List<String>> summaryData;
    if (isDaily || isWeekly) {
      summaryData = [
        [
          'Earnings Today',
          _fmtMoney(_subtotal(todayOrders)),
          '${todayOrders.length} Orders',
        ],
        [
          'Earnings This Period',
          _fmtMoney(_subtotal(completed)),
          '${completed.length} Orders',
        ],
        [
          'Total Monthly Earnings',
          _fmtMoney(monthRevenue),
          '${monthOrders.length} Orders',
        ],
      ];
    } else {
      summaryData = [
        [
          'Total Monthly Earnings',
          _fmtMoney(monthRevenue),
          '${monthOrders.length} Orders',
        ],
        [
          'Average Daily Revenue',
          elapsedDays == 0
              ? 'P 0.00 / day'
              : '${_fmtMoney(monthRevenue / elapsedDays)} / day',
          '',
        ],
        [
          'Month-End Run Rate',
          projected <= 0 ? 'P 0.00' : _fmtMoney(projected),
          '',
        ],
      ];
    }

    final List<List<String>> tableRows;
    final List<String> tableHeader;
    if (isDaily || isWeekly) {
      tableHeader = ['DAY & DATE', 'COMPLETED ORDERS', 'TOTAL EARNINGS'];
      tableRows = [
        for (var i = 6; i >= 0; i--)
          () {
            final day = now.subtract(Duration(days: i));
            final dayStart = DateTime(day.year, day.month, day.day);
            final dayOrders = byDay[dayStart] ?? <MarketOrder>[];
            return [
              DateFormat('yyyy-MM-dd').format(dayStart),
              '${dayOrders.length}',
              _fmtMoney(_subtotal(dayOrders)),
            ];
          }(),
      ];
    } else {
      tableHeader = ['WEEK RANGE', 'TOTAL ORDERS', 'WEEKLY EARNINGS'];
      final byWeek = <int, List<MarketOrder>>{};
      for (final o in completed) {
        byWeek.putIfAbsent((o.placedAt.day - 1) ~/ 7, () => []).add(o);
      }
      tableRows = [
        for (var w = 0; w < byWeek.keys.length; w++)
          () {
            final weekOrders = byWeek[w] ?? <MarketOrder>[];
            final firstDay = DateTime(start.year, start.month, w * 7 + 1);
            return [
              'Week ${w + 1} (${_fmtDay(firstDay)})',
              '${weekOrders.length}',
              _fmtMoney(_subtotal(weekOrders)),
            ];
          }(),
      ];
    }

    // Title Row 1
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('PalengkeGo - Stall Earnings Report');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#0B372B'),
    );

    // Subtitle Row 2
    final subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
    subtitleCell.value = TextCellValue('Stall: $stallName    $periodRange');
    subtitleCell.cellStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#64748B'),
    );

    // Summary Table Header (Row 4)
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0B372B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
      'Summary Category',
    );
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(
      'Total Amount (PHP)',
    );
    sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue(
      'Completed Orders',
    );

    sheet.cell(CellIndex.indexByString('A4')).cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByString('B4')).cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByString('C4')).cellStyle = headerStyle;

    final rowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#ECFDF5'),
    );

    // Summary Rows (5.. up, 0-based below)
    for (int r = 0; r < summaryData.length; r++) {
      final rowIndex = 4 + r;
      for (int c = 0; c < 3; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        );
        cell.value = TextCellValue(summaryData[r][c]);
        cell.cellStyle = rowStyle;
      }
    }

    // Breakdown Section Title
    final sectionStart = 6 + summaryData.length;
    final sectionTitleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sectionStart),
    );
    sectionTitleCell.value = TextCellValue('Sales & Earnings Breakdown');
    sectionTitleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0B372B'),
    );

    // Table Header
    final tableHeaderRow = sectionStart + 1;
    for (int c = 0; c < 3; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: tableHeaderRow),
      );
      cell.value = TextCellValue(tableHeader[c]);
      cell.cellStyle = headerStyle;
    }

    // Table Rows
    for (int r = 0; r < tableRows.length; r++) {
      final rowIndex = tableHeaderRow + 1 + r;
      for (int c = 0; c < 3; c++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          tableRows[r][c],
        );
      }
    }

    sheet.setColumnWidth(0, 34);
    sheet.setColumnWidth(1, 26);
    sheet.setColumnWidth(2, 26);

    return Uint8List.fromList(excel.encode() ?? const []);
  }
}
