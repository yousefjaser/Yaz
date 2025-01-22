import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/auth_provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/widgets/bottom_nav.dart';
import 'package:yaz/widgets/customer_list_widget.dart';
import 'package:yaz/widgets/drawer_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+966'; // السعودية كاختيار افتراضي
  bool _isLoading = false;

  // قائمة أكواد الدول
  final List<Map<String, String>> _countryCodes = [
    {'code': '+970', 'name': 'فلسطين 🇵🇸'},
    {'code': '+972', 'name': 'إسرائيل 🇮🇱'},
    {'code': '+966', 'name': 'السعودية 🇸🇦'},
    {'code': '+971', 'name': 'الإمارات 🇦🇪'},
    {'code': '+974', 'name': 'قطر 🇶🇦'},
    {'code': '+973', 'name': 'البحرين 🇧🇭'},
    {'code': '+965', 'name': 'الكويت 🇰🇼'},
    {'code': '+968', 'name': 'عمان 🇴🇲'},
    {'code': '+962', 'name': 'الأردن 🇯🇴'},
    {'code': '+961', 'name': 'لبنان 🇱🇧'},
    {'code': '+963', 'name': 'سوريا 🇸🇾'},
    {'code': '+964', 'name': 'العراق 🇮🇶'},
    {'code': '+967', 'name': 'اليمن 🇾🇪'},
    {'code': '+20', 'name': 'مصر 🇪🇬'},
    {'code': '+249', 'name': 'السودان 🇸🇩'},
    {'code': '+218', 'name': 'ليبيا 🇱🇾'},
    {'code': '+216', 'name': 'تونس 🇹🇳'},
    {'code': '+213', 'name': 'الجزائر 🇩🇿'},
    {'code': '+212', 'name': 'المغرب 🇲🇦'},
    {'code': '+222', 'name': 'موريتانيا 🇲🇷'},
    {'code': '+252', 'name': 'الصومال 🇸🇴'},
    {'code': '+253', 'name': 'جيبوتي 🇩🇯'},
    {'code': '+98', 'name': 'إيران 🇮🇷'},
    {'code': '+90', 'name': 'تركيا 🇹🇷'},
    {'code': '+92', 'name': 'باكستان 🇵🇰'},
    {'code': '+91', 'name': 'الهند 🇮🇳'},
    {'code': '+1', 'name': 'الولايات المتحدة 🇺🇸'},
    {'code': '+44', 'name': 'المملكة المتحدة 🇬🇧'},
    {'code': '+33', 'name': 'فرنسا 🇫🇷'},
    {'code': '+49', 'name': 'ألمانيا 🇩🇪'},
    {'code': '+7', 'name': 'روسيا 🇷🇺'},
    {'code': '+86', 'name': 'الصين 🇨🇳'},
    {'code': '+81', 'name': 'اليابان 🇯🇵'},
    {'code': '+82', 'name': 'كوريا الجنوبية 🇰🇷'},
    {'code': '+84', 'name': 'فيتنام 🇻🇳'},
    {'code': '+66', 'name': 'تايلاند 🇹🇭'},
    {'code': '+60', 'name': 'ماليزيا 🇲🇾'},
    {'code': '+62', 'name': 'إندونيسيا 🇮🇩'},
    {'code': '+63', 'name': 'الفلبين 🇵🇭'},
    {'code': '+65', 'name': 'سنغافورة 🇸🇬'},
    {'code': '+880', 'name': 'بنغلاديش 🇧🇩'},
    {'code': '+94', 'name': 'سريلانكا 🇱🇰'},
    {'code': '+977', 'name': 'نيبال 🇳🇵'},
    {'code': '+93', 'name': 'أفغانستان 🇦🇫'},
    {'code': '+55', 'name': 'البرازيل 🇧🇷'},
    {'code': '+54', 'name': 'الأرجنتين 🇦🇷'},
    {'code': '+52', 'name': 'المكسيك 🇲🇽'},
    {'code': '+27', 'name': 'جنوب أفريقيا 🇿🇦'},
    {'code': '+234', 'name': 'نيجيريا 🇳🇬'},
    {'code': '+254', 'name': 'كينيا 🇰🇪'},
    {'code': '+251', 'name': 'إثيوبيا 🇪🇹'}
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      try {
        final userData = await authProvider.getUserProfile();
        if (mounted && userData != null) {
          setState(() {
            _nameController.text = userData['name'] ?? '';
            
            // معالجة رقم الهاتف المخزن
            String storedPhone = userData['phone'] ?? '';
            if (storedPhone.isNotEmpty) {
              // البحث عن كود الدولة في الرقم المخزن
              String? countryCode = _countryCodes.firstWhere(
                (code) => storedPhone.startsWith(code['code']!),
                orElse: () => {'code': '+966', 'name': 'السعودية 🇸🇦'},
              )['code'];
              
              _selectedCountryCode = countryCode!;
              // إزالة كود الدولة من الرقم
              _phoneController.text = storedPhone.substring(countryCode.length);
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      // تحقق من أن الرقم يبدأ بـ 0 ويحتوي على 10 أرقام
      if (!RegExp(r'^0\d{9}$').hasMatch(value)) {
        return 'الرجاء إدخال رقم هاتف صحيح يبدأ بـ 0 ويتكون من 10 أرقام';
      }
    }
    return null;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // تجميع رقم الهاتف مع كود الدولة
      String fullPhone = '';
      if (_phoneController.text.isNotEmpty) {
        fullPhone = _selectedCountryCode + _phoneController.text;
      }

      await authProvider.updateUserProfile(
        name: _nameController.text,
        phone: fullPhone.isNotEmpty ? fullPhone : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المعلومات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : 'A',
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // حقل رقم الهاتف مع كود الدولة
              Row(
                children: [
                  // قائمة اختيار كود الدولة
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        items: _countryCodes.map((country) {
                          return DropdownMenuItem(
                            value: country['code'],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(country['name']!),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryCode = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // حقل رقم الهاتف
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: '5xxxxxxxx',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'حفظ التغييرات',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
