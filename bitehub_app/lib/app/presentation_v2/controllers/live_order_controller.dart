import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

enum LiveOrderSyncState {
  connecting,
  realtime,
  polling,
  offline,
  stopped,
}

class LiveOrderController extends ChangeNotifier {
  LiveOrderController({
    ApiService? apiService,
    Connectivity? connectivity,
  })  : _apiService = apiService ?? ApiService(),
        _connectivity = connectivity ?? Connectivity();

  final ApiService _apiService;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription? _socketSubscription;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pollingTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOffline = false;
  bool _isSocketConnected = false;
  bool _isConnectingSocket = false;
  bool _isPolling = false;
  bool _disposed = false;
  int _connectionGeneration = 0;
  int _consecutivePollFailures = 0;
  int? _targetOrderId;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;
  OrderModel? _trackedOrder;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isOffline => _isOffline;
  bool get isSocketConnected => _isSocketConnected;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  OrderModel? get trackedOrder => _trackedOrder;

  LiveOrderSyncState get syncState {
    if (_trackedOrder != null && _isTerminal(_trackedOrder!.status)) {
      return LiveOrderSyncState.stopped;
    }
    if (_isOffline) {
      return LiveOrderSyncState.offline;
    }
    if (_isSocketConnected) {
      return LiveOrderSyncState.realtime;
    }
    if (_isConnectingSocket) {
      return LiveOrderSyncState.connecting;
    }
    return LiveOrderSyncState.polling;
  }

  @visibleForTesting
  void seedPreview(
    OrderModel order, {
    DateTime? lastUpdatedAt,
    bool offline = false,
  }) {
    _trackedOrder = order;
    _targetOrderId = order.id;
    _lastUpdatedAt = lastUpdatedAt ?? DateTime.now();
    _isLoading = false;
    _isRefreshing = false;
    _isOffline = offline;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> initialize({
    OrderModel? initialOrder,
    int? initialOrderId,
  }) async {
    _trackedOrder = initialOrder;
    _targetOrderId = initialOrderId ?? initialOrder?.id;
    if (initialOrder != null) {
      _lastUpdatedAt = DateTime.now();
    }

    _connectivitySubscription ??=
        _connectivity.onConnectivityChanged.listen(_handleConnectivity);

    await refresh(orderId: _targetOrderId);
  }

  Future<void> refresh({
    int? orderId,
    bool silent = false,
  }) async {
    if (orderId != null) {
      _targetOrderId ??= orderId;
    }

    if (silent) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _notify();

    try {
      final orders = await _apiService.getOrders();
      final resolved = _resolveTrackedOrder(orders);

      if (resolved != null) {
        _trackedOrder = resolved;
        _targetOrderId ??= resolved.id;
        _lastUpdatedAt = DateTime.now();
        _errorMessage = null;
      } else if (_trackedOrder == null) {
        _errorMessage = _targetOrderId == null
            ? 'لا يوجد طلب متاح للتتبع.'
            : 'تعذر العثور على الطلب المطلوب.';
      }

      _isOffline = false;
      _consecutivePollFailures = 0;
      _configureLiveUpdates();
    } catch (error) {
      _errorMessage = error.toString();
      _isOffline = true;
      _isSocketConnected = false;
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      _notify();
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    final offline =
        results.every((result) => result == ConnectivityResult.none);
    _isOffline = offline;
    if (offline) {
      _isSocketConnected = false;
      _reconnectTimer?.cancel();
    } else {
      _errorMessage = null;
      _startPollingIfNeeded();
      _scheduleReconnect(const Duration(milliseconds: 400));
      unawaited(refresh(silent: true));
    }
    _notify();
  }

  OrderModel? _resolveTrackedOrder(List<OrderModel> orders) {
    final targetId = _targetOrderId;
    if (targetId != null) {
      for (final order in orders) {
        if (order.id == targetId) {
          return order;
        }
      }
      return null;
    }

    for (final order in orders) {
      if (!_isTerminal(order.status)) {
        return order;
      }
    }
    return orders.isEmpty ? null : orders.first;
  }

  void _configureLiveUpdates() {
    final order = _trackedOrder;
    if (order == null || _isTerminal(order.status)) {
      _stopLiveUpdates();
      return;
    }

    _startPolling(order.id);
    unawaited(_connectSocket());
  }

  Future<void> _connectSocket() async {
    final order = _trackedOrder;
    final cafeId = order?.cafeId;
    if (_disposed ||
        _isOffline ||
        _isConnectingSocket ||
        _isSocketConnected ||
        order == null ||
        cafeId == null ||
        cafeId.isEmpty ||
        _isTerminal(order.status)) {
      return;
    }

    _isConnectingSocket = true;
    final generation = ++_connectionGeneration;
    _notify();

    await _closeSocket();

    try {
      final apiUri = Uri.parse(ApiService.baseUrl);
      final token = await ApiService().getToken();
      if (token == null || token.isEmpty) {
        _isConnectingSocket = false;
        _notify();
        return;
      }
      final wsUri = apiUri.replace(
        scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/cafe/$cafeId/orders/',
        queryParameters: {'token': token},
      );

      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 8));

      if (_disposed || generation != _connectionGeneration) {
        await channel.sink.close();
        return;
      }

      _socketSubscription = channel.stream.listen(
        _handleMessage,
        onDone: () => _handleSocketClosed(generation),
        onError: (_) => _handleSocketClosed(generation),
        cancelOnError: true,
      );
      _isSocketConnected = true;
      _isConnectingSocket = false;
      _notify();
    } catch (_) {
      if (generation != _connectionGeneration || _disposed) {
        return;
      }
      await _closeSocket();
      _isSocketConnected = false;
      _isConnectingSocket = false;
      _scheduleReconnect(const Duration(seconds: 5));
      _notify();
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final message =
          json.decode(rawMessage.toString()) as Map<String, dynamic>;
      final payload = message['payload'];
      if (payload is! Map) {
        return;
      }

      final incoming = Map<String, dynamic>.from(payload);
      final incomingId = int.tryParse(incoming['id']?.toString() ?? '');
      if (incomingId == null || incomingId != _targetOrderId) {
        return;
      }

      final status = incoming['status']?.toString().trim().toUpperCase();
      final current = _trackedOrder;
      if (current == null || status == null || status.isEmpty) {
        return;
      }

      _trackedOrder = OrderModel.fromJson(incoming).copyWith(
        id: current.id,
        status: status,
        cafeId: incoming['cafe_id']?.toString() ?? current.cafeId,
        cafeName: incoming['cafe_name']?.toString() ?? current.cafeName,
        items: incoming['items'] is List
            ? OrderModel.fromJson(incoming).items
            : current.items,
      );
      _lastUpdatedAt = DateTime.now();
      _errorMessage = null;
      _isOffline = false;
      _isSocketConnected = true;
      _consecutivePollFailures = 0;

      if (_isTerminal(status)) {
        _stopLiveUpdates();
      }
      _notify();
    } catch (_) {
      // Polling remains the source of truth when a socket message is malformed.
    }
  }

  void _handleSocketClosed(int generation) {
    if (_disposed || generation != _connectionGeneration) {
      return;
    }
    _isSocketConnected = false;
    _isConnectingSocket = false;
    _notify();
    if (!_isOffline && _trackedOrder != null) {
      _scheduleReconnect(const Duration(seconds: 5));
    }
  }

  void _scheduleReconnect(Duration delay) {
    if (_disposed || _isOffline || _isSocketConnected) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && !_isOffline) {
        unawaited(_connectSocket());
      }
    });
  }

  void _startPollingIfNeeded() {
    final order = _trackedOrder;
    if (order != null && !_isTerminal(order.status)) {
      _startPolling(order.id);
    }
  }

  void _startPolling(int orderId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollTrackedOrder(orderId));
    });
  }

  Future<void> _pollTrackedOrder(int orderId) async {
    if (_disposed || _isPolling || _isOffline || orderId != _targetOrderId) {
      return;
    }
    _isPolling = true;
    try {
      final orders = await _apiService.getOrders();
      final latest = _resolveTrackedOrder(orders);
      if (latest != null && latest.id == orderId) {
        _trackedOrder = latest;
        _lastUpdatedAt = DateTime.now();
        _errorMessage = null;
        _isOffline = false;
        _consecutivePollFailures = 0;
        if (_isTerminal(latest.status)) {
          _stopLiveUpdates();
        }
        _notify();
      }
    } catch (error) {
      _consecutivePollFailures += 1;
      _errorMessage = error.toString();
      if (_consecutivePollFailures >= 2) {
        _isOffline = true;
        _isSocketConnected = false;
      }
      _notify();
    } finally {
      _isPolling = false;
    }
  }

  void _stopLiveUpdates() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isSocketConnected = false;
    _isConnectingSocket = false;
    _connectionGeneration += 1;
    unawaited(_closeSocket());
  }

  Future<void> _closeSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  bool _isTerminal(String status) {
    return const {'COMPLETED', 'CANCELLED'}
        .contains(status.trim().toUpperCase());
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pollingTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectionGeneration += 1;
    unawaited(_closeSocket());
    super.dispose();
  }
}
