import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, child) {
        if (!connectivity.showOfflineMessage) return const SizedBox.shrink();

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
