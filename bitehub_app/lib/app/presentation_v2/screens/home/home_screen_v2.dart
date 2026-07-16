import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/college_model.dart';
import 'package:bitehub_app/app/data/models/product_model.dart';
import 'package:bitehub_app/app/data/providers/cart_provider.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/home_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/product_image_view.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/product_skeleton_grid.dart';

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({
    super.key,
    this.controller,
    this.initializeController = true,
  });

  final HomeV2Controller? controller;
  final bool initializeController;

  @override
  State<HomeScreenV2> createState() => HomeScreenV2State();
}

class HomeScreenV2State extends State<HomeScreenV2> {
  late final HomeV2Controller _controller;
  late final TextEditingController _searchController;
  late final bool _ownsController;
  Timer? _stockRefreshTimer;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? HomeV2Controller();
    _searchController = TextEditingController();
    if (widget.initializeController) {
      _controller.initialize();
      _stockRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (!mounted || _controller.selectedCafe == null) {
          return;
        }
        unawaited(_controller.refresh(silent: true));
      });
    }
  }

  @override
  void dispose() {
    _stockRefreshTimer?.cancel();
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> selectCafeById(String cafeId) async {
    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      return;
    }

    for (final cafe in _controller.colleges) {
      if (cafe.id == normalizedCafeId) {
        await _controller.selectCafe(cafe);
        return;
      }
    }

    await _controller.refresh();
    for (final cafe in _controller.colleges) {
      if (cafe.id == normalizedCafeId) {
        await _controller.selectCafe(cafe);
        return;
      }
    }
  }

  Future<void> refresh() => _controller.refresh();

  void _clearSearch() {
    _searchController.clear();
    _controller.searchProducts('');
  }

  void _addToCart(ProductModel product) {
    final selectedCafe = _controller.selectedCafe;
    if (selectedCafe != null && !selectedCafe.canAcceptOrders) {
      _showMessage('مغلق');
      return;
    }

    if (!product.isAvailable) {
      _showMessage('هذا المنتج غير متاح حالياً');
      return;
    }

    try {
      context.read<CartProvider>().addItem(product);
      _showMessage('تمت إضافة ${product.name} إلى السلة');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth >= 1080
        ? 4
        : screenWidth >= 720
            ? 3
            : 2;
    final productCardExtent = screenWidth < 390 ? 268.0 : 278.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isOffline && _controller.products.isEmpty) {
          return NetworkStatePanel(
            title: 'تعذر تحميل القائمة',
            message: _controller.errorMessage ??
                'تأكد من اتصال الإنترنت ثم حاول مرة أخرى.',
            actionLabel: 'إعادة المحاولة',
            onRetry: _controller.refresh,
          );
        }

        final selectedCafe = _controller.selectedCafe;
        final visibleProducts = _controller.filteredProducts;

        return ColoredBox(
          color: AppColors.background,
          child: RefreshIndicator(
            color: AppColors.brandBlue,
            onRefresh: _controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHero(
                          searchController: _searchController,
                          hasSearchText:
                              _searchController.text.trim().isNotEmpty,
                          onSearchChanged: _controller.searchProducts,
                          onClearSearch: _clearSearch,
                        ),
                        if (_controller.isOffline) ...[
                          const SizedBox(height: BhSpacing.sm),
                          const _OfflineNotice(),
                        ],
                        const SizedBox(height: BhSpacing.lg),
                        BhSectionHeader(
                          title: 'اختر المقهى',
                          subtitle: 'حدد المقهى لعرض قائمته وأسعاره',
                          trailing: BhStatusPill(
                            label: '${_controller.colleges.length}',
                            foreground: AppColors.brandBlue,
                            background: const Color(0xFFEFF6FF),
                            icon: Icons.storefront_outlined,
                          ),
                        ),
                        const SizedBox(height: BhSpacing.sm),
                        _CafeSelector(
                          cafes: _controller.colleges,
                          selectedCafe: selectedCafe,
                          onSelect: _controller.selectCafe,
                        ),
                        const SizedBox(height: BhSpacing.lg),
                        BhSectionHeader(
                          title: selectedCafe?.name ?? 'قائمة المنتجات',
                          subtitle: _controller.searchQuery.trim().isEmpty
                              ? 'اختر الصنف وأضفه مباشرة إلى السلة'
                              : 'نتائج البحث في قائمة المقهى',
                          trailing: BhStatusPill(
                            label: '${visibleProducts.length} منتج',
                            foreground: AppColors.success,
                            background: const Color(0xFFE6F4F1),
                            icon: Icons.restaurant_menu_outlined,
                          ),
                        ),
                        const SizedBox(height: BhSpacing.md),
                        _CategoryStrip(
                          categories: _controller.categories,
                          selectedCategory: _controller.selectedCategory,
                          onSelect: _controller.selectCategory,
                        ),
                        const SizedBox(height: BhSpacing.lg),
                      ],
                    ),
                  ),
                ),
                if (_controller.isLoading)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverToBoxAdapter(child: ProductSkeletonGrid()),
                  )
                else if (visibleProducts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProductsState(
                      hasCafes: _controller.colleges.isNotEmpty,
                      selectedCafeName: selectedCafe?.name,
                      isSearching: _controller.searchQuery.trim().isNotEmpty,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverGrid.builder(
                      itemCount: visibleProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: BhSpacing.md,
                        crossAxisSpacing: BhSpacing.md,
                        mainAxisExtent: productCardExtent,
                      ),
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        return _ProductCard(
                          product: product,
                          canAcceptOrders:
                              selectedCafe?.canAcceptOrders ?? true,
                          onAddToCart: () => _addToCart(product),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.searchController,
    required this.hasSearchText,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final bool hasSearchText;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return _SearchField(
      controller: searchController,
      hasText: hasSearchText,
      onChanged: onSearchChanged,
      onClear: onClearSearch,
      compact: true,
    );
  }
}

// ignore: unused_element
class _SelectedCafeHeader extends StatelessWidget {
  const _SelectedCafeHeader({
    required this.cafe,
    required this.productCount,
    required this.cartCount,
  });

  final CollegeModel? cafe;
  final int productCount;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          _CafeAvatar(
            cafe: cafe,
            size: 72,
            selected: cafe != null,
          ),
          const SizedBox(width: BhSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تطلب الآن من',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cafe?.name ?? 'اختر المقهى',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cafe == null
                      ? 'حدد المقهى لعرض المنتجات'
                      : '$productCount منتج في القائمة',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BhSpacing.sm),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: cartCount > 0
                  ? const Color(0xFFEFF6FF)
                  : AppColors.neutral100,
              borderRadius: BorderRadius.circular(BhRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: cartCount > 0
                      ? AppColors.brandBlue
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  '$cartCount',
                  style: TextStyle(
                    color: cartCount > 0
                        ? AppColors.brandBlue
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CafeSelector extends StatelessWidget {
  const _CafeSelector({
    required this.cafes,
    required this.selectedCafe,
    required this.onSelect,
  });

  final List<CollegeModel> cafes;
  final CollegeModel? selectedCafe;
  final ValueChanged<CollegeModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (cafes.isEmpty) {
      return const BhSurface(
        child: Text(
          'لا توجد مقاهٍ متاحة حالياً',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cafes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cafe = cafes[index];
          return _CafeCard(
            cafe: cafe,
            selected: selectedCafe?.id == cafe.id,
            onTap: () => onSelect(cafe),
          );
        },
      ),
    );
  }
}

class _CafeCard extends StatelessWidget {
  const _CafeCard({
    required this.cafe,
    required this.selected,
    required this.onTap,
  });

  final CollegeModel cafe;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _CafeAvatar(
                      cafe: cafe,
                      size: selected ? 70 : 66,
                      selected: selected,
                    ),
                    if (selected)
                      const PositionedDirectional(
                        top: -2,
                        start: -2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.brandBlue,
                            size: 21,
                          ),
                        ),
                      ),
                    if (!cafe.canAcceptOrders)
                      const PositionedDirectional(
                        bottom: -5,
                        start: 0,
                        end: 0,
                        child: Center(
                          child: _SmallBadge(
                            label: 'مغلق',
                            foreground: AppColors.danger,
                            background: Color(0xFFFEE2E2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                  cafe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        selected ? AppColors.brandBlue : AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CafeAvatar extends StatelessWidget {
  const _CafeAvatar({
    required this.cafe,
    required this.size,
    required this.selected,
  });

  final CollegeModel? cafe;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final imageUrl = cafe?.image?.trim() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 3 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: selected ? AppColors.brandBlue : const Color(0xFFD8E4F7),
          width: selected ? 2.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: selected ? .13 : .06),
            blurRadius: selected ? 16 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? const _CafeImagePlaceholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                gaplessPlayback: true,
                cacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return const _CafeImagePlaceholder(isLoading: true);
                },
                errorBuilder: (_, __, ___) => const _CafeImagePlaceholder(),
              ),
      ),
    );
  }
}

class _CafeImagePlaceholder extends StatelessWidget {
  const _CafeImagePlaceholder({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 12 : 15,
        ),
        hintText: 'ابحث عن وجبة أو مشروب',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.brandBlue,
        ),
        suffixIcon: hasText
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'مسح البحث',
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 18 : BhRadius.md),
          borderSide: BorderSide(
            color: compact ? Colors.transparent : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 18 : BhRadius.md),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.3),
        ),
      ),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(category),
            onSelected: (_) => onSelect(category),
            selectedColor: const Color(0xFFEFF6FF),
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.brandBlue : AppColors.border,
            ),
            labelStyle: TextStyle(
              color: selected ? AppColors.brandBlue : AppColors.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canAcceptOrders,
    required this.onAddToCart,
  });

  final ProductModel product;
  final bool canAcceptOrders;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.hasDiscount && product.originalPrice != null;
    final canAddToCart = product.isAvailable && canAcceptOrders;

    return BhSurface(
      padding: EdgeInsets.zero,
      radius: 24,
      borderColor: const Color(0xFFE4ECE8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(23),
                    ),
                    child: ColoredBox(
                      color: AppColors.neutral100,
                      child: ProductImageView(
                        imagePath: product.getImageUrl(),
                        fit: BoxFit.cover,
                        fallback: const _FoodImageFallback(),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 9,
                  start: 9,
                  child: _SmallBadge(
                    label: !canAcceptOrders
                        ? 'مغلق'
                        : product.isAvailable
                            ? 'متاح'
                            : 'غير متاح',
                    foreground:
                        canAddToCart ? AppColors.success : AppColors.danger,
                    background: canAddToCart
                        ? const Color(0xFFE6F4F1)
                        : const Color(0xFFFEE2E2),
                  ),
                ),
                if (hasDiscount)
                  PositionedDirectional(
                    top: 9,
                    end: 9,
                    child: _SmallBadge(
                      label: '-${product.discountPercentage}%',
                      foreground: AppColors.warning,
                      background: const Color(0xFFFFF7E6),
                    ),
                  ),
                if (!canAddToCart)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .52),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(23),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  if (product.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _PriceBlock(
                          price: product.price,
                          originalPrice:
                              hasDiscount ? product.originalPrice : null,
                        ),
                      ),
                      SizedBox.square(
                        dimension: 36,
                        child: IconButton.filled(
                          onPressed: canAddToCart ? onAddToCart : null,
                          icon: const Icon(Icons.add_rounded, size: 21),
                          padding: EdgeInsets.zero,
                          tooltip: 'إضافة إلى السلة',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.brandBlue,
                            disabledBackgroundColor: AppColors.neutral100,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(BhRadius.sm),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodImageFallback extends StatelessWidget {
  const _FoodImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFFFFBEB),
            Color(0xFFEFF6FF),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_outlined,
          color: AppColors.brandBlue,
          size: 32,
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.price,
    required this.originalPrice,
  });

  final double price;
  final double? originalPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${price.toStringAsFixed(2)} د.ل',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.brandBlue,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        if (originalPrice != null)
          Text(
            '${originalPrice!.toStringAsFixed(2)} د.ل',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(BhRadius.sm),
        border: Border.all(color: const Color(0xFFF6D7A5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 17, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تعذر تحديث البيانات. يتم عرض آخر قائمة متاحة.',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.hasCafes,
    required this.selectedCafeName,
    required this.isSearching,
  });

  final bool hasCafes;
  final String? selectedCafeName;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final hasSelectedCafe = (selectedCafeName ?? '').trim().isNotEmpty;
    final title = !hasCafes
        ? 'لا توجد مقاهٍ متاحة'
        : !hasSelectedCafe
            ? 'اختر مقهى أولاً'
            : isSearching
                ? 'لا توجد نتائج مطابقة'
                : 'لا توجد منتجات حالياً';
    final message = !hasCafes
        ? 'ستظهر المقاهي هنا عند تفعيلها.'
        : !hasSelectedCafe
            ? 'اختر صورة المقهى من الأعلى لعرض قائمته وأسعاره.'
            : isSearching
                ? 'جرب كلمة بحث أخرى أو اختر تصنيفاً مختلفاً.'
                : 'لم يضف $selectedCafeName منتجات متاحة بعد.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Center(
        child: BhSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(BhRadius.md),
                ),
                child: const Icon(
                  Icons.restaurant_menu_outlined,
                  size: 28,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: BhSpacing.md),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
