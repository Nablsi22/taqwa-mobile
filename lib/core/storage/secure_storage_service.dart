import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/storage_service.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._();
  factory SecureStorageService() => _instance;
  SecureStorageService._();

  // Use the SAME StorageService that ApiClient uses on web
  final StorageService _webStorage = StorageService();

  static const _nativeStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      await _webStorage.write(key: key, value: value);
    } else {
      await _nativeStorage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      return await _webStorage.read(key: key);
    } else {
      return await _nativeStorage.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      await _webStorage.delete(key: key);
    } else {
      await _nativeStorage.delete(key: key);
    }
  }

  Future<void> saveAccessToken(String token) async {
    await _write(_accessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    return await _read(_accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _write(_refreshTokenKey, token);
  }

  Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _delete(_accessTokenKey);
    await _delete(_refreshTokenKey);
  }
}