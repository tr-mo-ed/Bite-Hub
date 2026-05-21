import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/live_order_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/custom_floating_snack_bar.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/order_status_ui.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/pressable_scale.dart';

class LiveOrderTrackingScreenV2 extends StatefulWidget {
  const LiveOrderTrackingScreenV2({
    super.key,
    this.initialOrder,
    this.initialOrderId,
  });

  final OrderModel? initialOrder;
  final int? initialOrderId;

  @override
  State<LiveOrderTrackingScreenV2> createState() =>
      _LiveOrderTrackingScreenV2State();
}

class _LiveOrderTrackingScreenV2State extends State<LiveOrderTrackingScreenV2> {
  late final LiveOrderController _controller;
  final ApiService _apiService = ApiService();
  bool _isCancelling = false;
  String? _lastAnnouncedStatus;

  @override
  void initState() {
    super.initState();
    _controller = LiveOrderController();
    _controller.initialize(
      initialOrder: widget.initialOrder,
      initialOrderId: widget.initialOrderId,
    );
    _lastAnnouncedStatus = widget.initialOrder?.status.toUpperCase();
  }

  @override
  void dispose() {
    _controller.dispose();
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
            body: NetworkStatePanel(
              title: 'المتتبع الحي غير متاح الآن',
              message: _controller.errorMessage ??
                  'انقطع الاتصال وسنحاول إعادة الربط تلقائياً.',
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
            appBar: AppBar(title: const Text('التتبع الحي')),
            body: const Center(
              child: Text('لا يوجد طلب نشط حالياً للتتبع.'),
            ),
          );
        }

        final status = BhOrderStatusSpec.fromStatus(order.status);
        final progress = status.progress;
        final canCancel = _canCancel(order.status);
        _announceStatusIfNeeded(order);

        return Scaffold(
          appBar: AppBar(
            title: Text('تتبع الطلب #${order.orderNumber}'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              _buildHeroCard(order, progress),
              const SizedBox(height: 20),
              _FloatingCard(
                child: _buildTimeline(status),
              ),
              if (canCancel) ...[
                const SizedBox(height: 18),
                PressableScale(
                  onTap: _isCancelling ? null : () => _handleCancelOrder(order),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Center(
                      child: _isCancelling
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFFDC2626),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cancel_outlined,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'إلغاء الطلب',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _FloatingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل الطلب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${item.quantity}x',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'الإجمالي',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${order.totalPrice.toStringAsFixed(2)} د.ل',
                          style: const TextStyle(
                            color: Color(0xFF3559C7),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
      final style = _bannerStyleForStatus(currentStatus);
      CustomFloatingSnackBar.show(
        context,
        title: style.title,
        message: style.description,
        icon: style.icon,
        accentColor: style.foregroundColor,
      );
    });
  }

  Widget _buildHeroCard(OrderModel order, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF3559C7), Color(0xFF24A8E0)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3559C7).withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.displayCafeName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _controller.isSocketConnected
                          ? Icons.wifi_tethering_rounded
                          : Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _controller.isSocketConnected ? 'Live' : 'Reconnecting',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: .18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFDE68A)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).round()}% من الرحلة اكتملت',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BhOrderStatusSpec status) {
    final currentIndex = status.trackingIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'رحلة الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            BhStatusPill(
              label: status.label,
              foreground: status.foregroundColor,
              background: status.backgroundColor,
              icon: status.icon,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(bhTrackingSteps.length, (index) {
          final step = bhTrackingSteps[index];
          final reached = currentIndex >= index;
          final current = currentIndex == index;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == bhTrackingSteps.length - 1 ? 0 : BhSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(BhSpacing.md),
              decoration: BoxDecoration(
                color: current ? status.backgroundColor : AppColors.neutral50,
                borderRadius: BorderRadius.circular(BhRadius.sm),
                border: Border.all(
                  color: current ? status.backgroundColor : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: reached ? status.foregroundColor : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            reached ? status.foregroundColor : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      reached ? step.icon : Icons.circle_outlined,
                      size: 16,
                      color: reached ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: BhSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight:
                                reached ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.caption,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool _canCancel(String status) {
    final normalized = status.trim().toUpperCase();
    return normalized == 'PENDING' || normalized == 'NEW';
  }

  BhOrderStatusSpec _bannerStyleForStatus(String status) {
    return BhOrderStatusSpec.fromStatus(status);
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
        title: 'تم استلام طلب الإلغاء',
        message: 'أرسلنا طلب إلغاء الطلب بنجاح.',
        icon: Icons.cancel_schedule_send_rounded,
        accentColor: const Color(0xFFDC2626),
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
        accentColor: const Color(0xFFDC2626),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
