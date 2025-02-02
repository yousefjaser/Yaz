import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class AppUpdateInfo {
  final String version;
  final int versionCode;
  final String releaseNotes;
  final String downloadUrl;
  final bool isForceUpdate;
  final String minVersion;

  AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.isForceUpdate,
    required this.minVersion,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    try {
      return AppUpdateInfo(
        version: json['version']?.toString() ?? '',
        versionCode: int.tryParse(json['version_code']?.toString() ?? '0') ?? 0,
        releaseNotes: json['release_notes']?.toString() ?? '',
        downloadUrl: Platform.isAndroid
            ? json['android_url']?.toString() ?? ''
            : json['ios_url']?.toString() ?? '',
        isForceUpdate: json['is_force_update'] as bool? ?? false,
        minVersion: json['min_version']?.toString() ?? '1.0.0',
      );
    } catch (e) {
      print('خطأ في تحويل البيانات: $e');
      return AppUpdateInfo(
        version: '1.0.0',
        versionCode: 1,
        releaseNotes: '',
        downloadUrl: '',
        isForceUpdate: false,
        minVersion: '1.0.0',
      );
    }
  }
}

class UpdateService {
  final SupabaseClient _supabase;
  static const String bucketName = 'app-updates';

  UpdateService(this._supabase);

  Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      // الحصول على معلومات الإصدار الحالي
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // البحث عن آخر تحديث متاح
      final response = await _supabase
          .from('app_updates')
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final update = AppUpdateInfo.fromJson(response);

        // التحقق من وجود تحديث جديد
        if (update.versionCode > currentBuildNumber) {
          return update;
        }
      }

      return null;
    } catch (e) {
      print('خطأ في التحقق من التحديثات: $e');
      return null;
    }
  }

  Future<String?> uploadUpdateFile(String filePath) async {
    try {
      if (!File(filePath).existsSync()) {
        throw Exception('الملف غير موجود');
      }

      final fileName = filePath.split('/').last;
      final file = File(filePath);

      // التحقق من حجم الملف
      final fileSize = await file.length();
      if (fileSize > 100 * 1024 * 1024) {
        // 100 MB
        throw Exception('حجم الملف كبير جداً');
      }

      final storageResponse = await _supabase.storage.from(bucketName).upload(
          'updates/$fileName', file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      if (storageResponse != null) {
        final publicUrl = _supabase.storage
            .from(bucketName)
            .getPublicUrl('updates/$fileName');

        return publicUrl;
      }
      return null;
    } catch (e) {
      print('خطأ في رفع ملف التحديث: $e');
      return null;
    }
  }

  Future<bool> addNewUpdate({
    required String version,
    required int versionCode,
    required String releaseNotes,
    required String androidUrl,
    String? iosUrl,
    bool isForceUpdate = false,
    required String minVersion,
  }) async {
    try {
      // التحقق من صحة البيانات
      if (version.isEmpty || versionCode <= 0 || androidUrl.isEmpty) {
        throw Exception('البيانات غير صحيحة');
      }

      final response = await _supabase.from('app_updates').insert({
        'version': version,
        'version_code': versionCode,
        'release_notes': releaseNotes,
        'android_url': androidUrl,
        'ios_url': iosUrl,
        'is_force_update': isForceUpdate,
        'min_version': minVersion,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      return response != null;
    } catch (e) {
      print('خطأ في إضافة التحديث: $e');
      return false;
    }
  }
}
