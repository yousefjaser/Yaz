import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  final String messageBirdKey = 'YOUR_MESSAGEBIRD_API_KEY';
  final String whatsappChannelId = 'YOUR_WHATSAPP_CHANNEL_ID';

  factory MessageService() {
    return _instance;
  }

  MessageService._internal();

  Future<bool> sendSMS(String to, String message) async {
    try {
      final url = Uri.parse('https://rest.messagebird.com/messages');
      final formattedPhone = _formatPhoneNumber(to);

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'AccessKey $messageBirdKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'recipients': [formattedPhone],
          'originator': 'YazApp',
          'body': message,
        }),
      );

      print('استجابة MessageBird: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('تم إرسال الرسالة بنجاح');
        print('معرف الرسالة: ${responseData['id']}');
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception('خطأ MessageBird:\n'
            'الكود: ${error['errors'][0]['code']}\n'
            'الرسالة: ${error['errors'][0]['description']}');
      }
    } catch (e) {
      throw Exception('فشل في إرسال الرسالة: $e');
    }
  }

  Future<bool> sendWhatsApp(String to, String message) async {
    try {
      debugPrint('محاولة إرسال رسالة واتساب...');

      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // تنظيف وتنسيق رقم الهاتف
      final formattedPhone = _formatPhoneNumber(to);
      debugPrint('رقم الهاتف المنسق: $formattedPhone');

      // التحقق من طول الرسالة
      if (message.trim().isEmpty) {
        throw Exception('الرسالة فارغة');
      }

      if (message.length > 4096) {
        throw Exception('الرسالة طويلة جداً');
      }

      // إرسال الرسالة عبر واتساب
      final url = Uri.parse('https://api.whatsapp.com/send');
      final response = await http.get(
        url.replace(queryParameters: {
          'phone': formattedPhone,
          'text': message,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('تم إرسال الرسالة بنجاح');
        return true;
      } else {
        throw Exception('فشل في إرسال الرسالة: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('خطأ في إرسال رسالة واتساب: $e');
      rethrow;
    }
  }

  String _formatPhoneNumber(String phone) {
    try {
      // إزالة جميع الأحرف غير الرقمية
      phone = phone.replaceAll(RegExp(r'[^\d]'), '');

      // التحقق من أن الرقم غير فارغ
      if (phone.isEmpty) {
        throw Exception('رقم الهاتف فارغ');
      }

      // إزالة الصفر في البداية إذا وجد
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }

      // إضافة رمز الدولة إذا لم يكن موجوداً
      if (!phone.startsWith('972')) {
        phone = '972$phone';
      }

      // التحقق من طول الرقم النهائي
      if (phone.length != 12) {
        throw Exception('رقم الهاتف غير صالح: $phone');
      }

      debugPrint('تم تنسيق رقم الهاتف: $phone');
      return phone;
    } catch (e) {
      debugPrint('خطأ في تنسيق رقم الهاتف: $e');
      rethrow;
    }
  }
}
