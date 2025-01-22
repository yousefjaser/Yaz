import 'package:workmanager/workmanager.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/services/whatsapp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:yaz/main.dart';
import 'package:intl/intl.dart';

class ReminderService {
  static const String reminderTask = 'payment_reminder';

  Future<void> initialize() async {
    debugPrint('تهيئة خدمة التذكير...');
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true,
      );
      debugPrint('تم تهيئة خدمة التذكير بنجاح');
    } catch (e) {
      debugPrint('خطأ في تهيئة خدمة التذكير: $e');
      rethrow;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('yyyy/MM/dd HH:mm', 'ar');
    return formatter.format(dateTime.toLocal());
  }

  Future<void> scheduleReminder(int paymentId, DateTime reminderDate) async {
    try {
      final uniqueId = 'payment_$paymentId';
      final localReminderDate = reminderDate.toLocal();
      debugPrint(
          'جدولة تذكير للدفعة: $paymentId في تاريخ: ${_formatDateTime(localReminderDate)}');

      // إلغاء أي تذكير سابق لنفس الدفعة
      await Workmanager().cancelByUniqueName(uniqueId);

      // حساب الفترة المتبقية حتى موعد التذكير
      final now = DateTime.now();
      final delay = localReminderDate.difference(now);

      debugPrint('الوقت الحالي: ${_formatDateTime(now)}');
      debugPrint('موعد التذكير: ${_formatDateTime(localReminderDate)}');
      debugPrint('الفرق بالدقائق: ${delay.inMinutes}');

      // التحقق من أن موعد التذكير لم يمر بعد
      if (delay.inMinutes > 0) {
        // تقسيم التذكيرات الطويلة إلى فترات أقصر
        if (delay.inDays > 0) {
          // إذا كان الموعد بعد أكثر من يوم، نجدول تذكيراً كل يوم
          for (int i = 1; i <= delay.inDays; i++) {
            final dailyReminder = now.add(Duration(days: i));
            if (dailyReminder.isBefore(localReminderDate)) {
              await _scheduleReminderTask(
                '${uniqueId}_daily_$i',
                paymentId,
                dailyReminder,
              );
            }
          }
        }

        // جدولة التذكير الرئيسي
        await _scheduleReminderTask(
          uniqueId,
          paymentId,
          localReminderDate,
        );
        debugPrint('تم جدولة التذكير بنجاح');
      } else {
        debugPrint('تم تجاوز موعد التذكير');
      }
    } catch (e) {
      debugPrint('خطأ في جدولة التذكير: $e');
      rethrow;
    }
  }

  Future<void> _scheduleReminderTask(
    String uniqueId,
    int paymentId,
    DateTime scheduledTime,
  ) async {
    final delay = scheduledTime.difference(DateTime.now());
    await Workmanager().registerOneOffTask(
      uniqueId,
      reminderTask,
      initialDelay: delay,
      inputData: {
        'payment_id': paymentId,
        'scheduled_time': scheduledTime.toIso8601String(),
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    debugPrint(
        'تم جدولة مهمة التذكير: $uniqueId للتاريخ: ${_formatDateTime(scheduledTime)}');
  }

  Future<void> cancelReminder(int paymentId) async {
    try {
      final uniqueId = 'payment_$paymentId';
      await Workmanager().cancelByUniqueName(uniqueId);
      // إلغاء التذكيرات اليومية أيضاً
      for (int i = 1; i <= 30; i++) {
        await Workmanager().cancelByUniqueName('${uniqueId}_daily_$i');
      }
      debugPrint('تم إلغاء التذكير للدفعة: $paymentId');
    } catch (e) {
      debugPrint('خطأ في إلغاء التذكير: $e');
      rethrow;
    }
  }
}
