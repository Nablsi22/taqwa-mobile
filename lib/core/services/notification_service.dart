import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background notification: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase and set up notification handling
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission (iOS will show a dialog, Android auto-grants)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('User denied notification permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        _sendTokenToServer(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground notification: ${message.notification?.title}');
        _showForegroundNotification(message);
      });

      // Handle notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification opened: ${message.notification?.title}');
        _handleNotificationTap(message);
      });

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  /// Register FCM token with the backend after login
  Future<void> registerTokenWithServer() async {
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      // Try to get token again
      _fcmToken = await _messaging.getToken();
    }

    if (_fcmToken == null) return;

    await _sendTokenToServer(_fcmToken!);
  }

  /// Send token to backend
  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient.instance.post(
        '/notifications/register-token',
        data: {'token': token},
      );
      debugPrint('FCM token registered with server');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Remove token from server (on logout)
  Future<void> removeTokenFromServer() async {
    try {
      await ApiClient.instance.dio.delete('/notifications/remove-token');
      debugPrint('FCM token removed from server');
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
    }
  }

  /// Show a notification banner when app is in foreground
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Use a global key to show snackbar from anywhere
    if (_scaffoldKey.currentState != null) {
      _scaffoldKey.currentState!.showSnackBar(
        SnackBar(
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.title ?? 'إعلان جديد',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (notification.body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.body!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          backgroundColor: const Color(0xFF1B4F72),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  /// Handle notification tap (navigate to announcements)
  void _handleNotificationTap(RemoteMessage message) {
    // You can navigate to specific screens based on message.data
    debugPrint('Notification tapped: ${message.data}');
  }

  /// Global scaffold key for showing foreground notifications
  static final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<ScaffoldMessengerState> get scaffoldKey => _scaffoldKey;
}
