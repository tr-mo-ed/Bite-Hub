import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';

class BhTrackingStep {
  const BhTrackingStep({
    required this.key,
    required this.label,
    required this.caption,
    required this.icon,
  });

  final String key;
  final String label;
  final String caption;
  final IconData icon;
}

class BhOrderStatusSpec {
  const BhOrderStatusSpec({
    required this.status,
    required this.label,
    required this.title,
    required this.description,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.progress,
    required this.trackingIndex,
  });

  final String status;
  final String label;
  final String title;
  final String description;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final double progress;
  final int trackingIndex;

  bool get isLive => !const {'COMPLETED', 'CANCELLED'}.contains(status);

  factory BhOrderStatusSpec.fromStatus(String rawStatus) {
    final status = rawStatus.trim().toUpperCase();
    switch (status) {
      case 'ACCEPTED':
        return const BhOrderStatusSpec(
          status: 'ACCEPTED',
          label: 'مقبول',
          title: 'تم قبول الطلب',
          description: 'استلمنا الطلب وبدأت معالجته داخل المقهى.',
          icon: Icons.thumb_up_alt_outlined,
          foregroundColor: AppColors.brandBlue,
          backgroundColor: Color(0xFFEFF6FF),
          progress: 0.36,
          trackingIndex: 1,
        );
      case 'PREPARING':
        return const BhOrderStatusSpec(
          status: 'PREPARING',
          label: 'قيد التحضير',
          title: 'الطلب قيد التحضير',
          description: 'يجري تجهيز الطلب الآن.',
          icon: Icons.local_fire_department_outlined,
          foregroundColor: AppColors.warning,
          backgroundColor: Color(0xFFFFF7E6),
          progress: 0.62,
          trackingIndex: 2,
        );
      case 'READY':
        return const BhOrderStatusSpec(
          status: 'READY',
          label: 'جاهز',
          title: 'الطلب جاهز للاستلام',
          description: 'يمكنك الآن استلام الطلب من نقطة التسليم.',
          icon: Icons.inventory_2_outlined,
          foregroundColor: AppColors.success,
          backgroundColor: Color(0xFFE6F4F1),
          progress: 0.86,
          trackingIndex: 3,
        );
      case 'COMPLETED':
        return const BhOrderStatusSpec(
          status: 'COMPLETED',
          label: 'مكتمل',
          title: 'تم تسليم الطلب',
          description: 'اكتملت الرحلة وتم تسليم الطلب بنجاح.',
          icon: Icons.check_circle_outline_rounded,
          foregroundColor: AppColors.success,
          backgroundColor: Color(0xFFE6F4F1),
          progress: 1,
          trackingIndex: 4,
        );
      case 'CANCELLED':
        return const BhOrderStatusSpec(
          status: 'CANCELLED',
          label: 'ملغى',
          title: 'تم إلغاء الطلب',
          description: 'تم تحديث حالة الطلب إلى ملغى.',
          icon: Icons.cancel_outlined,
          foregroundColor: AppColors.danger,
          backgroundColor: Color(0xFFFEE2E2),
          progress: 0,
          trackingIndex: 0,
        );
      case 'PENDING':
      default:
        return const BhOrderStatusSpec(
          status: 'PENDING',
          label: 'قيد المراجعة',
          title: 'تم استلام الطلب',
          description: 'ننتظر تأكيد المقهى للبدء في التحضير.',
          icon: Icons.schedule_outlined,
          foregroundColor: AppColors.textSecondary,
          backgroundColor: AppColors.neutral100,
          progress: 0.18,
          trackingIndex: 0,
        );
    }
  }
}

const List<BhTrackingStep> bhTrackingSteps = [
  BhTrackingStep(
    key: 'PENDING',
    label: 'استلام الطلب',
    caption: 'تم تسجيل الطلب في النظام',
    icon: Icons.receipt_long_outlined,
  ),
  BhTrackingStep(
    key: 'ACCEPTED',
    label: 'قبول الطلب',
    caption: 'المقهى أكد الطلب',
    icon: Icons.thumb_up_alt_outlined,
  ),
  BhTrackingStep(
    key: 'PREPARING',
    label: 'قيد التحضير',
    caption: 'يجري تجهيز الأصناف الآن',
    icon: Icons.local_fire_department_outlined,
  ),
  BhTrackingStep(
    key: 'READY',
    label: 'جاهز للاستلام',
    caption: 'الطلب بانتظارك',
    icon: Icons.inventory_2_outlined,
  ),
  BhTrackingStep(
    key: 'COMPLETED',
    label: 'تم التسليم',
    caption: 'اكتملت الرحلة',
    icon: Icons.check_circle_outline_rounded,
  ),
];
