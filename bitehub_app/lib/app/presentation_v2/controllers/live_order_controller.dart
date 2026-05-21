import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ???? ???? LiveOrderController ???? ???? ????? ???? ?? ???? ????.
class LiveOrderController extends ChangeNotifier {
  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService = ApiService();
  // ??? ??????? _connectivity ??? ?????? ???? ????? ????.
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription? _socketSubscription;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;

  bool _isLoading = true;
  bool _isOffline = false;
  bool _isSocketConnected = false;
  String? _errorMessage;
  OrderModel? _trackedOrder;

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isSocketConnected => _isSocketConnected;
  String? get errorMessage => _errorMessage;
  OrderModel? get trackedOrder => _trackedOrder;

  // ???? ???? initialize ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> initialize(
      {OrderModel? initialOrder, int? initialOrderId}) async {
    _trackedOrder = initialOrder;
    _connectivitySubscription ??=
        _connectivity.onConnectivityChanged.listen((results) {
      final offline =
          results.every((result) => result == ConnectivityResult.none);
      _isOffline = offline;
      notifyListeners();
      if (!offline && _trackedOrder != null && !_isSocketConnected) {
        _scheduleReconnect(const Duration(seconds: 1));
      }
    });

    await refresh(orderId: initialOrderId ?? initialOrder?.id);
  }

  // ???? ???? refresh ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> refresh({int? orderId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final orders = await _apiService.getOrders();
      _trackedOrder =
          _resolveTrackedOrder(orders, orderId ?? _trackedOrder?.id);
      _errorMessage = null;
      _isOffline = false;
      if (_trackedOrder != null) {
        await _connectSocket();
      }
    } catch (error) {
      _errorMessage = error.toString();
      _isOffline = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ???? ???? _resolveTrackedOrder ???? ??????? ?? ????? ???? ?????? ?????.
  OrderModel? _resolveTrackedOrder(List<OrderModel> orders, int? targetId) {
    if (orders.isEmpty) {
      return null;
    }
    if (targetId != null) {
      for (final order in orders) {
        if (order.id == targetId) {
          return order;
        }
      }
    }

    for (final order in orders) {
      if (!const {'COMPLETED', 'CANCELLED'}
          .contains(order.status.toUpperCase())) {
        return order;
      }
    }
    return orders.first;
  }

  // ???? ???? _connectSocket ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> _connectSocket() async {
    // ??? ??????? _trackedOrder ??? ?????? ???? ????? ????.
    final order = _trackedOrder;
    final cafeId = order?.cafeId;
    if (order == null || cafeId == null || cafeId.isEmpty) {
      return;
    }

    await _socketSubscription?.cancel();
    await _channel?.sink.close();

    final apiUri = Uri.parse(ApiService.baseUrl);
    final wsUri = apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/cafe/$cafeId/orders/',
      queryParameters: null,
    );

    _channel = WebSocketChannel.connect(wsUri);
    _socketSubscription = _channel!.stream.listen(
      _handleMessage,
      onDone: () {
        _isSocketConnected = false;
        notifyListeners();
        if (!_isOffline) {
          _scheduleReconnect(const Duration(seconds: 3));
        }
      },
      onError: (_) {
        _isSocketConnected = false;
        notifyListeners();
        if (!_isOffline) {
          _scheduleReconnect(const Duration(seconds: 3));
        }
      },
      cancelOnError: true,
    );

    _isSocketConnected = true;
    notifyListeners();
  }

  // ???? ???? _handleMessage ???? ??????? ?? ????? ???? ?????? ?????.
  void _handleMessage(dynamic rawMessage) {
    // ??? ??????? message ??? ?????? ???? ????? ????.
    final Map<String, dynamic> message =
        json.decode(rawMessage.toString()) as Map<String, dynamic>;
    final payload = message['payload'];
    if (payload is! Map<String, dynamic>) {
      return;
    }

    // ??? ??????? _trackedOrder ??? ?????? ???? ????? ????.
    final current = _trackedOrder;
    final incomingOrder = OrderModel.fromJson(payload);
    if (current == null || incomingOrder.id != current.id) {
      return;
    }

    _trackedOrder = incomingOrder;
    _isSocketConnected = true;
    notifyListeners();
  }

  // ???? ???? _scheduleReconnect ???? ??????? ?? ????? ???? ?????? ?????.
  void _scheduleReconnect(Duration delay) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isOffline && _trackedOrder != null) {
        unawaited(_connectSocket());
      }
    });
  }

  @override
  // ???? ???? dispose ???? ??????? ?? ????? ???? ?????? ?????.
  void dispose() {
    _reconnectTimer?.cancel();
    _connectivitySubscription?.cancel();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}


