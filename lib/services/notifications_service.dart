import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static void initialize(BuildContext context) {
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print(" Notification tapped: ${response.payload}");
      },
    );
  }

  static Future<void> display(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null && Platform.isAndroid) {
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'message_channel',
          'Messages',
          channelDescription: 'Channel for message notifications',
          importance: Importance.max,
          priority: Priority.high,
        );

        const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          notificationDetails,
          payload: message.data['payload'] ?? '',
        );
      }
    } catch (e) {
      print(" Error displaying notification: $e");
    }
  }

  static Future<void> requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print(' Permission granted');
    } else {
      print(' Permission denied');
    }
  }
}
