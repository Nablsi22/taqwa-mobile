import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(_dio, _storage));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  // ── HTTP Methods ──────────────────────────────────────
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
  }) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(
    String path, {
    dynamic data,
  }) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Dio get dio => _dio;
}

// ── Auth Interceptor (auto-attach token + auto-refresh) ─────
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SecureStorageService _storage;

  _AuthInterceptor(this._dio, this._storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isAuthPath = options.path.contains('/auth/login') ||
        options.path.contains('/auth/refresh');

    if (!isAuthPath) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          return handler.next(err);
        }

        final response = await _dio.post(
          ApiConstants.refresh,
          data: {'refreshToken': refreshToken},
        );

        final newAccessToken = response.data['accessToken'];
        final newRefreshToken = response.data['refreshToken'];

        await _storage.saveAccessToken(newAccessToken);
        if (newRefreshToken != null) {
          await _storage.saveRefreshToken(newRefreshToken);
        }

        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        final retryResponse = await _dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        await _storage.clearTokens();
        return handler.next(err);
      }
    }

    handler.next(err);
  }
}