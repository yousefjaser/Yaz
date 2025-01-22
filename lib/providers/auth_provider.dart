import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _loadingMessage = 'جاري التحميل...';
  bool _isAuthenticated = false;

  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  bool get isAuthenticated => _isAuthenticated;

  User? get currentUser => _supabase.auth.currentUser;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = _supabase.auth.currentSession;
    _isAuthenticated = session != null;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _loadingMessage = 'جاري تسجيل الدخول...';
    notifyListeners();

    try {
      debugPrint('محاولة تسجيل الدخول...');

      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // تنظيف البريد الإلكتروني
      email = email.trim().toLowerCase();

      // التحقق من صحة تنسيق البريد الإلكتروني
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('عنوان البريد الإلكتروني غير صالح');
      }

      // التحقق من طول كلمة المرور
      if (password.length < 6) {
        throw Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('فشل في تسجيل الدخول');
      }

      debugPrint('تم تسجيل الدخول بنجاح. معرف المستخدم: ${response.user!.id}');
      _isAuthenticated = true;
    } catch (e) {
      debugPrint('خطأ في تسجيل الدخول: $e');
      String errorMessage;

      if (e.toString().contains('SocketException')) {
        errorMessage = 'لا يمكن الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت';
      } else if (e.toString().contains('host lookup')) {
        errorMessage = 'مشكلة في الاتصال بالخادم، يرجى المحاولة لاحقاً';
      } else if (e.toString().contains('Invalid login credentials')) {
        errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else if (e.toString().contains('Email not confirmed')) {
        errorMessage = 'يرجى تأكيد البريد الإلكتروني أولاً';
      } else {
        errorMessage = 'حدث خطأ في تسجيل الدخول، يرجى المحاولة مرة أخرى';
      }

      _isLoading = false;
      notifyListeners();
      throw Exception(errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('بدء عملية إنشاء الحساب...');

      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // تنظيف البيانات
      email = email.trim().toLowerCase();
      name = name.trim();

      // التحقق من صحة البيانات
      if (name.isEmpty) {
        throw Exception('يرجى إدخال الاسم');
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('عنوان البريد الإلكتروني غير صالح');
      }

      if (password.length < 6) {
        throw Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      }

      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // إنشاء ملف شخصي للمستخدم الجديد
        await _supabase.from('profiles').insert({
          'id': res.user!.id,
          'name': name,
          'email': email,
        });
      }

      notifyListeners();
    } catch (e) {
      debugPrint('خطأ في إنشاء الحساب: $e');
      String errorMessage;

      if (e.toString().contains('SocketException')) {
        errorMessage = 'لا يمكن الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت';
      } else if (e.toString().contains('host lookup')) {
        errorMessage = 'مشكلة في الاتصال بالخادم، يرجى المحاولة لاحقاً';
      } else if (e.toString().contains('already registered')) {
        errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.toString().contains('weak password')) {
        errorMessage = 'كلمة المرور ضعيفة جداً';
      } else {
        errorMessage = 'حدث خطأ في إنشاء الحساب، يرجى المحاولة مرة أخرى';
      }

      _isLoading = false;
      notifyListeners();
      throw Exception(errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // تنظيف البريد الإلكتروني
      email = email.trim().toLowerCase();

      // التحقق من صحة تنسيق البريد الإلكتروني
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('عنوان البريد الإلكتروني غير صالح');
      }

      await _supabase.auth.resetPasswordForEmail(email);
      debugPrint('تم إرسال رابط إعادة تعيين كلمة المرور');
    } catch (e) {
      debugPrint('خطأ في إعادة تعيين كلمة المرور: $e');
      String errorMessage;

      if (e.toString().contains('SocketException')) {
        errorMessage = 'لا يمكن الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت';
      } else if (e.toString().contains('host lookup')) {
        errorMessage = 'مشكلة في الاتصال بالخادم، يرجى المحاولة لاحقاً';
      } else if (e.toString().contains('user not found')) {
        errorMessage = 'لم يتم العثور على حساب بهذا البريد الإلكتروني';
      } else {
        errorMessage =
            'حدث خطأ في إعادة تعيين كلمة المرور، يرجى المحاولة مرة أخرى';
      }

      _isLoading = false;
      notifyListeners();
      throw Exception(errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    _loadingMessage = 'جاري تسجيل الخروج...';
    notifyListeners();

    try {
      await _supabase.auth.signOut();
      _isAuthenticated = false;
      debugPrint('تم تسجيل الخروج بنجاح');
    } catch (e) {
      debugPrint('خطأ في تسجيل الخروج: $e');
      throw Exception('حدث خطأ في تسجيل الخروج');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({String? name, String? phone}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'لم يتم تسجيل الدخول';

      // تحديث جدول profiles
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'email': user.email,
        'phone': phone != null ? phone.substring(1) : null, // حذف الـ 0 من بداية الرقم
      });

      notifyListeners();
    } catch (e) {
      throw 'حدث خطأ في تحديث الملف الشخصي: $e';
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('name, email, phone, avatar_url')
          .eq('id', user.id)
          .single();

      return response;
    } catch (e) {
      debugPrint('خطأ في جلب معلومات المستخدم: $e');
      return null;
    }
  }
}
