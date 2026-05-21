import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/notification_model.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/presentation_v2/screens/orders/live_order_tracking_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/order_status_ui.dart';

class NotificationCenterSheet extends StatelessWidget {
  const NotificationCenterSheet({
    super.key,
    required this.hostContext,
  });

  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: BhSectionHeader(
                        title: 'الإشعارات',
                        subtitle: 'آخر تحديثات الطلبات في مكان واحد',
                      ),
                    ),
                    if (provider.unreadCount > 0)
                      TextButton(
                        onPressed: provider.markAllRead,
                        child: const Text('تحديد الكل كمقروء'),
                      ),
                  ],
                ),
                const SizedBox(height: BhSpacing.md),
                if (provider.items.isEmpty)
                  const Expanded(child: _NotificationEmptyState())
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: provider.items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: BhSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = provider.items[index];
                        return _NotificationRow(
                          item: item,
                          onTap: () => _handleNotificationTap(
                            context,
                            provider,
                            item,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationProvider provider,
    NotificationItem item,
  ) async {
    await provider.markAsRead(item.id);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();

    if (item.orderId == null) {
      return;
    }

    await Navigator.of(hostContext).push(
      MaterialPageRoute(
        builder: (_) => LiveOrderTrackingScreenV2(
          initialOrderId: item.orderId,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = BhOrderStatusSpec.fromStatus(item.status);
    final isUnread = !item.isRead;

    return BhSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(BhSpacing.md),
      color: isUnread ? Colors.white : AppColors.neutral50,
      borderColor: isUnread ? status.backgroundColor : AppColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.backgroundColor,
              borderRadius: BorderRadius.circular(BhRadius.sm),
            ),
            child: Icon(
              status.icon,
              size: 18,
              color: status.foregroundColor,
            ),
          ),
          const SizedBox(width: BhSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(item.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    BhStatusPill(
                      label: status.label,
                      foreground: status.foregroundColor,
                      background: status.backgroundColor,
                      icon: status.icon,
                    ),
                    if (item.orderId != null) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'اضغط لفتح التتبع',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUnread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: AppColors.brandBlue,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: BhSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: BhSpacing.md),
            Text(
              'لا توجد إشعارات حالياً',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'عند تغيّر حالة الطلب ستظهر هنا بشكل مرتب.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(String raw) {
  try {
    final local = DateTime.parse(raw).toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) {
      return 'الآن';
    }
    if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} د';
    }
    if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} س';
    }
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}
