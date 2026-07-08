import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/presentation_v2/screens/orders/live_order_tracking_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/order_status_ui.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/product_image_view.dart';

class OrdersScreenV2 extends StatefulWidget {
  const OrdersScreenV2({super.key});

  @override
  State<OrdersScreenV2> createState() => _OrdersScreenV2State();
}

class _OrdersScreenV2State extends State<OrdersScreenV2> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<OrderModel> _orders = const [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final notificationProvider = context.read<NotificationProvider>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _apiService.getOrders();
      await notificationProvider.refreshFromOrders(orders);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = orders;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _orders.isEmpty) {
      return NetworkStatePanel(
        title: 'تعذر تحميل الطلبات',
        message: _errorMessage!,
        actionLabel: 'إعادة التحميل',
        onRetry: _loadOrders,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: RefreshIndicator(
        color: AppColors.brandBlue,
        onRefresh: _loadOrders,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _OrdersSummary(orders: _orders),
            const SizedBox(height: BhSpacing.lg),
            const BhSectionHeader(
              title: 'سجل الطلبات',
              subtitle: 'تابع الطلبات الحالية وراجع الطلبات السابقة',
            ),
            const SizedBox(height: BhSpacing.md),
            if (_isLoading)
              const _OrdersLoadingState()
            else if (_orders.isEmpty)
              const _OrdersEmptyState()
            else
              ..._orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: BhSpacing.md),
                  child: _OrderRow(order: order),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrdersSummary extends StatelessWidget {
  const _OrdersSummary({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final live = orders.where((order) => _isLiveStatus(order.status)).length;
    final done = orders
        .where((order) => order.status.toUpperCase() == 'COMPLETED')
        .length;

    return BhSurface(
      padding: const EdgeInsets.all(BhSpacing.sm),
      radius: BhRadius.sm,
      child: Row(
        children: [
          _CompactOrderMetric(
            label: 'الإجمالي',
            value: '${orders.length}',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(width: BhSpacing.xs),
          _CompactOrderMetric(
            label: 'قيد التنفيذ',
            value: '$live',
            icon: Icons.timelapse_rounded,
          ),
          const SizedBox(width: BhSpacing.xs),
          _CompactOrderMetric(
            label: 'مكتمل',
            value: '$done',
            icon: Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final visual = BhOrderStatusSpec.fromStatus(order.status);
    final isLive = _isLiveStatus(order.status);

    return BhSurface(
      padding: const EdgeInsets.all(BhSpacing.sm),
      radius: BhRadius.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OrderPreviewImage(order: order),
              const SizedBox(width: BhSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${order.displayOrderCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.displayCafeName.isEmpty
                          ? 'Bite Hub'
                          : order.displayCafeName,
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
              BhStatusPill(
                label: _statusLabel(order.status),
                foreground: visual.foregroundColor,
                background: visual.backgroundColor,
              ),
            ],
          ),
          const SizedBox(height: BhSpacing.sm),
          Row(
            children: [
              _InlineMeta(
                icon: Icons.payments_outlined,
                value: '${order.totalPrice.toStringAsFixed(2)} د.ل',
              ),
              const SizedBox(width: 12),
              _InlineMeta(
                icon: Icons.shopping_bag_outlined,
                value: '${order.items.length} عناصر',
              ),
              const Spacer(),
              Text(
                _formatDate(order.dateObject),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: BhSpacing.sm),
            Text(
              order.items
                  .take(3)
                  .map((item) => '${item.quantity}x ${item.productName}')
                  .join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: BhSpacing.sm),
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveOrderTrackingScreenV2(
                        initialOrder: order,
                        initialOrderId: order.id,
                      ),
                    ),
                  );
                },
                icon: Icon(
                  isLive
                      ? Icons.location_searching_rounded
                      : Icons.receipt_long_rounded,
                  size: 18,
                ),
                label: Text(isLive ? 'تتبع الطلب' : 'عرض الطلب'),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      isLive ? AppColors.brandBlue : const Color(0xFFEFF4FF),
                  foregroundColor: isLive ? Colors.white : AppColors.brandBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BhRadius.sm),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderPreviewImage extends StatelessWidget {
  const _OrderPreviewImage({required this.order});

  final OrderModel order;

  String get _imagePath {
    for (final item in order.items) {
      final image = item.productImage?.trim() ?? '';
      if (image.isNotEmpty) {
        return image;
      }
    }
    return order.cafeLogo?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final visual = BhOrderStatusSpec.fromStatus(order.status);

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: ProductImageView(
                  imagePath: _imagePath,
                  fit: BoxFit.cover,
                  fallback: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Color(0xFFEFF6FF),
                          Colors.white,
                          Color(0xFFFFF7D6),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: AppColors.brandBlue,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: -3,
            bottom: -3,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                visual.icon,
                color: visual.foregroundColor,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactOrderMetric extends StatelessWidget {
  const _CompactOrderMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.brandBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: BhSpacing.md),
          child: BhSurface(
            child: SizedBox(height: 86),
          ),
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    return const BhSurface(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: BhSpacing.md),
          Text(
            'لا توجد طلبات حتى الآن',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عندما تقوم بأول طلب سيظهر هنا مع حالته وتفاصيله.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isLiveStatus(String status) {
  return BhOrderStatusSpec.fromStatus(status).isLive;
}

String _statusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'قيد المراجعة';
    case 'ACCEPTED':
      return 'مقبول';
    case 'PREPARING':
      return 'قيد التحضير';
    case 'READY':
      return 'جاهز';
    case 'COMPLETED':
      return 'مكتمل';
    case 'CANCELLED':
      return 'ملغى';
    default:
      return status;
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
