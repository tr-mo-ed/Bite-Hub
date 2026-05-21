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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BhSectionHeader(
            title: 'الطلبات',
            subtitle: 'نظرة مختصرة على نشاطك داخل Bite Hub',
          ),
          const SizedBox(height: BhSpacing.lg),
          Row(
            children: [
              BhMetric(
                label: 'الإجمالي',
                value: '${orders.length}',
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(width: BhSpacing.sm),
              BhMetric(
                label: 'قيد التنفيذ',
                value: '$live',
                icon: Icons.timelapse_rounded,
              ),
              const SizedBox(width: BhSpacing.sm),
              BhMetric(
                label: 'مكتمل',
                value: '$done',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
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
      padding: const EdgeInsets.all(BhSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.backgroundColor,
                  borderRadius: BorderRadius.circular(BhRadius.sm),
                ),
                child: Icon(visual.icon, color: visual.foregroundColor),
              ),
              const SizedBox(width: BhSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${order.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
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
          const SizedBox(height: BhSpacing.md),
          Container(
            padding: const EdgeInsets.all(BhSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(BhRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _MetaItem(
                  label: 'الإجمالي',
                  value: '${order.totalPrice.toStringAsFixed(2)} د.ل',
                ),
                _MetaDivider(),
                _MetaItem(label: 'العناصر', value: '${order.items.length}'),
                _MetaDivider(),
                _MetaItem(
                    label: 'التاريخ', value: _formatDate(order.dateObject)),
              ],
            ),
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: BhSpacing.md),
            Text(
              order.items
                  .take(3)
                  .map((item) => '${item.quantity}x ${item.productName}')
                  .join('  •  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: BhSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateTime(order.dateObject),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isLive)
                OutlinedButton.icon(
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
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: const Text('تتبع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(color: AppColors.border),
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

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: BhSpacing.sm),
      color: AppColors.border,
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_formatDate(local)}  ${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
