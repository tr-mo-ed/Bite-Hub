import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/live_order_controller.dart';
import 'package:bitehub_app/app/presentation_v2/screens/legal/usage_policy_screen.dart';
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
            title: const Text('تتبع الطلب'),
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
                _CurrentStatusCard(
                  status: status,
                  orderCode: order.displayOrderCode,
                  state: _controller.syncState,
                  lastUpdatedAt: _controller.lastUpdatedAt,
                ),
                const SizedBox(height: BhSpacing.md),
                if (status.isCancelled)
                  _CancelledOrderPanel(order: order)
                else
                  _OrderTimeline(status: status),
                const SizedBox(height: BhSpacing.md),
                _CancellationPolicyCard(
                  order: order,
                  canCancel: _canCancel(order.status),
                  isLoading: _isCancelling,
                  onCancel: () => _confirmCancelOrder(order),
                  onOpenPolicy: _openUsagePolicy,
                ),
                const SizedBox(height: BhSpacing.md),
                _OrderDetailsCard(order: order),
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

  void _openUsagePolicy() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const UsagePolicyScreen()),
    );
  }

  Future<void> _confirmCancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.cancel_outlined,
            color: AppColors.danger,
            size: 32,
          ),
          title: const Text('تأكيد إلغاء الطلب'),
          content: Text(
            'سيتم إلغاء الطلب #${order.displayOrderCode}. '
            '${_isWalletPayment(order) ? 'سيعاد المبلغ تلقائياً إلى محفظتك بعد نجاح الإلغاء.' : 'هذا الطلب غير مدفوع إلكترونياً، لذلك لا يوجد استرداد للمحفظة.'}',
            textAlign: TextAlign.center,
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

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({
    required this.status,
    required this.orderCode,
    required this.state,
    required this.lastUpdatedAt,
  });

  final BhOrderStatusSpec status;
  final String orderCode;
  final LiveOrderSyncState state;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final sync = _syncSpec(state);
    final nextStep = _nextStepLabel(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status.icon,
                  color: status.foregroundColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الطلب #$orderCode',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            status.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          if (nextStep != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Text(
                    'التالي',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nextStep,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!status.isCancelled) ...[
            const SizedBox(height: 18),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(sync.icon, size: 16, color: sync.foreground),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  sync.label,
                  style: TextStyle(
                    color: sync.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (lastUpdatedAt != null)
                Text(
                  _formatTime(lastUpdatedAt!),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
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
  const _CancelledOrderPanel({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      color: const Color(0xFFFFF8F7),
      borderColor: const Color(0xFFF1D0CC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.block_rounded, color: AppColors.danger, size: 25),
              SizedBox(width: BhSpacing.sm),
              Text(
                'توقف تنفيذ الطلب',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isWalletPayment(order)
                ? 'تم إلغاء الطلب. يعاد المبلغ إلى محفظتك تلقائياً، ويمكنك مراجعته في سجل عمليات المحفظة.'
                : 'تم إلغاء الطلب ولن ينتقل إلى التجهيز أو الاستلام. لا يوجد استرداد إلكتروني لهذا الطلب.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.5,
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
          if (order.notes.trim().isNotEmpty) ...[
            const SizedBox(height: BhSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BhSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(BhRadius.sm),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملاحظتك للمقهى',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.notes,
                    style: const TextStyle(
                      color: Color(0xFF713F12),
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

class _CancellationPolicyCard extends StatelessWidget {
  const _CancellationPolicyCard({
    required this.order,
    required this.canCancel,
    required this.isLoading,
    required this.onCancel,
    required this.onOpenPolicy,
  });

  final OrderModel order;
  final bool canCancel;
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onOpenPolicy;

  @override
  Widget build(BuildContext context) {
    final isTerminal = const {'COMPLETED', 'CANCELLED'}
        .contains(order.status.trim().toUpperCase());
    final title = canCancel
        ? 'يمكنك الإلغاء الآن'
        : isTerminal
            ? 'سياسة هذا الطلب'
            : 'بدأ المقهى تنفيذ الطلب';
    final message = canCancel
        ? _isWalletPayment(order)
            ? 'الإلغاء متاح قبل قبول المقهى، وسيعاد المبلغ إلى محفظتك تلقائياً.'
            : 'الإلغاء متاح قبل قبول المقهى. هذا الطلب غير مدفوع إلكترونياً.'
        : isTerminal
            ? 'يمكنك مراجعة سياسة الطلب والدفع والاسترداد في أي وقت.'
            : 'بعد قبول المقهى لا يمكن الإلغاء ذاتياً من التطبيق. تواصل مع المقهى أو الإدارة عند وجود مشكلة.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: canCancel ? const Color(0xFFFFFBF5) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canCancel ? const Color(0xFFF1D9B4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canCancel
                      ? const Color(0xFFFFF0DA)
                      : AppColors.neutral100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  canCancel
                      ? Icons.info_outline_rounded
                      : Icons.policy_outlined,
                  color:
                      canCancel ? AppColors.warning : AppColors.textSecondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: onOpenPolicy,
                child: const Text('عرض السياسة كاملة'),
              ),
              if (canCancel) ...[
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onCancel,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.danger,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    isLoading ? 'جاري الإلغاء...' : 'إلغاء الطلب',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Color(0xFFE7B8B8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
        background: Color(0xFFEAF4EF),
        border: Color(0xFFB9DDD2),
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

String? _nextStepLabel(BhOrderStatusSpec status) {
  if (status.isTerminal || status.isCancelled) {
    return null;
  }
  final nextIndex = status.trackingIndex + 1;
  if (nextIndex < 0 || nextIndex >= bhTrackingSteps.length) {
    return null;
  }
  return bhTrackingSteps[nextIndex].label;
}

bool _isWalletPayment(OrderModel order) {
  final paymentMethod = order.paymentMethod.trim().toUpperCase();
  return paymentMethod == 'WALLET' || paymentMethod == 'NFC';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
