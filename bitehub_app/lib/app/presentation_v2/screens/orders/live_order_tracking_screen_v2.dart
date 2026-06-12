import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/live_order_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/custom_floating_snack_bar.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/order_status_ui.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/product_image_view.dart';

class LiveOrderTrackingScreenV2 extends StatefulWidget {
  const LiveOrderTrackingScreenV2({
    super.key,
    this.initialOrder,
    this.initialOrderId,
    this.controller,
    this.initializeController = true,
  });

  final OrderModel? initialOrder;
  final int? initialOrderId;
  final LiveOrderController? controller;
  final bool initializeController;

  @override
  State<LiveOrderTrackingScreenV2> createState() =>
      _LiveOrderTrackingScreenV2State();
}

class _LiveOrderTrackingScreenV2State extends State<LiveOrderTrackingScreenV2> {
  late final LiveOrderController _controller;
  final ApiService _apiService = ApiService();
  bool _isCancelling = false;
  String? _lastAnnouncedStatus;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? LiveOrderController();
    if (widget.initializeController) {
      _controller.initialize(
        initialOrder: widget.initialOrder,
        initialOrderId: widget.initialOrderId,
      );
    }
    _lastAnnouncedStatus = widget.initialOrder?.status.toUpperCase();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final order = _controller.trackedOrder;

        if (_controller.isOffline && order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تتبع الطلب')),
            body: NetworkStatePanel(
              title: 'تعذر تحميل الطلب',
              message: _controller.errorMessage ??
                  'لا يوجد اتصال بالشبكة حالياً. حاول مرة أخرى عند عودة الإنترنت.',
              actionLabel: 'إعادة المحاولة',
              onRetry: _controller.refresh,
            ),
          );
        }

        if (_controller.isLoading && order == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تتبع الطلب')),
            body: const _MissingOrderState(),
          );
        }

        final status = BhOrderStatusSpec.fromStatus(order.status);
        _announceStatusIfNeeded(order);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('الطلب #${order.displayOrderCode}'),
            actions: [
              IconButton(
                onPressed: _controller.isRefreshing
                    ? null
                    : () => _controller.refresh(
                          orderId: order.id,
                          silent: true,
                        ),
                tooltip: 'تحديث الحالة',
                icon: _controller.isRefreshing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.brandBlue,
            onRefresh: () => _controller.refresh(
              orderId: order.id,
              silent: true,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: [
                _OrderIdentityCard(order: order, status: status),
                const SizedBox(height: BhSpacing.md),
                _SyncStatusStrip(
                  state: _controller.syncState,
                  lastUpdatedAt: _controller.lastUpdatedAt,
                ),
                const SizedBox(height: BhSpacing.md),
                _CurrentStatusCard(status: status),
                const SizedBox(height: BhSpacing.md),
                if (status.isCancelled)
                  const _CancelledOrderPanel()
                else
                  _OrderTimeline(status: status),
                const SizedBox(height: BhSpacing.md),
                _OrderDetailsCard(order: order),
                if (_canCancel(order.status)) ...[
                  const SizedBox(height: BhSpacing.md),
                  _CancelOrderButton(
                    isLoading: _isCancelling,
                    onPressed: () => _confirmCancelOrder(order),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _announceStatusIfNeeded(OrderModel order) {
    final currentStatus = order.status.toUpperCase();
    if (_lastAnnouncedStatus == null) {
      _lastAnnouncedStatus = currentStatus;
      return;
    }
    if (_lastAnnouncedStatus == currentStatus) {
      return;
    }
    _lastAnnouncedStatus = currentStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final style = BhOrderStatusSpec.fromStatus(currentStatus);
      CustomFloatingSnackBar.show(
        context,
        title: style.title,
        message: style.description,
        icon: style.icon,
        accentColor: style.foregroundColor,
      );
    });
  }

  bool _canCancel(String status) {
    final normalized = status.trim().toUpperCase();
    return normalized == 'PENDING' || normalized == 'NEW';
  }

  Future<void> _confirmCancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('إلغاء الطلب؟'),
          content: Text(
            'سيتم إلغاء الطلب #${order.displayOrderCode}. لا يمكن التراجع عن هذه العملية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _handleCancelOrder(order);
    }
  }

  Future<void> _handleCancelOrder(OrderModel order) async {
    setState(() => _isCancelling = true);
    try {
      await _apiService.cancelOrder(order.id);
      await _controller.refresh(orderId: order.id);
      if (!mounted) {
        return;
      }
      await CustomFloatingSnackBar.show(
        context,
        title: 'تم إلغاء الطلب',
        message: 'تم تحديث حالة الطلب بنجاح.',
        icon: Icons.cancel_outlined,
        accentColor: AppColors.danger,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await CustomFloatingSnackBar.show(
        context,
        title: 'تعذر إلغاء الطلب',
        message: error.toString(),
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }
}

class _OrderIdentityCard extends StatelessWidget {
  const _OrderIdentityCard({
    required this.order,
    required this.status,
  });

  final OrderModel order;
  final BhOrderStatusSpec status;

  @override
  Widget build(BuildContext context) {
    final cafeName =
        order.displayCafeName.isEmpty ? 'Bite Hub' : order.displayCafeName;

    return BhSurface(
      padding: const EdgeInsets.all(BhSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(BhRadius.md),
            child: SizedBox.square(
              dimension: 64,
              child: ProductImageView(
                imagePath: order.cafeLogo ?? 'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: BhSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cafeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'رقم الاستلام: ${order.displayOrderCode}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BhSpacing.sm),
          BhStatusPill(
            label: status.label,
            foreground: status.foregroundColor,
            background: status.backgroundColor,
            icon: status.icon,
          ),
        ],
      ),
    );
  }
}

class _SyncStatusStrip extends StatelessWidget {
  const _SyncStatusStrip({
    required this.state,
    required this.lastUpdatedAt,
  });

  final LiveOrderSyncState state;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final spec = _syncSpec(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(BhRadius.sm),
        border: Border.all(color: spec.border),
      ),
      child: Row(
        children: [
          Icon(spec.icon, size: 18, color: spec.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              spec.label,
              style: TextStyle(
                color: spec.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (lastUpdatedAt != null)
            Text(
              'آخر تحديث ${_formatTime(lastUpdatedAt!)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.status});

  final BhOrderStatusSpec status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BhSpacing.lg),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(BhRadius.lg),
        border: Border.all(
          color: status.foregroundColor.withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(BhRadius.md),
                ),
                child: Icon(
                  status.icon,
                  color: status.foregroundColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: BhSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!status.isCancelled) ...[
            const SizedBox(height: BhSpacing.lg),
            Row(
              children: List.generate(bhTrackingSteps.length, (index) {
                final active = index <= status.trackingIndex;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsetsDirectional.only(
                      end: index == bhTrackingSteps.length - 1 ? 0 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? status.foregroundColor : AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.status});

  final BhOrderStatusSpec status;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مراحل الطلب',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BhSpacing.lg),
          ...List.generate(bhTrackingSteps.length, (index) {
            final step = bhTrackingSteps[index];
            final reached = index <= status.trackingIndex;
            final current = index == status.trackingIndex;
            final isLast = index == bhTrackingSteps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 42,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: reached
                                ? status.foregroundColor
                                : AppColors.neutral100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: reached
                                  ? status.foregroundColor
                                  : AppColors.border,
                            ),
                          ),
                          child: Icon(
                            reached ? Icons.check_rounded : step.icon,
                            size: 17,
                            color: reached
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              color: index < status.trackingIndex
                                  ? status.foregroundColor
                                  : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: BhSpacing.sm),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom: isLast ? 0 : BhSpacing.md,
                      ),
                      padding: const EdgeInsets.all(BhSpacing.md),
                      decoration: BoxDecoration(
                        color: current
                            ? status.backgroundColor
                            : AppColors.neutral50,
                        borderRadius: BorderRadius.circular(BhRadius.sm),
                        border: Border.all(
                          color: current
                              ? status.foregroundColor.withValues(alpha: .24)
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.label,
                            style: TextStyle(
                              color: reached
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            current ? 'المرحلة الحالية' : step.caption,
                            style: TextStyle(
                              color: current
                                  ? status.foregroundColor
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CancelledOrderPanel extends StatelessWidget {
  const _CancelledOrderPanel();

  @override
  Widget build(BuildContext context) {
    return const BhSurface(
      color: Color(0xFFFFF7F7),
      borderColor: Color(0xFFFECACA),
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: AppColors.danger, size: 28),
          SizedBox(width: BhSpacing.md),
          Expanded(
            child: Text(
              'تم إيقاف رحلة هذا الطلب. لن تظهر مراحل تجهيز أو استلام لاحقة.',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final itemCount =
        order.items.fold<int>(0, (total, item) => total + item.quantity);

    return BhSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل الطلب',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BhSpacing.md),
          Row(
            children: [
              _OrderMetric(
                label: 'وقت الطلب',
                value: _formatTime(order.dateObject),
                icon: Icons.schedule_outlined,
              ),
              const SizedBox(width: BhSpacing.sm),
              _OrderMetric(
                label: 'عدد الأصناف',
                value: '$itemCount',
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(width: BhSpacing.sm),
              _OrderMetric(
                label: 'الإجمالي',
                value: '${order.totalPrice.toStringAsFixed(2)} د.ل',
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: BhSpacing.lg),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: BhSpacing.sm),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: BhSpacing.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(BhRadius.sm),
                      child: SizedBox.square(
                        dimension: 48,
                        child: ProductImageView(
                          imagePath:
                              item.productImage ?? 'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: BhSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (item.options.trim().isNotEmpty)
                            Text(
                              item.options,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.quantity} ×',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({
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
        padding: const EdgeInsets.all(BhSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(BhRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.brandBlue),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelOrderButton extends StatelessWidget {
  const _CancelOrderButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.danger,
                ),
              )
            : const Icon(Icons.cancel_outlined),
        label: Text(isLoading ? 'جاري الإلغاء...' : 'إلغاء الطلب'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BhRadius.md),
          ),
        ),
      ),
    );
  }
}

class _MissingOrderState extends StatelessWidget {
  const _MissingOrderState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: BhSpacing.md),
            Text(
              'لم يتم العثور على الطلب',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'ارجع إلى قائمة طلباتك واختر الطلب الذي تريد تتبعه.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_SyncVisualSpec _syncSpec(LiveOrderSyncState state) {
  switch (state) {
    case LiveOrderSyncState.realtime:
      return const _SyncVisualSpec(
        label: 'تحديث مباشر للحالة',
        icon: Icons.wifi_tethering_rounded,
        foreground: AppColors.success,
        background: Color(0xFFE6F4F1),
        border: Color(0xFFB7DED8),
      );
    case LiveOrderSyncState.connecting:
      return const _SyncVisualSpec(
        label: 'جاري ربط التحديث المباشر',
        icon: Icons.sync_rounded,
        foreground: AppColors.brandBlue,
        background: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
      );
    case LiveOrderSyncState.offline:
      return const _SyncVisualSpec(
        label: 'الاتصال متوقف، اسحب الشاشة للتحديث',
        icon: Icons.cloud_off_outlined,
        foreground: AppColors.danger,
        background: Color(0xFFFEE2E2),
        border: Color(0xFFFECACA),
      );
    case LiveOrderSyncState.stopped:
      return const _SyncVisualSpec(
        label: 'اكتمل تتبع هذا الطلب',
        icon: Icons.check_circle_outline_rounded,
        foreground: AppColors.textSecondary,
        background: AppColors.neutral100,
        border: AppColors.border,
      );
    case LiveOrderSyncState.polling:
      return const _SyncVisualSpec(
        label: 'تحديث تلقائي كل عدة ثوانٍ',
        icon: Icons.autorenew_rounded,
        foreground: AppColors.warning,
        background: Color(0xFFFFF7E6),
        border: Color(0xFFF6D7A5),
      );
  }
}

class _SyncVisualSpec {
  const _SyncVisualSpec({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
