import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/shell_v2_controller.dart';

class ShellDrawerV2 extends StatelessWidget {
  const ShellDrawerV2({
    super.key,
    required this.controller,
    required this.onSelectIndex,
    required this.onOpenCafeDashboard,
  });

  final ShellV2Controller controller;
  final ValueChanged<int> onSelectIndex;
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
                          AppColors.brandBlue,
                          Color(0xFF24A8E0),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandBlue.withValues(alpha: 0.18),
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
                                _initials(currentUser?.fullName ?? 'Bite Hub'),
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
                                    currentUser?.fullName ?? 'Bite Hub',
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
                      iconColor: AppColors.brandNavy,
                      textColor: AppColors.brandNavy,
                      backgroundColor: const Color(0xFFFFF4D6),
                      borderColor: const Color(0xFFF0B429),
                      onTap: onOpenCafeDashboard,
                    ),
                  ],
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
              Icon(icon, color: iconColor ?? AppColors.brandBlue),
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
