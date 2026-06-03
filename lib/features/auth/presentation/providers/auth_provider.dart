import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/services/notification_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔑 [AUTH] Starting login for: $username');
      _user = await _authRepository.login(
        username: username,
        password: password,
      );
      debugPrint('✅ [AUTH] Login successful! User: ${_user?.username}, Role: ${_user?.role}');
      _status = AuthStatus.authenticated;
      await NotificationService.instance.initialize();
      await NotificationService.instance.registerTokenWithServer();
    } catch (e, stackTrace) {
      debugPrint('❌ [AUTH] Login FAILED: $e');
      debugPrint('❌ [AUTH] Stack trace: $stackTrace');
      _errorMessage = e.toString();
      _status = AuthStatus.error;
    }

    debugPrint('📊 [AUTH] Final status: $_status');
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      debugPrint('🔄 [AUTH] Trying auto-login...');
      _user = await _authRepository.tryAutoLogin();
      _status = _user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      debugPrint('🔄 [AUTH] Auto-login result: $_status');
    } catch (e) {
      debugPrint('🔄 [AUTH] Auto-login failed: $e');
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await NotificationService.instance.removeTokenFromServer();
    await _authRepository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}