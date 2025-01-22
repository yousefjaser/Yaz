import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;
  late final SyncService _syncService;
  bool _isInitialized = false;
  late final Box<Customer> _customersBox;
  late final Box<Payment> _paymentsBox;
  static DatabaseService? _instance;

  DatabaseService._();

  static Future<DatabaseService> getInstance() async {
    if (_instance == null) {
      _instance = DatabaseService._();
      try {
        await _instance!.init();
      } catch (e) {
        _instance = null;
        debugPrint('خطأ في تهيئة DatabaseService: $e');
        rethrow;
      }
    }
    return _instance!;
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      debugPrint('فتح صناديق Hive...');
      try {
        _customersBox = await Hive.openBox<Customer>('customers');
      } catch (e) {
        debugPrint('خطأ في فتح صندوق العملاء: $e');
        await Hive.deleteBoxFromDisk('customers');
        _customersBox = await Hive.openBox<Customer>('customers');
      }

      try {
        _paymentsBox = await Hive.openBox<Payment>('payments');
      } catch (e) {
        debugPrint('خطأ في فتح صندوق الدفعات: $e');
        await Hive.deleteBoxFromDisk('payments');
        _paymentsBox = await Hive.openBox<Payment>('payments');
      }

      debugPrint('تهيئة خدمة المزامنة...');
      _syncService = SyncService(
        _supabase,
        this,
        _customersBox,
        _paymentsBox,
      );

      await _syncService.init();
      _isInitialized = true;
      debugPrint('تم تهيئة DatabaseService بنجاح');
    } catch (e) {
      debugPrint('خطأ في تهيئة DatabaseService: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('يجب تهيئة قاعدة البيانات أولاً');
    }
  }

  Future<List<Customer>> getAllCustomers() async {
    _checkInitialized();
    debugPrint('محاولة جلب العملاء...');

    try {
      // محاولة جلب البيانات المحلية أولاً
      final localCustomers = await _syncService.getLocalCustomers();
      debugPrint('تم العثور على ${localCustomers.length} عميل محلياً');

      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('لا يوجد اتصال بالإنترنت، استخدام البيانات المحلية');
        return localCustomers;
      }

      try {
        debugPrint('محاولة جلب البيانات من السيرفر...');
        final serverCustomers = await _fetchCustomersFromServer();
        debugPrint('تم جلب ${serverCustomers.length} عميل من السيرفر');

        // حفظ البيانات محلياً
        await _syncService.saveCustomersLocally(serverCustomers);
        return serverCustomers;
      } catch (serverError) {
        debugPrint('خطأ في جلب البيانات من السيرفر: $serverError');
        if (localCustomers.isNotEmpty) {
          debugPrint('استخدام البيانات المحلية كخطة بديلة');
          return localCustomers;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('خطأ في جلب العملاء: $e');
      // محاولة أخيرة لجلب البيانات المحلية
      try {
        final fallbackCustomers = await _syncService.getLocalCustomers();
        if (fallbackCustomers.isNotEmpty) {
          debugPrint(
              'تم استرجاع ${fallbackCustomers.length} عميل من التخزين المحلي');
          return fallbackCustomers;
        }
      } catch (localError) {
        debugPrint('فشل في استرجاع البيانات المحلية: $localError');
      }
      return [];
    }
  }

  Future<List<Customer>> _fetchCustomersFromServer() async {
    try {
      // التحقق من صلاحية الجلسة وتجديدها إذا لزم الأمر
      await _refreshSessionIfNeeded();

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      // محاولة جلب البيانات مع إعادة المحاولة في حالة انتهاء الجلسة
      for (int i = 0; i < 3; i++) {
        try {
          final response = await _supabase
              .from('customers')
              .select('*, payments(*)')
              .eq('user_id', userId)
              .order('created_at');

          final customers = (response as List).map((data) async {
            data['id'] = int.parse(data['id'].toString());
            final customer = Customer.fromMap(data);

            // التحقق من اللون في الخلفية
            await _ensureCustomerColorSilently(customer);

            if (data['payments'] != null) {
              customer.payments = (data['payments'] as List).map((payment) {
                payment['id'] = int.parse(payment['id'].toString());
                return Payment.fromMap(payment);
              }).toList();
            }
            return customer;
          });

          return Future.wait(customers);
        } catch (e) {
          if (e.toString().contains('JWT expired')) {
            debugPrint('انتهت صلاحية الجلسة، محاولة تجديد الجلسة...');
            await _refreshSessionIfNeeded();
            continue;
          }
          if (i == 2) throw e;
          await Future.delayed(Duration(seconds: 1));
        }
      }
      throw Exception('فشلت جميع محاولات جلب البيانات');
    } catch (e) {
      debugPrint('خطأ في جلب العملاء: $e');
      rethrow;
    }
  }

  Future<void> _refreshSessionIfNeeded() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugPrint('لا توجد جلسة نشطة، محاولة إعادة تسجيل الدخول...');
        await _handleSessionRefreshError();
        return;
      }

      // التحقق من انتهاء صلاحية الجلسة
      final expiresIn = session.expiresAt;
      if (expiresIn == null) {
        debugPrint('لا يمكن تحديد وقت انتهاء الجلسة');
        throw Exception('لا يمكن تحديد وقت انتهاء الجلسة');
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresIn * 1000);
      final timeUntilExpiry = expiresAt.difference(DateTime.now());

      // تجديد الجلسة إذا كان الوقت المتبقي أقل من 5 دقائق أو إذا انتهت الصلاحية
      if (timeUntilExpiry.inMinutes <= 5 || timeUntilExpiry.isNegative) {
        debugPrint('الجلسة منتهية أو على وشك الانتهاء، جاري التجديد...');

        // محاولة تجديد الجلسة
        final response = await _supabase.auth.refreshSession();
        if (response.session == null) {
          debugPrint('فشل في تجديد الجلسة، محاولة إعادة تسجيل الدخول...');
          await _handleSessionRefreshError();
          return;
        }

        debugPrint('تم تجديد الجلسة بنجاح');
      }
    } catch (e) {
      debugPrint('خطأ في تجديد الجلسة: $e');
      // محاولة إعادة تسجيل الدخول تلقائياً
      await _handleSessionRefreshError();
    }
  }

  Future<void> _ensureCustomerColorSilently(Customer customer) async {
    try {
      final response = await _supabase
          .from('customers')
          .select('color')
          .eq('id', customer.id.toString())
          .single();

      if (response['color'] == null) {
        await _supabase
            .from('customers')
            .update({'color': customer.color}).eq('id', customer.id.toString());
      }
    } catch (e) {
      // تجاهل الأخطاء للعمل في الخلفية بصمت
      debugPrint('خطأ صامت في التحقق من لون العميل: $e');
    }
  }

  Future<int> insertCustomer(Customer customer) async {
    try {
      // التحقق من الجلسة وتجديدها إذا لزم الأمر
      await _refreshSessionIfNeeded();

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      // محاولة إضافة العميل مع إعادة المحاولة في حالة الفشل
      for (int i = 0; i < 3; i++) {
        try {
          final response = await _supabase
              .from('customers')
              .insert({
                'name': customer.name,
                'phone': customer.phone,
                'address': customer.address,
                'notes': customer.notes,
                'color': customer.color,
                'balance': customer.balance,
                'user_id': userId,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          return response['id'];
        } catch (e) {
          if (e.toString().contains('JWT expired')) {
            debugPrint('انتهت صلاحية الجلسة، محاولة تجديد الجلسة...');
            await _refreshSessionIfNeeded();
            if (i < 2) continue;
          }
          rethrow;
        }
      }
      throw Exception('فشلت جميع محاولات إضافة العميل');
    } catch (e) {
      debugPrint('خطأ في إضافة العميل: $e');
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    await _supabase
        .from('customers')
        .update({
          'name': customer.name,
          'phone': customer.phone,
          'address': customer.address,
          'balance': customer.balance,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', customer.id.toString())
        .eq('user_id', userId);
  }

  Future<List<Payment>> getCustomerPayments(int customerId) async {
    _checkInitialized();

    try {
      // التحقق من صلاحية الجلسة وتجديدها إذا لزم الأمر
      await _refreshSessionIfNeeded();

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      // محاولة جلب الدفعات مع إعادة المحاولة في حالة الفشل
      for (int i = 0; i < 3; i++) {
        try {
          final response = await _supabase
              .from('payments')
              .select()
              .eq('customer_id', customerId)
              .eq('is_deleted', false)
              .order('date');

          return (response as List)
              .map((payment) => Payment.fromMap(payment))
              .toList();
        } catch (e) {
          if (e.toString().contains('JWT expired')) {
            debugPrint('انتهت صلاحية الجلسة، محاولة تجديد الجلسة...');
            await _refreshSessionIfNeeded();
            if (i < 2) continue;
          }
          rethrow;
        }
      }
      throw Exception('فشلت جميع محاولات جلب الدفعات');
    } catch (e) {
      debugPrint('خطأ في جلب الدفعات: $e');
      rethrow;
    }
  }

  Future<Customer?> getCustomerById(int customerId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    final response = await _supabase
        .from('customers')
        .select('*, payments(*)')
        .eq('id', customerId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;

    final customer = Customer.fromMap(response);
    if (response['payments'] != null) {
      customer.payments = (response['payments'] as List)
          .map((payment) => Payment.fromMap({...payment, 'id': payment['id']}))
          .toList();
    }
    return customer;
  }

  Future<String> insertPayment(Payment payment) async {
    _checkInitialized();
    debugPrint('إضافة دفعة جديدة...');
    debugPrint('معرف العميل: ${payment.customerId}');
    debugPrint('المبلغ: ${payment.amount}');
    debugPrint('التاريخ: ${payment.date}');

    try {
      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('لا يوجد اتصال بالإنترنت. حفظ الدفعة محلياً...');
        payment.isSynced = false;
        await _paymentsBox.put(payment.id.toString(), payment);
        return payment.id.toString();
      }

      // محاولة حفظ الدفعة على السيرفر
      try {
        final response = await _supabase
            .from('payments')
            .insert({
              'customer_id': payment.customerId,
              'amount': payment.amount,
              'date': payment.date.toIso8601String(),
              'reminder_date': payment.reminderDate?.toIso8601String(),
              'notes': payment.notes,
              'reminder_sent': payment.reminderDate != null ? false : null,
              'reminder_sent_at': null,
              'is_deleted': false,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        payment.id = int.parse(response['id'].toString());
        payment.isSynced = true;
        debugPrint('تم حفظ الدفعة على السيرفر. المعرف: ${payment.id}');
      } catch (e) {
        debugPrint('خطأ في حفظ الدفعة على السيرفر: $e');
        payment.isSynced = false;
      }

      // حفظ الدفعة محلياً
      await _paymentsBox.put(payment.id.toString(), payment);
      debugPrint('تم حفظ الدفعة محلياً');

      return payment.id.toString();
    } catch (e) {
      debugPrint('خطأ في حفظ الدفعة: $e');
      rethrow;
    }
  }

  Future<void> updatePayment(Payment payment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    if (payment.id == null) {
      throw Exception('لا يمكن تحديث دفعة بدون معرف');
    }

    await _supabase.from('payments').update({
      'amount': payment.amount,
      'date': payment.date.toIso8601String(),
      'notes': payment.notes,
      'reminder_date': payment.reminderDate?.toIso8601String(),
      'reminder_sent': payment.reminderSent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', payment.id.toString());
  }

  Future<void> deletePayment(int paymentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      await _supabase.from('payments').delete().eq('id', paymentId);
    } catch (e) {
      throw Exception('فشل في حذف الدفعة: $e');
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    await _supabase
        .from('customers')
        .delete()
        .eq('id', customerId)
        .eq('user_id', userId)
        .select();
  }

  Future<void> saveLocalCustomer(Customer customer) async {
    final box = await Hive.openBox<Customer>('customers');
    await box.add(customer);
  }

  Future<void> dispose() async {
    debugPrint('إغلاق DatabaseService...');
    try {
      if (_customersBox.isOpen) {
        await _customersBox.close();
      }
      if (_paymentsBox.isOpen) {
        await _paymentsBox.close();
      }
      await _syncService.dispose();
      _isInitialized = false;
      debugPrint('تم إغلاق DatabaseService بنجاح');
    } catch (e) {
      debugPrint('خطأ في إغلاق DatabaseService: $e');
    }
  }

  Future<List<Customer>> getAllCustomersFromServer() async {
    _checkInitialized();
    final session = _supabase.auth.currentSession;
    if (session == null) return [];

    final response = await _supabase
        .from('customers')
        .select()
        .eq('user_id', session.user.id);

    final customers = (response as List).map((data) {
      final customer = Customer.fromMap(data);
      // التأكد من وجود لون لكل عميل
      ensureCustomerColor(customer);
      return customer;
    }).toList();

    return customers;
  }

  Future<List<Customer>> getAllLocalCustomers() async {
    final box = await Hive.openBox<Customer>('customers');
    return box.values.toList();
  }

  Future<void> movePaymentToTrash(Payment payment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      await _supabase.from('payments').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', payment.id.toString());
    } catch (e) {
      throw Exception('فشل في نقل الدفعة إلى سلة المحذوفات: $e');
    }
  }

  Future<void> restorePayment(int paymentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      await _supabase.from('payments').update({
        'is_deleted': false,
        'deleted_at': null,
      }).eq('id', paymentId);
    } catch (e) {
      throw Exception('فشل في استعادة الدفعة: $e');
    }
  }

  Future<List<Payment>> getDeletedPayments() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      final response = await _supabase
          .from('payments')
          .select('*, customers(*)')
          .eq('is_deleted', true)
          .order('deleted_at', ascending: false);

      return (response as List).map((data) => Payment.fromMap(data)).toList();
    } catch (e) {
      throw Exception('فشل في جلب الدفعات المحذوفة: $e');
    }
  }

  Future<void> restorePaymentFromTrash(int paymentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      await _supabase.from('payments').update({
        'is_deleted': false,
        'deleted_at': null,
      }).eq('id', paymentId.toString());
    } catch (e) {
      throw Exception('فشل في استعادة الدفعة من سلة المحذوفات: $e');
    }
  }

  Future<void> permanentlyDeletePayments(List<int> paymentIds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      for (final id in paymentIds) {
        await _supabase.from('payments').delete().eq('id', id.toString());
      }
    } catch (e) {
      throw Exception('فشل في الحذف النهائي للدفعات: $e');
    }
  }

  Future<void> permanentlyDeleteCustomers(List<int> customerIds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      for (final id in customerIds) {
        await _supabase.from('customers').delete().eq('id', id.toString());
      }
    } catch (e) {
      throw Exception('فشل في الحذف النهائي للعملاء: $e');
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      // تنظيف البريد الإلكتروني
      email = email.trim().toLowerCase();

      // التحقق من صحة تنسيق البريد الإلكتروني
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('عنوان البريد الإلكتروني غير صالح');
      }

      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      if (e.toString().contains('email_address_invalid')) {
        throw Exception('عنوان البريد الإلكتروني غير صالح');
      } else {
        throw Exception('حدث خطأ في إنشاء الحساب: ${e.toString()}');
      }
    }
  }

  Future<bool> checkAuthentication() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugPrint('لا توجد جلسة نشطة');
        return false;
      }

      debugPrint('معرف المستخدم: ${session.user.id}');

      // التحقق من وجود المستخدم في قاعدة البيانات
      try {
        final response = await _supabase
            .from('users')
            .select('id')
            .eq('id', session.user.id)
            .single();

        if (response == null) {
          // إنشاء مستخدم جديد إذا لم يكن موجوداً
          await _supabase.from('users').insert({
            'id': session.user.id,
            'email': session.user.email,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        return true;
      } catch (e) {
        debugPrint('خطأ في الوصول لقاعدة البيانات: $e');
        return false;
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من المصادقة: $e');
      return false;
    }
  }

  Future<void> ensureCustomerColor(Customer customer) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      final response = await _supabase
          .from('customers')
          .select('color')
          .eq('id', customer.id.toString())
          .single();

      if (response['color'] == null) {
        await _supabase
            .from('customers')
            .update({'color': customer.color})
            .eq('id', customer.id.toString())
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من لون العميل: $e');
    }
  }

  Future<void> _handleSessionRefreshError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (email != null && password != null) {
        debugPrint('محاولة إعادة تسجيل الدخول تلقائياً...');

        // إلغاء الجلسة الحالية
        await _supabase.auth.signOut();
        await Future.delayed(Duration(seconds: 1));

        // محاولة تسجيل الدخول من جديد
        final response = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.session == null) {
          throw Exception('فشل في إعادة تسجيل الدخول');
        }

        debugPrint('تم إعادة تسجيل الدخول بنجاح');
        return;
      } else {
        throw Exception('لا توجد بيانات تسجيل الدخول');
      }
    } catch (e) {
      debugPrint('خطأ في إعادة تسجيل الدخول: $e');
      rethrow;
    }
  }

  Future<List<Payment>> getPayments(Customer customer) async {
    try {
      if (customer.id == null) {
        throw Exception('معرف العميل غير موجود');
      }

      final response = await _supabase
          .from('payments')
          .select()
          .eq('customer_id', customer.id.toString())
          .order('date', ascending: false);

      return (response as List)
          .map((payment) => Payment.fromJson(payment))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب المدفوعات: $e');
      rethrow;
    }
  }

  Future<void> addPayment(Customer customer, Payment payment) async {
    try {
      final response = await _supabase.from('payments').insert({
        'customer_id': customer.id,
        'amount': payment.amount,
        'date': payment.date.toIso8601String(),
        'notes': payment.notes,
        'reminder_date': payment.reminderDate?.toIso8601String(),
      }).select();

      if (response == null || (response as List).isEmpty) {
        throw Exception('فشل في إضافة الدفعة');
      }
    } catch (e) {
      debugPrint('خطأ في إضافة الدفعة: $e');
      rethrow;
    }
  }

  Future<List<Payment>> getAllPayments() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      final response = await _supabase
          .from('payments')
          .select('*, customers(*)')
          .eq('user_id', userId)
          .order('date', ascending: false);

      return (response as List)
          .map((payment) => Payment.fromJson(payment))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب جميع المدفوعات: $e');
      return [];
    }
  }
}
