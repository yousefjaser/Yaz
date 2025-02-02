import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/database_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'local_storage_service.dart';

class SyncService {
  final SupabaseClient _supabase;
  final DatabaseService _databaseService;
  final Box<Customer> _customersLocal;
  final Box<Payment> _paymentsLocal;
  bool _isInitialized = false;
  Timer? _syncTimer;

  SyncService(
    this._supabase,
    this._databaseService,
    this._customersLocal,
    this._paymentsLocal,
  ) {
    // بدء المزامنة التلقائية كل 5 دقائق
    _startAutoSync();
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          await syncAll();
        } catch (e) {
          debugPrint('خطأ في المزامنة التلقائية: $e');
        }
      }
    });
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      debugPrint('تهيئة خدمة المزامنة...');
      await _ensureBoxesOpen();
      _isInitialized = true;
      debugPrint('تم تهيئة خدمة المزامنة بنجاح');

      // مزامنة أولية
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await syncAll();
      }
    } catch (e) {
      debugPrint('خطأ في تهيئة خدمة المزامنة: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> syncAll() async {
    try {
      debugPrint('بدء المزامنة الشاملة...');

      // 1. جلب العملاء من السيرفر أولاً
      final serverCustomers = await _fetchServerCustomers();
      debugPrint('تم جلب ${serverCustomers.length} عميل من السيرفر');

      // 2. مزامنة العملاء المحليين غير المتزامنين
      await _syncLocalCustomers();

      // 3. تحديث التخزين المحلي مع بيانات السيرفر
      await _updateLocalStorage(serverCustomers);

      // 4. مزامنة الدفعات
      await _syncPayments();

      // 5. مزامنة التذكيرات
      await _syncReminders();

      debugPrint('تمت المزامنة الشاملة بنجاح');
    } catch (e) {
      debugPrint('خطأ في المزامنة الشاملة: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchServerCustomers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('customers')
          .select('*, payments(*)')
          .eq('user_id', userId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('خطأ في جلب العملاء من السيرفر: $e');
      return [];
    }
  }

  Future<void> _syncLocalCustomers() async {
    try {
      debugPrint('مزامنة العملاء المحليين غير المتزامنين...');

      // التحقق من العملاء غير المتزامنين
      final unsyncedCustomers = _customersLocal.values
          .where((customer) => !customer.isSynced)
          .toList();

      if (unsyncedCustomers.isEmpty) {
        debugPrint('لا يوجد عملاء غير متزامنين');
        return;
      }

      debugPrint('عدد العملاء غير المتزامنين: ${unsyncedCustomers.length}');

      // جلب العملاء الحاليين من السيرفر للتحقق من التكرار
      final existingCustomers = await _fetchServerCustomers();
      final existingPhones = existingCustomers
          .map((c) => c['phone']?.toString().trim())
          .where((p) => p != null && p.isNotEmpty)
          .toSet();

      for (var customer in unsyncedCustomers) {
        try {
          // التحقق من عدم وجود العميل مسبقاً
          if (existingPhones.contains(customer.phone.trim())) {
            debugPrint(
                'العميل ${customer.name} موجود مسبقاً (رقم الهاتف مكرر)');
            await _customersLocal.delete(customer.id.toString());
            continue;
          }

          // رفع العميل للسيرفر
          final response = await _supabase
              .from('customers')
              .insert({
                'name': customer.name.trim(),
                'phone': customer.phone.trim(),
                'address': customer.address?.trim(),
                'notes': customer.notes?.trim(),
                'color': customer.color,
                'balance': customer.balance,
                'created_at': customer.createdAt?.toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
                'user_id': _supabase.auth.currentUser?.id,
              })
              .select()
              .single();

          // حذف النسخة القديمة
          await _customersLocal.delete(customer.id.toString());

          // تحديث العميل بالـ id الجديد من السيرفر
          customer.id = response['id'];
          customer.isSynced = true;
          await _customersLocal.put(customer.id.toString(), customer);
          debugPrint('تمت مزامنة العميل: ${customer.name} (${customer.id})');
        } catch (e) {
          debugPrint('خطأ في مزامنة العميل ${customer.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('خطأ في مزامنة العملاء المحليين: $e');
    }
  }

  Future<void> _updateLocalStorage(
      List<Map<String, dynamic>> serverCustomers) async {
    try {
      debugPrint('تحديث التخزين المحلي...');
      debugPrint('عدد العملاء في السيرفر: ${serverCustomers.length}');

      // إنشاء مجموعة من أرقام الهواتف الموجودة
      final Set<String> existingPhones = {};

      // تحديث العملاء الموجودين وإضافة الجدد
      for (var serverCustomer in serverCustomers) {
        final customerId = serverCustomer['id'].toString();
        final phone = serverCustomer['phone']?.toString().trim() ?? '';

        // تخطي العملاء المكررين
        if (phone.isNotEmpty && existingPhones.contains(phone)) {
          debugPrint('تم تخطي عميل مكرر: $phone');
          continue;
        }

        if (phone.isNotEmpty) {
          existingPhones.add(phone);
        }

        // تحويل بيانات العميل
        final customer = Customer.fromMap(serverCustomer);
        customer.isSynced = true;

        // حفظ العميل محلياً
        await _customersLocal.put(customerId, customer);

        // معالجة الدفعات
        if (serverCustomer['payments'] != null) {
          for (var paymentData in serverCustomer['payments']) {
            final payment = Payment.fromMap(paymentData);
            payment.isSynced = true;
            await _paymentsLocal.put(payment.id.toString(), payment);
          }
        }
      }

      // حذف العملاء المكررين من التخزين المحلي
      final localCustomers = _customersLocal.values.toList();
      final phonesToKeep = <String, String>{}; // phone -> customerId

      for (var customer in localCustomers) {
        final phone = customer.phone.trim();
        if (phone.isEmpty) continue;

        if (phonesToKeep.containsKey(phone)) {
          // حذف النسخة المكررة
          await _customersLocal.delete(customer.id.toString());
          debugPrint('تم حذف عميل مكرر محلياً: ${customer.name} ($phone)');
        } else {
          phonesToKeep[phone] = customer.id.toString();
        }
      }

      debugPrint('تم تحديث التخزين المحلي بنجاح');
      debugPrint('عدد العملاء المحليين: ${_customersLocal.length}');
      debugPrint('عدد الدفعات المحلية: ${_paymentsLocal.length}');
    } catch (e) {
      debugPrint('خطأ في تحديث التخزين المحلي: $e');
    }
  }

  Future<void> _syncPayments() async {
    try {
      debugPrint('مزامنة الدفعات غير المتزامنة...');
      final unsyncedPayments =
          _paymentsLocal.values.where((payment) => !payment.isSynced).toList();

      for (var payment in unsyncedPayments) {
        try {
          // رفع الدفعة للسيرفر بدون تحديد الـ id
          final response = await _supabase
              .from('payments')
              .insert({
                'customer_id': payment.customerId,
                'amount': payment.amount,
                'date': payment.date.toIso8601String(),
                'notes': payment.notes,
                'title': payment.title,
                'reminder_date': payment.reminderDate?.toIso8601String(),
                'reminder_sent': payment.reminderSent,
                'created_at': payment.createdAt?.toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
                'user_id': _supabase.auth.currentUser?.id,
              })
              .select()
              .single();

          // حذف النسخة القديمة
          await _paymentsLocal.delete(payment.id.toString());

          // تحديث الدفعة بالـ id الجديد من السيرفر
          payment.id = response['id'];
          payment.isSynced = true;
          await _paymentsLocal.put(payment.id.toString(), payment);
          debugPrint('تمت مزامنة الدفعة: ${payment.id}');

          // تحديث رصيد العميل
          await _updateCustomerBalance(payment.customerId);
        } catch (e) {
          debugPrint('خطأ في مزامنة الدفعة: $e');
        }
      }
    } catch (e) {
      debugPrint('خطأ في مزامنة الدفعات: $e');
    }
  }

  Future<void> _syncReminders() async {
    try {
      debugPrint('مزامنة التذكيرات...');

      // جلب الدفعات التي لديها تذكيرات لم يتم إرسالها
      final paymentsWithReminders = _paymentsLocal.values.where((payment) {
        if (payment.reminderDate == null) return false;
        if (payment.reminderSent == null) return false;
        return !payment.reminderSent! &&
            payment.reminderDate!.isAfter(DateTime.now());
      }).toList();

      for (var payment in paymentsWithReminders) {
        try {
          if (payment.id == null) continue;

          // تحديث حالة التذكير على السيرفر
          await _supabase.from('payments').update({
            'reminder_sent': payment.reminderSent,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', payment.id!);

          debugPrint('تم تحديث حالة التذكير للدفعة: ${payment.id}');
        } catch (e) {
          debugPrint('خطأ في مزامنة تذكير الدفعة ${payment.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('خطأ في مزامنة التذكيرات: $e');
      rethrow;
    }
  }

  Future<void> _updateCustomerBalance(int customerId) async {
    try {
      // حساب الرصيد الجديد
      final payments = _paymentsLocal.values
          .where((payment) => payment.customerId == customerId)
          .toList();

      double newBalance = 0;
      for (var payment in payments) {
        newBalance += payment.amount;
      }

      // تحديث رصيد العميل محلياً
      final customer = _customersLocal.get(customerId.toString());
      if (customer != null) {
        customer.balance = newBalance;
        customer.isSynced = false;
        await _customersLocal.put(customerId.toString(), customer);
      }

      // تحديث الرصيد على السيرفر
      await _supabase.from('customers').update({
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', customerId);

      debugPrint('تم تحديث رصيد العميل $customerId');
    } catch (e) {
      debugPrint('خطأ في تحديث رصيد العميل: $e');
    }
  }

  Future<void> _ensureBoxesOpen() async {
    try {
      if (!_customersLocal.isOpen) {
        debugPrint('فتح صندوق العملاء...');
        await Hive.openBox<Customer>('customers');
      }
      if (!_paymentsLocal.isOpen) {
        debugPrint('فتح صندوق الدفعات...');
        await Hive.openBox<Payment>('payments');
      }
    } catch (e) {
      debugPrint('خطأ في فتح الصناديق: $e');
      rethrow;
    }
  }

  Future<List<Customer>> getLocalCustomers() async {
    try {
      await _ensureBoxesOpen();

      final customers = _customersLocal.values.toList();
      debugPrint('تم جلب ${customers.length} عميل من التخزين المحلي');

      // تحميل الدفعات لكل عميل
      for (var customer in customers) {
        try {
          final payments = _paymentsLocal.values
              .where((payment) => payment.customerId == customer.id)
              .toList();
          customer.payments = payments;
        } catch (e) {
          debugPrint('خطأ في تحميل دفعات العميل ${customer.id}: $e');
        }
      }

      return customers;
    } catch (e) {
      debugPrint('خطأ في جلب العملاء المحليين: $e');
      return [];
    }
  }

  Future<void> saveCustomersLocally(List<Customer> customers) async {
    try {
      debugPrint('حفظ ${customers.length} عميل محلياً...');
      await _ensureBoxesOpen();

      // إنشاء مجموعة لتتبع أرقام الهواتف
      final Map<String, Customer> phoneToCustomer = {};
      final Set<String> idsToDelete = {};

      // تجميع العملاء حسب رقم الهاتف
      for (var customer in customers) {
        final phone = customer.phone.trim();
        if (phone.isEmpty) continue;

        if (phoneToCustomer.containsKey(phone)) {
          // إذا كان العميل موجود مسبقاً، نحتفظ بالأحدث
          final existingCustomer = phoneToCustomer[phone]!;
          if (customer.updatedAt != null &&
              existingCustomer.updatedAt != null &&
              customer.updatedAt!.isAfter(existingCustomer.updatedAt!)) {
            idsToDelete.add(existingCustomer.id.toString());
            phoneToCustomer[phone] = customer;
          } else {
            idsToDelete.add(customer.id.toString());
          }
        } else {
          phoneToCustomer[phone] = customer;
        }
      }

      // حذف العملاء المكررين
      for (var id in idsToDelete) {
        await _customersLocal.delete(id);
        debugPrint('تم حذف العميل المكرر: $id');
      }

      // حفظ العملاء الفريدين
      for (var customer in phoneToCustomer.values) {
        await _customersLocal.put(customer.id.toString(), customer);
        debugPrint('تم حفظ العميل: ${customer.name} (${customer.id})');

        // حفظ الدفعات
        if (customer.payments != null) {
          for (var payment in customer.payments!) {
            // التحقق من وجود دفعة محلية غير متزامنة
            final existingPayment = _paymentsLocal.get(payment.id.toString());
            if (existingPayment != null && !existingPayment.isSynced) {
              debugPrint(
                  'تخطي تحديث الدفعة ${payment.id} لأنها غير متزامنة محلياً');
              continue;
            }

            await _paymentsLocal.put(payment.id.toString(), payment);
          }
        }
      }

      debugPrint('تم حفظ البيانات محلياً بنجاح');
    } catch (e) {
      debugPrint('خطأ في حفظ البيانات محلياً: $e');
      rethrow;
    }
  }

  Future<void> syncLocalData() async {
    try {
      debugPrint('بدء مزامنة البيانات المحلية...');
      await _ensureBoxesOpen();

      final unsyncedCustomers = _customersLocal.values
          .where((customer) => !customer.isSynced)
          .toList();

      final unsyncedPayments =
          _paymentsLocal.values.where((payment) => !payment.isSynced).toList();

      debugPrint(
          'وجدت ${unsyncedCustomers.length} عميل و ${unsyncedPayments.length} دفعة غير متزامنة');

      // مزامنة العملاء
      for (var customer in unsyncedCustomers) {
        try {
          await _databaseService.insertCustomer(customer);
          customer.isSynced = true;
          await _customersLocal.put(customer.id.toString(), customer);
          debugPrint('تمت مزامنة العميل ${customer.id} بنجاح');
        } catch (e) {
          debugPrint('خطأ في مزامنة العميل ${customer.id}: $e');
        }
      }

      // مزامنة الدفعات
      for (var payment in unsyncedPayments) {
        try {
          await _databaseService.insertPayment(payment);
          payment.isSynced = true;
          await _paymentsLocal.put(payment.id.toString(), payment);
          debugPrint('تمت مزامنة الدفعة ${payment.id} بنجاح');
        } catch (e) {
          debugPrint('خطأ في مزامنة الدفعة ${payment.id}: $e');
        }
      }

      debugPrint('تمت المزامنة بنجاح');
    } catch (e) {
      debugPrint('خطأ في مزامنة البيانات: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    debugPrint('إغلاق خدمة المزامنة...');
    try {
      if (_customersLocal.isOpen) {
        await _customersLocal.close();
      }
      if (_paymentsLocal.isOpen) {
        await _paymentsLocal.close();
      }
      _isInitialized = false;
      debugPrint('تم إغلاق خدمة المزامنة بنجاح');
    } catch (e) {
      debugPrint('خطأ في إغلاق خدمة المزامنة: $e');
    }
  }
}
