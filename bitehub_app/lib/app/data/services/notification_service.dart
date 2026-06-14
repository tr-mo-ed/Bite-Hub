import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitehub_app/app/data/models/notification_model.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _notificationsKey = 'bitehub_notifications_v2';
  static const String _statusCacheKey = 'bitehub_order_status_cache_v2';
  static const String _shownExternalNotificationsKey =
      'bitehub_shown_external_notifications_v2';
  static const String _channelKey = 'bitehub_order_updates_v2';
  static const int _maxNotifications = 50;
  static const int _maxShownExternalNotifications = 200;

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: 'Bite Hub - تحديثات الطلبات',
          channelDescription: 'حالة الطلب والمحفظة داخل Bite Hub',
          importance: NotificationImportance.High,
          defaultColor: const Color(0xFF167C68),
          ledColor: const Color(0xFF167C68),
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: false,
    );
  }

  Future<void> requestPermissionIfNeeded() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (isAllowed) {
      return;
    }
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<List<NotificationItem>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotifications(List<NotificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = items.take(_maxNotifications).toList();
    final encoded = json.encode(
      trimmed.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_notificationsKey, encoded);
  }

  Future<void> markAllRead() async {
    final items = await loadNotifications();
    final updated = items.map((item) => item.copyWith(isRead: true)).toList();
    await saveNotifications(updated);
  }

  Future<void> markAsRead(String id) async {
    final items = await loadNotifications();
    final updated = items
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList();
    await saveNotifications(updated);
  }

  Future<int> getUnreadCount() async {
    final items = await loadNotifications();
    return items.where((item) => !item.isRead).length;
  }

  Future<List<NotificationItem>> updateFromOrders(
      List<OrderModel> orders) async {
    final statusCache = await _loadStatusCache();
    final items = await loadNotifications();

    for (final order in orders) {
      final key = order.id.toString();
      final status = order.status.toUpperCase();
      final previousStatus = statusCache[key];

      if (previousStatus == null) {
        statusCache[key] = status;
        if (status != 'PENDING') {
          final notification = _buildNotification(order, status);
          if (notification != null) {
            items.insert(0, notification);
            await showExternalNotificationOnce(notification);
          }
        }
        continue;
      }

      if (previousStatus == status) {
        continue;
      }

      final notification = _buildNotification(order, status);
      if (notification != null) {
        items.insert(0, notification);
        await showExternalNotificationOnce(notification);
      }
      statusCache[key] = status;
    }

    await saveNotifications(items);
    await _saveStatusCache(statusCache);
    return items;
  }

  NotificationItem? _buildNotification(OrderModel order, String status) {
    final orderNumber = order.displayOrderCode.isNotEmpty
        ? order.displayOrderCode
        : order.id.toString();

    switch (status) {
      case 'ACCEPTED':
        return NotificationItem(
          id: '${order.id}-accepted-${DateTime.now().millisecondsSinceEpoch}',
          orderId: order.id,
          status: status,
          title: 'تم قبول طلبك',
          body: 'طلبك رقم #$orderNumber تم قبوله وبدأت معالجته.',
          createdAt: DateTime.now().toIso8601String(),
        );
      case 'PREPARING':
        return NotificationItem(
          id: '${order.id}-preparing-${DateTime.now().millisecondsSinceEpoch}',
          orderId: order.id,
          status: status,
          title: 'طلبك قيد التحضير',
          body: 'المقهى يعمل الآن على تجهيز الطلب رقم #$orderNumber.',
          createdAt: DateTime.now().toIso8601String(),
        );
      case 'READY':
        return NotificationItem(
          id: '${order.id}-ready-${DateTime.now().millisecondsSinceEpoch}',
          orderId: order.id,
          status: status,
          title: 'طلبك جاهز للاستلام',
          body: 'يمكنك الآن استلام الطلب رقم #$orderNumber من نقطة الاستلام.',
          createdAt: DateTime.now().toIso8601String(),
        );
      case 'CANCELLED':
        return NotificationItem(
          id: '${order.id}-cancelled-${DateTime.now().millisecondsSinceEpoch}',
          orderId: order.id,
          status: status,
          title: 'تم إلغاء الطلب',
          body: 'تم إلغاء الطلب رقم #$orderNumber. راجع تفاصيل الطلب للتأكد.',
          createdAt: DateTime.now().toIso8601String(),
        );
      default:
        return null;
    }
  }

  Future<void> showExternalNotificationOnce(NotificationItem item) async {
    if (item.id.trim().isEmpty) {
      return;
    }
    final shownIds = await _loadShownExternalNotificationIds();
    if (shownIds.contains(item.id)) {
      return;
    }
    await _showSystemNotification(item);
    shownIds.insert(0, item.id);
    await _saveShownExternalNotificationIds(shownIds);
  }

  Future<void> _showSystemNotification(NotificationItem item) async {
    await requestPermissionIfNeeded();

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        channelKey: _channelKey,
        title: item.title,
        body: item.body,
        summary: item.orderId == null
            ? 'Bite Hub • المحفظة'
            : 'Bite Hub • تحديث الطلب',
        icon: 'resource://drawable/ic_stat_bitehub',
        largeIcon: 'asset://assets/images/bitehub_app_icon.png',
        notificationLayout: NotificationLayout.BigText,
        payload: {
          'order_id': item.orderId?.toString() ?? '',
          'status': item.status,
          'notification_id': item.id,
        },
      ),
    );
  }

  Future<Map<String, String>> _loadStatusCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statusCacheKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveStatusCache(Map<String, String> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusCacheKey, json.encode(cache));
  }

  Future<List<String>> _loadShownExternalNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shownExternalNotificationsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.map((item) => item.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveShownExternalNotificationIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = ids.take(_maxShownExternalNotifications).toList();
    await prefs.setString(
      _shownExternalNotificationsKey,
      json.encode(trimmed),
    );
  }
}
