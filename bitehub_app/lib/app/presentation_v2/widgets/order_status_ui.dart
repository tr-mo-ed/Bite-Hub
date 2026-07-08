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

  bool get isCancelled => status == 'CANCELLED';
  bool get isTerminal => const {'COMPLETED', 'CANCELLED'}.contains(status);
  bool get isLive => !isTerminal;

  factory BhOrderStatusSpec.fromStatus(String rawStatus) {
    final status = rawStatus.trim().toUpperCase();
    switch (status) {
      case 'ACCEPTED':
        return const BhOrderStatusSpec(
          status: 'ACCEPTED',
          label: 'تم القبول',
          title: 'وافق المقهى على طلبك',
          description: 'تم اعتماد الطلب وسينتقل إلى التجهيز خلال لحظات.',
          icon: Icons.thumb_up_alt_outlined,
          foregroundColor: AppColors.brandBlue,
          backgroundColor: Color(0xFFEFF6FF),
          progress: .4,
          trackingIndex: 1,
        );
      case 'PREPARING':
        return const BhOrderStatusSpec(
          status: 'PREPARING',
          label: 'قيد التجهيز',
          title: 'يتم تجهيز طلبك الآن',
          description: 'فريق المقهى يعمل على تجهيز الأصناف المطلوبة.',
          icon: Icons.soup_kitchen_outlined,
          foregroundColor: AppColors.warning,
          backgroundColor: Color(0xFFFFF7E6),
          progress: .6,
          trackingIndex: 2,
        );
      case 'READY':
        return const BhOrderStatusSpec(
          status: 'READY',
          label: 'جاهز للاستلام',
          title: 'طلبك جاهز',
          description: 'توجه إلى نقطة المقهى وأظهر رقم الطلب عند الاستلام.',
          icon: Icons.inventory_2_outlined,
          foregroundColor: AppColors.success,
          backgroundColor: Color(0xFFE6F4F1),
          progress: .8,
          trackingIndex: 3,
        );
      case 'COMPLETED':
        return const BhOrderStatusSpec(
          status: 'COMPLETED',
          label: 'تم التسليم',
          title: 'اكتمل الطلب',
          description: 'تم تسجيل تسليم الطلب بنجاح.',
          icon: Icons.check_circle_outline_rounded,
          foregroundColor: AppColors.success,
          backgroundColor: Color(0xFFE6F4F1),
          progress: 1,
          trackingIndex: 4,
        );
      case 'CANCELLED':
        return const BhOrderStatusSpec(
          status: 'CANCELLED',
          label: 'ملغي',
          title: 'تم إلغاء الطلب',
          description: 'هذا الطلب متوقف ولن ينتقل إلى أي مرحلة أخرى.',
          icon: Icons.cancel_outlined,
          foregroundColor: AppColors.danger,
          backgroundColor: Color(0xFFFEE2E2),
          progress: 0,
          trackingIndex: -1,
        );
      case 'NEW':
      case 'PENDING':
      default:
        return const BhOrderStatusSpec(
          status: 'PENDING',
          label: 'بانتظار القبول',
          title: 'وصل طلبك إلى المقهى',
          description: 'بانتظار قبول المقهى للطلب قبل بدء التجهيز.',
          icon: Icons.schedule_outlined,
          foregroundColor: AppColors.textSecondary,
          backgroundColor: AppColors.neutral100,
          progress: .2,
          trackingIndex: 0,
        );
    }
  }
}

const List<BhTrackingStep> bhTrackingSteps = [
  BhTrackingStep(
    key: 'PENDING',
    label: 'استلام الطلب',
    caption: 'تم تسجيل الطلب وإرساله إلى المقهى',
    icon: Icons.receipt_long_outlined,
  ),
  BhTrackingStep(
    key: 'ACCEPTED',
    label: 'قبول الطلب',
    caption: 'وافق المقهى على تنفيذ الطلب',
    icon: Icons.thumb_up_alt_outlined,
  ),
  BhTrackingStep(
    key: 'PREPARING',
    label: 'تجهيز الطلب',
    caption: 'يتم تجهيز الأصناف المطلوبة',
    icon: Icons.soup_kitchen_outlined,
  ),
  BhTrackingStep(
    key: 'READY',
    label: 'جاهز للاستلام',
    caption: 'يمكنك التوجه إلى نقطة المقهى',
    icon: Icons.inventory_2_outlined,
  ),
  BhTrackingStep(
    key: 'COMPLETED',
    label: 'تم التسليم',
    caption: 'اكتملت رحلة الطلب',
    icon: Icons.check_circle_outline_rounded,
  ),
];
