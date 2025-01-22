import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static const String _baseUrl =
      'https://whatsapp-bot-nodeserver-production.up.railway.app/api/v1/';

  Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // تنظيف رقم الهاتف من أي رموز غير رقمية
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // إذا كان الرقم يبدأ بصفر، نحذفه
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }

      // إذا لم يبدأ الرقم بـ 972، نضيفه
      if (!cleanNumber.startsWith('972')) {
        cleanNumber = '972$cleanNumber';
      }

      debugPrint('إرسال رسالة واتساب إلى: $cleanNumber');
      debugPrint('نص الرسالة: $message');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'number': cleanNumber,
          'message': message,
        }),
      );

      debugPrint('استجابة API: ${response.statusCode}');
      debugPrint('محتوى الاستجابة: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('خطأ في إرسال رسالة واتساب: $e');
      return false;
    }
  }

  Future<bool> sendPaymentReminder({
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
      return false;
    }
  }

  Future<bool> schedulePaymentReminder({
    required String phoneNumber,
    required String customerName,
    required double amount,
    required DateTime dueDate,
    required DateTime scheduleDate,
    String? customMessage,
  }) async {
    try {
      final defaultMessage = 'السلام عليكم @الاسم،\nنود تذكيركم بموعد استحقاق @النوع بقيمة @المبلغ في تاريخ @التاريخ';
      
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
      return false;
    }
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('EEEE، d MMMM yyyy', 'ar');
    return formatter.format(date);
  }

  String _formatTime(DateTime date) {
    final formatter = DateFormat('h:mm a', 'ar');
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
    final formattedDate = DateFormat('yyyy/MM/dd').format(date);
    final paymentType = amount >= 0 ? 'دفعة' : 'دين';

    return message
      .replaceAll('@الاسم', customerName)
      .replaceAll('@الرقم', phoneNumber)
      .replaceAll('@المبلغ', formattedAmount)
      .replaceAll('@التاريخ', formattedDate)
      .replaceAll('@النوع', paymentType);
  }
}
