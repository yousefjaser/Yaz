import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/auth_provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/widgets/bottom_nav.dart';
import 'package:yaz/widgets/customer_list_widget.dart';
import 'package:yaz/widgets/drawer_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCountryCode = '+970';
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  late TabController _tabController;
  String _selectedLanguage = 'العربية';
  String _selectedThemeMode = 'تلقائي';

  // إحصائيات المستخدم
  final Map<String, dynamic> _userStats = {
    'totalCustomers': 0,
    'totalPayments': 0,
    'totalDebts': 0.0,
    'totalCredits': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedCountryCode = '+970';
    _loadUserData();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final customersProvider =
          Provider.of<CustomersProvider>(context, listen: false);
      final customers = await customersProvider.getCustomers();

      double totalDebts = 0;
      double totalCredits = 0;
      int totalPayments = 0;

      for (var customer in customers) {
        if (customer.balance < 0) {
          totalDebts += customer.balance.abs();
        } else {
          totalCredits += customer.balance;
        }
        // يمكن إضافة المزيد من الإحصائيات هنا
      }

      if (mounted) {
        setState(() {
          _userStats['totalCustomers'] = customers.length;
          _userStats['totalDebts'] = totalDebts;
          _userStats['totalCredits'] = totalCredits;
          _userStats['totalPayments'] = totalPayments;
        });
      }
    } catch (e) {
      debugPrint('خطأ في تحميل الإحصائيات: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
              ),
            ),
            SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 20),
                            _buildStatsCards(),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'الملف الشخصي'),
                            Tab(text: 'الإعدادات'),
                            Tab(text: 'الأمان'),
                          ],
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                        ),
                      ),
                      pinned: true,
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _buildSettingsTab(),
                    _buildSecurityTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text[0].toUpperCase()
                    : 'A',
                style: TextStyle(
                  fontSize: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text
                    : 'المستخدم',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _emailController.text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Container(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            'العملاء',
            _userStats['totalCustomers']?.toString() ?? '0',
            Icons.people,
            Colors.blue,
          ),
          _buildStatCard(
            'الديون',
            _userStats['totalDebts'] != null
                ? '${NumberFormat('#,##0.00').format(_userStats['totalDebts'])} ₪'
                : '0.00 ₪',
            Icons.arrow_downward,
            Colors.red,
          ),
          _buildStatCard(
            'المدفوعات',
            _userStats['totalCredits'] != null
                ? '${NumberFormat('#,##0.00').format(_userStats['totalCredits'])} ₪'
                : '0.00 ₪',
            Icons.arrow_upward,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isNumber = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 170,
      margin: const EdgeInsets.only(left: 8),
      child: Card(
        elevation: 4,
        shadowColor: color.withOpacity(0.2),
        color: isDark ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'الاسم',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال الاسم';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _businessNameController,
              label: 'اسم المتجر/الشركة',
              icon: Icons.business,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'العنوان',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),
            _buildPhoneField(),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.save_rounded,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'حفظ التغييرات',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingSection(
          title: 'المظهر',
          children: [
            _buildSettingTile(
              title: 'الوضع الليلي',
              subtitle: 'تفعيل المظهر الداكن',
              leading: Icon(
                Icons.dark_mode,
                color: isDark ? Colors.blue : Colors.blueGrey,
              ),
              trailing: Switch(
                value: _isDarkMode,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() => _isDarkMode = value);
                },
              ),
            ),
            _buildSettingTile(
              title: 'السمة',
              subtitle: _selectedThemeMode,
              leading: Icon(
                Icons.palette,
                color: isDark ? Colors.purple : Colors.deepPurple,
              ),
              onTap: _showThemeDialog,
            ),
          ],
        ),
        _buildSettingSection(
          title: 'التنبيهات',
          children: [
            _buildSettingTile(
              title: 'الإشعارات',
              subtitle: 'تفعيل الإشعارات والتنبيهات',
              leading: Icon(
                Icons.notifications,
                color: isDark ? Colors.amber : Colors.orange,
              ),
              trailing: Switch(
                value: _notificationsEnabled,
                activeColor: Colors.amber,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
            ),
          ],
        ),
        _buildSettingSection(
          title: 'اللغة والمنطقة',
          children: [
            _buildSettingTile(
              title: 'اللغة',
              subtitle: _selectedLanguage,
              leading: Icon(
                Icons.language,
                color: isDark ? Colors.green : Colors.teal,
              ),
              onTap: _showLanguageDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingSection(
          title: 'الأمان',
          children: [
            _buildSettingTile(
              title: 'تغيير كلمة المرور',
              subtitle: 'تحديث كلمة المرور الخاصة بك',
              leading: Icon(
                Icons.lock_outlined,
                color: isDark ? Colors.blue : Colors.indigo,
              ),
              onTap: () {
                // تنفيذ تغيير كلمة المرور
              },
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Column(
                  children: [
                    _buildSettingTile(
                      title: 'سجل النشاط',
                      subtitle: 'عرض سجل تسجيل الدخول والنشاطات',
                      leading: Icon(
                        Icons.history,
                        color: isDark ? Colors.purple : Colors.deepPurple,
                      ),
                      onTap: () {
                        // عرض سجل النشاط
                      },
                    ),
                    _buildSettingTile(
                      title: 'المصادقة الثنائية',
                      subtitle: 'تفعيل المصادقة الثنائية لحماية إضافية',
                      leading: Icon(
                        Icons.security,
                        color: isDark ? Colors.green : Colors.teal,
                      ),
                      onTap: () {
                        // تنفيذ المصادقة الثنائية
                      },
                    ),
                  ],
                ),
                Container(
                  height: 140, // زيادة ارتفاع الظل
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.8) // زيادة التعتيم قليلاً
                        : Colors.grey[100]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'قريباً',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingSection({
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[850]
                : Theme.of(context).cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.grey[800]!
                  : Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingTile({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          : null,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[850]
            : Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.grey[800]!
              : Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : null,
          ),
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPhoneField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[850]
            : Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.grey[800]!
              : Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.grey[800]!
                      : Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: isDark ? Colors.grey[850] : Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  items: _countryCodes.map((country) {
                    return DropdownMenuItem(
                      value: country['code'],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${country['name']}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCountryCode = value!);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : null,
                ),
                prefixIcon: Icon(
                  Icons.phone,
                  color: Theme.of(context).primaryColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              validator: _validatePhone,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Text(
          'اختر السمة',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('تلقائي', Icons.brightness_auto),
            _buildThemeOption('فاتح', Icons.brightness_high),
            _buildThemeOption('داكن', Icons.brightness_4),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      selected: _selectedThemeMode == title,
      onTap: () {
        setState(() => _selectedThemeMode = title);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguageDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Text(
          'اختر اللغة',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('العربية', '🇵🇸'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, String flag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        language,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      selected: _selectedLanguage == language,
      onTap: () {
        setState(() => _selectedLanguage = language);
        Navigator.pop(context);
      },
    );
  }

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
    {'code': '+20', 'name': 'مصر 🇪🇬'},
  ];

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
            _businessNameController.text = userData['business_name'] ?? '';
            _addressController.text = userData['address'] ?? '';

            // معالجة رقم الهاتف المخزن
            String storedPhone = userData['phone'] ?? '';
            if (storedPhone.isNotEmpty) {
              // البحث عن كود الدولة في الرقم المخزن
              String? countryCode = _countryCodes.firstWhere(
                (code) => storedPhone.startsWith(code['code']!),
                orElse: () => {'code': '+970', 'name': 'فلسطين 🇵🇸'},
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
        businessName: _businessNameController.text.isNotEmpty
            ? _businessNameController.text
            : null,
        address:
            _addressController.text.isNotEmpty ? _addressController.text : null,
        themeMode: _selectedThemeMode,
        language: _selectedLanguage,
        notificationsEnabled: _notificationsEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المعلومات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // رقم الهاتف اختياري
    }

    // تحقق من أن الرقم يحتوي على أرقام فقط
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'الرجاء إدخال أرقام فقط';
    }

    // تحقق من طول رقم الهاتف (بين 9 و 10 أرقام)
    if (value.length < 9 || value.length > 10) {
      return 'رقم الهاتف يجب أن يكون بين 9 و 10 أرقام';
    }

    return null;
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
