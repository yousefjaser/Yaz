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

class SyncService {
  final SupabaseClient _supabase;
  final DatabaseService _databaseService;
  final Box<Customer> _customersLocal;
  final Box<Payment> _paymentsLocal;
  bool _isInitialized = false;

  SyncService(
    this._supabase,
    this._databaseService,
    this._customersLocal,
    this._paymentsLocal,
  );

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      debugPrint('تهيئة خدمة المزامنة...');
      await _ensureBoxesOpen();
      _isInitialized = true;
      debugPrint('تم تهيئة خدمة المزامنة بنجاح');
    } catch (e) {
      debugPrint('خطأ في تهيئة خدمة المزامنة: $e');
      _isInitialized = false;
      rethrow;
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

      // مسح البيانات القديمة
      await _customersLocal.clear();
      await _paymentsLocal.clear();

      // حفظ العملاء والدفعات
      for (var customer in customers) {
        try {
          await _customersLocal.put(customer.id.toString(), customer);

          for (var payment in customer.payments) {
            try {
              await _paymentsLocal.put(payment.id.toString(), payment);
            } catch (e) {
              debugPrint('خطأ في حفظ الدفعة ${payment.id}: $e');
            }
          }
        } catch (e) {
          debugPrint('خطأ في حفظ العميل ${customer.id}: $e');
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
