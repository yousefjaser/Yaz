import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/analytics_screen.dart';
import '../providers/settings_provider.dart';

class DrawerWidget extends StatelessWidget {
  const DrawerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final user = authProvider.currentUser;
    final email = user?.email ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: FutureBuilder<Map<String, dynamic>?>(
                future: authProvider.getUserProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('جاري التحميل...', 
                      style: TextStyle(color: Colors.white)
                    );
                  }
                  if (snapshot.hasError) {
                    debugPrint('خطأ في جلب الملف الشخصي: ${snapshot.error}');
                    return const Text('المستخدم',
                      style: TextStyle(color: Colors.white)
                    );
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return Text(
                      snapshot.data!['name'] ?? 'المستخدم',
                      style: const TextStyle(color: Colors.white)
                    );
                  }
                  return const Text('المستخدم',
                    style: TextStyle(color: Colors.white)
                  );
                },
              ),
              accountEmail: Text(
                email,
                style: const TextStyle(color: Colors.white70)
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: authProvider.getUserProfile(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                      );
                    }
                    if (snapshot.hasError) {
                      debugPrint('خطأ في جلب الصورة: ${snapshot.error}');
                      return Text(
                        email.isNotEmpty ? email[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.black54
                        ),
                      );
                    }
                    final name = snapshot.data?['name'] ?? email;
                    return Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.black54
                      ),
                    );
                  },
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9C27B0) // لون بنفسجي للوضع الداكن
                    : const Color(0xFFBA68C8), // لون بنفسجي فاتح للوضع الفاتح
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9C27B0)
                        : const Color(0xFFBA68C8),
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF7B1FA2)
                        : const Color(0xFF9C27B0),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('الرئيسية'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('الملف الشخصي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('تحليل البيانات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('سلة المحذوفات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrashScreen()),
                );
              },
            ),
            const Divider(),
            SwitchListTile(
              secondary: Icon(
                settingsProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              title: const Text('الوضع الداكن'),
              value: settingsProvider.isDarkMode,
              onChanged: (_) => settingsProvider.toggleTheme(),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.pop(context);
                authProvider.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
