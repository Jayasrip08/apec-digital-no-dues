import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Top-level function for background message handling
/// This must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.notification?.title}');
  // Handle background message here if needed
}

/// Notification Service for managing FCM notifications
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');

        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          print('FCM Token: $token');
          await saveFCMToken(token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(saveFCMToken);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('User denied notification permission');
      } else {
        print('Notification permission status: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token saved to Firestore');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    // You can show a dialog or snackbar here
    // For now, we'll just log it
    if (message.notification != null) {
      print('Title: ${message.notification!.title}');
      print('Body: ${message.notification!.body}');
    }

    // Mark notification as received in Firestore
    _markNotificationAsReceived(message);
  }

  /// Handle notification tap (when user taps notification)
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    // Navigate based on notification type
    final type = message.data['type'];
    
    switch (type) {
      case 'payment_reminder':
        // Navigate to payment screen
        print('Navigate to payment screen');
        break;
      case 'payment_verified':
      case 'payment_rejected':
        // Navigate to payment history
        print('Navigate to payment history');
        break;
      default:
        print('Unknown notification type: $type');
    }
  }

  /// Mark notification as received
  Future<void> _markNotificationAsReceived(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && message.data.containsKey('notificationId')) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(message.data['notificationId'])
            .update({'received': true, 'receivedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      print('Error marking notification as received: $e');
    }
  }

  /// Show in-app notification (for foreground messages)
  static void showInAppNotification(
    BuildContext context,
    String title,
    String body,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.indigo,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('read', isEqualTo: false)
            .count()
            .get();
        return snapshot.count ?? 0;
      }
    } catch (e) {
      print('Error getting unread count: $e');
    }
    return 0;
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Delete FCM token on logout
  Future<void> deleteFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
        await _messaging.deleteToken();
        print('FCM token deleted');
      }
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}
