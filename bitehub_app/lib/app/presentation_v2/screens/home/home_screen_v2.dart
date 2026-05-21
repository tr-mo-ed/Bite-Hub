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
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => HomeScreenV2State();
}

class HomeScreenV2State extends State<HomeScreenV2> {
  late final HomeV2Controller _controller;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _controller = HomeV2Controller();
    _searchController = TextEditingController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> selectCafeById(String cafeId) async {
    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      return;
    }

    final selectedMatches =
        _controller.colleges.where((cafe) => cafe.id == normalizedCafeId);
    if (selectedMatches.isNotEmpty) {
      await _controller.selectCafe(selectedMatches.first);
      return;
    }

    await _controller.refresh();
    final refreshedMatches =
        _controller.colleges.where((cafe) => cafe.id == normalizedCafeId);
    if (refreshedMatches.isNotEmpty) {
      await _controller.selectCafe(refreshedMatches.first);
    }
  }

  void _addToCart(ProductModel product) {
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
    final crossAxisCount = screenWidth >= 1120
        ? 4
        : screenWidth >= 760
            ? 3
            : 2;
    final childAspectRatio = screenWidth >= 760 ? .76 : .62;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isOffline && _controller.products.isEmpty) {
          return NetworkStatePanel(
            title: 'تعذر تحميل الواجهة الآن',
            message: _controller.errorMessage ??
                'تم فقدان الاتصال. سنحاول إعادة المزامنة عند عودة الإنترنت.',
            actionLabel: 'إعادة المحاولة',
            onRetry: _controller.refresh,
          );
        }

        final selectedCafeName =
            _controller.selectedCafe?.name ?? 'اختر المقهى';

        return DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.background),
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
                        _HomeOverview(
                          selectedCafe: _controller.selectedCafe,
                          cafeCount: _controller.colleges.length,
                          productCount: _controller.products.length,
                        ),
                        const SizedBox(height: BhSpacing.lg),
                        TextField(
                          controller: _searchController,
                          onChanged: _controller.searchProducts,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'ابحث عن منتج',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: BhSpacing.lg),
                        BhSectionHeader(
                          title: 'المقاهي',
                          subtitle: 'اختر المقهى ثم استعرض القائمة المتاحة',
                          trailing: BhStatusPill(
                            label: '${_controller.colleges.length}',
                            foreground: AppColors.brandBlue,
                            background: const Color(0xFFEFF6FF),
                          ),
                        ),
                        const SizedBox(height: BhSpacing.md),
                        _CafeSelector(
                          cafes: _controller.colleges,
                          selectedCafe: _controller.selectedCafe,
                          onSelect: _controller.selectCafe,
                        ),
                        const SizedBox(height: BhSpacing.xl),
                        BhSectionHeader(
                          title: selectedCafeName,
                          subtitle: 'القائمة الحالية',
                          trailing: BhStatusPill(
                            label:
                                '${_controller.filteredProducts.length} منتج',
                            foreground: AppColors.success,
                            background: const Color(0xFFE6F4F1),
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
                else if (_controller.filteredProducts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProductsState(
                      hasCafes: _controller.colleges.isNotEmpty,
                      selectedCafeName: _controller.selectedCafe?.name,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverGrid.builder(
                      itemCount: _controller.filteredProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: BhSpacing.md,
                        crossAxisSpacing: BhSpacing.md,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final product = _controller.filteredProducts[index];
                        return _ProductCard(
                          product: product,
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

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({
    required this.selectedCafe,
    required this.cafeCount,
    required this.productCount,
  });

  final CollegeModel? selectedCafe;
  final int cafeCount;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      padding: const EdgeInsets.all(BhSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.neutral50,
                  borderRadius: BorderRadius.circular(BhRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(width: BhSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bite Hub',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      selectedCafe?.name ?? 'اختر المقهى المناسب للطلب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BhSpacing.lg),
          Row(
            children: [
              BhMetric(
                label: 'مقهى',
                value: '$cafeCount',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(width: BhSpacing.sm),
              BhMetric(
                label: 'منتج',
                value: '$productCount',
                icon: Icons.restaurant_menu_outlined,
              ),
              const SizedBox(width: BhSpacing.sm),
              BhMetric(
                label: 'نشط',
                value: selectedCafe == null ? '0' : '1',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
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
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cafes.length,
        separatorBuilder: (_, __) => const SizedBox(width: BhSpacing.sm),
        itemBuilder: (context, index) {
          final cafe = cafes[index];
          final selected = selectedCafe?.id == cafe.id;
          return _CafeChip(
            cafe: cafe,
            selected: selected,
            onTap: () => onSelect(cafe),
          );
        },
      ),
    );
  }
}

class _CafeChip extends StatelessWidget {
  const _CafeChip({
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
      width: 188,
      child: BhSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(BhSpacing.md),
        borderColor: selected ? AppColors.brandBlue : AppColors.border,
        color: selected ? const Color(0xFFF8FBFF) : AppColors.surface,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEFF6FF) : AppColors.neutral50,
                borderRadius: BorderRadius.circular(BhRadius.sm),
              ),
              child: Icon(
                selected ? Icons.storefront_rounded : Icons.storefront_outlined,
                color: selected ? AppColors.brandBlue : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: BhSpacing.sm),
            Expanded(
              child: Text(
                cafe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.brandBlue : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
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
      height: 40,
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
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
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
    required this.onAddToCart,
  });

  final ProductModel product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final imagePath = product.getImageUrl();

    return BhSurface(
      padding: EdgeInsets.zero,
      radius: BhRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(BhRadius.md),
                    ),
                    child: ColoredBox(
                      color: AppColors.neutral100,
                      child: ProductImageView(
                        imagePath: imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                if (!product.isAvailable)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: BhStatusPill(
                      label: 'غير متاح',
                      foreground: AppColors.danger,
                      background: Color(0xFFFEE2E2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(BhSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${product.price.toStringAsFixed(2)} د.ل',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.brandBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 36,
                        child: IconButton.filled(
                          onPressed: product.isAvailable ? onAddToCart : null,
                          icon: const Icon(Icons.add_rounded, size: 19),
                          padding: EdgeInsets.zero,
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

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.hasCafes,
    required this.selectedCafeName,
  });

  final bool hasCafes;
  final String? selectedCafeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Center(
        child: BhSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.restaurant_menu_outlined,
                size: 42,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: BhSpacing.md),
              Text(
                hasCafes ? 'لا توجد منتجات حالياً' : 'لا توجد مقاهٍ متاحة',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedCafeName == null
                    ? 'عند توفر المقاهي ستظهر القوائم هنا.'
                    : 'لا توجد عناصر مطابقة في $selectedCafeName.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
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
