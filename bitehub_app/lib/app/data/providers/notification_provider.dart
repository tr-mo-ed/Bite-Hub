import 'package:flutter/material.dart';

import 'package:bitehub_app/app/data/models/notification_model.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/notification_service.dart';

// ???? ???? NotificationProvider ???? ???? ????? ???? ?? ???? ????.
class NotificationProvider extends ChangeNotifier {
  // ??? ??????? _service ??? ?????? ???? ????? ????.
  final NotificationService _service = NotificationService.instance;

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
    _items = await _service.loadNotifications();
    _isLoading = false;
    notifyListeners();
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
}
