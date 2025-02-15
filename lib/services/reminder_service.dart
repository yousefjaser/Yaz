import 'package:workmanager/workmanager.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/services/whatsapp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:yaz/main.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class ReminderService {
  static const String reminderTask = 'payment_reminder';
  final SupabaseClient _supabase;
  final LocalStorageService storage;
  final DatabaseService database;
  static ReminderService? _instance;

  ReminderService._({
    required this.storage,
    required this.database,
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  static Future<ReminderService> getInstance() async {
    if (_instance == null) {
      final storage = await LocalStorageService.getInstance();
      final database = await DatabaseService.getInstance();
      final supabase = Supabase.instance.client;

      _instance = ReminderService._(
        storage: storage,
        database: database,
        supabase: supabase,
      );

      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
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

      // الحصول على معلومات الدفعة والعميل
      final payment = await database.getPaymentById(paymentId);
      if (payment == null) {
        throw Exception('لم يتم العثور على الدفعة');
      }

      // إنشاء تذكير جديد في قاعدة البيانات
      final reminder = Reminder(
        customerId: payment.customerId,
        reminderDate: localReminderDate,
        message: payment.notes?.isNotEmpty == true
            ? payment.notes!
            : 'تذكير بموعد الدفعة',
      );

      // حفظ التذكير في Supabase
      await createReminder(reminder);

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

  Future<void> createReminder(Reminder reminder) async {
    try {
      // لا نقوم بتعيين معرف - سيقوم Supabase بإنشائه تلقائياً
      final response = await _supabase
          .from('reminders')
          .insert({
            'customer_id': reminder.customerId,
            'reminder_date': reminder.reminderDate.toIso8601String(),
            'message': reminder.message,
            'is_completed': reminder.isCompleted,
            'created_at': reminder.createdAt.toIso8601String(),
            'is_synced': true,
          })
          .select()
          .single();
      
      // تحديث المعرف من السيرفر
      reminder.id = response['id'].toString();
      reminder.isSynced = true;
      
      // حفظ التذكير في التخزين المحلي
      await storage.insertReminder(reminder);
      
      debugPrint('تم إنشاء التذكير بنجاح مع المعرف: ${reminder.id}');
    } catch (e) {
      debugPrint('خطأ في إنشاء التذكير: $e');
      throw Exception('فشل في إنشاء التذكير: $e');
    }
  }

  Future<List<Reminder>> getCustomerReminders(String customerId) async {
    try {
      final response = await _supabase
          .from('reminders')
          .select()
          .eq('customer_id', customerId)
          .order('reminder_date');

      return (response as List).map((data) => Reminder.fromJson(data)).toList();
    } catch (e) {
      throw Exception('فشل في جلب التذكيرات: $e');
    }
  }

  Future<void> markReminderAsCompleted(String reminderId) async {
    try {
      await _supabase
          .from('reminders')
          .update({'is_completed': true}).eq('id', reminderId);
    } catch (e) {
      throw Exception('فشل في تحديث حالة التذكير: $e');
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    try {
      await _supabase.from('reminders').delete().eq('id', reminderId);
    } catch (e) {
      throw Exception('فشل في حذف التذكير: $e');
    }
  }
}
