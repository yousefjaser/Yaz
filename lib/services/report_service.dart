import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:flutter/foundation.dart';

class ReportService {
  static final _dateFormat = intl.DateFormat('yyyy/MM/dd HH:mm');
  static final _currencyFormat = intl.NumberFormat('#,##0.00', 'ar');

  Future<String> getReportsPath() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('لا يمكن الوصول إلى مجلد التخزين');
      }
      final reportsDir = Directory('${directory.path}/Reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      return reportsDir.path;
    } else if (Platform.isWindows) {
      final documentsPath =
          '${Platform.environment['USERPROFILE']}\\Documents\\YazReports';
      final reportsDir = Directory(documentsPath);
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      debugPrint('مسار حفظ التقارير: $documentsPath');
      return documentsPath;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${directory.path}/Reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      return reportsDir.path;
    }
  }

  Future<String> generateCustomerReport({
    required Customer customer,
    required DateTime startDate,
    required DateTime endDate,
    required String format,
  }) async {
    try {
      debugPrint('بدء إنشاء التقرير...');
      debugPrint('عدد الدفعات الكلي: ${customer.payments.length}');

      // تصفية الدفعات غير المحذوفة فقط
      final payments = customer.payments.where((p) => !p.isDeleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      debugPrint('عدد الدفعات بعد استبعاد المحذوفة: ${payments.length}');
      payments.forEach((p) {
        debugPrint(
            'دفعة: تاريخ=${p.date}, مبلغ=${p.amount}, محذوفة=${p.isDeleted}, عنوان=${p.title}');
      });

      String filePath;
      if (format == 'pdf') {
        filePath =
            await _generatePdfReport(customer, payments, startDate, endDate);
      } else {
        filePath =
            await _generateExcelReport(customer, payments, startDate, endDate);
      }

      debugPrint('تم إنشاء التقرير بنجاح');
      debugPrint('مسار الملف: $filePath');

      try {
        if (Platform.isWindows) {
          // فتح مجلد التقارير مباشرة
          final reportsPath = await getReportsPath();
          await Process.run('explorer.exe', [reportsPath]);
        } else {
          await Share.shareXFiles([XFile(filePath)]);
        }
      } catch (e) {
        debugPrint('لا يمكن فتح المجلد: $e');
      }

      return filePath;
    } catch (e) {
      debugPrint('حدث خطأ أثناء إنشاء التقرير: $e');
      rethrow;
    }
  }

  Future<String> _generatePdfReport(
    Customer customer,
    List<Payment> payments,
    DateTime startDate,
    DateTime endDate,
  ) async {
    debugPrint('إنشاء تقرير PDF...');
    final pdf = pw.Document();

    // تحميل الخط العربي
    final arabicFont = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(arabicFont);

    // إنشاء الصفحة
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          final baseStyle = pw.TextStyle(font: ttf);
          final titleStyle = baseStyle.copyWith(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          );
          final subtitleStyle = baseStyle.copyWith(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          );
          final headerStyle = baseStyle.copyWith(
            fontSize: 14,
            color: PdfColors.grey800,
          );
          final contentStyle = baseStyle.copyWith(fontSize: 12);

          return [
            // ترويسة التقرير
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('كشف حساب تفصيلي', style: titleStyle),
                        pw.SizedBox(height: 10),
                        pw.Divider(color: PdfColors.blue200),
                        pw.SizedBox(height: 10),
                        pw.Text('معلومات العميل', style: subtitleStyle),
                        pw.SizedBox(height: 5),
                        _buildInfoRow(
                            'الاسم:', customer.name, headerStyle, contentStyle),
                        _buildInfoRow('رقم الهاتف:', customer.phone,
                            headerStyle, contentStyle),
                        if (customer.address != null &&
                            customer.address!.isNotEmpty)
                          _buildInfoRow('العنوان:', customer.address!,
                              headerStyle, contentStyle),
                        if (customer.notes != null &&
                            customer.notes!.isNotEmpty)
                          _buildInfoRow('ملاحظات:', customer.notes!,
                              headerStyle, contentStyle),
                        pw.SizedBox(height: 10),
                        pw.Text('معلومات التقرير', style: subtitleStyle),
                        pw.SizedBox(height: 5),
                        _buildInfoRow(
                            'الفترة:',
                            '${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
                            headerStyle,
                            contentStyle),
                        _buildInfoRow(
                            'الرصيد الحالي:',
                            '${_currencyFormat.format(customer.balance)} شيكل',
                            headerStyle,
                            contentStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ملخص الحساب
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ملخص الحساب', style: subtitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryBox(
                        'إجمالي المدفوعات',
                        _currencyFormat.format(payments
                            .where((p) => p.amount > 0)
                            .fold(0.0, (sum, p) => sum + p.amount)),
                        PdfColors.green700,
                        headerStyle,
                        contentStyle,
                      ),
                      _buildSummaryBox(
                        'إجمالي الديون',
                        _currencyFormat.format(payments
                            .where((p) => p.amount < 0)
                            .fold(0.0, (sum, p) => sum + p.amount.abs())),
                        PdfColors.red700,
                        headerStyle,
                        contentStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // تفاصيل المعاملات
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('تفاصيل المعاملات', style: subtitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Table.fromTextArray(
                    headers: ['التاريخ', 'النوع', 'المبلغ', 'البيان', 'الرصيد'],
                    data: payments.asMap().entries.map((entry) {
                      final payment = entry.value;
                      final isDebt = payment.amount < 0;

                      // حساب الرصيد المتراكم
                      double runningBalance = 0;
                      for (var i = payments.length - 1; i >= entry.key; i--) {
                        runningBalance += payments[i].amount;
                      }

                      return [
                        _dateFormat.format(payment.date),
                        isDebt ? 'دين' : 'دفعة',
                        '${_currencyFormat.format(payment.amount.abs())} شيكل',
                        payment.title ?? '-',
                        '${_currencyFormat.format(runningBalance)} شيكل',
                      ];
                    }).toList(),
                    headerStyle: headerStyle.copyWith(color: PdfColors.white),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.blue700,
                    ),
                    rowDecoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.blue50),
                      ),
                    ),
                    cellStyle: contentStyle,
                    cellHeight: 30,
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.center,
                      2: pw.Alignment.center,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.center,
                    },
                    oddRowDecoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final reportsPath = await getReportsPath();
    final fileName =
        'كشف_حساب_${customer.name}_${intl.DateFormat('yyyy_MM_dd').format(DateTime.now())}.pdf';
    final filePath = '$reportsPath/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    debugPrint('تم حفظ ملف PDF في: $filePath');
    return filePath;
  }

  pw.Widget _buildInfoRow(String label, String value, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Expanded(
            child: pw.Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryBox(String label, String value, PdfColor color,
      pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: labelStyle.copyWith(color: color)),
          pw.SizedBox(height: 5),
          pw.Text('${value} شيكل',
              style: valueStyle.copyWith(
                  color: color, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<String> _generateExcelReport(
    Customer customer,
    List<Payment> payments,
    DateTime startDate,
    DateTime endDate,
  ) async {
    debugPrint('إنشاء تقرير Excel...');

    final excel = Excel.createExcel();
    final sheet = excel['كشف حساب'];
    excel.setDefaultSheet('كشف حساب');

    // تنسيق العناوين
    var headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Right,
    );

    var contentStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
    );

    // عنوان التقرير
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    var cell = sheet.cell(CellIndex.indexByString('A1'));
    cell.value = TextCellValue('كشف حساب تفصيلي');
    cell.cellStyle = headerStyle;

    // معلومات العميل
    sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('E3'));
    cell = sheet.cell(CellIndex.indexByString('A3'));
    cell.value = TextCellValue('معلومات العميل');
    cell.cellStyle = headerStyle;

    // الاسم
    cell = sheet.cell(CellIndex.indexByString('A4'));
    cell.value = TextCellValue('الاسم:');
    cell.cellStyle = contentStyle;

    sheet.merge(CellIndex.indexByString('B4'), CellIndex.indexByString('E4'));
    cell = sheet.cell(CellIndex.indexByString('B4'));
    cell.value = TextCellValue(customer.name);
    cell.cellStyle = contentStyle;

    // رقم الهاتف
    cell = sheet.cell(CellIndex.indexByString('A5'));
    cell.value = TextCellValue('رقم الهاتف:');
    cell.cellStyle = contentStyle;

    sheet.merge(CellIndex.indexByString('B5'), CellIndex.indexByString('E5'));
    cell = sheet.cell(CellIndex.indexByString('B5'));
    cell.value = TextCellValue(customer.phone);
    cell.cellStyle = contentStyle;

    // العنوان
    if (customer.address != null && customer.address!.isNotEmpty) {
      cell = sheet.cell(CellIndex.indexByString('A6'));
      cell.value = TextCellValue('العنوان:');
      cell.cellStyle = contentStyle;

      sheet.merge(CellIndex.indexByString('B6'), CellIndex.indexByString('E6'));
      cell = sheet.cell(CellIndex.indexByString('B6'));
      cell.value = TextCellValue(customer.address!);
      cell.cellStyle = contentStyle;
    }

    // معلومات التقرير
    sheet.merge(CellIndex.indexByString('A8'), CellIndex.indexByString('E8'));
    cell = sheet.cell(CellIndex.indexByString('A8'));
    cell.value = TextCellValue('معلومات التقرير');
    cell.cellStyle = headerStyle;

    // الفترة
    cell = sheet.cell(CellIndex.indexByString('A9'));
    cell.value = TextCellValue('الفترة:');
    cell.cellStyle = contentStyle;

    sheet.merge(CellIndex.indexByString('B9'), CellIndex.indexByString('E9'));
    cell = sheet.cell(CellIndex.indexByString('B9'));
    cell.value = TextCellValue(
        '${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}');
    cell.cellStyle = contentStyle;

    // الرصيد الحالي
    cell = sheet.cell(CellIndex.indexByString('A10'));
    cell.value = TextCellValue('الرصيد الحالي:');
    cell.cellStyle = contentStyle;

    sheet.merge(CellIndex.indexByString('B10'), CellIndex.indexByString('E10'));
    cell = sheet.cell(CellIndex.indexByString('B10'));
    cell.value =
        TextCellValue('${_currencyFormat.format(customer.balance)} شيكل');
    cell.cellStyle = contentStyle;

    // ملخص الحساب
    sheet.merge(CellIndex.indexByString('A12'), CellIndex.indexByString('E12'));
    cell = sheet.cell(CellIndex.indexByString('A12'));
    cell.value = TextCellValue('ملخص الحساب');
    cell.cellStyle = headerStyle;

    // إجمالي المدفوعات
    cell = sheet.cell(CellIndex.indexByString('A13'));
    cell.value = TextCellValue('إجمالي المدفوعات:');
    cell.cellStyle = contentStyle;

    final totalPayments = payments
        .where((p) => p.amount > 0)
        .fold(0.0, (sum, p) => sum + p.amount);

    sheet.merge(CellIndex.indexByString('B13'), CellIndex.indexByString('E13'));
    cell = sheet.cell(CellIndex.indexByString('B13'));
    cell.value = TextCellValue('${_currencyFormat.format(totalPayments)} شيكل');
    cell.cellStyle = contentStyle;

    // إجمالي الديون
    cell = sheet.cell(CellIndex.indexByString('A14'));
    cell.value = TextCellValue('إجمالي الديون:');
    cell.cellStyle = contentStyle;

    final totalDebts = payments
        .where((p) => p.amount < 0)
        .fold(0.0, (sum, p) => sum + p.amount.abs());

    sheet.merge(CellIndex.indexByString('B14'), CellIndex.indexByString('E14'));
    cell = sheet.cell(CellIndex.indexByString('B14'));
    cell.value = TextCellValue('${_currencyFormat.format(totalDebts)} شيكل');
    cell.cellStyle = contentStyle;

    // إنشاء صفحة جديدة للمعاملات
    final transactionsSheet = excel['تفاصيل المعاملات'];
    excel.copy('كشف حساب', 'تفاصيل المعاملات');

    // عنوان الصفحة
    transactionsSheet.merge(
        CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    var transactionCell = transactionsSheet.cell(CellIndex.indexByString('A1'));
    transactionCell.value = TextCellValue('تفاصيل المعاملات');
    transactionCell.cellStyle = headerStyle;

    // معلومات العميل مختصرة
    transactionCell = transactionsSheet.cell(CellIndex.indexByString('A3'));
    transactionCell.value = TextCellValue('اسم العميل:');
    transactionCell.cellStyle = contentStyle;

    transactionsSheet.merge(
        CellIndex.indexByString('B3'), CellIndex.indexByString('E3'));
    transactionCell = transactionsSheet.cell(CellIndex.indexByString('B3'));
    transactionCell.value = TextCellValue(customer.name);
    transactionCell.cellStyle = contentStyle;

    // عناوين الأعمدة
    final headers = ['التاريخ', 'النوع', 'المبلغ', 'البيان', 'الرصيد'];
    for (var i = 0; i < headers.length; i++) {
      transactionCell = transactionsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
      transactionCell.value = TextCellValue(headers[i]);
      transactionCell.cellStyle = headerStyle;
    }

    // بيانات المعاملات
    var currentRow = 6;
    double runningBalance = 0;

    for (var payment in payments) {
      final isDebt = payment.amount < 0;
      runningBalance += payment.amount;

      // التاريخ
      transactionCell = transactionsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      transactionCell.value = TextCellValue(_dateFormat.format(payment.date));
      transactionCell.cellStyle = contentStyle;

      // النوع
      transactionCell = transactionsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      transactionCell.value = TextCellValue(isDebt ? 'دين' : 'دفعة');
      transactionCell.cellStyle = contentStyle;

      // المبلغ
      transactionCell = transactionsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow));
      transactionCell.value =
          TextCellValue('${_currencyFormat.format(payment.amount.abs())} شيكل');
      transactionCell.cellStyle = contentStyle;

      // البيان
      transactionCell = transactionsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
      transactionCell.value = TextCellValue(payment.title ?? '-');
      transactionCell.cellStyle = contentStyle;

      // الرصيد
      transactionCell = transactionsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
      transactionCell.value =
          TextCellValue('${_currencyFormat.format(runningBalance)} شيكل');
      transactionCell.cellStyle = contentStyle;

      currentRow++;
    }

    // تعيين عرض الأعمدة في صفحة المعاملات
    transactionsSheet.setColumnWidth(0, 25); // التاريخ
    transactionsSheet.setColumnWidth(1, 15); // النوع
    transactionsSheet.setColumnWidth(2, 20); // المبلغ
    transactionsSheet.setColumnWidth(3, 30); // البيان
    transactionsSheet.setColumnWidth(4, 20); // الرصيد

    final reportsPath = await getReportsPath();
    final fileName =
        'كشف_حساب_${customer.name}_${intl.DateFormat('yyyy_MM_dd').format(DateTime.now())}.xlsx';
    final filePath = '$reportsPath\\$fileName';

    debugPrint('حفظ الملف في: $filePath');

    try {
      final file = File(filePath);
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        debugPrint('تم حفظ ملف Excel بنجاح');
        return filePath;
      } else {
        throw Exception('فشل في ترميز ملف Excel');
      }
    } catch (e) {
      debugPrint('خطأ في حفظ ملف Excel: $e');
      rethrow;
    }
  }
}
