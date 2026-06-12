import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bitehub_app/app/data/models/notification_model.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/data/services/notification_service.dart';

// ???? ???? NotificationProvider ???? ???? ????? ???? ?? ???? ????.
class NotificationProvider extends ChangeNotifier {
  // ??? ??????? _service ??? ?????? ???? ????? ????.
  final NotificationService _service = NotificationService.instance;
  final ApiService _apiService = ApiService();

  Timer? _serverRefreshTimer;
  bool _isRefreshingFromServer = false;
  List<NotificationItem> _items = [];
  bool _isLoading = false;
  NotificationItem? _pendingBanner;
  int _bannerSequence = 0;

  List<NotificationItem> get items => _items;
  bool get isLoading => _isLoading;
  int get unreadCount => _items.where((item) => !item.isRead).length;
  NotificationItem? get pendingBanner => _pendingBanner;
  int get bannerSequence => _bannerSequence;

  // ???? ???? load ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _items = await _loadMergedNotifications();
    _isLoading = false;
    notifyListeners();
  }

  void startAutoRefresh() {
    if (_serverRefreshTimer != null) {
      return;
    }
    unawaited(refreshFromServer(silent: true));
    _serverRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(refreshFromServer(silent: true));
    });
  }

  void stopAutoRefresh() {
    _serverRefreshTimer?.cancel();
    _serverRefreshTimer = null;
  }

  Future<void> refreshFromServer({bool silent = false}) async {
    if (_isRefreshingFromServer) {
      return;
    }
    _isRefreshingFromServer = true;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _items = await _loadMergedNotifications();
    } finally {
      _isRefreshingFromServer = false;
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // ???? ???? refreshFromOrders ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> refreshFromOrders(List<OrderModel> orders) async {
    final previousIds = _items.map((item) => item.id).toSet();
    _items = await _service.updateFromOrders(orders);
    final addedItems = _items
        .where((item) => !previousIds.contains(item.id))
        .toList(growable: false);
    if (addedItems.isNotEmpty) {
      _pendingBanner = addedItems.first;
      _bannerSequence++;
    }
    notifyListeners();
  }

  // ???? ???? markAllRead ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> markAllRead() async {
    try {
      await _apiService.markNotificationsRead();
    } catch (_) {
      // Local read state still keeps the UI responsive if the server is offline.
    }
    await _service.markAllRead();
    _items = await _service.loadNotifications();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    _items = await _service.loadNotifications();
    notifyListeners();
  }

  void clearPendingBanner() {
    _pendingBanner = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  Future<List<NotificationItem>> _loadMergedNotifications() async {
    final localItems = await _service.loadNotifications();
    try {
      final serverItems = await _apiService.getNotifications();
      final unreadServerItems = serverItems.where((item) => !item.isRead);
      for (final item in unreadServerItems) {
        await _service.showExternalNotificationOnce(item);
      }
      final merged = <String, NotificationItem>{};
      for (final item in [...serverItems, ...localItems]) {
        merged[item.id] = item;
      }
      final items = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _service.saveNotifications(items);
      return items;
    } catch (_) {
      return localItems;
    }
  }
}
