import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaz/config/supabase_config.dart';
import 'package:yaz/providers/auth_provider.dart';
import 'package:yaz/providers/settings_provider.dart';
import 'package:yaz/screens/auth/login_screen.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yaz/models/adapters/customer_adapter.dart';
import 'package:yaz/models/adapters/payment_adapter.dart';
import 'package:yaz/screens/profile_screen.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/services/whatsapp_service.dart';
import 'package:yaz/widgets/add_customer_sheet.dart';
import 'package:yaz/widgets/bottom_nav.dart';
import 'package:yaz/screens/home.dart';
import 'package:yaz/screens/trash_screen.dart';
import 'package:yaz/screens/analytics_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yaz/widgets/drawer_widget.dart';
import 'package:yaz/services/local_storage_service.dart';
import 'package:yaz/services/sync_service.dart';
import 'package:yaz/providers/connectivity_provider.dart';
import 'package:yaz/widgets/offline_banner.dart';

String _formatDateTime(DateTime dateTime) {
  final localDateTime = dateTime.toLocal();
  final hour = localDateTime.hour.toString().padLeft(2, '0');
  final minute = localDateTime.minute.toString().padLeft(2, '0');
  final day = localDateTime.day.toString().padLeft(2, '0');
  final month = localDateTime.month.toString().padLeft(2, '0');
  return '$day/$month/${localDateTime.year} $hour:$minute';
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('تنفيذ المهمة: $task');
      debugPrint('البيانات: $inputData');

      if (task == 'payment_reminder') {
        // فحص الاتصال بالإنترنت
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          debugPrint('لا يوجد اتصال بالإنترنت، سيتم تأجيل المهمة');
          return false;
        }

        if (inputData == null ||
            !inputData.containsKey('payment_id') ||
            !inputData.containsKey('scheduled_time')) {
          debugPrint('البيانات المطلوبة غير متوفرة');
          return false;
        }

        final paymentId = inputData['payment_id'] as int;
        final scheduledTime =
            DateTime.parse(inputData['scheduled_time']).toLocal();

        debugPrint('معالجة الدفعة رقم: $paymentId');
        debugPrint('الوقت المجدول: ${_formatDateTime(scheduledTime)}');

        debugPrint('تهيئة Supabase...');
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        debugPrint('تم تهيئة Supabase بنجاح');

        final response = await Supabase.instance.client
            .from('payments')
            .select('*, customers(*)')
            .eq('id', paymentId)
            .single();

        if (response == null) {
          debugPrint('لم يتم العثور على الدفعة');
          return true;
        }

        final payment = response;
        final customer = response['customers'];

        if (customer == null) {
          debugPrint('لم يتم العثور على العميل');
          return true;
        }

        final reminderDate = DateTime.parse(payment['reminder_date']).toLocal();
        final now = DateTime.now().toLocal();

        debugPrint('الوقت الحالي: ${_formatDateTime(now)}');
        debugPrint('موعد التذكير: ${_formatDateTime(reminderDate)}');
        debugPrint('الفرق بالدقائق: ${reminderDate.difference(now).inMinutes}');

        // تحديث: تخفيف شرط المطابقة للوقت
        final timeDifference =
            scheduledTime.difference(reminderDate).inMinutes.abs();
        if (timeDifference > 5) {
          // السماح بفارق 5 دقائق
          debugPrint(
              'موعد التذكير تم تغييره بفارق $timeDifference دقيقة، إلغاء التذكير الحالي');
          return true;
        }

        if (!payment['reminder_sent']) {
          debugPrint('إرسال تذكير للعميل: ${customer['name']}');
          debugPrint('رقم الهاتف: ${customer['phone']}');
          debugPrint('المبلغ: ${payment['amount']}');

          try {
            final whatsapp = WhatsAppService();
            final (success, error) = await whatsapp.sendPaymentReminder(
              phoneNumber: customer['phone'],
              customerName: customer['name'],
              amount: payment['amount'].abs(),
              dueDate: reminderDate,
            );

            if (success) {
              debugPrint('تم إرسال التذكير بنجاح');
              try {
                // تحديث حالة الإرسال وإضافة وقت الإرسال الفعلي
                final updateResponse = await Supabase.instance.client
                    .from('payments')
                    .update({
                      'reminder_sent': true,
                      'reminder_sent_at': DateTime.now().toIso8601String(),
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', paymentId)
                    .select()
                    .maybeSingle();

                if (updateResponse == null) {
                  debugPrint('لم يتم العثور على الدفعة للتحديث');
                  return false;
                }

                debugPrint(
                    'تم تحديث حالة الإرسال: ${updateResponse['reminder_sent']}');
                debugPrint(
                    'وقت الإرسال: ${updateResponse['reminder_sent_at']}');

                // التحقق من نجاح التحديث
                if (updateResponse['reminder_sent'] == true &&
                    updateResponse['reminder_sent_at'] != null) {
                  debugPrint('تم تحديث حالة الإرسال بنجاح');
                  return true;
                } else {
                  debugPrint('فشل في تحديث حالة الإرسال في قاعدة البيانات');
                  return false;
                }
              } catch (updateError) {
                debugPrint('خطأ في تحديث حالة الإرسال: $updateError');
                return false;
              }
            } else {
              debugPrint('فشل في إرسال التذكير');
              return false;
            }
          } catch (e) {
            debugPrint('خطأ في إرسال التذكير: $e');
            return false;
          }
        } else {
          debugPrint('تم إرسال التذكير مسبقاً');
          debugPrint('وقت الإرسال السابق: ${payment['reminder_sent_at']}');
          return true;
        }
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('خطأ في تنفيذ المهمة: $e');
      debugPrint('تفاصيل الخطأ: $stackTrace');
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // تهيئة SharedPreferences أولاً
    final prefs = await SharedPreferences.getInstance();

    // تهيئة Hive
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CustomerAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PaymentAdapter());
    }

    // تهيئة Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    // تهيئة DatabaseService
    late DatabaseService db;
    try {
      db = await DatabaseService.getInstance();
    } catch (e) {
      debugPrint('خطأ في تهيئة DatabaseService: $e');
      runApp(const ErrorApp());
      return;
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(prefs),
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => db,
            lazy: false,
          ),
          ChangeNotifierProxyProvider<AuthProvider, CustomersProvider>(
            create: (_) => CustomersProvider(db),
            update: (_, auth, customers) {
              customers?.updateAuth(auth);
              return customers ?? CustomersProvider(db);
            },
          ),
          ChangeNotifierProvider(
            create: (_) => ConnectivityProvider(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('خطأ في تهيئة التطبيق: $e');
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Cairo',
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Text('حدث خطأ في تهيئة التطبيق'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select((SettingsProvider p) => p.isDarkMode);
    return MaterialApp(
      title: 'تطبيق العملاء',
      theme: ThemeData(
        fontFamily: 'Cairo',
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Cairo',
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
      ],
      locale: const Locale('ar', ''),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      auth.loadingMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (auth.isAuthenticated) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const DrawerWidget(),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: AppBar(
                  title: Text(
                    _currentIndex == 0 ? 'العملاء' : 'الملف الشخصي',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
              ),
              const OfflineBanner(),
              Expanded(
                child: Stack(
                  children: [
                    PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      children: [
                        Consumer<CustomersProvider>(
                          builder: (context, provider, _) {
                            return CustomerListWidget(
                              customers: provider.filteredCustomers,
                            );
                          },
                        ),
                        const ProfileScreen(),
                      ],
                    ),
                    if (_currentIndex == 0)
                      Positioned(
                        left: 16,
                        bottom: 90,
                        child: FloatingActionButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => const AddCustomerSheet(),
                            );
                          },
                          child: const Icon(Icons.add),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: BottomNav(
                        currentIndex: _currentIndex,
                        onTap: (index) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
