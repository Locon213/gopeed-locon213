import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

import '../api/api.dart';
import '../api/model/task.dart';
import '../i18n/message.dart';
import '../util/util.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int _downloadCompleteNotificationId = 1000;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Track previously seen tasks to detect state changes
  final Map<String, Status> _previousTaskStatuses = {};

  Future<void> initialize() async {
    if (Util.isWeb()) {
      // Web platform doesn't support local notifications
      return;
    }

    // Request notification permission
    await _requestNotificationPermission();

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse payload) {
        debugPrint('Notification tapped: ${payload.payload}');
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (Util.isIOS() || Util.isAndroid()) {
      // On iOS and Android, we can request notification permissions
      final status = await Permission.notification.request();
      debugPrint('Notification permission status: $status');
    } else if (Util.isWindows()) {
      // On Windows, we don't need explicit permission for notifications
    } else if (Util.isLinux() || Util.isMacos()) {
      // On Linux and macOS, we don't need explicit permission for notifications
    }
  }

  Future<bool> _hasNotificationPermission() async {
    if (Util.isWeb()) {
      return false;
    }

    if (Util.isIOS() || Util.isAndroid()) {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }

    // On desktop platforms, we assume permission is granted
    return true;
  }

  Future<void> showDownloadCompleteNotification(
      String fileName, String fileSize) async {
    if (!await _hasNotificationPermission()) {
      debugPrint('Notification permission not granted');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'download_complete_channel',
      'Download Complete Notifications',
      channelDescription: 'Notifications for completed downloads',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Download completed',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      _downloadCompleteNotificationId + Random().nextInt(1000),
      'downloadCompleteTitle'.tr,
      'downloadCompleteBody'.trParams({'fileName': fileName, 'fileSize': fileSize}),
      details,
    );
  }

  Future<void> showDownloadFailedNotification(
      String fileName, String errorMessage) async {
    if (!await _hasNotificationPermission()) {
      debugPrint('Notification permission not granted');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'download_failed_channel',
      'Download Failed Notifications',
      channelDescription: 'Notifications for failed downloads',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Download failed',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      _downloadCompleteNotificationId + Random().nextInt(1000),
      'downloadFailedTitle'.tr,
      'downloadFailedBody'.trParams({'fileName': fileName, 'error': errorMessage}),
      details,
    );
  }

  /// Monitor tasks and send notifications when their status changes to done or error
  Future<void> monitorTaskChanges(List<Task> currentTasks) async {
    for (final task in currentTasks) {
      final previousStatus = _previousTaskStatuses[task.id];

      // Check if task status has changed to done or error
      if (previousStatus != null && previousStatus != task.status) {
        if (task.status == Status.done) {
          // Show download complete notification
          await showDownloadCompleteNotification(task.name, _formatFileSize(task.progress.used));
        } else if (task.status == Status.error) {
          // Show download failed notification
          await showDownloadFailedNotification(task.name, task.progress.extractStatus.name);
        }
      }

      // Update the stored status for this task
      _previousTaskStatuses[task.id] = task.status;
    }

    // Clean up old tasks that are no longer in the list
    final currentTaskIds = currentTasks.map((task) => task.id).toSet();
    _previousTaskStatuses.removeWhere((taskId, _) => !currentTaskIds.contains(taskId));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}