import 'package:flutter/foundation.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/providers/auth_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yaz/models/payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';

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

  CustomersProvider(this._databaseService) {
    debugPrint('تم إنشاء CustomersProvider');
    _initializeData();
  }

  Future<void> _initializeData() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        await loadCustomers();
      } catch (e) {
        debugPrint('خطأ في تحميل البيانات الأولية: $e');
      }
    }
  }

  void updateAuth(AuthProvider authProvider) async {
    if (!authProvider.isAuthenticated) {
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
      final connectivityResult = await Connectivity().checkConnectivity();
      debugPrint(
          'حالة الاتصال بالإنترنت: ${connectivityResult == ConnectivityResult.none ? 'غير متصل' : 'متصل'}');

      // محاولة تحميل البيانات المحلية أولاً
      try {
        debugPrint('محاولة تحميل البيانات المحلية...');
        _customers = await _databaseService.getAllLocalCustomers();
        if (_customers.isNotEmpty) {
          debugPrint('تم تحميل ${_customers.length} عميل من التخزين المحلي');
          _applyFilters();
        }
      } catch (localError) {
        debugPrint('خطأ في تحميل البيانات المحلية: $localError');
      }

      // إذا لم يكن هناك اتصال بالإنترنت، نكتفي بالبيانات المحلية
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('لا يوجد اتصال بالإنترنت، الاكتفاء بالبيانات المحلية');
        return;
      }

      // التحقق من حالة المصادقة
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.isExpired) {
        debugPrint('الجلسة منتهية، محاولة تجديد الجلسة...');
        try {
          final response = await Supabase.instance.client.auth.refreshSession();
          if (response.session == null) {
            throw Exception('فشل في تجديد الجلسة');
          }
          debugPrint('تم تجديد الجلسة بنجاح');
        } catch (e) {
          debugPrint('خطأ في تجديد الجلسة: $e');
          if (_customers.isEmpty) {
            throw Exception('لا يمكن تحميل البيانات: فشل في تجديد الجلسة');
          }
          return;
        }
      }

      debugPrint('جاري تحميل العملاء من السيرفر...');

      // محاولة تحميل البيانات مع إعادة المحاولة في حالة الفشل
      for (int i = 0; i < 3; i++) {
        try {
          final serverCustomers = await _databaseService.getAllCustomers();
          if (serverCustomers.isNotEmpty) {
            _customers = serverCustomers;
            debugPrint('تم تحميل ${_customers.length} عميل من السيرفر');
            _applyFilters();
            return;
          }
        } catch (e) {
          debugPrint('محاولة ${i + 1} فشلت: $e');
          if (i < 2) {
            debugPrint('انتظار قبل إعادة المحاولة...');
            await Future.delayed(Duration(seconds: 2));
            try {
              await Supabase.instance.client.auth.refreshSession();
              debugPrint('تم تجديد الجلسة قبل المحاولة التالية');
            } catch (refreshError) {
              debugPrint('فشل في تجديد الجلسة: $refreshError');
            }
          }
        }
      }

      if (_customers.isEmpty) {
        throw Exception('فشل في تحميل البيانات من السيرفر والتخزين المحلي');
      }
    } catch (e) {
      debugPrint('خطأ في تحميل العملاء: $e');
      rethrow;
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
      // إضافة العميل إلى قاعدة البيانات
      await _databaseService.addCustomer(customer);

      // تحديث القائمة المحلية مباشرة
      _customers.add(customer);
      _applyFilters(); // تحديث القائمة المفلترة
      notifyListeners();

      // إعادة تحميل العملاء لضمان التزامن
      await loadCustomers();
    } catch (e) {
      debugPrint('خطأ في إضافة العميل: $e');
      // حتى في حالة الخطأ، إذا تم الحفظ محلياً نقوم بإضافته للقائمة
      if (!_customers.contains(customer)) {
        _customers.add(customer);
        _applyFilters();
        notifyListeners();
      }
      if (!e.toString().contains('تم حفظ العميل محلياً')) {
        rethrow;
      }
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
      try {
        await _databaseService.updateCustomer(customer);
      } catch (e) {
        debugPrint('خطأ في تحديث العميل: $e');
      }
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
}
