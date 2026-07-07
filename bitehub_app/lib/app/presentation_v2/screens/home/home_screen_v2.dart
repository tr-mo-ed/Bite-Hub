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

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? HomeV2Controller();
    _searchController = TextEditingController();
    if (widget.initializeController) {
      _controller.initialize();
    }
  }

  @override
  void dispose() {
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
      _showMessage('المقهى مغلق حاليًا ولا يستقبل طلبات جديدة');
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
    final cartCount = context.watch<CartProvider>().itemCount;

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
                          cafe: selectedCafe,
                          productCount: _controller.products.length,
                          cafeCount: _controller.colleges.length,
                          cartCount: cartCount,
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
                            background: const Color(0xFFEAF4EF),
                            icon: Icons.storefront_outlined,
                          ),
                        ),
                        const SizedBox(height: BhSpacing.sm),
                        _CafeSelector(
                          cafes: _controller.colleges,
                          selectedCafe: selectedCafe,
                          onSelect: _controller.selectCafe,
                        ),
                        if (selectedCafe != null &&
                            !selectedCafe.canAcceptOrders) ...[
                          const SizedBox(height: BhSpacing.md),
                          _CafeClosedNotice(cafeName: selectedCafe.name),
                        ],
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
    required this.cafe,
    required this.productCount,
    required this.cafeCount,
    required this.cartCount,
    required this.searchController,
    required this.hasSearchText,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final CollegeModel? cafe;
  final int productCount;
  final int cafeCount;
  final int cartCount;
  final TextEditingController searchController;
  final bool hasSearchText;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final cafeName = cafe?.name ?? 'اختر المقهى';
    final subtitle = cafe == null
        ? 'حدد المقهى وشوف المنيو مباشرة'
        : 'منيو سريع، واضح، وجاهز للطلب';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF123E36),
            Color(0xFF167C68),
            Color(0xFF42A88F),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: .24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -34,
            end: -26,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .10),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 18,
            start: -42,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandGold.withValues(alpha: .16),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CafeAvatar(
                    cafe: cafe,
                    size: 56,
                    selected: cafe != null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bite Hub',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .76),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cafeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .82),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeroCartBadge(cartCount: cartCount),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroMetric(
                      icon: Icons.storefront_rounded,
                      value: '$cafeCount',
                      label: 'مقهى',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroMetric(
                      icon: Icons.restaurant_menu_rounded,
                      value: '$productCount',
                      label: 'منتج',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: _HeroMetric(
                      icon: Icons.flash_on_rounded,
                      value: 'سريع',
                      label: 'طلبك',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SearchField(
                controller: searchController,
                hasText: hasSearchText,
                onChanged: onSearchChanged,
                onClear: onClearSearch,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCartBadge extends StatelessWidget {
  const _HeroCartBadge({required this.cartCount});

  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .20)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(
            child: Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          if (cartCount > 0)
            PositionedDirectional(
              top: -5,
              end: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandGold,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$cartCount',
                  style: const TextStyle(
                    color: AppColors.brandNavy,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
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
                  ? const Color(0xFFEAF4EF)
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

class _CafeClosedNotice extends StatelessWidget {
  const _CafeClosedNotice({required this.cafeName});

  final String cafeName;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      borderColor: const Color(0xFFFEE2E2),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cafeName مغلق حاليًا',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يمكنك تصفح القائمة، لكن إنشاء الطلبات متوقف إلى أن يفتح المقهى استقبال الطلبات.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
      height: 94,
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
      width: 158,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE9F7F3) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? AppColors.brandBlue : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandNavy.withValues(
                    alpha: selected ? .12 : .055,
                  ),
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _CafeAvatar(
                  cafe: cafe,
                  size: 46,
                  selected: selected,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cafe.name,
                        maxLines: cafe.canAcceptOrders ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AppColors.brandBlue
                              : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      if (!cafe.canAcceptOrders) ...[
                        const SizedBox(height: 5),
                        const _SmallBadge(
                          label: 'مغلق',
                          foreground: AppColors.danger,
                          background: Color(0xFFFEE2E2),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.brandBlue,
                    size: 18,
                  ),
                ],
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
    final initials = _cafeInitials(cafe?.name ?? 'Bite Hub');

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
            ? _CafeInitials(initials: initials)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _CafeInitials(initials: initials),
              ),
      ),
    );
  }
}

class _CafeInitials extends StatelessWidget {
  const _CafeInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFF4FF),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.brandBlue,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _cafeInitials(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty && word != 'مقهى')
      .toList();
  if (words.isEmpty) {
    return 'BH';
  }
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length >= 2 ? 2 : 1);
  }
  return '${words.first[0]}${words.last[0]}';
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
            selectedColor: const Color(0xFFE9F7F3),
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
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 9,
                  start: 9,
                  child: _SmallBadge(
                    label: !canAcceptOrders
                        ? 'المقهى مغلق'
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
    final title = !hasCafes
        ? 'لا توجد مقاهٍ متاحة'
        : isSearching
            ? 'لا توجد نتائج مطابقة'
            : 'لا توجد منتجات حالياً';
    final message = !hasCafes
        ? 'ستظهر المقاهي هنا عند تفعيلها.'
        : isSearching
            ? 'جرب كلمة بحث أخرى أو اختر تصنيفاً مختلفاً.'
            : 'لم يضف ${selectedCafeName ?? 'المقهى'} منتجات متاحة بعد.';

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
                  color: const Color(0xFFEAF4EF),
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
