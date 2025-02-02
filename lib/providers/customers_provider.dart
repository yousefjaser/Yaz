import 'package:flutter/foundation.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/providers/auth_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yaz/models/payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:yaz/services/connectivity_service.dart';

class CustomersProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  bool _isLoading = false;
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<Customer> _deletedCustomers = [];
  List<Payment> _deletedPayments = [];
  String _searchQuery = '';
  bool _isInitialized = false;

  // Getters
  bool get isLoading => _isLoading;
  List<Customer> get customers => _customers;
  List<Customer> get filteredCustomers => _filteredCustomers;
  List<Customer> get deletedCustomers => _deletedCustomers;
  List<Payment> get deletedPayments => _deletedPayments;
  bool get isInitialized => _isInitialized;

  // قائمة العملاء التي تنتظر المزامنة
  final List<Customer> _syncQueue = [];

  CustomersProvider(this._databaseService) {
    debugPrint('تم إنشاء CustomersProvider');
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && !session.isExpired) {
        debugPrint('جلسة صالحة، جاري تحميل البيانات...');
        await loadCustomers();
      } else {
        debugPrint('لا توجد جلسة صالحة');
        _customers = [];
        _filteredCustomers = [];
      }
    } catch (e) {
      debugPrint('خطأ في تحميل البيانات الأولية: $e');
      _customers = [];
      _filteredCustomers = [];
    }
  }

  void updateAuth(AuthProvider authProvider) async {
    if (!authProvider.isAuthenticated) {
      // حذف جميع البيانات المحلية عند تسجيل الخروج
      final box = await Hive.openBox<Customer>('customers');
      await box.clear();
      
      _customers = [];
      _filteredCustomers = [];
      _deletedCustomers = [];
      _deletedPayments = [];
      _isInitialized = false;
      notifyListeners();
      return;
    }

    try {
      debugPrint('بدء تحميل البيانات بعد المصادقة...');
      _isLoading = true;
      notifyListeners();

      await loadCustomers();
      _isInitialized = true;
      debugPrint('تم تهيئة البيانات بنجاح');
    } catch (e) {
      debugPrint('خطأ في تحميل العملاء بعد المصادقة: $e');
      _isInitialized = false;
      _customers = [];
      _filteredCustomers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCustomers() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('بدء تحميل العملاء...');

      // فحص الاتصال بالإنترنت
      final isOnline = await isConnected();
      debugPrint('حالة الاتصال بالإنترنت: ${isOnline ? 'متصل' : 'غير متصل'}');

      // التأكد من وجود جلسة صالحة
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.isExpired) {
        debugPrint('لا توجد جلسة صالحة، تخطي تحميل البيانات');
        _customers = [];
        _filteredCustomers = [];
        return;
      }

      // تحميل البيانات من السيرفر إذا كان هناك اتصال
      if (isOnline) {
        try {
          debugPrint('جلب البيانات من السيرفر...');
          final serverCustomers = await _databaseService.getAllCustomers();
          _customers = serverCustomers;
          debugPrint('تم تحميل ${_customers.length} عميل من السيرفر');
        } catch (e) {
          debugPrint('خطأ في تحميل البيانات من السيرفر: $e');
          // في حالة الفشل، نحاول تحميل البيانات المحلية
          _customers = await _databaseService.getAllLocalCustomers();
          debugPrint('تم تحميل ${_customers.length} عميل من التخزين المحلي');
        }
      } else {
        // تحميل البيانات المحلية في حالة عدم وجود اتصال
        _customers = await _databaseService.getAllLocalCustomers();
        debugPrint('تم تحميل ${_customers.length} عميل من التخزين المحلي');
      }

      _applyFilters();
    } catch (e) {
      debugPrint('خطأ في تحميل العملاء: $e');
      _customers = [];
      _filteredCustomers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isConnected() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      final box = await Hive.openBox<Customer>('customers');

      // التأكد من وجود جلسة صالحة
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.isExpired) {
        throw Exception('لا توجد جلسة صالحة');
      }

      // إضافة العميل عبر DatabaseService
      final addedCustomer = await _databaseService.addCustomer(customer);
      
      // تحديث القوائم المحلية
      _customers.add(addedCustomer);
      _applyFilters();
      notifyListeners();
      
    } catch (e) {
      debugPrint('خطأ في إضافة العميل: $e');
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      final box = await Hive.openBox<Customer>('customers');
      
      // إنشاء نسخة جديدة من العميل
      final updatedCustomer = Customer(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        address: customer.address,
        notes: customer.notes,
        color: customer.color,
        balance: customer.balance,
        createdAt: customer.createdAt,
        updatedAt: DateTime.now(),
        userId: customer.userId,
        isDeleted: customer.isDeleted,
        deletedAt: customer.deletedAt,
        localId: customer.localId,
        isSynced: customer.isSynced,
      );

      // محاولة المزامنة مع السيرفر إذا كان هناك اتصال
      if (await ConnectivityService.isConnected()) {
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final data = {
              'name': updatedCustomer.name,
              'phone': updatedCustomer.phone,
              'address': updatedCustomer.address,
              'notes': updatedCustomer.notes,
              'color': updatedCustomer.color,
              'balance': updatedCustomer.balance,
              'user_id': userId,
              'created_at': updatedCustomer.createdAt.toIso8601String(),
              'updated_at': updatedCustomer.updatedAt.toIso8601String(),
              'is_deleted': updatedCustomer.isDeleted,
              'deleted_at': updatedCustomer.deletedAt?.toIso8601String(),
              'local_id': updatedCustomer.localId?.toString(),
            };

            if (updatedCustomer.isSynced) {
              // إذا كان العميل متزامناً، نقوم بالتحديث
              await Supabase.instance.client
                  .from('customers')
                  .update(data)
                  .eq('id', updatedCustomer.id.toString());
            } else {
              // إذا لم يكن متزامناً، نقوم بالإضافة
              final response = await Supabase.instance.client
                  .from('customers')
                  .insert(data)
                  .select()
                  .single();
              
              // تحديث المعرف من السيرفر
              final serverId = response['id'];
              if (serverId != null) {
                // حذف العميل القديم
                await box.delete(updatedCustomer.id.toString());
                
                // تحديث المعرف وحفظ العميل الجديد
                updatedCustomer.id = int.parse(serverId.toString());
                updatedCustomer.isSynced = true;
              }
            }
          }
        } catch (e) {
          updatedCustomer.isSynced = false;
          debugPrint('فشل في تحديث العميل في السيرفر: $e');
        }
      } else {
        updatedCustomer.isSynced = false;
      }

      // تحديث محلياً
      await box.put(updatedCustomer.id.toString(), updatedCustomer);
      
      // تحديث القائمة المحلية
      final index = _customers.indexWhere((c) => c.id == updatedCustomer.id);
      if (index != -1) {
        _customers[index] = updatedCustomer;
        _applyFilters();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('خطأ في تحديث العميل: $e');
      rethrow;
    }
  }

  // مزامنة العملاء غير المتزامنين
  Future<void> syncCustomers() async {
    try {
      final box = await Hive.openBox<Customer>('customers');
      final unsyncedCustomers = box.values.where((c) => !c.isSynced).toList();
      
      for (var customer in unsyncedCustomers) {
        try {
          await updateCustomer(customer);
        } catch (e) {
          debugPrint('خطأ في مزامنة العميل ${customer.name}: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('خطأ في مزامنة العملاء: $e');
    }
  }

  void searchCustomers(String query) {
    _searchQuery = query;
    _updateFilteredCustomers();
    notifyListeners();
  }

  void _updateFilteredCustomers() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = List.from(_customers);
      notifyListeners();
      return;
    }

    final searchLower = _searchQuery.toLowerCase();
    _filteredCustomers = _customers.where((customer) {
      return customer.name.toLowerCase().contains(searchLower) ||
          customer.phone.contains(searchLower);
    }).toList();

    notifyListeners();
  }

  Future<void> deleteCustomer(Customer customer) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (customer.id != null) {
        await _databaseService.deleteCustomer(customer.id!);
        _customers.removeWhere((c) => c.id == customer.id);
        _updateFilteredCustomers();
      }
    } catch (e) {
      debugPrint('خطأ في حذف العميل: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Payment?> getLastPayment(Customer customer) async {
    if (customer.id == null) return null;
    final payments = await _databaseService.getCustomerPayments(customer.id!);
    if (payments.isEmpty) return null;
    return payments.last;
  }

  void hideCustomer(Customer customer) {
    _customers.remove(customer);
    _deletedCustomers.add(customer);
    notifyListeners();
  }

  void restoreCustomer(Customer customer, [int? index]) {
    _deletedCustomers.remove(customer);
    if (index != null) {
      _customers.insert(index, customer);
    } else {
      _customers.add(customer);
    }
    notifyListeners();
  }

  void hidePayment(Payment payment) {
    _deletedPayments.add(payment);
    notifyListeners();
  }

  Future<void> loadDeletedPayments() async {
    try {
      _deletedPayments = await _databaseService.getDeletedPayments();
      notifyListeners();
    } catch (e) {
      debugPrint('خطأ في تحميل الدفعات المحذوفة: $e');
    }
  }

  Future<void> restorePayment(Payment payment) async {
    try {
      await _databaseService.restorePaymentFromTrash(payment.id!);
      _deletedPayments.removeWhere((p) => p.id == payment.id);
      notifyListeners();
    } catch (e) {
      debugPrint('خطأ في استعادة الدفعة: $e');
    }
  }

  Future<void> permanentlyDeletePayments(List<int> paymentIds) async {
    try {
      await _databaseService.permanentlyDeletePayments(paymentIds);
      _deletedPayments.removeWhere((p) => paymentIds.contains(p.id));
      notifyListeners();
    } catch (e) {
      throw Exception('خطأ في الحذف النهائي للدفعات: $e');
    }
  }

  Future<void> permanentlyDeleteCustomers(List<int> customerIds) async {
    try {
      await _databaseService.permanentlyDeleteCustomers(customerIds);
      _deletedCustomers.removeWhere((c) => customerIds.contains(c.id));
      notifyListeners();
    } catch (e) {
      throw Exception('خطأ في الحذف النهائي للعملاء: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _updateFilteredCustomers();
    notifyListeners();
  }

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = List.from(_customers);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.contains(query);
      }).toList();
    }
    notifyListeners();
  }

  void removeCustomer(Customer customer) {
    _customers.remove(customer);
    notifyListeners();
  }

  // التحقق من وجود عملاء في انتظار المزامنة
  bool get hasPendingSync => _customers.any((customer) => !customer.isSynced);

  // الحصول على عدد العملاء في انتظار المزامنة
  int get pendingSyncCount =>
      _customers.where((customer) => !customer.isSynced).length;

  // الحصول على قائمة العملاء في انتظار المزامنة
  List<Customer> get pendingSyncCustomers =>
      _customers.where((customer) => !customer.isSynced).toList();

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .order('name');

      return (response as List).map((data) => Customer.fromMap(data)).toList();
    } catch (e) {
      debugPrint('خطأ في جلب العملاء: $e');
      return [];
    }
  }

  // إضافة دالة للحصول على عميل محدد
  Future<Customer?> getCustomer(int customerId) async {
    try {
      final box = await Hive.openBox<Customer>('customers');
      return box.get(customerId.toString());
    } catch (e) {
      debugPrint('خطأ في جلب العميل: $e');
      return null;
    }
  }
}
