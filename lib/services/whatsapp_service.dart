import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import 'package:yaz/models/payment.dart';

class WhatsAppService {
  static const String _baseUrl =
      'https://whatsapp-bot-nodeserver-production.up.railway.app/api/v1/';

  static const Map<int, String> messageTemplates = {
    1: '''مرحبا @الاسم
نود إعلامك بموعد استحقاق دين بقيمة @المبلغ في @التاريخ
نشكر تعاونكم معنا''',

    2: '''مرحبا @الاسم
هذا تذكير بموعد استحقاق دين بقيمة @المبلغ في @التاريخ
نشكر تعاونكم معنا''',

    3: '''عزيزي @الاسم
نود إعلامكم بأنه تم استلام @النوع بقيمة @المبلغ في @التاريخ
شكراً لكم''',

    4: '''*كشف حساب*
العميل: @الاسم
رقم الهاتف: @الهاتف
تاريخ الكشف: @التاريخ
----------------
إجمالي المدفوع: @المدفوع ₪
إجمالي الديون: @الديون ₪
الرصيد الحالي: @الرصيد ₪
----------------
شكراً لتعاملكم معنا!''',
  };

  String _translateError(String error) {
    switch (error.toLowerCase()) {
      case 'phone number is not registered on whatsapp':
        return 'رقم الهاتف غير مسجل في واتساب';
      case 'message not sent':
        return 'لم يتم إرسال الرسالة';
      case 'invalid phone number':
        return 'رقم الهاتف غير صحيح';
      default:
        return 'حدث خطأ في إرسال الرسالة: $error';
    }
  }

  Future<(bool, String)> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // تنظيف رقم الهاتف من أي رموز غير رقمية
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // إذا كان الرقم يبدأ بصفر، نحذفه فقط
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }

      debugPrint('إرسال رسالة واتساب إلى: $cleanNumber');
      debugPrint('نص الرسالة: $message');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "number": cleanNumber,
          "message": message
        }),
      );

      debugPrint('استجابة API: ${response.statusCode}');
      debugPrint('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        return (true, '');
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['error'] as String? ?? 'خطأ غير معروف';
        return (false, _translateError(errorMessage));
      }
    } catch (e) {
      debugPrint('خطأ في إرسال رسالة الواتساب: $e');
      return (false, 'حدث خطأ في إرسال الرسالة');
    }
  }

  Future<(bool, String)> sendPaymentReminder({
    required String phoneNumber,
    required String customerName,
    required double amount,
    required DateTime dueDate,
  }) async {
    try {
      // تحويل التاريخ إلى التوقيت المحلي وتنسيقه
      final localDueDate = dueDate.toLocal();
      final formattedDate = _formatDate(localDueDate);
      final formattedTime = _formatTime(localDueDate);

      final message = '''مرحباً $customerName،
نود تذكيركم بموعد استحقاق الدفعة:
المبلغ: ${amount.toStringAsFixed(2)} ₪
التاريخ: $formattedDate
الوقت: $formattedTime

نشكر لكم حسن تعاونكم.''';

      return sendMessage(
        phoneNumber: phoneNumber,
        message: message,
      );
    } catch (e) {
      debugPrint('خطأ في إرسال تذكير الدفع: $e');
      return (false, 'حدث خطأ في إرسال تذكير الدفع');
    }
  }

  Future<(bool, String)> schedulePaymentReminder({
    required String phoneNumber,
    required String customerName,
    required double amount,
    required DateTime dueDate,
    required DateTime scheduleDate,
    String? customMessage,
  }) async {
    try {
      final defaultMessage =
          'السلام عليكم @الاسم،\nنود تذكيركم بموعد استحقاق @النوع بقيمة @المبلغ في تاريخ @التاريخ';

      // استبدال المتغيرات في الرسالة
      final finalMessage = _replaceMessageVariables(
        message: customMessage ?? defaultMessage,
        customerName: customerName,
        phoneNumber: phoneNumber,
        amount: amount,
        date: dueDate,
      );

      // إرسال الرسالة عبر API
      return sendMessage(
        phoneNumber: phoneNumber,
        message: finalMessage,
      );
    } catch (e) {
      debugPrint('خطأ في جدولة تذكير الدفع: $e');
      return (false, 'حدث خطأ في جدولة تذكير الدفع');
    }
  }

  String _formatDate(DateTime date) {
    final formatter = intl.DateFormat('EEEE، d MMMM yyyy', 'ar');
    return formatter.format(date);
  }

  String _formatTime(DateTime date) {
    final formatter = intl.DateFormat('h:mm a', 'ar');
    return formatter.format(date);
  }

  String _replaceMessageVariables({
    required String message,
    required String customerName,
    required String phoneNumber,
    required double amount,
    required DateTime date,
  }) {
    final formattedAmount = '${amount.abs()} ₪';
    final formattedDate = intl.DateFormat('yyyy/MM/dd').format(date);
    final paymentType = amount >= 0 ? 'دفعة' : 'دين';

    return message
        .replaceAll('@الاسم', customerName)
        .replaceAll('@الرقم', phoneNumber)
        .replaceAll('@المبلغ', formattedAmount)
        .replaceAll('@التاريخ', formattedDate)
        .replaceAll('@النوع', paymentType);
  }

  String buildMessageFromTemplate({
    required int templateId,
    required String customerName,
    String? phone,
    required double amount,
    required DateTime date,
    double? totalPaid,
    double? totalDebt,
    double? balance,
  }) {
    String message = messageTemplates[templateId] ?? '';
    final formattedAmount = '${amount.abs()} ₪';
    final formattedDate = intl.DateFormat('yyyy/MM/dd').format(date);
    final paymentType = amount >= 0 ? 'دفعة' : 'دين';

    message = message
        .replaceAll('@الاسم', customerName)
        .replaceAll('@المبلغ', formattedAmount)
        .replaceAll('@التاريخ', formattedDate)
        .replaceAll('@النوع', paymentType);

    // إضافة معلومات كشف الحساب إذا كان النموذج رقم 4
    if (templateId == 4 && phone != null && totalPaid != null && totalDebt != null && balance != null) {
      message = message
          .replaceAll('@الهاتف', phone)
          .replaceAll('@المدفوع', totalPaid.toStringAsFixed(2))
          .replaceAll('@الديون', totalDebt.toStringAsFixed(2))
          .replaceAll('@الرصيد', balance.toStringAsFixed(2));
    }

    return message;
  }

  /// نموذج رسالة إيصال الدفع
  String buildPaymentReceiptMessage({
    required String customerName,
    required double amount,
    required DateTime date,
    String? notes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*إيصال دفع*');
    buffer.writeln('----------------');
    buffer.writeln('العميل: $customerName');
    buffer.writeln('المبلغ: ${amount.toStringAsFixed(2)} ₪');
    buffer.writeln('التاريخ: ${_formatDateTime(date)}');
    if (notes?.isNotEmpty ?? false) {
      buffer.writeln('ملاحظات: $notes');
    }
    buffer.writeln('----------------');
    buffer.writeln('شكراً لك!');
    return buffer.toString();
  }

  /// نموذج رسالة كشف الحساب
  String buildStatementMessage({
    required String customerName,
    required String phone,
    required List<Payment> payments,
    required double balance,
  }) {
    var totalPaid = 0.0;
    var totalDebt = 0.0;
    
    final buffer = StringBuffer();
    buffer.writeln('*كشف حساب*');
    buffer.writeln('----------------');
    buffer.writeln('العميل: $customerName');
    buffer.writeln('رقم الهاتف: $phone');
    buffer.writeln('تاريخ الكشف: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('----------------');
    
    // ترتيب الدفعات حسب التاريخ
    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    for (var payment in sortedPayments) {
      final amount = payment.amount;
      if (amount > 0) {
        totalPaid += amount;
        buffer.writeln('✅ ${_formatDateTime(payment.date)}: دفعة +${amount.toStringAsFixed(2)} ₪');
      } else {
        totalDebt += amount.abs();
        buffer.writeln('🔴 ${_formatDateTime(payment.date)}: دين -${amount.abs().toStringAsFixed(2)} ₪');
      }
      if (payment.notes?.isNotEmpty ?? false) {
        buffer.writeln('   ملاحظات: ${payment.notes}');
      }
    }
    
    buffer.writeln('----------------');
    buffer.writeln('إجمالي المدفوع: ${totalPaid.toStringAsFixed(2)} ₪');
    buffer.writeln('إجمالي الديون: ${totalDebt.toStringAsFixed(2)} ₪');
    buffer.writeln('الرصيد الحالي: ${balance.toStringAsFixed(2)} ₪');
    buffer.writeln('----------------');
    buffer.writeln('شكراً لتعاملكم معنا!');
    
    return buffer.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    return intl.DateFormat('yyyy/MM/dd').format(dateTime);
  }
}
