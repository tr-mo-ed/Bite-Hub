import 'package:flutter/material.dart';

import 'package:bitehub_app/app/data/models/college_model.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/shell_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/product_image_view.dart';

class ShellDrawerV2 extends StatelessWidget {
  const ShellDrawerV2({
    super.key,
    required this.controller,
    required this.onSelectIndex,
    required this.onSelectCafe,
    required this.onOpenCafeDashboard,
  });

  final ShellV2Controller controller;
  final ValueChanged<int> onSelectIndex;
  final ValueChanged<CollegeModel> onSelectCafe;
  final VoidCallback onOpenCafeDashboard;

  @override
  Widget build(BuildContext context) {
    final currentUser = controller.authProvider.currentUser;

    return Drawer(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF7F9FD),
                    Colors.white,
                  ],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1B2559),
                          Color(0xFF3559C7),
                          Color(0xFF24A8E0),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF3559C7).withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.16),
                              child: Text(
                                _initials(currentUser?.fullName ?? 'BYTE HUB'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser?.fullName ?? 'BYTE HUB',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentUser?.email ?? 'student@bytehub.app',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFD54F).withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFFE082)
                                  .withValues(alpha: .45),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: Color(0xFFFFE082),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'لوحة الطلبات السريعة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel('التنقل'),
                  _DrawerTile(
                    icon: Icons.home_rounded,
                    title: 'الرئيسية',
                    onTap: () => onSelectIndex(0),
                  ),
                  _DrawerTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'طلباتي',
                    onTap: () => onSelectIndex(1),
                  ),
                  _DrawerTile(
                    icon: Icons.shopping_cart_rounded,
                    title: 'السلة',
                    onTap: () => onSelectIndex(2),
                  ),
                  _DrawerTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'المحفظة',
                    onTap: () => onSelectIndex(3),
                  ),
                  _DrawerTile(
                    icon: Icons.person_rounded,
                    title: 'حسابي',
                    onTap: () => onSelectIndex(4),
                  ),
                  if (controller.authProvider.hasCafeDashboardAccess) ...[
                    const SizedBox(height: 6),
                    const _SectionLabel('إدارة المقهى'),
                    _DrawerTile(
                      icon: Icons.dashboard_rounded,
                      title: 'لوحة تحكم المقهى',
                      subtitle: controller
                              .authProvider.currentUser?.managedCafeName ??
                          'الدخول إلى المنظومة الصغيرة',
                      iconColor: const Color(0xFF123C7A),
                      textColor: const Color(0xFF123C7A),
                      backgroundColor: const Color(0xFFFFF4D6),
                      borderColor: const Color(0xFFF0B429),
                      onTap: onOpenCafeDashboard,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: _SectionLabel('المقاهي المتاحة')),
                      IconButton(
                        onPressed: controller.refreshCafes,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFFE0B42C),
                        ),
                        tooltip: 'تحديث القائمة',
                      ),
                    ],
                  ),
                  if (controller.isLoadingCafes)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (controller.cafes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFFE0A800),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'لا توجد مقاهٍ متاحة حالياً',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (controller.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              controller.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    ...controller.cafes.map(
                      (cafe) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => onSelectCafe(cafe),
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.035),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: ProductImageView(
                                      imagePath: cafe.image ??
                                          'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cafe.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    iconColor: Colors.redAccent,
                    textColor: Colors.redAccent,
                    onTap: controller.logout,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'BH';
    }
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1B2559),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Color? iconColor;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? const Color(0xFF3559C7)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: (textColor ?? const Color(0xFF64748B))
                              .withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
