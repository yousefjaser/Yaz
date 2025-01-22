import 'dart:convert';
import 'package:http/http.dart' as http;

class TwilioService {
  static final TwilioService _instance = TwilioService._internal();
  final String accountSid = 'AC74ec2f52eccba640623773672ef94391';
  final String authToken = '8912e2cec3b9bed5c40bc7b3c10cb4af';
  final String twilioNumber = '+16508806290';

  factory TwilioService() {
    return _instance;
  }

  TwilioService._internal();

  Future<bool> sendMessage(String to, String message) async {
    try {
      final url = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

      final formattedPhone = _formatPhoneNumber(to);

      final response = await http.post(
        url,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': twilioNumber,
          'To': formattedPhone,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('تم إرسال الرسالة بنجاح');
        print('معرف الرسالة: ${responseData['sid']}');
        print('الحالة: ${responseData['status']}');
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(
          'خطأ Twilio (${error['code']}): ${error['message']}\n'
          'للمزيد من المعلومات: ${error['more_info']}',
        );
      }
    } catch (e) {
      throw Exception('فشل في إرسال الرسالة: $e');
    }
  }

  String _formatPhoneNumber(String phone) {
    // إزالة المسافات والرموز الخاصة
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // التحقق من تنسيق الرقم
    if (phone.startsWith('0')) {
      // تحويل 0598565009 إلى +970598565009
      phone = '+970${phone.substring(1)}';
    } else if (phone.length == 9) {
      // تحويل 598565009 إلى +970598565009
      phone = '+970$phone';
    } else if (phone.startsWith('+')) {
      // لا تغيير إذا كان الرقم يبدأ بـ +
      return phone;
    } else {
      throw Exception(
          'رقم الهاتف غير صالح. يجب أن يبدأ بـ 0 أو يتكون من 9 أرقام');
    }

    // التحقق من طول رقم الهاتف النهائي
    if (phone.length != 13) {
      throw Exception('رقم الهاتف غير صالح: $phone');
    }

    print('تم تنسيق رقم الهاتف: $phone');
    return phone;
  }
}
