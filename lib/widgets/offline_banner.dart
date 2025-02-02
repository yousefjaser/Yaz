import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/database_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, DatabaseService>(
      builder: (context, connectivity, database, child) {
        // إذا كان هناك اتصال، لا نعرض البانر
        if (!connectivity.showOfflineMessage) {
          return const SizedBox.shrink();
        }

        // إذا كان هناك مزامنة جارية، نعرض شريط التقدم
        if (database.isSyncing) {
          return Material(
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          database.syncStatus,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: database.syncProgress,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        // عرض بانر وضع عدم الاتصال
        return Material(
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange,
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'تم تفعيل وضع العمل بدون اتصال',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: connectivity.dismissOfflineMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
