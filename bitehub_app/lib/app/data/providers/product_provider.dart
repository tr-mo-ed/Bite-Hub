import 'package:flutter/material.dart';
import 'package:bitehub_app/app/core/enums/view_state.dart';
import 'package:bitehub_app/app/data/models/product_model.dart'; // ✅ المودل الجديد
import 'package:bitehub_app/app/data/services/api_service.dart';

// ???? ???? ProductProvider ???? ???? ????? ???? ?? ???? ????.
class ProductProvider extends ChangeNotifier {
  // ??? ??????? allCategoryLabel ??? ?????? ???? ????? ????.
  static const String allCategoryLabel = 'الكل';
  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService = ApiService();

  ViewState _state = ViewState.idle;
  String? _errorMessage;
  List<ProductModel> _allProducts = []; // ✅ استخدام ProductModel
  String? _selectedCategory;
  String _searchQuery = '';

  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<ProductModel> get products => filteredProducts;

  List<ProductModel> get filteredProducts {
    Iterable<ProductModel> filtered = _allProducts;

    // منطق الفلترة حسب التصنيف
    final isAllCategory = _selectedCategory == null ||
        _selectedCategory == allCategoryLabel ||
        _selectedCategory == 'all';

    if (!isAllCategory) {
      filtered = filtered.where((p) => p.category == _selectedCategory);
    }

    // منطق البحث المحسن
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where(
        (p) =>
            p.name.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query) ||
            // ✅ استخدام الحقول الجديدة من المودل
            p.cafeName.toLowerCase().contains(query) ||
            p.collegeName.toLowerCase().contains(query),
      );
    }
    return filtered.toList();
  }

  // ???? ???? fetchAllProducts ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> fetchAllProducts() async {
    _errorMessage = null;
    _setState(ViewState.busy);
    try {
      _allProducts = await _apiService.getProducts();
      _setState(ViewState.retrieved);
    } catch (e) {
      _errorMessage = 'تعذر تحميل المنتجات. تأكد من الإنترنت ثم حاول مرة أخرى.';
      _setState(ViewState.error);
    }
  }

  // ???? ???? toggleFavorite ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> toggleFavorite(String productId) async {
    final index = _allProducts.indexWhere(
      (p) => p.id.toString() == productId.toString(),
    );
    if (index != -1) {
      // ✅ تعديل حالة المفضلة
      _allProducts[index].isFavorite = !_allProducts[index].isFavorite;
      notifyListeners();
    }
  }

  // ???? ???? filterByCategory ???? ??????? ?? ????? ???? ?????? ?????.
  void filterByCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // ???? ???? updateSearchQuery ???? ??????? ?? ????? ???? ?????? ?????.
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<String> get availableCategories {
    final categories = _allProducts
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    categories.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    return categories;
  }

  // ???? ???? _setState ???? ??????? ?? ????? ???? ?????? ?????.
  void _setState(ViewState newState) {
    _state = newState;
    notifyListeners();
  }
}
