import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/services/connectivity_service.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/providers/customers_provider.dart';

class PaymentsProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  final CustomersProvider _customersProvider;
  List<Payment> _payments = [];
  List<Payment> _pendingPayments = [];
  bool _isLoading = false;

  PaymentsProvider(this._databaseService, this._customersProvider) {
    _initializeData();
  }

  List<Payment> get payments => _payments;
  bool get hasPendingPayments => _pendingPayments.isNotEmpty;
  int get pendingPaymentsCount => _pendingPayments.length;
  bool get isLoading => _isLoading;

  Future<void> _initializeData() async {
    await loadPayments();
  }

  Future<void> loadPayments() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      // فتح صندوق الدفعات المحلي
      final box = await Hive.openBox<Payment>('payments');

      // تحميل الدفعات المحلية أولاً
      final localPayments = box.values.toList();
      debugPrint('تم تحميل ${localPayments.length} دفعة من التخزين المحلي');

      // التحقق من الاتصال بالإنترنت
      if (await ConnectivityService.isConnected()) {
        try {
          // محاولة تحميل الدفعات من السيرفر
          final serverPayments = await _databaseService.getAllPayments();

          // مسح البيانات المحلية القديمة
          await box.clear();

          // حفظ الدفعات الجديدة محلياً
          for (var payment in serverPayments) {
            await box.put(payment.id.toString(), payment);
          }

          _payments = serverPayments;
          debugPrint('تم تحميل ${_payments.length} دفعة من السيرفر');
        } catch (e) {
          debugPrint('خطأ في تحميل الدفعات من السيرفر: $e');
          // في حالة الخطأ، نستخدم الدفعات المحلية
          _payments = localPayments;
        }
      } else {
        debugPrint('لا يوجد اتصال بالإنترنت، استخدام الدفعات المحلية');
        _payments = localPayments;
      }

      // تحديث قائمة الدفعات المعلقة
      _pendingPayments = _payments.where((p) => !p.isSynced).toList();
    } catch (e) {
      debugPrint('خطأ في تحميل الدفعات: $e');
      _payments = [];
      _pendingPayments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPayment(Payment payment) async {
    try {
      // حفظ الدفعة محلياً أولاً
      final box = await Hive.openBox<Payment>('payments');
      final id = DateTime.now().millisecondsSinceEpoch;
      payment.id = id;
      payment.isSynced = false;

      // الحصول على العميل من التخزين المحلي
      final customersBox = await Hive.openBox<Customer>('customers');
      final customer = customersBox.get(payment.customerId.toString());

      if (customer != null) {
        // تحديث رصيد العميل محلياً
        customer.balance += payment.amount;
        await customersBox.put(customer.id.toString(), customer);

        // حفظ الدفعة محلياً
        await box.put(id.toString(), payment);
        _payments.add(payment);

        // إضافة الدفعة لقائمة الانتظار إذا كان العميل غير متزامن أو لا يوجد اتصال
        if (!customer.isSynced || !(await ConnectivityService.isConnected())) {
          _pendingPayments.add(payment);
          debugPrint('تم إضافة الدفعة لقائمة الانتظار');
        } else {
          // محاولة حفظ الدفعة على السيرفر إذا كان العميل متزامن ويوجد اتصال
          try {
            final Map<String, dynamic> response =
                await _databaseService.savePayment(payment);
            payment.id = response['id'];
            payment.isSynced = true;
            await box.put(payment.id.toString(), payment);
          } catch (e) {
            debugPrint('خطأ في حفظ الدفعة على السيرفر: $e');
            _pendingPayments.add(payment);
          }
        }

        notifyListeners();
      } else {
        throw Exception('لم يتم العثور على العميل في التخزين المحلي');
      }
    } catch (e) {
      debugPrint('خطأ في إضافة الدفعة: $e');
      rethrow;
    }
  }

  Future<void> syncPendingPayments() async {
    if (_pendingPayments.isEmpty) return;

    final box = await Hive.openBox<Payment>('payments');

    for (var payment in List.from(_pendingPayments)) {
      try {
        if (await ConnectivityService.isConnected()) {
          // التحقق من حالة مزامنة العميل أولاً
          final customer =
              await _customersProvider.getCustomer(payment.customerId);
          if (customer == null) {
            debugPrint('لم يتم العثور على العميل للدفعة المعلقة');
            continue;
          }

          // إذا كان العميل غير متزامن، نتخطى مزامنة الدفعة حتى تتم مزامنة العميل
          if (!customer.isSynced) {
            debugPrint('العميل غير متزامن، تأجيل مزامنة الدفعة');
            continue;
          }

          final Map<String, dynamic> response =
              await _databaseService.savePayment(payment);
          payment.id = response['id'];
          payment.isSynced = true;
          await box.put(payment.id.toString(), payment);
          _pendingPayments.remove(payment);
          debugPrint('تمت مزامنة الدفعة بنجاح');
        }
      } catch (e) {
        debugPrint('خطأ في مزامنة الدفعة: $e');
      }
    }
    notifyListeners();
  }
}
