import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  static Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map((status) {
      return status != ConnectivityResult.none;
    });
  }
}
