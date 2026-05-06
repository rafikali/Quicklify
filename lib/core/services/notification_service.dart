import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String _tag = 'NotificationService';
  static const String _channelId = 'quicklify_downloads';
  static const String _channelName = 'Downloads';
  static const String _channelDesc = 'Download progress notifications';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Unique int ID per taskId (flutter_local_notifications needs int IDs)
  static final Map<String, int> _idMap = {};
  static int _nextId = 1000;

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    dev.log('NotificationService initialized', name: _tag);
  }

  static int _idFor(String taskId) {
    return _idMap.putIfAbsent(taskId, () => _nextId++);
  }

  static Future<void> showProgress({
    required String taskId,
    required String filename,
    required int progress,
  }) async {
    if (!Platform.isAndroid) return;

    final id = _idFor(taskId);
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      autoCancel: false,
    );

    await _plugin.show(
      id,
      'Downloading',
      filename,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showComplete({
    required String taskId,
    required String filename,
  }) async {
    if (!Platform.isAndroid) return;

    final id = _idFor(taskId);
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
    );

    await _plugin.show(
      id,
      'Download complete',
      filename,
      const NotificationDetails(android: androidDetails),
    );
    _idMap.remove(taskId);
  }

  static Future<void> showFailed({
    required String taskId,
    required String filename,
  }) async {
    if (!Platform.isAndroid) return;

    final id = _idFor(taskId);
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
    );

    await _plugin.show(
      id,
      'Download failed',
      filename,
      const NotificationDetails(android: androidDetails),
    );
    _idMap.remove(taskId);
  }

  static Future<void> cancel(String taskId) async {
    final id = _idMap.remove(taskId);
    if (id != null) {
      await _plugin.cancel(id);
    }
  }
}
