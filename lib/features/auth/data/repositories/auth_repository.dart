import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  /// Login and store tokens
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        data: {
          'username': username,
          'password': password,
        },
      );

      final authResponse = AuthResponseModel.fromJson(response.data);

      // Save tokens securely
      await _storage.saveAccessToken(authResponse.accessToken);
      if (authResponse.refreshToken != null) {
        await _storage.saveRefreshToken(authResponse.refreshToken!);
      }

      // Fetch user profile
      return await getProfile();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get current user profile
  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.get(ApiConstants.me);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Check if user has a valid saved session
  Future<UserModel?> tryAutoLogin() async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;

    try {
      return await getProfile();
    } catch (_) {
      await _storage.clearTokens();
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _storage.clearTokens();
  }

  /// Convert DioException to readable error message (Arabic)
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'انتهت مهلة الاتصال. تحقق من اتصالك بالإنترنت';
      case DioExceptionType.connectionError:
        return 'لا يمكن الاتصال بالخادم. تأكد من تشغيل الخادم';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'اسم المستخدم أو كلمة المرور غير صحيحة';
        } else if (statusCode == 403) {
          return 'ليس لديك صلاحية للوصول';
        } else if (statusCode == 429) {
          return 'محاولات كثيرة. حاول مرة أخرى لاحقاً';
        }
        return 'حدث خطأ في الخادم';
      default:
        return 'حدث خطأ غير متوقع. حاول مرة أخرى';
    }
  }
}