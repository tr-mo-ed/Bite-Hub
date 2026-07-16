import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:bitehub_app/app/data/models/college_model.dart';
import 'package:bitehub_app/app/data/models/product_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

// ???? ???? HomeV2Controller ???? ???? ????? ???? ?? ???? ????.
class HomeV2Controller extends ChangeNotifier {
  HomeV2Controller({
    ApiService? apiService,
    Connectivity? connectivity,
  })  : _apiService = apiService ?? ApiService(),
        _connectivity = connectivity ?? Connectivity();

  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService;
  // ??? ??????? _connectivity ??? ?????? ???? ????? ????.
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isLoading = true;
  bool _isOffline = false;
  String? _errorMessage;
  List<CollegeModel> _cafes = [];
  List<ProductModel> _products = [];
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  CollegeModel? _selectedCafe;

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  List<CollegeModel> get cafes => _cafes;
  List<ProductModel> get products => _products;
  List<CollegeModel> get colleges => _cafes;
  CollegeModel? get selectedCafe => _selectedCafe;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<String> get categories {
    final values = _products
        .map((product) => product.category)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['الكل', ...values];
  }

  List<ProductModel> get featuredProducts => _products.take(5).toList();

  List<ProductModel> get filteredProducts {
    var filtered = _products.where(
      (product) =>
          _selectedCategory == 'الكل' || product.category == _selectedCategory,
    );

    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      filtered = filtered.where(
        (product) => product.name.toLowerCase().contains(normalizedQuery),
      );
    }

    return filtered.toList();
  }

  @visibleForTesting
  void seedPreview({
    required List<CollegeModel> cafes,
    required CollegeModel selectedCafe,
    required List<ProductModel> products,
  }) {
    _cafes = cafes;
    _selectedCafe = selectedCafe;
    _products = products;
    _isLoading = false;
    _isOffline = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ???? ???? initialize ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> initialize() async {
    _connectivitySubscription ??=
        _connectivity.onConnectivityChanged.listen((results) {
      _isOffline = results.every((result) => result == ConnectivityResult.none);
      notifyListeners();
      if (!_isOffline && _cafes.isEmpty) {
        unawaited(refresh());
      }
    });
    await refresh();
  }

  // ???? ???? refresh ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final cafes = await _apiService.getCafes();
      final selectedCafeId = _selectedCafe?.id;
      _cafes = cafes;
      CollegeModel? refreshedSelection;
      if (selectedCafeId != null) {
        for (final cafe in cafes) {
          if (cafe.id == selectedCafeId) {
            refreshedSelection = cafe;
            break;
          }
        }
      }
      _selectedCafe = refreshedSelection;
      if (_selectedCafe != null) {
        _products = await _apiService.getProducts(cafeId: _selectedCafe!.id);
      } else {
        _products = [];
      }
      _isOffline = false;
    } catch (_) {
      if (!silent || _products.isEmpty) {
        _errorMessage =
            'تعذر تحميل المقاهي والمنتجات. تأكد من الإنترنت ثم حاول مرة أخرى.';
        _isOffline = true;
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // ???? ???? selectCafe ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> selectCafe(CollegeModel cafe) async {
    if (_selectedCafe?.id == cafe.id) {
      return;
    }

    _selectedCafe = cafe;
    _selectedCategory = 'الكل';
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _apiService.getProducts(cafeId: cafe.id);
      _errorMessage = null;
      _isOffline = false;
    } catch (_) {
      _errorMessage = 'تعذر تحميل منتجات هذا المقهى. حاول مرة أخرى.';
      _isOffline = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ???? ???? selectCategory ???? ??????? ?? ????? ???? ?????? ?????.
  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // ???? ???? searchProducts ???? ??????? ?? ????? ???? ?????? ?????.
  void searchProducts(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  @override
  // ???? ???? dispose ???? ??????? ?? ????? ???? ?????? ?????.
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
