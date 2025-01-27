import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = true;
  bool _showOfflineMessage = false;

  bool get isOnline => _isOnline;
  bool get showOfflineMessage => _showOfflineMessage;

  ConnectivityProvider() {
    _init();
  }

  void _init() {
    ConnectivityService.isConnected().then((online) {
      _isOnline = online;
      if (!online) _showOfflineMessage = true;
      notifyListeners();
    });

    ConnectivityService.connectivityStream.listen((online) {
      _isOnline = online;
      if (!online) _showOfflineMessage = true;
      notifyListeners();
    });
  }

  void dismissOfflineMessage() {
    _showOfflineMessage = false;
    notifyListeners();
  }
}
