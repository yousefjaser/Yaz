import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'dart:math';

class DatabaseService with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  late final SyncService _syncService;
  bool _isInitialized = false;
  late final Box<Customer> _customersBox;
  late final Box<Payment> _paymentsBox;
  static DatabaseService? _instance;

  // إضافة متغيرات جديدة لتتبع حالة المزامنة
  bool _isSyncing = false;
  int _totalItemsToSync = 0;
  int _syncedItems = 0;
  String _syncStatus = '';

  // إضافة getters للوصول إلى حالة المزامنة
  bool get isSyncing => _isSyncing;
  int get totalItemsToSync => _totalItemsToSync;
  int get syncedItems => _syncedItems;
  String get syncStatus => _syncStatus;
  double get syncProgress =>
      _totalItemsToSync > 0 ? _syncedItems / _totalItemsToSync : 0.0;

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
      debugPrint('تهيئة DatabaseService...');

      // التحقق من الاتصال بالإنترنت
      final hasConnection = await ConnectivityService.isConnected();
      debugPrint(hasConnection ? 'متصل بالإنترنت' : 'غير متصل بالإنترنت');

      // تهيئة التخزين المحلي
      try {
        debugPrint('تهيئة التخزين المحلي...');

        // فتح صندوق العملاء
        try {
          _customersBox = await Hive.openBox<Customer>('customers');
          debugPrint('تم فتح صندوق العملاء بنجاح');
        } catch (e) {
          debugPrint('خطأ في فتح صندوق العملاء: $e');
          // محاولة إصلاح صندوق العملاء
          try {
            await Hive.deleteBoxFromDisk('customers');
            _customersBox = await Hive.openBox<Customer>('customers');
            debugPrint('تم إصلاح وإعادة فتح صندوق العملاء');
          } catch (repairError) {
            debugPrint('فشل في إصلاح صندوق العملاء: $repairError');
            throw Exception('فشل في تهيئة صندوق العملاء');
          }
        }

        // فتح صندوق الدفعات
        try {
          _paymentsBox = await Hive.openBox<Payment>('payments');
          debugPrint('تم فتح صندوق الدفعات بنجاح');
        } catch (e) {
          debugPrint('خطأ في فتح صندوق الدفعات: $e');
          // محاولة إصلاح صندوق الدفعات
          try {
            await Hive.deleteBoxFromDisk('payments');
            _paymentsBox = await Hive.openBox<Payment>('payments');
            debugPrint('تم إصلاح وإعادة فتح صندوق الدفعات');
          } catch (repairError) {
            debugPrint('فشل في إصلاح صندوق الدفعات: $repairError');
            throw Exception('فشل في تهيئة صندوق الدفعات');
          }
        }

        debugPrint('تم فتح جميع صناديق Hive بنجاح');
      } catch (e) {
        debugPrint('خطأ في تهيئة التخزين المحلي: $e');
        throw Exception('فشل في تهيئة التخزين المحلي: $e');
      }

      // إذا كان هناك اتصال بالإنترنت، نقوم بتهيئة Supabase والمزامنة
      if (hasConnection) {
        try {
          debugPrint('تهيئة خدمة المزامنة...');
          _syncService = SyncService(
            _supabase,
            this,
            _customersBox,
            _paymentsBox,
          );

          await _syncService.init();
          debugPrint('تم تهيئة خدمة المزامنة بنجاح');
        } catch (e) {
          debugPrint('خطأ في تهيئة خدمة المزامنة: $e');
          // نستمر في العمل حتى مع فشل المزامنة
        }
      } else {
        debugPrint(
            'العمل في وضع عدم الاتصال - سيتم استخدام التخزين المحلي فقط');
      }

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
      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('لا يوجد اتصال بالإنترنت، استخدام البيانات المحلية');
        return await getAllLocalCustomers();
      }

      // التحقق من صلاحية الجلسة
      final session = _supabase.auth.currentSession;
      if (session == null || session.isExpired) {
        debugPrint('لا توجد جلسة صالحة، استخدام البيانات المحلية');
        return await getAllLocalCustomers();
      }

      try {
        debugPrint('جلب البيانات من السيرفر...');
        final response = await _supabase
            .from('customers')
            .select('*, payments(*)')
            .eq('user_id', session.user.id)
            .order('created_at');

        // إنشاء مجموعة لتتبع أرقام الهواتف المكررة
        final Set<String> processedPhones = {};
        final List<Customer> uniqueCustomers = [];

        for (var data in response) {
          final phone = data['phone']?.toString().trim() ?? '';

          // تخطي العملاء المكررين
          if (phone.isNotEmpty && processedPhones.contains(phone)) {
            debugPrint('تم تخطي عميل مكرر من السيرفر: $phone');
            continue;
          }

          if (phone.isNotEmpty) {
            processedPhones.add(phone);
          }

          final customer = Customer.fromMap(data);
          customer.isSynced = true;

          if (data['payments'] != null) {
            customer.payments = (data['payments'] as List).map((payment) {
              final p = Payment.fromMap(payment);
              p.isSynced = true;
              return p;
            }).toList();
          }

          uniqueCustomers.add(customer);
        }

        debugPrint('تم جلب ${uniqueCustomers.length} عميل من السيرفر');
        return uniqueCustomers;
      } catch (e) {
        debugPrint('خطأ في جلب البيانات من السيرفر: $e');
        return await getAllLocalCustomers();
      }
    } catch (e) {
      debugPrint('خطأ في جلب العملاء: $e');
      return await getAllLocalCustomers();
    }
  }

  Future<List<Customer>> getAllLocalCustomers() async {
    try {
      final box = await Hive.openBox<Customer>('customers');
      final currentUserId = _supabase.auth.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('لا يوجد مستخدم حالي');
        return [];
      }

      // إنشاء مجموعة لتتبع أرقام الهواتف المكررة
      final Set<String> processedPhones = {};
      final List<Customer> uniqueCustomers = [];
      final customersToDelete = <String>[];

      for (var customer in box.values) {
        // تخطي العملاء الذين لا ينتمون للمستخدم الحالي
        if (customer.userId != currentUserId) {
          continue;
        }

        final phone = customer.phone.trim();

        if (phone.isEmpty) {
          uniqueCustomers.add(customer);
          continue;
        }

        if (processedPhones.contains(phone)) {
          customersToDelete.add(customer.id.toString());
          debugPrint('تم تحديد عميل مكرر للحذف: ${customer.name} ($phone)');
          continue;
        }

        processedPhones.add(phone);
        uniqueCustomers.add(customer);
      }

      // حذف العملاء المكررين
      for (var id in customersToDelete) {
        await box.delete(id);
      }

      debugPrint('تم تحميل ${uniqueCustomers.length} عميل من التخزين المحلي للمستخدم $currentUserId');
      return uniqueCustomers;
    } catch (e) {
      debugPrint('خطأ في تحميل العملاء المحليين: $e');
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
                'color': customer.color ?? '#000000',
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
    try {
      // جلب الدفعات المحلية أولاً
      final localPayments = _paymentsBox.values
          .where((payment) => payment.customerId == customerId)
          .toList();

      // إذا كان متصلاً، نحاول جلب الدفعات من السيرفر
      if (await ConnectivityService.isConnected()) {
        try {
          final response = await _supabase
              .from('payments')
              .select('*, customers(*)')
              .eq('customer_id', customerId)
              .eq('is_deleted', false)
              .order('date');

          final serverPayments = (response as List).map((payment) {
            final p = Payment.fromMap(payment);
            p.isSynced = true;
            return p;
          }).toList();

          // تحديث التخزين المحلي
          for (var payment in serverPayments) {
            await _paymentsBox.put(payment.id.toString(), payment);
          }

          return serverPayments;
        } catch (e) {
          debugPrint('خطأ في جلب الدفعات من السيرفر: $e');
          return localPayments;
        }
      }

      // إذا لم يكن هناك اتصال، نعيد الدفعات المحلية فقط
      localPayments.sort((a, b) => b.date.compareTo(a.date));
      return localPayments;
    } catch (e) {
      debugPrint('خطأ في جلب الدفعات: $e');
      return [];
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
              'notes': payment.notes,
              'reminder_date': payment.reminderDate?.toIso8601String(),
              'reminder_sent': payment.reminderSent,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'user_id': payment.userId,
              'reminder_sent': payment.reminderSent,
            })
            .select()
            .single();

        payment.id = response['id'];
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

    final updateData = {
      'amount': payment.amount,
      'date': payment.date.toIso8601String(),
      'notes': payment.notes,
      'reminder_date': payment.reminderDate?.toIso8601String(),
      'reminder_sent': payment.reminderSent,
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted': payment.isDeleted,
      'deleted_at': payment.deletedAt?.toIso8601String(),
      'is_synced': payment.isSynced,
    };

    await _supabase.from('payments').update(updateData).eq('id', payment.id!);
  }

  Future<void> deletePayment(int paymentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      // تحديث حالة الحذف بدلاً من الحذف النهائي
      await _supabase.from('payments').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
        'is_synced': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);

      // تحديث في التخزين المحلي
      final payment = _paymentsBox.get(paymentId.toString());
      if (payment != null) {
        payment.isDeleted = true;
        payment.deletedAt = DateTime.now();
        payment.isSynced = false;
        await _paymentsBox.put(paymentId.toString(), payment);
      }
    } catch (e) {
      throw Exception('فشل في حذف الدفعة: $e');
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      // تحديث حالة الحذف بدلاً من الحذف النهائي
      await _supabase
          .from('customers')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
            'is_synced': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', customerId)
          .eq('user_id', userId);

      // تحديث في التخزين المحلي
      final customer = _customersBox.get(customerId.toString());
      if (customer != null) {
        customer.isDeleted = true;
        customer.deletedAt = DateTime.now();
        customer.isSynced = false;
        await _customersBox.put(customerId.toString(), customer);
      }

      // تحديث حالة الدفعات المرتبطة بالعميل
      final customerPayments =
          _paymentsBox.values.where((p) => p.customerId == customerId);
      for (var payment in customerPayments) {
        payment.isDeleted = true;
        payment.deletedAt = DateTime.now();
        payment.isSynced = false;
        await _paymentsBox.put(payment.id.toString(), payment);
      }
    } catch (e) {
      throw Exception('فشل في حذف العميل: $e');
    }
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
      super.dispose();
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
    try {
      // جلب الدفعات المحذوفة من التخزين المحلي
      final deletedPayments =
          _paymentsBox.values.where((p) => p.isDeleted).toList();

      // إذا كان هناك اتصال، نحاول جلب الدفعات المحذوفة من السيرفر
      if (await ConnectivityService.isConnected()) {
        try {
          final response =
              await _supabase.from('payments').select().eq('is_deleted', true);

          final serverPayments =
              (response as List).map((data) => Payment.fromMap(data)).toList();

          // دمج القوائم وإزالة التكرار
          final allPayments = {...deletedPayments, ...serverPayments}.toList();
          return allPayments;
        } catch (e) {
          debugPrint('خطأ في جلب الدفعات المحذوفة من السيرفر: $e');
        }
      }

      return deletedPayments;
    } catch (e) {
      debugPrint('خطأ في جلب الدفعات المحذوفة: $e');
      return [];
    }
  }

  Future<void> restorePaymentFromTrash(int paymentId) async {
    try {
      // جلب الدفعة من التخزين المحلي
      final payment = _paymentsBox.get(paymentId.toString());
      if (payment == null) {
        throw Exception('الدفعة غير موجودة');
      }

      payment.isDeleted = false;
      payment.deletedAt = null;
      payment.isSynced = false;

      // تحديث في التخزين المحلي
      await _paymentsBox.put(paymentId.toString(), payment);

      // إذا كان هناك اتصال، نحاول التحديث على السيرفر
      if (await ConnectivityService.isConnected()) {
        await syncPayment(payment);
      }
    } catch (e) {
      debugPrint('خطأ في استرجاع الدفعة: $e');
      rethrow;
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
    if (customer.color == null || customer.color.isEmpty) {
      // إنشاء لون عشوائي إذا لم يكن هناك لون
      final random = Random();
      final colors = [
        '#FF5733',
        '#33FF57',
        '#3357FF',
        '#FF33F5',
        '#33FFF5',
        '#F5FF33',
        '#FF3333',
        '#33FF33'
      ];
      customer.color = colors[random.nextInt(colors.length)];

      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

        await _supabase
            .from('customers')
            .update({'color': customer.color})
            .eq('id', customer.id.toString())
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('خطأ في تحديث لون العميل: $e');
      }
    }
  }

  Future<void> _handleSessionRefreshError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (email == null || password == null) {
        throw Exception('بيانات الاعتماد غير متوفرة');
      }

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('تم إعادة تسجيل الدخول بنجاح');
    } catch (e) {
      debugPrint('فشل في إعادة تسجيل الدخول: $e');
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

  // دالة للتحقق من تشابه النصوص
  double _calculateSimilarity(String str1, String str2) {
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    // تنظيف وتوحيد النصوص
    str1 = str1.trim().toLowerCase();
    str2 = str2.trim().toLowerCase();

    // حساب مسافة ليفنشتاين
    int maxLength = str1.length > str2.length ? str1.length : str2.length;
    int distance = _levenshteinDistance(str1, str2);

    // حساب نسبة التشابه
    return 1 - (distance / maxLength);
  }

  // خوارزمية ليفنشتاين لحساب التشابه بين النصوص
  int _levenshteinDistance(String str1, String str2) {
    var distances = List.generate(
      str1.length + 1,
      (i) => List.generate(str2.length + 1, (j) => j == 0 ? i : 0),
    );

    for (var j = 0; j <= str2.length; j++) {
      distances[0][j] = j;
    }

    for (var i = 1; i <= str1.length; i++) {
      for (var j = 1; j <= str2.length; j++) {
        if (str1[i - 1] == str2[j - 1]) {
          distances[i][j] = distances[i - 1][j - 1];
        } else {
          distances[i][j] = [
            distances[i - 1][j] + 1,
            distances[i][j - 1] + 1,
            distances[i - 1][j - 1] + 1,
          ].reduce((curr, next) => curr < next ? curr : next);
        }
      }
    }

    return distances[str1.length][str2.length];
  }

  // دالة للتحقق من تكرار العميل
  Future<Map<String, dynamic>> _checkDuplicateCustomer(
      Customer newCustomer) async {
    try {
      final existingCustomers = await getAllLocalCustomers();
      double maxSimilarity = 0.0;
      Customer? duplicateCustomer;
      String? duplicateReason;

      for (var existing in existingCustomers) {
        // التحقق من تطابق رقم الهاتف
        if (existing.phone.trim() == newCustomer.phone.trim()) {
          return {
            'isDuplicate': true,
            'customer': existing,
            'reason': 'رقم الهاتف متطابق',
            'similarity': 1.0
          };
        }

        // حساب تشابه الاسم
        double nameSimilarity = _calculateSimilarity(
          existing.name,
          newCustomer.name,
        );

        // حساب تشابه العنوان إذا كان موجوداً
        double addressSimilarity = 0.0;
        if (existing.address != null && newCustomer.address != null) {
          addressSimilarity = _calculateSimilarity(
            existing.address!,
            newCustomer.address!,
          );
        }

        // حساب التشابه الكلي
        double totalSimilarity = nameSimilarity * 0.7 + addressSimilarity * 0.3;

        // تحديث أعلى نسبة تشابه
        if (totalSimilarity > maxSimilarity) {
          maxSimilarity = totalSimilarity;
          duplicateCustomer = existing;

          if (nameSimilarity > 0.8) {
            duplicateReason = 'الاسم متشابه جداً';
          } else if (addressSimilarity > 0.8) {
            duplicateReason = 'العنوان متشابه جداً';
          } else if (totalSimilarity > 0.7) {
            duplicateReason = 'تشابه كبير في المعلومات العامة';
          }
        }
      }

      // إذا كان هناك تشابه كبير
      if (maxSimilarity > 0.7 && duplicateCustomer != null) {
        return {
          'isDuplicate': true,
          'customer': duplicateCustomer,
          'reason': duplicateReason ?? 'تشابه في المعلومات',
          'similarity': maxSimilarity
        };
      }

      return {'isDuplicate': false};
    } catch (e) {
      debugPrint('خطأ في التحقق من تكرار العميل: $e');
      return {'isDuplicate': false};
    }
  }

  Future<Customer> addCustomer(Customer customer) async {
    try {
      _checkInitialized();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      // تعيين البيانات الأساسية للعميل
      customer.userId = userId;
      customer.createdAt = DateTime.now();
      customer.updatedAt = DateTime.now();
      customer.id = DateTime.now().millisecondsSinceEpoch;

      // حفظ العميل محلياً أولاً
      await saveLocalCustomer(customer);
      debugPrint('تم حفظ العميل محلياً: ${customer.name}');

      // محاولة المزامنة مع السيرفر إذا كان هناك اتصال
      if (await ConnectivityService.isConnected()) {
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
                'created_at': customer.createdAt.toIso8601String(),
                'updated_at': customer.updatedAt.toIso8601String(),
              })
              .select()
              .single();

          // تحديث معرف العميل من السيرفر
          final serverId = response['id'].toString();
          customer.id = int.parse(serverId);
          customer.isSynced = true;

          // تحديث التخزين المحلي بالمعرف الجديد
          await saveLocalCustomer(customer);
          debugPrint('تم مزامنة العميل مع السيرفر: ${customer.name}');
        } catch (e) {
          debugPrint('فشل في مزامنة العميل مع السيرفر: $e');
          customer.isSynced = false;
          // لا نقوم برمي الخطأ هنا لأن العميل تم حفظه محلياً بنجاح
        }
      } else {
        debugPrint('لا يوجد اتصال بالإنترنت. العميل سيتم مزامنته لاحقاً');
        customer.isSynced = false;
      }

      return customer;
    } catch (e) {
      debugPrint('خطأ في إضافة العميل: $e');
      rethrow;
    }
  }

  Future<Payment> addPayment(Payment payment) async {
    _checkInitialized();
    debugPrint('إضافة دفعة جديدة...');

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // التحقق من وجود العميل
      final customer = await getCustomerById(payment.customerId);
      if (customer == null) {
        throw Exception('العميل غير موجود');
      }

      // إضافة معرف المستخدم للدفعة
      payment.userId = userId;

      // حفظ الدفعة باستخدام savePayment
      final result = await savePayment(payment);
      
      if (result['status'] == 'synced' || result['status'] == 'local') {
        // تحديث رصيد العميل
        customer.balance = (customer.balance ?? 0) + payment.amount;
        await updateCustomer(customer);
        
        // إعادة تحميل الدفعة من قاعدة البيانات المحلية
        final savedPayment = _paymentsBox.get(result['id']);
        if (savedPayment != null) {
          debugPrint('تم إضافة الدفعة بنجاح. المعرف: ${savedPayment.id}');
          return savedPayment;
        }
      }
      
      throw Exception('فشل في حفظ الدفعة');
    } catch (e) {
      debugPrint('خطأ في إضافة الدفعة: $e');
      rethrow;
    }
  }

  Future<List<Payment>> getAllPayments() async {
    try {
      debugPrint('جلب جميع الدفعات...');
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      // جلب جميع الدفعات المحلية (المتزامنة وغير المتزامنة) التي لم يتم حذفها
      final localPayments =
          _paymentsBox.values.where((p) => !p.isDeleted).toList();
      debugPrint('عدد الدفعات المحلية: ${localPayments.length}');

      // عرض معلومات عن الدفعات المحلية
      for (var payment in localPayments) {
        debugPrint(
            'دفعة محلية - المعرف: ${payment.id}, متزامنة: ${payment.isSynced}, معرف العميل: ${payment.customerId}');
      }

      // التحقق من الاتصال بالإنترنت
      if (await ConnectivityService.isConnected()) {
        try {
          debugPrint('جلب الدفعات من السيرفر...');
          final response = await _supabase
              .from('payments')
              .select('*, customers(*)')
              .eq('user_id', userId)
              .eq('is_deleted', false)
              .order('date', ascending: false);

          final serverPayments = (response as List)
              .map((data) {
                try {
                  final payment = Payment.fromMap({
                    ...data,
                    'id': data['id'],
                    'customer_id': data['customer_id'],
                    'amount': data['amount'],
                    'date': data['date'],
                    'notes': data['notes'],
                    'reminder_date': data['reminder_date'],
                    'reminder_sent': data['reminder_sent'] ?? false,
                    'is_deleted': data['is_deleted'] ?? false,
                    'deleted_at': data['deleted_at'],
                    'created_at': data['created_at'],
                    'updated_at': data['updated_at'],
                    'user_id': data['user_id'],
                    'title': data['title'],
                  });
                  payment.isSynced = true;
                  return payment;
                } catch (e) {
                  debugPrint('خطأ في تحويل بيانات الدفعة: $e');
                  return null;
                }
              })
              .whereType<Payment>()
              .toList();

          debugPrint('عدد الدفعات من السيرفر: ${serverPayments.length}');

          // تحديث التخزين المحلي للدفعات المتزامنة فقط
          for (var serverPayment in serverPayments) {
            final localPayment = _paymentsBox.get(serverPayment.id.toString());
            if (localPayment == null || localPayment.isSynced) {
              await _paymentsBox.put(
                  serverPayment.id.toString(), serverPayment);
            }
          }

          // دمج الدفعات المحلية غير المتزامنة مع الدفعات من السيرفر
          final allPayments = <Payment>[];

          // إضافة الدفعات المحلية غير المتزامنة
          allPayments.addAll(localPayments.where((p) => !p.isSynced));

          // إضافة الدفعات من السيرفر
          allPayments.addAll(serverPayments);

          // ترتيب الدفعات حسب التاريخ
          allPayments.sort((a, b) => b.date.compareTo(a.date));

          debugPrint('إجمالي عدد الدفعات بعد الدمج: ${allPayments.length}');
          return allPayments;
        } catch (e) {
          debugPrint('خطأ في جلب الدفعات من السيرفر: $e');
          // في حالة الخطأ، نعيد الدفعات المحلية فقط
          localPayments.sort((a, b) => b.date.compareTo(a.date));
          return localPayments;
        }
      } else {
        debugPrint('لا يوجد اتصال، إرجاع الدفعات المحلية فقط');
        localPayments.sort((a, b) => b.date.compareTo(a.date));
        return localPayments;
      }
    } catch (e) {
      debugPrint('خطأ في جلب الدفعات: $e');
      return [];
    }
  }

  Future<List<Customer>> getCustomers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final response = await _supabase
          .from('customers')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      return (response as List).map((data) => Customer.fromMap(data)).toList();
    } catch (e) {
      debugPrint('خطأ في جلب العملاء: $e');
      return [];
    }
  }

  Future<Payment?> getPaymentById(int paymentId) async {
    _checkInitialized();
    try {
      final payment = _paymentsBox.get(paymentId.toString());
      return payment;
    } catch (e) {
      debugPrint('خطأ في جلب الدفعة: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> savePayment(Payment payment) async {
    try {
      // التحقق من الاتصال بالإنترنت
      if (!await ConnectivityService.isConnected()) {
        debugPrint('لا يوجد اتصال بالإنترنت. حفظ الدفعة محلياً...');
        payment.isSynced = false;
        await _paymentsBox.put(payment.id.toString(), payment);
        return {'id': payment.id.toString(), 'status': 'local'};
      }

      // إنشاء معرف مؤقت للدفعة إذا لم يكن موجوداً
      payment.id ??= DateTime.now().millisecondsSinceEpoch;

      // تجهيز البيانات للحفظ في السيرفر
      final data = {
        'customer_id': payment.customerId.toString(),
        'amount': payment.amount,
        'date': payment.date.toIso8601String(),
        'notes': payment.notes,
        'reminder_date': payment.reminderDate?.toIso8601String(),
        'reminder_sent': payment.reminderSent ?? false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
        'deleted_at': null,
        'user_id': _supabase.auth.currentUser?.id,
      };

      try {
        // محاولة حفظ الدفعة على السيرفر
        final response = await _supabase
            .from('payments')
            .insert(data)
            .select()
            .single();

        // تحديث معرف الدفعة بالمعرف من السيرفر
        payment.id = int.parse(response['id'].toString());
        payment.isSynced = true;
        
        // تحديث الدفعة في التخزين المحلي مع المعرف الجديد
        await _paymentsBox.put(payment.id.toString(), payment);
        
        debugPrint('تم حفظ الدفعة على السيرفر والتخزين المحلي بنجاح');
        return {'id': payment.id.toString(), 'status': 'synced'};
      } catch (e) {
        debugPrint('خطأ في حفظ الدفعة على السيرفر: $e');
        // في حالة فشل الحفظ على السيرفر، نحفظ محلياً
        payment.isSynced = false;
        await _paymentsBox.put(payment.id.toString(), payment);
        return {'id': payment.id.toString(), 'status': 'local_only'};
      }
    } catch (e) {
      debugPrint('خطأ في حفظ الدفعة: $e');
      throw Exception('فشل في حفظ الدفعة: $e');
    }
  }

  Future<Customer?> getCustomer(int customerId) async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .eq('id', customerId)
          .single();

      if (response != null) {
        return Customer.fromMap(response);
      }
      return null;
    } catch (e) {
      print('خطأ في جلب العميل: $e');
      return null;
    }
  }

  Future<void> syncPayment(Payment payment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      // التحقق من وجود العميل في قاعدة البيانات
      final customerResponse = await _supabase
          .from('customers')
          .select('id')
          .eq('id', payment.customerId.toString())
          .maybeSingle();

      if (customerResponse == null) {
        debugPrint(
            'تخطي مزامنة الدفعة: العميل غير موجود في قاعدة البيانات (${payment.customerId})');
        return;
      }

      final paymentData = {
        'customer_id': payment.customerId.toString(),
        'amount': payment.amount,
        'date': payment.date.toIso8601String(),
        'notes': payment.notes,
        'reminder_date': payment.reminderDate?.toIso8601String(),
        'reminder_sent': payment.reminderSent,
        'is_deleted': payment.isDeleted,
        'deleted_at': payment.deletedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'user_id': userId,
        'title': payment.title,
      };

      // التحقق مما إذا كانت الدفعة موجودة في السيرفر
      final existingPayment = await _supabase
          .from('payments')
          .select()
          .eq('id', payment.id.toString())
          .maybeSingle();

      if (existingPayment == null) {
        // إذا لم تكن موجودة، نقوم بإنشائها
        final response = await _supabase
            .from('payments')
            .insert(paymentData)
            .select()
            .single();

        // تحديث معرف الدفعة بالمعرف من السيرفر
        payment.id = response['id'];
        payment.isSynced = true;

        // تحديث التخزين المحلي
        await _paymentsBox.put(payment.id.toString(), payment);
        debugPrint('تم إنشاء الدفعة في السيرفر: ${payment.id}');
      } else {
        // إذا كانت موجودة، نقوم بتحديثها
        await _supabase
            .from('payments')
            .update(paymentData)
            .eq('id', payment.id.toString());

        // تحديث حالة المزامنة محلياً
        payment.isSynced = true;
        await _paymentsBox.put(payment.id.toString(), payment);
        debugPrint('تم تحديث الدفعة في السيرفر: ${payment.id}');
      }
    } catch (e) {
      debugPrint('خطأ في مزامنة الدفعة: $e');
      rethrow;
    }
  }

  Future<void> syncCustomer(Customer customer) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      // تحديث البيانات على السيرفر
      await _supabase
          .from('customers')
          .update({
            'name': customer.name,
            'phone': customer.phone,
            'address': customer.address,
            'balance': customer.balance,
            'is_deleted': customer.isDeleted,
            'deleted_at': customer.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', customer.id.toString())
          .eq('user_id', userId);

      // تحديث حالة المزامنة محلياً
      customer.isSynced = true;
      await _customersBox.put(customer.id.toString(), customer);

      debugPrint('تمت مزامنة العميل بنجاح');
    } catch (e) {
      debugPrint('خطأ في مزامنة العميل: $e');
      rethrow;
    }
  }

  Future<void> syncAll() async {
    try {
      debugPrint('بدء المزامنة الشاملة...');

      // التحقق من الاتصال بالإنترنت
      final hasConnection = await ConnectivityService.isConnected();
      if (!hasConnection) {
        _syncStatus = 'لا يوجد اتصال بالإنترنت، تخطي المزامنة';
        notifyListeners();
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      // إصلاح معرفات العملاء في الدفعات القديمة
      debugPrint('إصلاح معرفات العملاء في الدفعات القديمة...');
      await fixOldPayments();

      // جلب جميع العملاء من السيرفر
      debugPrint('جلب العملاء من السيرفر...');
      final serverCustomersResponse =
          await _supabase.from('customers').select().eq('user_id', userId);
      debugPrint('تم جلب ${serverCustomersResponse.length} عميل من السيرفر');

      // إنشاء خريطة للعملاء في السيرفر باستخدام رقم الهاتف كمفتاح
      final Map<String, Map<String, dynamic>> serverCustomersByPhone = {};
      for (var customer in serverCustomersResponse) {
        if (customer['phone'] != null &&
            customer['phone'].toString().isNotEmpty) {
          serverCustomersByPhone[customer['phone'].toString()] = customer;
        }
      }

      // مزامنة العملاء المحليين غير المتزامنين
      debugPrint('مزامنة العملاء المحليين غير المتزامنين...');
      final unsyncedCustomers =
          _customersBox.values.where((c) => !c.isSynced).toList();
      debugPrint('عدد العملاء غير المتزامنين: ${unsyncedCustomers.length}');

      // خريطة لتتبع معرفات العملاء القديمة والجديدة
      Map<String, String> customerIdMapping = {};

      // مزامنة العملاء
      for (var customer in unsyncedCustomers) {
        try {
          final oldId = customer.id.toString();
          final serverCustomer = serverCustomersByPhone[customer.phone];

          if (serverCustomer != null) {
            debugPrint(
                'العميل ${customer.name} موجود مسبقاً (رقم الهاتف مكرر)');
            customerIdMapping[oldId] = serverCustomer['id'].toString();

            // تحديث العميل المحلي بمعرف السيرفر
            final updatedCustomer = Customer(
              id: int.tryParse(oldId) ?? 0,
              name: customer.name,
              phone: customer.phone,
              address: customer.address,
              notes: customer.notes,
              color: '#000000',
              balance: customer.balance,
              isSynced: true,
              createdAt: customer.createdAt,
              updatedAt: DateTime.now(),
              userId: userId,
              isDeleted: customer.isDeleted,
              deletedAt: customer.deletedAt,
            );

            await _customersBox.delete(oldId);
            await _customersBox.put(
                updatedCustomer.id.toString(), updatedCustomer);

            // تحديث معرف العميل في الدفعات المرتبطة
            final relatedPayments = _paymentsBox.values
                .where((p) => p.customerId.toString() == oldId);
            for (var payment in relatedPayments) {
              debugPrint(
                  'تحديث معرف العميل في الدفعة من $oldId إلى ${updatedCustomer.id}');
              final updatedPayment = Payment(
                id: payment.id,
                customerId: updatedCustomer.id ?? 0,
                amount: payment.amount,
                date: payment.date,
                notes: payment.notes,
                reminderDate: payment.reminderDate,
                reminderSent: payment.reminderSent,
                isDeleted: payment.isDeleted,
                deletedAt: payment.deletedAt,
                isSynced: false,
                createdAt: payment.createdAt,
                updatedAt: DateTime.now(),
                title: payment.title,
                userId: userId,
              );
              await _paymentsBox.put(payment.id.toString(), updatedPayment);
            }
          } else {
            // إضافة عميل جديد للسيرفر
            final response = await _supabase
                .from('customers')
                .insert({
                  'name': customer.name,
                  'phone': customer.phone,
                  'address': customer.address,
                  'notes': customer.notes,
                  'color': '#000000',
                  'balance': customer.balance,
                  'user_id': userId,
                  'created_at': customer.createdAt?.toIso8601String() ??
                      DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                  'is_deleted': customer.isDeleted,
                  'deleted_at': customer.deletedAt?.toIso8601String(),
                })
                .select()
                .single();

            customerIdMapping[oldId] = response['id'].toString();

            // تحديث العميل المحلي بالمعرف الجديد
            final updatedCustomer = Customer(
              id: int.tryParse(response['id']) ?? 0,
              name: customer.name,
              phone: customer.phone,
              address: customer.address,
              notes: customer.notes,
              color: '#000000',
              balance: customer.balance,
              isSynced: true,
              createdAt: customer.createdAt,
              updatedAt: DateTime.now(),
              userId: userId,
              isDeleted: customer.isDeleted,
              deletedAt: customer.deletedAt,
            );

            await _customersBox.delete(oldId);
            await _customersBox.put(
                updatedCustomer.id.toString(), updatedCustomer);

            // تحديث معرف العميل في الدفعات المرتبطة
            final relatedPayments = _paymentsBox.values
                .where((p) => p.customerId.toString() == oldId);
            for (var payment in relatedPayments) {
              debugPrint(
                  'تحديث معرف العميل في الدفعة من $oldId إلى ${updatedCustomer.id}');
              final updatedPayment = Payment(
                id: payment.id,
                customerId: updatedCustomer.id ?? 0,
                amount: payment.amount,
                date: payment.date,
                notes: payment.notes,
                reminderDate: payment.reminderDate,
                reminderSent: payment.reminderSent,
                isDeleted: payment.isDeleted,
                deletedAt: payment.deletedAt,
                isSynced: false,
                createdAt: payment.createdAt,
                updatedAt: DateTime.now(),
                title: payment.title,
                userId: userId,
              );
              await _paymentsBox.put(payment.id.toString(), updatedPayment);
            }
          }
        } catch (e) {
          debugPrint('خطأ في مزامنة العميل ${customer.name}: $e');
        }
      }

      // مزامنة الدفعات غير المتزامنة
      debugPrint('مزامنة الدفعات غير المتزامنة...');
      final unsyncedPayments =
          _paymentsBox.values.where((p) => !p.isSynced).toList();
      debugPrint('عدد الدفعات غير المتزامنة: ${unsyncedPayments.length}');

      // مزامنة الدفعات
      for (var payment in unsyncedPayments) {
        try {
          // التحقق من وجود العميل في السيرفر
          final customerResponse = await _supabase
              .from('customers')
              .select('id')
              .eq('id', payment.customerId.toString())
              .maybeSingle();

          if (customerResponse == null) {
            debugPrint(
                'تخطي مزامنة الدفعة: العميل غير موجود في السيرفر (${payment.customerId})');
            continue;
          }

          final paymentData = {
            'customer_id': payment.customerId.toString(),
            'amount': payment.amount,
            'date': payment.date.toIso8601String(),
            'notes': payment.notes,
            'reminder_date': payment.reminderDate?.toIso8601String(),
            'reminder_sent': payment.reminderSent,
            'created_at': payment.createdAt?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'user_id': userId,
            'is_deleted': payment.isDeleted,
            'deleted_at': payment.deletedAt?.toIso8601String(),
            'title': payment.title,
          };

          final response = await _supabase
              .from('payments')
              .insert(paymentData)
              .select()
              .single();

          // تحديث الدفعة المحلية
          final oldId = payment.id.toString();
          final newPayment = Payment(
            id: response['id'],
            customerId: payment.customerId,
            amount: payment.amount,
            date: payment.date,
            notes: payment.notes,
            reminderDate: payment.reminderDate,
            reminderSent: payment.reminderSent,
            isDeleted: payment.isDeleted,
            deletedAt: payment.deletedAt,
            isSynced: true,
            createdAt: payment.createdAt,
            updatedAt: DateTime.now(),
            title: payment.title,
            userId: userId,
          );

          await _paymentsBox.delete(oldId);
          await _paymentsBox.put(newPayment.id.toString(), newPayment);
          debugPrint('تمت مزامنة الدفعة بنجاح');
        } catch (e) {
          debugPrint('خطأ في مزامنة الدفعة: $e');
        }
      }

      debugPrint('تمت المزامنة الشاملة بنجاح');
      _syncStatus = 'اكتملت المزامنة';
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _syncStatus = 'حدث خطأ في المزامنة';
      _isSyncing = false;
      notifyListeners();
      debugPrint('خطأ في مزامنة البيانات: $e');
      rethrow;
    }
  }

  Future<List<Customer>> getDeletedCustomers() async {
    try {
      // جلب العملاء المحذوفين من التخزين المحلي
      final deletedCustomers =
          _customersBox.values.where((c) => c.isDeleted).toList();

      // إذا كان هناك اتصال، نحاول جلب العملاء المحذوفين من السيرفر
      if (await ConnectivityService.isConnected()) {
        try {
          final userId = _supabase.auth.currentUser?.id;
          if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

          final response = await _supabase
              .from('customers')
              .select()
              .eq('is_deleted', true)
              .eq('user_id', userId);

          final serverCustomers =
              (response as List).map((data) => Customer.fromMap(data)).toList();

          // دمج القوائم وإزالة التكرار
          final allCustomers =
              {...deletedCustomers, ...serverCustomers}.toList();
          return allCustomers;
        } catch (e) {
          debugPrint('خطأ في جلب العملاء المحذوفين من السيرفر: $e');
        }
      }

      return deletedCustomers;
    } catch (e) {
      debugPrint('خطأ في جلب العملاء المحذوفين: $e');
      return [];
    }
  }

  Future<void> restoreCustomer(Customer customer) async {
    try {
      customer.isDeleted = false;
      customer.deletedAt = null;
      customer.isSynced = false;

      // تحديث في التخزين المحلي
      await _customersBox.put(customer.id.toString(), customer);

      // إذا كان هناك اتصال، نحاول التحديث على السيرفر
      if (await ConnectivityService.isConnected()) {
        await syncCustomer(customer);
      }
    } catch (e) {
      debugPrint('خطأ في استرجاع العميل: $e');
      rethrow;
    }
  }

  Future<void> restoreCustomerFromTrash(Customer customer) async {
    try {
      customer.isDeleted = false;
      customer.deletedAt = null;
      customer.isSynced = false;

      // تحديث في التخزين المحلي
      await _customersBox.put(customer.id.toString(), customer);

      // إذا كان هناك اتصال، نحاول التحديث على السيرفر
      if (await ConnectivityService.isConnected()) {
        await syncCustomer(customer);
      }
    } catch (e) {
      debugPrint('خطأ في استرجاع العميل: $e');
      rethrow;
    }
  }

  Future<void> fixOldPayments() async {
    try {
      final unSyncedPayments =
          _paymentsBox.values.where((p) => !p.isSynced).toList();
      final syncedCustomers =
          _customersBox.values.where((c) => c.isSynced).toList();

      // إنشاء خريطة للعملاء المتزامنين باستخدام المعرف المحلي
      final customerMap = <String, Customer>{};
      for (var customer in syncedCustomers) {
        if (customer.localId != null) {
          customerMap[customer.localId!] = customer;
        }
      }

      for (var payment in unSyncedPayments) {
        // البحث عن العميل المتزامن المطابق
        final matchingCustomer = customerMap.values.firstWhere(
          (c) => c.id == payment.customerId,
          orElse: () => syncedCustomers.firstWhere(
            (c) => c.id == payment.customerId,
            orElse: () => Customer(
              name: 'Unknown',
              phone: 'Unknown',
              id: 0,
              color: '#000000',
            ),
          ),
        );

        if (matchingCustomer.id != null && matchingCustomer.id != 0) {
          final updatedPayment = payment.copyWith(
            customerId: matchingCustomer.id!,
            isSynced: false,
          );
          await _paymentsBox.put(payment.key, updatedPayment);
          print(
              'تم تحديث الدفعة ${payment.id} للعميل ${matchingCustomer.name}');
        } else {
          print('لم يتم العثور على عميل متزامن للدفعة ${payment.id}');
        }
      }
    } catch (e) {
      print('خطأ في إصلاح الدفعات القديمة: $e');
      rethrow;
    }
  }

  Future<void> syncCustomers() async {
    try {
      final localCustomers =
          _customersBox.values.where((c) => !c.isSynced).toList();

      for (var customer in localCustomers) {
        if (customer.localId == null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final phoneHash = customer.phone.hashCode;
          final localId = timestamp.toString() + '_' + phoneHash.toString();
          customer.localId = localId;
          await customer.save();
        }

        final response = await _supabase
            .from('customers')
            .upsert(customer.toJson(), onConflict: 'local_id');

        final responseData = response.data;
        if (response.error == null &&
            responseData != null &&
            responseData is List &&
            responseData.length > 0) {
          final serverCustomer = responseData[0];
          final serverId = serverCustomer['id'];
          if (serverId != null) {
            final customerIdInt =
                serverId is int ? serverId : int.tryParse(serverId.toString());
            if (customerIdInt != null) {
              customer.id = customerIdInt;
              customer.isSynced = true;
              await customer.save();

              final relatedPayments = _paymentsBox.values
                  .where((p) => p.customerId == customer.id)
                  .toList();

              for (var payment in relatedPayments) {
                final newPayment = payment.copyWith(
                  customerId: customerIdInt,
                  isSynced: false,
                );
                await _paymentsBox.put(payment.key, newPayment);
              }
            }
          }
        } else {
          print('خطأ في مزامنة العميل: ${response.error?.message}');
        }
      }
    } catch (e) {
      print('خطأ في مزامنة العملاء: $e');
      rethrow;
    }
  }
}
